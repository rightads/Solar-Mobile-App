from datetime import datetime
from typing import List, Optional
import uuid
from pydantic import BaseModel, Field
from app.models.enums import TicketPriority, TicketStatus, TicketType
from app.schemas.user import UserRead
from app.schemas.work_assignment import CustomerShortForLabour


class TicketImageRead(BaseModel):
    id: uuid.UUID
    ticket_id: uuid.UUID
    file_key: str
    download_url: Optional[str] = None
    uploaded_by: Optional[uuid.UUID] = None
    created_at: datetime

    class Config:
        from_attributes = True


class TicketCommentCreate(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000, description="Comment or reply message")


class TicketCommentRead(BaseModel):
    id: uuid.UUID
    ticket_id: uuid.UUID
    author_id: Optional[uuid.UUID] = None
    message: str
    created_at: datetime
    author: Optional[UserRead] = None

    class Config:
        from_attributes = True


class TicketStatusLogRead(BaseModel):
    id: uuid.UUID
    ticket_id: uuid.UUID
    from_status: Optional[TicketStatus] = None
    to_status: TicketStatus
    changed_by: Optional[uuid.UUID] = None
    note: Optional[str] = None
    created_at: datetime
    actor: Optional[UserRead] = None

    class Config:
        from_attributes = True


class TicketCreate(BaseModel):
    type: TicketType = Field(..., description="structure, wiring, or inverter")
    title: str = Field(..., min_length=3, max_length=200)
    description: str = Field(..., min_length=5, max_length=4000)
    error_code: Optional[str] = Field(None, max_length=60, description="Optional inverter fault or error code")
    priority: TicketPriority = Field(default=TicketPriority.NORMAL)
    image_keys: Optional[List[str]] = Field(default_factory=list, max_length=10, description="IDs of files uploaded via /files")


class TicketStatusUpdate(BaseModel):
    status: TicketStatus = Field(..., description="Target status (assigned, in_progress, resolved, closed, reopened)")
    resolution_note: Optional[str] = Field(None, max_length=2000, description="Required when marking ticket resolved")


class TicketAssign(BaseModel):
    assigned_to: uuid.UUID = Field(..., description="User ID of the employee assigned to resolve ticket")


class TicketRead(BaseModel):
    id: uuid.UUID
    ticket_no: str
    customer_id: uuid.UUID
    type: TicketType
    title: str
    description: str
    error_code: Optional[str] = None
    status: TicketStatus
    priority: TicketPriority
    assigned_to: Optional[uuid.UUID] = None
    resolved_at: Optional[datetime] = None
    resolution_note: Optional[str] = None
    created_by: uuid.UUID
    created_at: datetime
    updated_at: datetime
    customer: Optional[CustomerShortForLabour] = None
    assignee: Optional[UserRead] = None
    creator: Optional[UserRead] = None
    images: Optional[List[TicketImageRead]] = None
    comments: Optional[List[TicketCommentRead]] = None
    status_logs: Optional[List[TicketStatusLogRead]] = None

    class Config:
        from_attributes = True
