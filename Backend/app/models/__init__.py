"""SQLAlchemy Models package."""
from app.db.base import Base
from app.models.auth import OtpCode, RefreshToken
from app.models.customer import Customer, StageHistory
from app.models.document import CustomerDocument
from app.models.enums import (
    CustomerStage,
    CustomerPhase,
    DocumentType,
    ItemCategory,
    ItemUnit,
    KedlDemandStatus,
    KedlFileStatus,
    KedlFileType,
    LeadStatus,
    PaymentAction,
    PaymentMode,
    PaymentStatus,
    SerialStatus,
    StockMovementType,
    SystemPhase,
    TeamType,
    TicketPriority,
    TicketStatus,
    TicketType,
    UserRole,
    WorkStatus,
    WorkType,
)
from app.models.inventory import InventoryItem, PlannedMaterial, SerialItem, StockMovement, Supplier
from app.models.kedl import KedlDemand, KedlDocument, KedlFile, KedlStatusLog
from app.models.lead import Lead
from app.models.notification import Notification, SystemAuditLog
from app.models.payment import Payment, PaymentAuditLog
from app.models.team import Team
from app.models.ticket import ServiceTicket, TicketComment, TicketImage, TicketStatusLog
from app.models.user import User
from app.models.work_assignment import WorkAssignment, WorkPhoto, WorkStatusLog

__all__ = [
    "Base",
    "UserRole",
    "TeamType",
    "WorkType",
    "WorkStatus",
    "CustomerStage",
    "LeadStatus",
    "DocumentType",
    "SystemPhase",
    "PaymentMode",
    "PaymentStatus",
    "PaymentAction",
    "KedlFileType",
    "KedlFileStatus",
    "KedlDemandStatus",
    "TicketType",
    "TicketStatus",
    "TicketPriority",
    "ItemCategory",
    "ItemUnit",
    "StockMovementType",
    "SerialStatus",
    "User",
    "Team",
    "OtpCode",
    "RefreshToken",
    "Customer",
    "StageHistory",
    "Lead",
    "CustomerDocument",
    "Payment",
    "PaymentAuditLog",
    "WorkAssignment",
    "WorkPhoto",
    "WorkStatusLog",
    "KedlFile",
    "KedlDemand",
    "KedlDocument",
    "KedlStatusLog",
    "ServiceTicket",
    "TicketImage",
    "TicketComment",
    "TicketStatusLog",
    "Supplier",
    "InventoryItem",
    "StockMovement",
    "SerialItem",
    "PlannedMaterial",
    "Notification",
    "SystemAuditLog",
]


