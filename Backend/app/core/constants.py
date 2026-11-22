"""Central place for business-rule constants that were previously scattered across services."""
from app.models.enums import CustomerStage

# Ordered customer project timeline: (stage, display title, owning department,
# customer field holding the assigned employee).
#
# Each stage belongs to one employee department. When a stage is marked Done
# the project hands off automatically to the next stage's department (see
# app.services.workflow). Discom owns two stages: the name-change / other
# changes paperwork before installation, and net metering after it.
STAGE_FLOW = [
    (CustomerStage.DOCUMENTS_COLLECTION, "Client Documents Collection", "sales", "sales_id"),
    (CustomerStage.DISCOM_NAME_CHANGE, "Discom: Name Change & Other Changes", "discom", "discom_employee_id"),
    (CustomerStage.STRUCTURE_WORK, "Structure Work", "structure", "structure_employee_id"),
    (CustomerStage.WIRING_WORK, "Wiring Work", "wiring", "wiring_employee_id"),
    (CustomerStage.CIVIL_WORK, "Civil Work", "civil", "civil_employee_id"),
    (CustomerStage.SUBSIDY_WORK, "Subsidy Work", "subsidy", "subsidy_employee_id"),
    (CustomerStage.DISCOM_NET_METERING, "Discom: Net Metering", "discom", "discom_employee_id"),
    (CustomerStage.ACCOUNT_BILL, "Account / Bill", "account", "account_employee_id"),
]

STAGE_ORDER = [(stage, title) for stage, title, _, _ in STAGE_FLOW]

FIRST_STAGE = STAGE_ORDER[0][0].value
