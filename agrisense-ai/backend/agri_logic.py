"""
AgriSense AI - Agri-Logic Engine
Turns raw sensor numbers into real, structured farming advice, grounded in
real ICAR reference values and real government fertilizer MRPs.
"""

from dataclasses import dataclass, field
from typing import List


@dataclass
class Advisory:
    category: str
    severity: str
    message: str


@dataclass
class AdvisoryReport:
    advisories: List[Advisory] = field(default_factory=list)

    def add(self, category: str, severity: str, message: str):
        self.advisories.append(Advisory(category, severity, message))


# Real ICAR reference values — Indian Institute of Soil Science (IISS), Bhopal.
# General fertilizer recommendation for the Soybean-Wheat cropping system in
# MP's Malwa/Vindhyan plateau: Soybean 20:60:20 kg NPK/ha, Wheat 120:60:40 kg NPK/ha.
# Source: https://iiss.icar.gov.in/r%20and%20d.html
IDEAL_NPK = {
    "soybean": {"nitrogen": (15, 25), "phosphorus": (45, 65), "potassium": (15, 25)},
    "wheat":   {"nitrogen": (90, 130), "phosphorus": (45, 65), "potassium": (30, 45)},
}

MOISTURE_STRESS_THRESHOLD = {
    "soybean": 25,
    "wheat": 30,
}


def evaluate_irrigation(crop: str, soil_moisture: float) -> Advisory:
    threshold = MOISTURE_STRESS_THRESHOLD.get(crop, 25)
    if soil_moisture < threshold - 5:
        return Advisory("irrigation", "red", f"Soil moisture critically low ({soil_moisture}%). Irrigate now.")
    elif soil_moisture < threshold:
        return Advisory("irrigation", "amber", f"Soil moisture below ideal ({soil_moisture}%). Plan irrigation soon.")
    else:
        return Advisory("irrigation", "green", f"Soil moisture adequate ({soil_moisture}%).")


def evaluate_nutrients(crop: str, nitrogen: float, phosphorus: float, potassium: float) -> List[Advisory]:
    results = []
    ranges = IDEAL_NPK.get(crop, IDEAL_NPK["soybean"])
    # (short name, fertilizer name, real MRP per bag, bag size kg, % nutrient content).
    # Prices: Govt of India, June 2026 (Urea MRP notified; DAP Rabi 2025-26 rate;
    # MOP approx NBS-linked retail).
    labels = {
        "nitrogen": ("N", "Urea", 242, 45, 0.46),
        "phosphorus": ("P", "DAP", 1350, 50, 0.46),
        "potassium": ("K", "MOP", 1710, 50, 0.60),
    }
    values = {"nitrogen": nitrogen, "phosphorus": phosphorus, "potassium": potassium}

    for nutrient, (low, high) in ranges.items():
        value = values[nutrient]
        short, fertilizer, price, bag_kg, content_pct = labels[nutrient]
        if value < low:
            deficit_kg_per_ha = round(low - value, 1)
            fertilizer_kg = deficit_kg_per_ha / content_pct
            bags_needed = max(1, round(fertilizer_kg / bag_kg))
            cost = bags_needed * price
            results.append(Advisory("nutrient", "red",
                f"{short} deficient ({value}, ideal {low}-{high}). Apply {fertilizer} to correct "
                f"~{deficit_kg_per_ha} kg/ha shortfall — approx. {bags_needed} bag(s) "
                f"({bag_kg}kg) at ₹{price}/bag ≈ ₹{cost} per hectare (MRP, June 2026)."))
        elif value > high:
            results.append(Advisory("nutrient", "amber",
                f"{short} above ideal range ({value}, ideal {low}-{high}). Avoid further {fertilizer} application."))
        else:
            results.append(Advisory("nutrient", "green", f"{short} within healthy range ({value})."))
    return results


def evaluate_pest_risk(crop: str, temperature: float, humidity: float) -> Advisory:
    if crop == "soybean" and temperature > 25 and humidity > 70:
        return Advisory("pest", "red",
            "Warm + humid conditions favor Yellow Mosaic Virus (whitefly-transmitted). "
            "If not already seed-treated, consult local KVK about Imidacloprid 70% WG seed treatment "
            "and monitor for whitefly activity.")
    if crop == "wheat" and 18 <= temperature <= 30 and humidity >= 76:
        return Advisory("pest", "amber",
            "Temperature and humidity are in the range favorable for wheat leaf rust. "
            "Inspect leaves for orange-brown pustules; if found, consider a Propiconazole or "
            "Tebuconazole-based fungicide per label dose.")
    return Advisory("pest", "green", "No elevated pest/disease risk detected from current conditions.")


def generate_advisory(soil_type: str, nitrogen: float, phosphorus: float, potassium: float,
                       soil_moisture: float, temperature: float, humidity: float,
                       district: str, crop: str) -> AdvisoryReport:
    report = AdvisoryReport()
    report.add(*_to_tuple(evaluate_irrigation(crop, soil_moisture)))
    for advisory in evaluate_nutrients(crop, nitrogen, phosphorus, potassium):
        report.add(*_to_tuple(advisory))
    report.add(*_to_tuple(evaluate_pest_risk(crop, temperature, humidity)))
    return report


def _to_tuple(advisory: Advisory):
    return (advisory.category, advisory.severity, advisory.message)


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