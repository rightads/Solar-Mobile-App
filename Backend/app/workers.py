from uvicorn.workers import UvicornWorker


class SecureUvicornWorker(UvicornWorker):
    """Uvicorn worker that does not advertise the server software."""

    CONFIG_KWARGS = {"server_header": False, "date_header": True}
