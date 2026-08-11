"""
AgriSense AI - Backend
Week 2: Sensor-ingestion endpoint (manual entry for now, faculty-provided values)
Week 3: Every reading now automatically gets a real advisory attached.

Run with: uvicorn main:app --reload
Then open: http://localhost:8000/docs
"""

from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import SQLModel, Field, create_engine, Session, select

from agri_logic import generate_advisory

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


# One advisory line (irrigation / nutrient / pest), matching agri_logic.Advisory
class AdvisoryOut(SQLModel):
    category: str
    severity: str   # "green" | "amber" | "red"
    message: str


# What we return after saving a reading: the reading itself + its advisories
class ReadingWithAdvisory(SQLModel):
    reading: Reading
    advisories: List[AdvisoryOut]


# -----------------------------
# 3. Create the database file + table on startup
# -----------------------------
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)


app = FastAPI(title="AgriSense AI Backend")

# Allow the Flutter web app (running on a different local port) to call this API.
# For the hackathon/demo we allow all origins; tighten this before any real deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    create_db_and_tables()


# -----------------------------
# 4. Endpoints
# -----------------------------

@app.post("/api/v1/readings", response_model=ReadingWithAdvisory)
def create_reading(payload: ReadingCreate):
    """
    Accepts one sensor reading (or manually-typed faculty value), saves it,
    and runs it through the agri-logic engine to return real advice immediately.
    id and timestamp are always set by the server.
    """
    reading = Reading(**payload.dict())
    with Session(engine) as session:
        session.add(reading)
        session.commit()
        session.refresh(reading)

    report = generate_advisory(
        soil_type=reading.soil_type,
        nitrogen=reading.nitrogen,
        phosphorus=reading.phosphorus,
        potassium=reading.potassium,
        soil_moisture=reading.soil_moisture,
        temperature=reading.temperature,
        humidity=reading.humidity,
        district=reading.district,
        crop=reading.crop,
    )
    advisories = [
        AdvisoryOut(category=a.category, severity=a.severity, message=a.message)
        for a in report.advisories
    ]
    return ReadingWithAdvisory(reading=reading, advisories=advisories)


@app.get("/api/v1/readings/latest", response_model=Optional[Reading])
def get_latest_reading():
    with Session(engine) as session:
        statement = select(Reading).order_by(Reading.timestamp.desc())
        result = session.exec(statement).first()
        if not result:
            raise HTTPException(status_code=404, detail="No readings yet")
        return result


@app.get("/api/v1/advisory/latest", response_model=ReadingWithAdvisory)
def get_latest_advisory():
    """
    Returns the most recent reading together with its advisories,
    WITHOUT creating a new database entry (read-only, safe to call anytime
    the dashboard loads or refreshes).
    """
    with Session(engine) as session:
        statement = select(Reading).order_by(Reading.timestamp.desc())
        reading = session.exec(statement).first()
        if not reading:
            raise HTTPException(status_code=404, detail="No readings yet")

    report = generate_advisory(
        soil_type=reading.soil_type,
        nitrogen=reading.nitrogen,
        phosphorus=reading.phosphorus,
        potassium=reading.potassium,
        soil_moisture=reading.soil_moisture,
        temperature=reading.temperature,
        humidity=reading.humidity,
        district=reading.district,
        crop=reading.crop,
    )
    advisories = [
        AdvisoryOut(category=a.category, severity=a.severity, message=a.message)
        for a in report.advisories
    ]
    return ReadingWithAdvisory(reading=reading, advisories=advisories)


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