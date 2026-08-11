// AgriSense AI - API service
// Handles all HTTP calls to the FastAPI backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  // While developing locally, the backend runs at this address.
  // We'll change this one line later when we deploy to the cloud.
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Reading?> fetchLatestReading() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/readings/latest'));
    if (response.statusCode == 200) {
      return Reading.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null; // no readings yet
    } else {
      throw Exception('Failed to load latest reading (${response.statusCode})');
    }
  }

  // Returns the latest reading + its advisories in ONE call, read-only
  // (doesn't create a new database entry every time you refresh).
  static Future<ReadingWithAdvisory?> fetchLatestWithAdvisory() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/advisory/latest'));
    if (response.statusCode == 200) {
      return ReadingWithAdvisory.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null; // no readings yet
    } else {
      throw Exception('Failed to load advisory (${response.statusCode})');
    }
  }

  static Future<List<Reading>> fetchHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/readings/history'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((r) => Reading.fromJson(r)).toList();
    } else {
      throw Exception('Failed to load history (${response.statusCode})');
    }
  }

  static Future<ReadingWithAdvisory> submitReading({
    required String soilType,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double soilMoisture,
    required double temperature,
    required double humidity,
    required String district,
    required String crop,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/readings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'soil_type': soilType,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'soil_moisture': soilMoisture,
        'temperature': temperature,
        'humidity': humidity,
        'district': district,
        'crop': crop,
      }),
    );
    if (response.statusCode == 200) {
      return ReadingWithAdvisory.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to submit reading (${response.statusCode}): ${response.body}');
    }
  }

  // Runs the agri-logic against the LATEST saved reading by re-submitting it.
  // Simplest way for the dashboard to always show current advisories.
  static Future<List<Advisory>> fetchAdvisoriesForLatest() async {
    final result = await fetchLatestWithAdvisory();
    return result?.advisories ?? [];
  }
}
