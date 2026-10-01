from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from app.core.config import get_settings
from app.db.base import Base

settings = get_settings()
engine = create_async_engine(settings.database_url, echo=False)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        if engine.url.get_backend_name() == "sqlite":
            def additive_sqlite_migrations(sync_conn):
                columns = {row[1] for row in sync_conn.exec_driver_sql("PRAGMA table_info(accounts)").fetchall()}
                migrations = {
                    "twofa_method": "ALTER TABLE accounts ADD COLUMN twofa_method VARCHAR(30)",
                    "added_via": "ALTER TABLE accounts ADD COLUMN added_via VARCHAR(40) NOT NULL DEFAULT 'manual'",
                    "import_confidence": "ALTER TABLE accounts ADD COLUMN import_confidence FLOAT",
                    "evidence_source": "ALTER TABLE accounts ADD COLUMN evidence_source VARCHAR(100)",
                    "risk_components": "ALTER TABLE accounts ADD COLUMN risk_components JSON DEFAULT '{}'",
                }
                for name, statement in migrations.items():
                    if name not in columns:
                        sync_conn.exec_driver_sql(statement)
                family_columns = {row[1] for row in sync_conn.exec_driver_sql("PRAGMA table_info(family_members)").fetchall()}
                if "share_level" not in family_columns:
                    sync_conn.exec_driver_sql(
                        "ALTER TABLE family_members ADD COLUMN share_level VARCHAR(20) NOT NULL DEFAULT 'summary'"
                    )
            await conn.run_sync(additive_sqlite_migrations)


async def get_db():
    async with async_session() as session:
        yield session
