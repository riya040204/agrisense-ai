"""
AgriSense AI - Backend
Week 2: Sensor-ingestion endpoint (manual entry for now, faculty-provided values)

Run with: uvicorn main:app --reload
Then open: http://localhost:8000/docs
"""

from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException
from sqlmodel import SQLModel, Field, create_engine, Session, select

# -----------------------------
# 1. Database setup (SQLite - zero config, just a local file)
# -----------------------------
DATABASE_URL = "sqlite:///./agrisense.db"
engine = create_engine(DATABASE_URL, echo=False)


# -----------------------------
# 2. The data model — this IS your 8-parameter data contract, made real
# -----------------------------

# The DATABASE table — includes id and timestamp, which the server controls.
class Reading(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    soil_type: str
    nitrogen: float          # kg/ha
    phosphorus: float        # kg/ha
    potassium: float         # kg/ha
    soil_moisture: float     # %
    temperature: float       # °C
    humidity: float          # %
    district: str
    crop: str                # "soybean" or "wheat"
    timestamp: datetime = Field(default_factory=datetime.utcnow)


# What the CLIENT is allowed to send — no id, no timestamp.
# The server always generates those itself, so a client can never overwrite them.
class ReadingCreate(SQLModel):
    soil_type: str
    nitrogen: float
    phosphorus: float
    potassium: float
    soil_moisture: float
    temperature: float
    humidity: float
    district: str
    crop: str


# -----------------------------
# 3. Create the database file + table on startup
# -----------------------------
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)


app = FastAPI(title="AgriSense AI Backend")


@app.on_event("startup")
def on_startup():
    create_db_and_tables()


# -----------------------------
# 4. Endpoints
# -----------------------------

@app.post("/api/v1/readings", response_model=Reading)
def create_reading(payload: ReadingCreate):
    """
    Accepts one sensor reading (or manually-typed faculty value) and saves it.
    FastAPI + Pydantic automatically reject bad data (wrong type, missing field)
    before this code even runs. id and timestamp are always set by the server.
    """
    reading = Reading(**payload.dict())
    with Session(engine) as session:
        session.add(reading)
        session.commit()
        session.refresh(reading)
        return reading


@app.get("/api/v1/readings/latest", response_model=Optional[Reading])
def get_latest_reading():
    with Session(engine) as session:
        statement = select(Reading).order_by(Reading.timestamp.desc())
        result = session.exec(statement).first()
        if not result:
            raise HTTPException(status_code=404, detail="No readings yet")
        return result


@app.get("/api/v1/readings/history", response_model=List[Reading])
def get_reading_history(district: Optional[str] = None, crop: Optional[str] = None):
    """
    Returns all readings, optionally filtered by district and/or crop.
    """
    with Session(engine) as session:
        statement = select(Reading)
        if district:
            statement = statement.where(Reading.district == district)
        if crop:
            statement = statement.where(Reading.crop == crop)
        statement = statement.order_by(Reading.timestamp.desc())
        return session.exec(statement).all()


@app.get("/")
def root():
    return {"message": "AgriSense AI backend is running. Go to /docs to test it."}