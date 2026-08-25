// AgriSense AI - Data models
// These mirror the shapes returned by the FastAPI backend exactly.

class Advisory {
  final String category; // "irrigation" | "nutrient" | "pest"
  final String severity; // "green" | "amber" | "red"
  final String message;

  Advisory({required this.category, required this.severity, required this.message});

  factory Advisory.fromJson(Map<String, dynamic> json) {
    return Advisory(
      category: json['category'],
      severity: json['severity'],
      message: json['message'],
    );
  }
}

class Reading {
  final int id;
  final String soilType;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double soilMoisture;
  final double temperature;
  final double humidity;
  final String district;
  final String crop;
  final String timestamp;

  Reading({
    required this.id,
    required this.soilType,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.soilMoisture,
    required this.temperature,
    required this.humidity,
    required this.district,
    required this.crop,
    required this.timestamp,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: json['id'],
      soilType: json['soil_type'],
      nitrogen: (json['nitrogen'] as num).toDouble(),
      phosphorus: (json['phosphorus'] as num).toDouble(),
      potassium: (json['potassium'] as num).toDouble(),
      soilMoisture: (json['soil_moisture'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      district: json['district'],
      crop: json['crop'],
      timestamp: json['timestamp'],
    );
  }
}

// What POST /api/v1/diagnose returns.
class Diagnosis {
  final bool healthy;
  final String? crop;
  final String condition;
  final double confidence;
  final String advice;

  Diagnosis({
    required this.healthy,
    required this.crop,
    required this.condition,
    required this.confidence,
    required this.advice,
  });

  factory Diagnosis.fromJson(Map<String, dynamic> json) {
    return Diagnosis(
      healthy: json['healthy'],
      crop: json['crop'],
      condition: json['condition'],
      confidence: (json['confidence'] as num).toDouble(),
      advice: json['advice'],
    );
  }
}
// What POST /api/v1/readings returns: the saved reading + its advisories together.
class ReadingWithAdvisory {
  final Reading reading;
  final List<Advisory> advisories;

  ReadingWithAdvisory({required this.reading, required this.advisories});

  factory ReadingWithAdvisory.fromJson(Map<String, dynamic> json) {
    return ReadingWithAdvisory(
      reading: Reading.fromJson(json['reading']),
      advisories: (json['advisories'] as List)
          .map((a) => Advisory.fromJson(a))
          .toList(),
    );
  }
}