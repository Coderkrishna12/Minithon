from datetime import datetime, timezone
from sqlalchemy import DateTime, TypeDecorator


def utcnow() -> datetime:
    """Return current timezone-aware UTC datetime."""
    return datetime.now(timezone.utc)


def ensure_aware(dt: datetime | None) -> datetime | None:
    """Ensure a datetime object is timezone-aware and set to UTC."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class UTCDateTime(TypeDecorator):
    """
    SQLAlchemy TypeDecorator that guarantees timezone-aware UTC datetimes.
    - On write: rejects naive datetimes and converts aware datetimes to UTC.
    - On read: attaches UTC timezone if the database driver returned a naive datetime.
    """
    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            if not isinstance(value, datetime):
                raise TypeError(f"Expected datetime object, got {type(value)}")
            if value.tzinfo is None:
                raise ValueError(f"UTCDateTime requires timezone-aware datetime, got naive: {value}")
            return value.astimezone(timezone.utc)
        return None

    def process_result_value(self, value, dialect):
        if value is not None:
            if value.tzinfo is None:
                return value.replace(tzinfo=timezone.utc)
            return value.astimezone(timezone.utc)
        return None
