"""
AgriSense AI - Photo Diagnosis
Week 6: Healthy vs. diseased leaf detection using a pretrained model
(linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification), trained on
the real PlantVillage dataset (38 classes across multiple crops).

We call Hugging Face's free Inference API rather than running the model
locally — no training, no GPU, no cost, and it works from a normal laptop.

NOTE: Uses the SYNCHRONOUS httpx client deliberately. httpx's async client
hits a known Windows event-loop / DNS resolution bug (getaddrinfo failures)
in some environments even when the network itself is fine. The sync client
avoids it entirely, and FastAPI safely runs sync code in a thread pool.
"""

import os
import httpx
from dotenv import load_dotenv

load_dotenv()

HF_API_TOKEN = os.getenv("HF_API_TOKEN")
MODEL_ID = "linkanjarad/mobilenet_v2_1.0_224-plant-disease-identification"
# Hugging Face retired api-inference.huggingface.co in favor of this router
# endpoint (Inference Providers). Same free tier, new address.
HF_API_URL = f"https://router.huggingface.co/hf-inference/models/{MODEL_ID}"


class DiagnosisResult:
    def __init__(self, healthy: bool, label: str, confidence: float, crop, condition: str):
        self.healthy = healthy
        self.label = label
        self.confidence = confidence
        self.crop = crop
        self.condition = condition


def _parse_label(raw_label: str):
    is_healthy = "healthy" in raw_label.lower()
    crop = raw_label.split("___")[0].replace("_", " ") if "___" in raw_label else None
    condition = raw_label.split("___")[-1].replace("_", " ") if "___" in raw_label else raw_label.replace("_", " ")
    return crop, condition, is_healthy


def diagnose_image(image_bytes: bytes, content_type: str = "image/jpeg") -> DiagnosisResult:
    """
    Synchronous on purpose — see module docstring. Called from the FastAPI
    route via run_in_threadpool so it doesn't block the server.
    """
    if not HF_API_TOKEN:
        raise RuntimeError(
            "HF_API_TOKEN not set. Add it to backend/.env as HF_API_TOKEN=hf_xxx "
            "(see .env.example)."
        )

    # Hugging Face requires a Content-Type telling it this is image data,
    # not raw/unspecified bytes — without it, it rejects the request.
    headers = {
        "Authorization": f"Bearer {HF_API_TOKEN}",
        "Content-Type": content_type or "image/jpeg",
    }

    try:
        with httpx.Client(timeout=40.0) as client:
            response = client.post(HF_API_URL, headers=headers, content=image_bytes)
    except httpx.RequestError as e:
        raise RuntimeError(f"Could not reach Hugging Face (network issue): {e}")

    if response.status_code == 503:
        data = response.json()
        wait = data.get("estimated_time", 20)
        raise RuntimeError(f"Model is warming up, try again in ~{int(wait)} seconds.")

    if response.status_code == 401:
        raise RuntimeError("Hugging Face rejected the token (401). Check HF_API_TOKEN in backend/.env.")

    if response.status_code != 200:
        raise RuntimeError(f"Diagnosis service error ({response.status_code}): {response.text[:300]}")

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