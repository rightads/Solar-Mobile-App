"""Central place for business-rule constants that were previously scattered across services."""
from app.models.enums import CustomerStage

# Ordered customer project timeline: (stage, display title).
#
# The project runs through the four employee departments only:
#   Site-ops does the whole installation (structure, electrical and civil work
#   are tasks inside one "Site Installation" stage), KEDL handles the discom
#   files and makes the system live, and Service hands the project over.
# Sales creates the customer and assigns the Site-ops and KEDL employees, so it
# has no stage of its own.
STAGE_ORDER = [
    (CustomerStage.INSTALLATION_COMPLETE, "Site Installation"),
    (CustomerStage.KEDL_PROCESS, "KEDL Discom Paperwork"),
    (CustomerStage.SYSTEM_LIVE, "System Live & Net Metering"),
    (CustomerStage.HANDED_OVER, "Project Handed Over"),
]

FIRST_STAGE = STAGE_ORDER[0][0].value
