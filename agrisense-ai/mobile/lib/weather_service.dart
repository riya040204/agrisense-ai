// AgriSense AI - Weather service
// Auto-fills temperature & humidity using Open-Meteo (free, no API key needed).
// https://open-meteo.com

import 'dart:convert';
import 'package:http/http.dart' as http;

class DistrictLocation {
  final String name;
  final double lat;
  final double lon;
  const DistrictLocation(this.name, this.lat, this.lon);
}

// Coordinates for the shortlisted MP districts.
const Map<String, DistrictLocation> districtLocations = {
  'Dewas': DistrictLocation('Dewas', 22.9676, 76.0534),
  'Indore': DistrictLocation('Indore', 22.7196, 75.8577),
  'Bhopal': DistrictLocation('Bhopal', 23.2599, 77.4126),
  'Ujjain': DistrictLocation('Ujjain', 23.1793, 75.7849),
  'Sehore': DistrictLocation('Sehore', 23.2032, 77.0844),
  'Vidisha': DistrictLocation('Vidisha', 23.5251, 77.8081),
};

class WeatherReading {
  final double temperature;
  final double humidity;
  const WeatherReading({required this.temperature, required this.humidity});
}

class WeatherService {
  static Future<WeatherReading> fetchCurrent(String district) async {
    final loc = districtLocations[district] ?? districtLocations['Dewas']!;
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${loc.lat}&longitude=${loc.lon}'
      '&current=temperature_2m,relative_humidity_2m',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Weather lookup failed (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    final current = data['current'];
    return WeatherReading(
      temperature: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
    );
  }
}