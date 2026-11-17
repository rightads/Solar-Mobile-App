"""Inventory API schemas. IDs are strings: records live in MongoDB."""
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import ItemCategory, ItemUnit, SerialStatus, StockMovementType

_ID = Field(..., min_length=1, max_length=64)


# Supplier Schemas
class SupplierCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(..., min_length=1, max_length=150)
    phone: Optional[str] = Field(None, max_length=20)
    address: Optional[str] = Field(None, max_length=300)
    gst_no: Optional[str] = Field(None, max_length=30)


class SupplierUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    phone: Optional[str] = Field(None, max_length=20)
    address: Optional[str] = Field(None, max_length=300)
    gst_no: Optional[str] = Field(None, max_length=30)
    is_active: Optional[bool] = None


class SupplierRead(BaseModel):
    id: str
    name: str
    phone: Optional[str] = None
    address: Optional[str] = None
    gst_no: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime


# Inventory Item Schemas
class InventoryItemCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    category: ItemCategory
    name: str = Field(..., min_length=1, max_length=150)
    brand: Optional[str] = Field(None, max_length=100)
    model: Optional[str] = Field(None, max_length=100)
    unit: ItemUnit = ItemUnit.PCS
    has_serial: bool = False
    min_stock: int = Field(0, ge=0, le=1_000_000)
    specs: Optional[Dict[str, Any]] = None


class InventoryItemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    category: Optional[ItemCategory] = None
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    brand: Optional[str] = Field(None, max_length=100)
    model: Optional[str] = Field(None, max_length=100)
    unit: Optional[ItemUnit] = None
    min_stock: Optional[int] = Field(None, ge=0, le=1_000_000)
    specs: Optional[Dict[str, Any]] = None
    is_active: Optional[bool] = None


class InventoryItemRead(BaseModel):
    id: str
    category: ItemCategory
    name: str
    brand: Optional[str] = None
    model: Optional[str] = None
    unit: ItemUnit
    has_serial: bool
    min_stock: int
    stock_qty: int
    specs: Optional[Dict[str, Any]] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime


class LowStockItemRead(BaseModel):
    id: str
    category: ItemCategory
    name: str
    brand: Optional[str] = None
    model: Optional[str] = None
    unit: ItemUnit
    min_stock: int
    stock_qty: int
    shortage: int


# Stock Movement Schemas
class StockInRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    item_id: str = _ID
    qty: int = Field(..., gt=0, le=1_000_000)
    supplier_id: Optional[str] = Field(None, max_length=64)
    unit_cost: Optional[int] = Field(None, ge=0, le=10_000_000_00, description="Unit cost in paise")
    invoice_no: Optional[str] = Field(None, max_length=100)
    note: Optional[str] = Field(None, max_length=500)
    serial_numbers: Optional[List[str]] = Field(None, max_length=5000, description="Serial numbers for serialized items")
    warranty_months: int = Field(0, ge=0, le=600, description="Warranty duration in months for serial items")


class StockOutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    item_id: str = _ID
    qty: int = Field(..., gt=0, le=1_000_000)
    customer_id: str = _ID
    note: Optional[str] = Field(None, max_length=500)
    serial_numbers: Optional[List[str]] = Field(None, max_length=5000, description="Serial numbers to issue from stock")


class StockAdjustRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    item_id: str = _ID
    new_qty: int = Field(..., ge=0, le=1_000_000, description="New exact stock quantity")
    note: str = Field(..., min_length=3, max_length=500, description="Mandatory audit explanation for stock adjustment")


class StockMovementRead(BaseModel):
    id: str
    item_id: str
    item_name: Optional[str] = None
    type: StockMovementType
    qty: int
    supplier_id: Optional[str] = None
    supplier_name: Optional[str] = None
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    unit_cost: Optional[int] = None
    invoice_no: Optional[str] = None
    note: Optional[str] = None
    serial_numbers: List[str] = []
    moved_by: str
    mover_name: Optional[str] = None
    moved_at: datetime


# Serial Item Schemas
class SerialItemRead(BaseModel):
    id: str
    item_id: str
    item_name: Optional[str] = None
    serial_no: str
    status: SerialStatus
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    supplier_id: Optional[str] = None
    supplier_name: Optional[str] = None
    warranty_months: int
    warranty_until: Optional[datetime] = None
    installed_on: Optional[datetime] = None
    created_at: datetime


class SerialStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: SerialStatus = Field(..., description="New status, e.g. defective or returned")
    note: Optional[str] = Field(None, max_length=500)


class SerialDetailRead(BaseModel):
    id: str
    item_id: str
    item_name: str
    category: ItemCategory
    brand: Optional[str] = None
    model: Optional[str] = None
    serial_no: str
    status: SerialStatus
    customer_id: Optional[str] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_address: Optional[str] = None
    supplier_id: Optional[str] = None
    supplier_name: Optional[str] = None
    warranty_months: int
    installed_on: Optional[datetime] = None
    warranty_until: Optional[datetime] = None
    is_under_warranty: bool


# Customer Material Allocations
class CustomerMaterialItemRead(BaseModel):
    item_id: str
    item_name: str
    category: ItemCategory
    unit: ItemUnit
    total_qty: int
    serials: List[SerialItemRead] = []


class CustomerMaterialsResponse(BaseModel):
    customer_id: str
    customer_name: str
    materials: List[CustomerMaterialItemRead]
