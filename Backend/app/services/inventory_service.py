"""Inventory on MongoDB: items, suppliers, a stock ledger and serial-number tracking.

Collections
  inventory_items  one document per material; ``stock_qty`` is the live count
  suppliers        vendors stock is bought from
  stock_movements  append-only ledger (in / out / adjust / return); names are
                   snapshotted so history stays readable after renames
  serial_items     one document per serialised unit (panel, inverter, ...)

Consistency rules
  * Stock counts only change through conditional ``$inc`` updates, so two
    people issuing the last units at the same time cannot drive stock negative.
  * Serial numbers are stored upper-cased and are unique across all items
    (the service team looks them up without knowing the item).
  * For serialised items ``stock_qty`` always equals the number of serials
    ``in_stock``; manual count adjustments are refused for them.
"""
import calendar
import re
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional

from pymongo import ASCENDING, ReturnDocument
from pymongo.errors import DuplicateKeyError

from app.core.exceptions import BadRequestException, ConflictException, NotFoundException, ValidationException
from app.db.mongo import get_mongo_db
from app.models.enums import SerialStatus, StockMovementType
from app.schemas.inventory import (
    InventoryItemCreate,
    InventoryItemUpdate,
    SerialStatusUpdate,
    StockAdjustRequest,
    StockInRequest,
    StockOutRequest,
    SupplierCreate,
    SupplierUpdate,
)

ITEMS, SUPPLIERS, MOVES, SERIALS = "inventory_items", "suppliers", "stock_movements", "serial_items"
_LIVE = {"is_deleted": {"$ne": True}}
_indexes_ready = False


def _add_months(dt: datetime, months: int) -> datetime:
    """Add calendar months, clamping the day to the target month's length."""
    month_index = dt.month - 1 + months
    year = dt.year + month_index // 12
    month = month_index % 12 + 1
    day = min(dt.day, calendar.monthrange(year, month)[1])
    return dt.replace(year=year, month=month, day=day)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None or dt.tzinfo is not None:
        return dt
    return dt.replace(tzinfo=timezone.utc)


def _db():
    global _indexes_ready
    db = get_mongo_db()
    if db is None:
        raise BadRequestException("Inventory is temporarily unavailable. Please try again.")
    if not _indexes_ready:
        db[SERIALS].create_index([("serial_no", ASCENDING)], unique=True, name="serial_no_unique")
        db[SERIALS].create_index([("item_id", ASCENDING), ("status", ASCENDING)])
        db[MOVES].create_index([("moved_at", -1)])
        db[MOVES].create_index([("customer_id", ASCENDING)])
        _indexes_ready = True
    return db


def _clean_serials(raw: Optional[Iterable[str]]) -> List[str]:
    return [s.strip().upper() for s in (raw or []) if s and s.strip()]


