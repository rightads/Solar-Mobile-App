import enum


class UserRole(str, enum.Enum):
    ADMIN = "admin"
    SALES = "sales"
    LABOUR = "labour"
    KEDL = "kedl"
    CLIENT = "client"
    MANAGER = "manager"
    OFFICE_STAFF = "office_staff"
    TECHNICIAN = "technician"
    SERVICE = "service"
    SITE = "site"
    EMPLOYEE = "employee"


class TeamType(str, enum.Enum):
    STRUCTURE = "structure"
    ELECTRICAL = "electrical"
    CIVIL = "civil"


class WorkType(str, enum.Enum):
    STRUCTURE = "structure"
    ELECTRICAL = "electrical"
    CIVIL = "civil"


class WorkStatus(str, enum.Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class CustomerStage(str, enum.Enum):
    SALE_CONFIRMED = "SALE_CONFIRMED"
    DOCUMENTS_RECEIVED = "DOCUMENTS_RECEIVED"
    ADVANCE_VERIFIED = "ADVANCE_VERIFIED"
    STRUCTURE_WORK = "STRUCTURE_WORK"
    ELECTRICAL_WORK = "ELECTRICAL_WORK"
    CIVIL_WORK = "CIVIL_WORK"
    INSTALLATION_COMPLETE = "INSTALLATION_COMPLETE"
    KEDL_PROCESS = "KEDL_PROCESS"
    SYSTEM_LIVE = "SYSTEM_LIVE"
    HANDED_OVER = "HANDED_OVER"


class LeadStatus(str, enum.Enum):
    NEW = "new"
    CONTACTED = "contacted"
    FOLLOW_UP = "follow_up"
    CONVERTED = "converted"
    LOST = "lost"


class DocumentType(str, enum.Enum):
    E_BILL = "e_bill"
    AADHAAR = "aadhaar"
    PAN = "pan"
    CANCELLED_CHEQUE = "cancelled_cheque"
    REGISTRY = "registry"
    OTHER = "other"


class SystemPhase(str, enum.Enum):
    SINGLE = "single"
    THREE = "three"


# Alias for backward compatibility
CustomerPhase = SystemPhase


class PaymentMode(str, enum.Enum):
    CASH = "cash"
    UPI = "upi"
    BANK_TRANSFER = "bank_transfer"
    CHEQUE = "cheque"
    OTHER = "other"


class PaymentStatus(str, enum.Enum):
    PENDING = "pending"
    SALES_APPROVED = "sales_approved"
    VERIFIED = "verified"
    REJECTED = "rejected"


class PaymentAction(str, enum.Enum):
    SUBMITTED = "submitted"
    SALES_APPROVED = "sales_approved"
    VERIFIED = "verified"
    REJECTED = "rejected"
    UPDATED = "updated"


class KedlFileType(str, enum.Enum):
    NAME_CHANGE = "name_change"
    LOAD = "load"
    NET = "net"


class KedlFileStatus(str, enum.Enum):
    NOT_STARTED = "not_started"
    SUBMITTED = "submitted"
    DEMAND_RAISED = "demand_raised"
    DEMAND_PAID = "demand_paid"
    APPROVED = "approved"
    REJECTED = "rejected"


class KedlDemandStatus(str, enum.Enum):
    OPEN = "open"
    PAID = "paid"
    WAIVED = "waived"


class TicketType(str, enum.Enum):
    STRUCTURE = "structure"
    WIRING = "wiring"
    INVERTER = "inverter"


class TicketStatus(str, enum.Enum):
    OPEN = "open"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"
    REOPENED = "reopened"


class TicketPriority(str, enum.Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"


class ItemCategory(str, enum.Enum):
    PANEL = "panel"
    INVERTER = "inverter"
    STRUCTURE = "structure"
    CABLE = "cable"
    ELECTRICAL = "electrical"
    CIVIL = "civil"
    METER = "meter"
    OTHER = "other"


class ItemUnit(str, enum.Enum):
    PCS = "pcs"
    METER = "meter"
    KG = "kg"
    SET = "set"
    BAG = "bag"


class StockMovementType(str, enum.Enum):
    IN = "in"
    OUT = "out"
    ADJUST = "adjust"
    RETURN = "return"


class SerialStatus(str, enum.Enum):
    IN_STOCK = "in_stock"
    INSTALLED = "installed"
    RETURNED = "returned"
    DEFECTIVE = "defective"



class ApprovalStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    ALL = "all"
