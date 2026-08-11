"""
AgriSense AI - Photo Diagnosis
Week 6: Healthy vs. diseased leaf detection using a pretrained model
(linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification), trained on
the real PlantVillage dataset (38 classes across multiple crops).

We call Hugging Face's free Inference API rather than running the model
locally — no training, no GPU, no cost, and it works from a normal laptop.
"""

import os
import httpx
from dotenv import load_dotenv

load_dotenv()

HF_API_TOKEN = os.getenv("HF_API_TOKEN")
MODEL_ID = "linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification"
HF_API_URL = f"https://api-inference.huggingface.co/models/{MODEL_ID}"


class DiagnosisResult:
    def __init__(self, healthy: bool, label: str, confidence: float, crop: str | None, condition: str):
        self.healthy = healthy
        self.label = label
        self.confidence = confidence
        self.crop = crop
        self.condition = condition


def _parse_label(raw_label: str):
    """
    PlantVillage-style labels look like 'Tomato___healthy' or
    'Potato___Early_blight'. Split into (crop, condition, is_healthy).
    """
    parts = raw_label.replace("___", "_").split("_")
    # crude but reliable: 'healthy' keyword decides status regardless of format
    is_healthy = "healthy" in raw_label.lower()
    crop = parts[0].replace("-", " ") if parts else None
    condition = raw_label.split("___")[-1].replace("_", " ") if "___" in raw_label else raw_label.replace("_", " ")
    return crop, condition, is_healthy


async def diagnose_image(image_bytes: bytes) -> DiagnosisResult:
    if not HF_API_TOKEN:
        raise RuntimeError(
            "HF_API_TOKEN not set. Add it to backend/.env as HF_API_TOKEN=hf_xxx "
            "(see .env.example)."
        )

    headers = {"Authorization": f"Bearer {HF_API_TOKEN}"}

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(HF_API_URL, headers=headers, content=image_bytes)

    if response.status_code == 503:
        # Model is "cold" and loading on Hugging Face's servers — normal for
        # free tier on first use, retry after the estimated wait.
        data = response.json()
        wait = data.get("estimated_time", 20)
        raise RuntimeError(f"Model is warming up, try again in ~{int(wait)} seconds.")

    if response.status_code != 200:
        raise RuntimeError(f"Diagnosis service error ({response.status_code}): {response.text}")

    predictions = response.json()
    if not isinstance(predictions, list) or not predictions:
        raise RuntimeError(f"Unexpected response from diagnosis service: {predictions}")

    top = max(predictions, key=lambda p: p["score"])
    crop, condition, is_healthy = _parse_label(top["label"])

    return DiagnosisResult(
        healthy=is_healthy,
        label=top["label"],
        confidence=round(top["score"] * 100, 1),
        crop=crop,
        condition=condition,
    )