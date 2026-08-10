"""
AgriSense AI - Agri-Logic Engine
Week 3: Turns raw sensor numbers into real, structured farming advice.

This module knows nothing about FastAPI or the database — it just takes
numbers in and returns advice out. That makes it easy to test on its own.

NOTE: The exact thresholds below are reasonable starting placeholders.
Replace them with real ICAR / Krishi Vigyan Kendra (KVK) baseline values
for soybean and wheat in Vertisol vs Alluvial soils once your team
(or faculty mentor) has sourced them — that's Student 4's Week 3 job.
"""

from dataclasses import dataclass, field
from typing import List


@dataclass
class Advisory:
    category: str       # "irrigation", "nutrient", "pest"
    severity: str        # "green" (healthy), "amber" (watch), "red" (act now)
    message: str


@dataclass
class AdvisoryReport:
    advisories: List[Advisory] = field(default_factory=list)

    def add(self, category: str, severity: str, message: str):
        self.advisories.append(Advisory(category, severity, message))


# -----------------------------
# Placeholder ideal ranges — SOURCE THESE FROM ICAR/KVK BEFORE THE DEMO
# -----------------------------
IDEAL_NPK = {
    "soybean": {"nitrogen": (20, 40), "phosphorus": (15, 30), "potassium": (15, 30)},
    "wheat":   {"nitrogen": (40, 70), "phosphorus": (20, 40), "potassium": (20, 40)},
}

MOISTURE_STRESS_THRESHOLD = {
    "soybean": 25,   # % — below this, soybean (rainfed, Kharif) is under stress
    "wheat": 30,      # % — wheat (irrigated, Rabi) needs more consistent moisture
}


def evaluate_irrigation(crop: str, soil_moisture: float) -> Advisory:
    threshold = MOISTURE_STRESS_THRESHOLD.get(crop, 25)
    if soil_moisture < threshold - 5:
        return Advisory("irrigation", "red",
                         f"Soil moisture critically low ({soil_moisture}%). Irrigate now.")
    elif soil_moisture < threshold:
        return Advisory("irrigation", "amber",
                         f"Soil moisture below ideal ({soil_moisture}%). Plan irrigation soon.")
    else:
        return Advisory("irrigation", "green",
                         f"Soil moisture adequate ({soil_moisture}%).")


def evaluate_nutrients(crop: str, nitrogen: float, phosphorus: float, potassium: float) -> List[Advisory]:
    results = []
    ranges = IDEAL_NPK.get(crop, IDEAL_NPK["soybean"])
    labels = {"nitrogen": ("N", "Urea"), "phosphorus": ("P", "DAP"), "potassium": ("K", "MOP")}
    values = {"nitrogen": nitrogen, "phosphorus": phosphorus, "potassium": potassium}

    for nutrient, (low, high) in ranges.items():
        value = values[nutrient]
        short, fertilizer = labels[nutrient]
        if value < low:
            deficit = round(low - value, 1)
            results.append(Advisory("nutrient", "red",
                f"{short} deficient ({value}, ideal {low}-{high}). Apply {fertilizer} to correct ~{deficit} kg/ha shortfall."))
        elif value > high:
            results.append(Advisory("nutrient", "amber",
                f"{short} above ideal range ({value}, ideal {low}-{high}). Avoid further {fertilizer} application."))
        else:
            results.append(Advisory("nutrient", "green", f"{short} within healthy range ({value})."))
    return results


def evaluate_pest_risk(crop: str, temperature: float, humidity: float) -> Advisory:
    """
    Simple placeholder rules. Replace with real thresholds for known MP pests:
    - Soybean: Girdle beetle, Yellow Mosaic Virus (favoured by high humidity + warm temps)
    - Wheat: Rust (favoured by high humidity + moderate temps)
    """
    if crop == "soybean" and temperature > 28 and humidity > 70:
        return Advisory("pest", "red",
            "Conditions favor Yellow Mosaic Virus / Girdle beetle risk. Inspect crop and consult local KVK.")
    if crop == "wheat" and 15 <= temperature <= 25 and humidity > 75:
        return Advisory("pest", "amber",
            "Conditions favor Rust risk. Monitor leaves closely over the coming week.")
    return Advisory("pest", "green", "No elevated pest/disease risk detected from current conditions.")


def generate_advisory(soil_type: str, nitrogen: float, phosphorus: float, potassium: float,
                       soil_moisture: float, temperature: float, humidity: float,
                       district: str, crop: str) -> AdvisoryReport:
    """
    Main entry point. Takes the 8 parameters and returns a structured advisory report.
    """
    report = AdvisoryReport()

    report.add(*_to_tuple(evaluate_irrigation(crop, soil_moisture)))
    for advisory in evaluate_nutrients(crop, nitrogen, phosphorus, potassium):
        report.add(*_to_tuple(advisory))
    report.add(*_to_tuple(evaluate_pest_risk(crop, temperature, humidity)))

    return report


def _to_tuple(advisory: Advisory):
    return (advisory.category, advisory.severity, advisory.message)


# -----------------------------
# Quick manual test — run this file directly to sanity-check the rules
# -----------------------------
if __name__ == "__main__":
    test_cases = [
        dict(soil_type="black_cotton", nitrogen=40, phosphorus=18, potassium=25,
             soil_moisture=22, temperature=33, humidity=55, district="Dewas", crop="soybean"),
        dict(soil_type="alluvial", nitrogen=60, phosphorus=30, potassium=35,
             soil_moisture=45, temperature=18, humidity=60, district="Indore", crop="wheat"),
    ]
    for case in test_cases:
        print(f"\n--- {case['crop'].upper()} in {case['district']} ---")
        report = generate_advisory(**case)
        for a in report.advisories:
            print(f"[{a.severity.upper():5}] {a.category:10} {a.message}")