// AgriSense AI - Mobile App
// Week 4-5: Dashboard connected to the live backend.

import 'package:flutter/material.dart';
import 'models.dart';
import 'api_service.dart';

void main() {
  runApp(const AgriSenseApp());
}

class AgriSenseApp extends StatelessWidget {
  const AgriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriSense AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32), // agricultural green
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReadingWithAdvisory? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.fetchLatestWithAdvisory();
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriSense AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Could not reach the backend.\n\n'
              'Make sure `uvicorn main:app --reload` is running in your backend '
              'folder, then pull down to retry.\n\nDetails: $_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      );
    }

    if (_data == null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.eco_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'No readings yet.\nSubmit one via the backend\'s /docs page to see it here.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final reading = _data!.reading;
    final advisories = _data!.advisories;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(reading),
        const SizedBox(height: 16),
        _buildSensorGrid(reading),
        const SizedBox(height: 24),
        Text('Advisories', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...advisories.map((a) => _buildAdvisoryCard(a)),
      ],
    );
  }

  Widget _buildHeaderCard(Reading reading) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.agriculture, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_capitalize(reading.crop)} • ${reading.district}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Soil: ${_capitalize(reading.soilType.replaceAll('_', ' '))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Updated: ${reading.timestamp.split('.')[0].replaceAll('T', ' ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGrid(Reading reading) {
    final items = [
      ('Nitrogen (N)', '${reading.nitrogen} kg/ha', Icons.science_outlined),
      ('Phosphorus (P)', '${reading.phosphorus} kg/ha', Icons.science_outlined),
      ('Potassium (K)', '${reading.potassium} kg/ha', Icons.science_outlined),
      ('Soil Moisture', '${reading.soilMoisture}%', Icons.water_drop_outlined),
      ('Temperature', '${reading.temperature}°C', Icons.thermostat_outlined),
      ('Humidity', '${reading.humidity}%', Icons.cloud_outlined),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items.map((item) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(item.$3, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.$1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(item.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdvisoryCard(Advisory advisory) {
    final Color color = switch (advisory.severity) {
      'red' => Colors.red,
      'amber' => Colors.orange,
      _ => Colors.green,
    };
    final IconData icon = switch (advisory.category) {
      'irrigation' => Icons.water_drop,
      'nutrient' => Icons.eco,
      'pest' => Icons.bug_report,
      _ => Icons.info,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          _capitalize(advisory.category),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        subtitle: Text(advisory.message),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
