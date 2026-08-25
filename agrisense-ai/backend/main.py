"""
AgriSense AI - Backend
Week 2: Sensor-ingestion endpoint (manual entry for now, faculty-provided values)
Week 3: Every reading now automatically gets a real advisory attached.
Week 6: Photo-based leaf diagnosis via a pretrained model.

Run with: uvicorn main:app --reload
Then open: http://localhost:8000/docs
"""

from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.concurrency import run_in_threadpool
from sqlmodel import SQLModel, Field, create_engine, Session, select

from agri_logic import generate_advisory
from diagnosis import diagnose_image

# -----------------------------
# 1. Database setup (SQLite - zero config, just a local file)
# -----------------------------
DATABASE_URL = "sqlite:///./agrisense.db"
engine = create_engine(DATABASE_URL, echo=False)


# -----------------------------
# 2. Data models
# -----------------------------

class Reading(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    soil_type: str
    nitrogen: float
    phosphorus: float
    potassium: float
    soil_moisture: float
    temperature: float
    humidity: float
    district: str
    crop: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)


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


class AdvisoryOut(SQLModel):
    category: str
    severity: str
    message: str


class ReadingWithAdvisory(SQLModel):
    reading: Reading
    advisories: List[AdvisoryOut]


class DiagnosisOut(SQLModel):
    healthy: bool
    crop: Optional[str]
    condition: str
    confidence: float
    advice: str


def create_db_and_tables():
    SQLModel.metadata.create_all(engine)


app = FastAPI(title="AgriSense AI Backend")

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
# 3. Endpoints
# -----------------------------

@app.post("/api/v1/readings", response_model=ReadingWithAdvisory)
def create_reading(payload: ReadingCreate):
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
    advisories = [AdvisoryOut(category=a.category, severity=a.severity, message=a.message) for a in report.advisories]
    return ReadingWithAdvisory(reading=reading, advisories=advisories)


@app.get("/api/v1/advisory/latest", response_model=ReadingWithAdvisory)
def get_latest_advisory():
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
    advisories = [AdvisoryOut(category=a.category, severity=a.severity, message=a.message) for a in report.advisories]
    return ReadingWithAdvisory(reading=reading, advisories=advisories)


@app.get("/api/v1/readings/history", response_model=List[Reading])
def get_reading_history(district: Optional[str] = None, crop: Optional[str] = None):
    with Session(engine) as session:
        statement = select(Reading)
        if district:
            statement = statement.where(Reading.district == district)
        if crop:
            statement = statement.where(Reading.crop == crop)
        statement = statement.order_by(Reading.timestamp.desc())
        return session.exec(statement).all()


@app.post("/api/v1/diagnose", response_model=DiagnosisOut)
async def diagnose(file: UploadFile = File(...)):
    """
    Accepts a leaf photo and returns healthy/diseased status.
    diagnose_image() is synchronous (see diagnosis.py for why), so we run it
    in a thread pool here to avoid blocking the server while it waits on
    Hugging Face's response.
    """
    image_bytes = await file.read()
    content_type = file.content_type or "image/jpeg"
    try:
        result = await run_in_threadpool(diagnose_image, image_bytes, content_type)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))

    if result.healthy:
        advice = "No signs of disease detected. Continue routine monitoring."
    else:
        advice = (
            f"Possible {result.condition} detected. This is an automated first check, not a lab "
            "diagnosis — confirm with your local Krishi Vigyan Kendra (KVK) before applying any treatment."
        )

    return DiagnosisOut(
        healthy=result.healthy,
        crop=result.crop,
        condition=result.condition,
        confidence=result.confidence,
        advice=advice,
    )


@app.get("/")
def root():
    return {"message": "AgriSense AI backend is running. Go to /docs to test it."}