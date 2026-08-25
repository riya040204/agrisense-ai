// AgriSense AI - Crop growth stages
// Real stage timelines. Wheat stages are from an ICAR-IARI study conducted
// specifically in Vertisols of Central India near Indore, MP (Indian Journal
// of Agronomy). Soybean stages are standard V/R staging (Bayer Crop Science
// agronomy guidance + peer-reviewed drought-stress research on R3/R5 stages).

class GrowthStage {
  final String name;
  final int startDay;
  final int endDay;
  final bool criticalForWater;
  final String note;

  const GrowthStage({
    required this.name,
    required this.startDay,
    required this.endDay,
    required this.criticalForWater,
    required this.note,
  });

  bool contains(int day) => day >= startDay && day <= endDay;
}

const Map<String, List<GrowthStage>> cropStages = {
  'wheat': [
    GrowthStage(
      name: 'Germination',
      startDay: 0,
      endDay: 19,
      criticalForWater: false,
      note: 'Seedling establishing. Light, even moisture is enough — avoid waterlogging.',
    ),
    GrowthStage(
      name: 'Crown Root Initiation',
      startDay: 20,
      endDay: 39,
      criticalForWater: true,
      note: 'Most critical irrigation stage. Water deficiency now hampers root establishment '
          'and permanently affects yield potential (ICAR, Vertisols of Central India study).',
    ),
    GrowthStage(
      name: 'Tillering',
      startDay: 40,
      endDay: 59,
      criticalForWater: true,
      note: 'Proper irrigation now increases the number of productive tillers/spikes.',
    ),
    GrowthStage(
      name: 'Jointing',
      startDay: 60,
      endDay: 84,
      criticalForWater: true,
      note: 'Stem elongation and spike differentiation. Water stress interrupts nutrient uptake.',
    ),
    GrowthStage(
      name: 'Flowering',
      startDay: 85,
      endDay: 99,
      criticalForWater: true,
      note: 'Critical for grain setting. Moisture stress now can cause poor pollination.',
    ),
    GrowthStage(
      name: 'Grain Filling',
      startDay: 100,
      endDay: 140,
      criticalForWater: false,
      note: 'Grains filling out. Reduce irrigation as the crop approaches maturity.',
    ),
  ],
  'soybean': [
    GrowthStage(
      name: 'Germination',
      startDay: 0,
      endDay: 6,
      criticalForWater: false,
      note: 'Irrigate once right after sowing if rainfall is insufficient.',
    ),
    GrowthStage(
      name: 'Vegetative Growth',
      startDay: 7,
      endDay: 34,
      criticalForWater: false,
      note: 'Low water need. Too much irrigation now can delay flowering and increase disease risk.',
    ),
    GrowthStage(
      name: 'Flowering',
      startDay: 35,
      endDay: 49,
      criticalForWater: true,
      note: 'Water stress during flowering directly reduces pod set.',
    ),
    GrowthStage(
      name: 'Pod Formation',
      startDay: 50,
      endDay: 69,
      criticalForWater: true,
      note: 'One of the two most critical stages for water. Avoid any moisture stress.',
    ),
    GrowthStage(
      name: 'Seed Filling',
      startDay: 70,
      endDay: 89,
      criticalForWater: true,
      note: 'The other most critical stage. Drought now causes the largest yield losses.',
    ),
    GrowthStage(
      name: 'Maturity',
      startDay: 90,
      endDay: 110,
      criticalForWater: false,
      note: 'Reduce irrigation as pods dry down ahead of harvest.',
    ),
  ],
};

GrowthStage? currentStage(String crop, int daysAfterSowing) {
  final stages = cropStages[crop] ?? cropStages['soybean']!;
  for (final stage in stages) {
    if (stage.contains(daysAfterSowing)) return stage;
  }
  return stages.last; // past the mapped range — treat as at/after maturity
}