def _out(doc: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if doc is None:
        return None
    d = dict(doc)
    d["id"] = str(d.pop("_id"))
    return d


def _user_label(user: Any) -> Dict[str, Any]:
    return {"moved_by": str(getattr(user, "id", "")), "mover_name": getattr(user, "name", None)}


def _customer(db, customer_id: str) -> Dict[str, Any]:
    cid = str(customer_id)
    cust = db["customers"].find_one({"$or": [{"_id": cid}, {"id": cid}], "is_deleted": {"$ne": True}})
    if not cust:
        raise NotFoundException("Customer not found.")
    return cust


def _record(db, item: Dict[str, Any], type_: StockMovementType, qty: int, user: Any, **extra) -> Dict[str, Any]:
    mid = str(uuid.uuid4())
    move = {
        "_id": mid, "item_id": str(item["_id"]), "item_name": item.get("name"), "type": type_.value, "qty": int(qty),
        "supplier_id": None, "supplier_name": None, "customer_id": None, "customer_name": None,
        "unit_cost": None, "invoice_no": None, "note": None, "serial_numbers": [],
        "moved_at": _now(), **_user_label(user),
    }
    move.update({k: v for k, v in extra.items() if v is not None})
    db[MOVES].insert_one(move)
    return _out(move)


class InventoryService:
    # ------------------ SUPPLIERS ------------------
    @staticmethod
    def create_supplier(data: SupplierCreate) -> Dict[str, Any]:
        now = _now()
        sid = str(uuid.uuid4())
        doc = {"_id": sid, **{k: (v.strip() if isinstance(v, str) else v) for k, v in data.model_dump().items()},
               "is_active": True, "is_deleted": False, "created_at": now, "updated_at": now}
        _db()[SUPPLIERS].insert_one(doc)
        return _out(doc)

    @staticmethod
    def _supplier_doc(supplier_id: str) -> Dict[str, Any]:
        doc = _db()[SUPPLIERS].find_one({"_id": str(supplier_id), **_LIVE})
        if not doc:
            raise NotFoundException("Supplier not found.")
        return doc

    @staticmethod
    def get_supplier(supplier_id: str) -> Dict[str, Any]:
        return _out(InventoryService._supplier_doc(supplier_id))

    @staticmethod
    def list_suppliers(is_active: Optional[bool] = None, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        query: Dict[str, Any] = dict(_LIVE)
        if is_active is not None:
            query["is_active"] = is_active
        cur = _db()[SUPPLIERS].find(query).sort("name", ASCENDING).skip(offset).limit(limit)
        return [_out(d) for d in cur]

    @staticmethod
    def update_supplier(supplier_id: str, data: SupplierUpdate) -> Dict[str, Any]:
        InventoryService._supplier_doc(supplier_id)
        updates = {k: (v.strip() if isinstance(v, str) else v) for k, v in data.model_dump(exclude_unset=True).items()}
        updates["updated_at"] = _now()
        doc = _db()[SUPPLIERS].find_one_and_update({"_id": str(supplier_id)}, {"$set": updates},
                                                   return_document=ReturnDocument.AFTER)
        return _out(doc)

    @staticmethod
    def delete_supplier(supplier_id: str) -> None:
        InventoryService._supplier_doc(supplier_id)
        _db()[SUPPLIERS].update_one({"_id": str(supplier_id)},
                                    {"$set": {"is_deleted": True, "is_active": False, "updated_at": _now()}})

    # ------------------ ITEMS ------------------
    @staticmethod
    def create_item(data: InventoryItemCreate) -> Dict[str, Any]:
        now = _now()
        iid = str(uuid.uuid4())
        fields = data.model_dump(mode="json")
        for k in ("name", "brand", "model"):
            if isinstance(fields.get(k), str):
                fields[k] = fields[k].strip() or None
        if not fields.get("name"):
            raise ValidationException("Item name is required.")
        doc = {"_id": iid, **fields, "stock_qty": 0, "is_active": True, "is_deleted": False,
               "created_at": now, "updated_at": now}
        _db()[ITEMS].insert_one(doc)
        return _out(doc)

    @staticmethod
    def _item_doc(item_id: str) -> Dict[str, Any]:
        doc = _db()[ITEMS].find_one({"_id": str(item_id), **_LIVE})
        if not doc:
            raise NotFoundException("Inventory item not found.")
        return doc

    @staticmethod
    def get_item(item_id: str) -> Dict[str, Any]:
        return _out(InventoryService._item_doc(item_id))

    @staticmethod
    def list_items(category: Optional[str] = None, low_stock: bool = False, search: Optional[str] = None,
                   is_active: Optional[bool] = None, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        clauses: List[Dict[str, Any]] = [dict(_LIVE)]
        if category:
            clauses.append({"category": str(getattr(category, "value", category))})
        if is_active is not None:
            clauses.append({"is_active": is_active})
        if low_stock:
            clauses.append({"$expr": {"$lte": ["$stock_qty", "$min_stock"]}})
        if search:
            rx = {"$regex": re.escape(search.strip()), "$options": "i"}
            clauses.append({"$or": [{"name": rx}, {"brand": rx}, {"model": rx}]})
        cur = _db()[ITEMS].find({"$and": clauses}).sort("name", ASCENDING).skip(offset).limit(limit)
        return [_out(d) for d in cur]

    @staticmethod
    def get_low_stock_items() -> List[Dict[str, Any]]:
        items = [i for i in _db()[ITEMS].find({**_LIVE, "is_active": True})
                 if int(i.get("stock_qty", 0)) <= int(i.get("min_stock", 0))]
        items.sort(key=lambda i: int(i.get("min_stock", 0)) - int(i.get("stock_qty", 0)), reverse=True)
        return [{**_out(i), "shortage": max(0, int(i.get("min_stock", 0)) - int(i.get("stock_qty", 0)))} for i in items]

    @staticmethod
    def update_item(item_id: str, data: InventoryItemUpdate) -> Dict[str, Any]:
        InventoryService._item_doc(item_id)
        updates = data.model_dump(mode="json", exclude_unset=True)
        for k in ("name", "brand", "model"):
            if isinstance(updates.get(k), str):
                updates[k] = updates[k].strip() or None
        if "name" in updates and not updates["name"]:
            raise ValidationException("Item name is required.")
        updates["updated_at"] = _now()
        doc = _db()[ITEMS].find_one_and_update({"_id": str(item_id)}, {"$set": updates},
                                               return_document=ReturnDocument.AFTER)
        return _out(doc)

    @staticmethod
    def delete_item(item_id: str) -> None:
        item = InventoryService._item_doc(item_id)
        if int(item.get("stock_qty", 0)) > 0:
            raise BadRequestException("This item still has stock. Issue or adjust it to zero before deleting.")
        _db()[ITEMS].update_one({"_id": item["_id"]}, {"$set": {"is_deleted": True, "is_active": False, "updated_at": _now()}})

    # ------------------ STOCK MOVEMENTS ------------------
    @staticmethod
    def stock_in(data: StockInRequest, user: Any) -> Dict[str, Any]:
        db = _db()
        item = InventoryService._item_doc(data.item_id)
        supplier = InventoryService._supplier_doc(data.supplier_id) if data.supplier_id else None
        serials: List[str] = []
        if item.get("has_serial"):
            serials = _clean_serials(data.serial_numbers)
            if len(serials) != data.qty:
                raise ValidationException(
                    f"'{item['name']}' needs exactly {data.qty} serial numbers, received {len(serials)}.")
            if len(set(serials)) != len(serials):
                raise ValidationException("Duplicate serial numbers in this delivery.")
            existing = [d["serial_no"] for d in db[SERIALS].find({"serial_no": {"$in": serials}}, {"serial_no": 1})]
            if existing:
                raise ConflictException(f"Serial number(s) already registered: {', '.join(sorted(existing))}")
            now = _now()
            docs = [{
                "_id": str(uuid.uuid4()), "item_id": str(item["_id"]), "item_name": item["name"], "serial_no": s,
                "status": SerialStatus.IN_STOCK.value, "customer_id": None, "customer_name": None,
                "supplier_id": str(supplier["_id"]) if supplier else None,
                "supplier_name": supplier.get("name") if supplier else None,
                "warranty_months": data.warranty_months, "warranty_until": None, "installed_on": None,
                "created_at": now, "updated_at": now,
            } for s in serials]
            try:
                db[SERIALS].insert_many(docs, ordered=True)
            except DuplicateKeyError:
                # Lost a race with another delivery: undo what we inserted.
                db[SERIALS].delete_many({"_id": {"$in": [d["_id"] for d in docs]}, "status": SerialStatus.IN_STOCK.value})
                raise ConflictException("One or more serial numbers were registered at the same time. Please retry.")
        db[ITEMS].update_one({"_id": item["_id"]}, {"$inc": {"stock_qty": data.qty}, "$set": {"updated_at": _now()}})
        return _record(
            db, item, StockMovementType.IN, data.qty, user,
            supplier_id=str(supplier["_id"]) if supplier else None,
            supplier_name=supplier.get("name") if supplier else None,
            unit_cost=data.unit_cost, invoice_no=(data.invoice_no or "").strip() or None,
            note=(data.note or "").strip() or None, serial_numbers=serials,
        )

    @staticmethod
    def stock_out(data: StockOutRequest, user: Any) -> Dict[str, Any]:
        db = _db()
        item = InventoryService._item_doc(data.item_id)
        customer = _customer(db, data.customer_id)
        cid, cname = str(customer["_id"]), customer.get("name")
        serials: List[str] = []
        claimed: List[str] = []
        now = _now()
        if item.get("has_serial"):
            serials = _clean_serials(data.serial_numbers)
            if len(serials) != data.qty or len(set(serials)) != len(serials):
                raise ValidationException(
                    f"Select exactly {data.qty} different serial numbers of '{item['name']}' to issue.")
            # Claim each serial atomically; roll back if any is not in stock.
            for s in serials:
                doc = db[SERIALS].find_one_and_update(
                    {"serial_no": s, "item_id": str(item["_id"]), "status": SerialStatus.IN_STOCK.value},
                    {"$set": {"status": SerialStatus.INSTALLED.value, "customer_id": cid, "customer_name": cname,
                              "installed_on": now, "updated_at": now}},
                    return_document=ReturnDocument.AFTER,
                )
                if not doc:
                    InventoryService._release(db, claimed)
                    raise ValidationException(f"Serial number {s} is not in stock for '{item['name']}'.")
                claimed.append(s)
                if int(doc.get("warranty_months") or 0) > 0:
                    db[SERIALS].update_one({"_id": doc["_id"]},
                                           {"$set": {"warranty_until": _add_months(now, int(doc["warranty_months"]))}})
        res = db[ITEMS].update_one(
            {"_id": item["_id"], "stock_qty": {"$gte": data.qty}},
            {"$inc": {"stock_qty": -data.qty}, "$set": {"updated_at": now}},
        )
        if res.modified_count != 1:
            InventoryService._release(db, claimed)
            latest = db[ITEMS].find_one({"_id": item["_id"]}) or item
            raise ValidationException(
                f"Not enough stock of '{item['name']}'. Available: {int(latest.get('stock_qty', 0))}, requested: {data.qty}.")
        return _record(db, item, StockMovementType.OUT, data.qty, user, customer_id=cid, customer_name=cname,
                       note=(data.note or "").strip() or None, serial_numbers=serials)

    @staticmethod
    def _release(db, serials: List[str]) -> None:
        if serials:
            db[SERIALS].update_many({"serial_no": {"$in": serials}}, {"$set": {
                "status": SerialStatus.IN_STOCK.value, "customer_id": None, "customer_name": None,
                "installed_on": None, "warranty_until": None, "updated_at": _now()}})

    @staticmethod
    def adjust_stock(data: StockAdjustRequest, user: Any) -> Dict[str, Any]:
        db = _db()
        item = InventoryService._item_doc(data.item_id)
        if item.get("has_serial"):
            raise BadRequestException(
                "Stock of serial-tracked items follows their serial numbers. Use Stock In, Issue, "
                "or mark a serial defective/returned instead.")
        old = db[ITEMS].find_one_and_update({"_id": item["_id"]},
                                            {"$set": {"stock_qty": data.new_qty, "updated_at": _now()}})
        old_qty = int((old or item).get("stock_qty", 0))
        return _record(db, item, StockMovementType.ADJUST, data.new_qty - old_qty, user,
                       note=f"Adjusted from {old_qty} to {data.new_qty}: {data.note.strip()}")

    @staticmethod
    def list_movements(item_id: Optional[str] = None, customer_id: Optional[str] = None,
                       supplier_id: Optional[str] = None, movement_type: Optional[str] = None,
                       limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        query: Dict[str, Any] = {}
        if item_id:
            query["item_id"] = str(item_id)
        if customer_id:
            query["customer_id"] = str(customer_id)
        if supplier_id:
            query["supplier_id"] = str(supplier_id)
        if movement_type:
            query["type"] = str(getattr(movement_type, "value", movement_type))
        cur = _db()[MOVES].find(query).sort("moved_at", -1).skip(offset).limit(limit)
        return [_out(d) for d in cur]

    # ------------------ SERIALS ------------------
    @staticmethod
    def list_serials(status: Optional[str] = None, item_id: Optional[str] = None, search: Optional[str] = None,
                     limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
        query: Dict[str, Any] = {}
        if status:
            query["status"] = str(getattr(status, "value", status))
        if item_id:
            query["item_id"] = str(item_id)
        if search:
            rx = {"$regex": re.escape(search.strip()), "$options": "i"}
            query["$or"] = [{"serial_no": rx}, {"item_name": rx}, {"customer_name": rx}]
        cur = _db()[SERIALS].find(query).sort("updated_at", -1).skip(offset).limit(limit)
        return [_out(d) for d in cur]

    @staticmethod
    def get_customer_materials(customer: Dict[str, Any]) -> Dict[str, Any]:
        db = _db()
        cid = str(customer["_id"])
        totals: Dict[str, int] = {}
        for m in db[MOVES].find({"customer_id": cid, "type": StockMovementType.OUT.value}):
            totals[m["item_id"]] = totals.get(m["item_id"], 0) + int(m.get("qty", 0))
        serials_by_item: Dict[str, List[Dict[str, Any]]] = {}
        for s in db[SERIALS].find({"customer_id": cid}):
            serials_by_item.setdefault(s["item_id"], []).append(_out(s))
        materials = []
        for iid in sorted(set(totals) | set(serials_by_item)):
            item = db[ITEMS].find_one({"_id": iid}) or {}
            materials.append({
                "item_id": iid, "item_name": item.get("name") or "Removed item",
                "category": item.get("category", "other"), "unit": item.get("unit", "pcs"),
                "total_qty": totals.get(iid, len(serials_by_item.get(iid, []))),
                "serials": serials_by_item.get(iid, []),
            })
        return {"customer_id": cid, "customer_name": customer.get("name") or "Customer", "materials": materials}

    @staticmethod
    def get_serial_detail(serial_no: str) -> Dict[str, Any]:
        db = _db()
        s = db[SERIALS].find_one({"serial_no": serial_no.strip().upper()})
        if not s:
            raise NotFoundException(f"Serial number '{serial_no.strip()}' not found.")
        item = db[ITEMS].find_one({"_id": s["item_id"]}) or {}
        cust = db["customers"].find_one({"_id": s["customer_id"]}) if s.get("customer_id") else None
        until = _aware(s.get("warranty_until"))
        return {
            **_out(s),
            "item_name": item.get("name") or s.get("item_name") or "Solar component",
            "category": item.get("category", "other"), "brand": item.get("brand"), "model": item.get("model"),
            "customer_name": (cust or {}).get("name") or s.get("customer_name"),
            "customer_phone": (cust or {}).get("phone"), "customer_address": (cust or {}).get("address"),
            "warranty_until": until,
            "is_under_warranty": bool(until and until >= _now()),
        }

    @staticmethod
    def update_serial_status(serial_id: str, data: SerialStatusUpdate, user: Any) -> Dict[str, Any]:
        """Move a serial between in_stock / defective / returned (installing goes through stock-out).

        in_stock → defective/returned takes the unit out of sellable stock;
        defective/returned/installed → in_stock puts it back (an installed unit
        returned to the warehouse leaves the customer's project).
        """
        db = _db()
        s = db[SERIALS].find_one({"_id": str(serial_id)})
        if not s:
            raise NotFoundException("Serial item not found.")
        old, new = s["status"], data.status.value
        if new == old:
            return _out(s)
        if new == SerialStatus.INSTALLED.value:
            raise BadRequestException("Issue the serial to a customer with Stock Out to mark it installed.")
        item = db[ITEMS].find_one({"_id": s["item_id"]}) or {"_id": s["item_id"], "name": s.get("item_name")}
        note = (data.note or "").strip() or "No reason given"
        updates: Dict[str, Any] = {"status": new, "updated_at": _now()}
        delta = 0
        if old == SerialStatus.IN_STOCK.value:
            delta = -1
        elif new == SerialStatus.IN_STOCK.value:
            delta = 1
            updates.update({"customer_id": None, "customer_name": None, "installed_on": None, "warranty_until": None})
        res = db[SERIALS].update_one({"_id": s["_id"], "status": old}, {"$set": updates})
        if res.modified_count != 1:
            raise ConflictException("This serial was changed by someone else. Refresh and try again.")
        if delta:
            db[ITEMS].update_one({"_id": item["_id"]}, {"$inc": {"stock_qty": delta}, "$set": {"updated_at": _now()}})
        move_type = StockMovementType.RETURN if (new == SerialStatus.RETURNED.value or old == SerialStatus.INSTALLED.value) \
            else StockMovementType.ADJUST
        _record(db, item, move_type, delta, user, customer_id=s.get("customer_id"), customer_name=s.get("customer_name"),
                note=f"Serial {s['serial_no']}: {old} → {new}. {note}", serial_numbers=[s["serial_no"]])
        return _out(db[SERIALS].find_one({"_id": s["_id"]}))
