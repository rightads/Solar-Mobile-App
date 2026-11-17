"""Inventory & materials (MongoDB): items, suppliers, stock ledger, serial numbers.

Reads are limited to staff; customers never see stock. Writes follow the
original role gates: admins/managers manage the catalogue, office staff book
deliveries, site/service technicians may issue stock to a project and flag
defective serials.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status

from app.core import access
from app.core.deps import MongoUserProxy, require_roles, require_staff
from app.models.enums import ItemCategory, SerialStatus, StockMovementType, UserRole
from app.schemas.inventory import (
    CustomerMaterialsResponse,
    InventoryItemCreate,
    InventoryItemRead,
    InventoryItemUpdate,
    LowStockItemRead,
    SerialDetailRead,
    SerialItemRead,
    SerialStatusUpdate,
    StockAdjustRequest,
    StockInRequest,
    StockMovementRead,
    StockOutRequest,
    SupplierCreate,
    SupplierRead,
    SupplierUpdate,
)
from app.services.inventory_service import InventoryService as Inv

router = APIRouter(tags=["Inventory & Materials"])

require_catalogue = require_roles(UserRole.ADMIN, UserRole.MANAGER)
require_stock_in = require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.OFFICE_STAFF)
require_stock_out = require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.OFFICE_STAFF, UserRole.TECHNICIAN)
require_serial_status = require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.TECHNICIAN)


# ------------------ SUPPLIERS ------------------
@router.get("/suppliers", response_model=List[SupplierRead], summary="List suppliers")
async def list_suppliers(
    is_active: Optional[bool] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_user: MongoUserProxy = Depends(require_staff),
):
    return Inv.list_suppliers(is_active=is_active, limit=limit, offset=offset)


@router.post("/suppliers", response_model=SupplierRead, status_code=status.HTTP_201_CREATED,
             summary="Register a supplier (Admin, Manager)")
async def create_supplier(data: SupplierCreate, current_user: MongoUserProxy = Depends(require_catalogue)):
    return Inv.create_supplier(data)


@router.get("/suppliers/{supplier_id}", response_model=SupplierRead, summary="Get supplier details")
async def get_supplier(supplier_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    return Inv.get_supplier(supplier_id)


@router.patch("/suppliers/{supplier_id}", response_model=SupplierRead, summary="Update supplier details (Admin, Manager)")
async def update_supplier(supplier_id: str, data: SupplierUpdate, current_user: MongoUserProxy = Depends(require_catalogue)):
    return Inv.update_supplier(supplier_id, data)


@router.delete("/suppliers/{supplier_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete a supplier (Admin)")
async def delete_supplier(supplier_id: str, current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN))):
    Inv.delete_supplier(supplier_id)


# ------------------ INVENTORY ITEMS ------------------
@router.get("/inventory/items", response_model=List[InventoryItemRead],
            summary="List inventory items with search and category filters")
async def list_items(
    category: Optional[ItemCategory] = Query(None),
    low_stock: bool = Query(False),
    search: Optional[str] = Query(None, max_length=100),
    is_active: Optional[bool] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: MongoUserProxy = Depends(require_staff),
):
    return Inv.list_items(category=category, low_stock=low_stock, search=search,
                          is_active=is_active, limit=limit, offset=offset)


@router.get("/inventory/low-stock", response_model=List[LowStockItemRead],
            summary="Items at or below their minimum stock level")
async def get_low_stock_items(current_user: MongoUserProxy = Depends(require_staff)):
    return Inv.get_low_stock_items()


@router.post("/inventory/items", response_model=InventoryItemRead, status_code=status.HTTP_201_CREATED,
             summary="Create an inventory item (Admin, Manager)")
async def create_item(data: InventoryItemCreate, current_user: MongoUserProxy = Depends(require_catalogue)):
    return Inv.create_item(data)


@router.get("/inventory/items/{item_id}", response_model=InventoryItemRead, summary="Inventory item details")
async def get_item(item_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    return Inv.get_item(item_id)


@router.patch("/inventory/items/{item_id}", response_model=InventoryItemRead,
              summary="Update inventory item details (Admin, Manager)")
async def update_item(item_id: str, data: InventoryItemUpdate, current_user: MongoUserProxy = Depends(require_catalogue)):
    return Inv.update_item(item_id, data)


@router.delete("/inventory/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT,
               summary="Delete an inventory item with no stock left (Admin)")
async def delete_item(item_id: str, current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN))):
    Inv.delete_item(item_id)


# ------------------ STOCK MOVEMENTS ------------------
@router.post("/inventory/stock-in", response_model=StockMovementRead, status_code=status.HTTP_201_CREATED,
             summary="Record a delivery (with serial numbers for serialised items)")
async def stock_in(data: StockInRequest, current_user: MongoUserProxy = Depends(require_stock_in)):
    return Inv.stock_in(data, current_user)


@router.post("/inventory/stock-out", response_model=StockMovementRead, status_code=status.HTTP_201_CREATED,
             summary="Issue stock (and serial numbers) to a customer project")
async def stock_out(data: StockOutRequest, current_user: MongoUserProxy = Depends(require_stock_out)):
    return Inv.stock_out(data, current_user)


@router.post("/inventory/adjust", response_model=StockMovementRead,
             summary="Correct a stock count with a mandatory note (Admin, Manager)")
async def adjust_stock(data: StockAdjustRequest, current_user: MongoUserProxy = Depends(require_catalogue)):
    return Inv.adjust_stock(data, current_user)


@router.get("/inventory/movements", response_model=List[StockMovementRead], summary="Stock ledger")
async def list_movements(
    item_id: Optional[str] = Query(None, max_length=64),
    customer_id: Optional[str] = Query(None, max_length=64),
    supplier_id: Optional[str] = Query(None, max_length=64),
    movement_type: Optional[StockMovementType] = Query(None, alias="type"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: MongoUserProxy = Depends(require_staff),
):
    return Inv.list_movements(item_id=item_id, customer_id=customer_id, supplier_id=supplier_id,
                              movement_type=movement_type, limit=limit, offset=offset)


# ------------------ SERIALS & CUSTOMER MATERIALS ------------------
@router.get("/inventory/serials", response_model=List[SerialItemRead], summary="Serial-numbered units")
async def list_serials(
    serial_status: Optional[SerialStatus] = Query(None, alias="status"),
    item_id: Optional[str] = Query(None, max_length=64),
    search: Optional[str] = Query(None, max_length=100),
    limit: int = Query(200, ge=1, le=500),
    offset: int = Query(0, ge=0),
    current_user: MongoUserProxy = Depends(require_staff),
):
    return Inv.list_serials(status=serial_status, item_id=item_id, search=search, limit=limit, offset=offset)


@router.get("/customers/{customer_id}/materials", response_model=CustomerMaterialsResponse,
            summary="Materials and serial numbers issued to a customer project")
async def get_customer_materials(customer_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    return Inv.get_customer_materials(access.require_customer(current_user, customer_id))


@router.get("/serials/{serial_no}", response_model=SerialDetailRead,
            summary="Look up a serial number for project and warranty details")
async def get_serial_details(serial_no: str, current_user: MongoUserProxy = Depends(require_staff)):
    return Inv.get_serial_detail(serial_no)


@router.patch("/serials/{serial_id}/status", response_model=SerialItemRead,
              summary="Mark a serial defective / returned / back in stock")
async def update_serial_status(serial_id: str, data: SerialStatusUpdate,
                               current_user: MongoUserProxy = Depends(require_serial_status)):
    return Inv.update_serial_status(serial_id, data, current_user)
