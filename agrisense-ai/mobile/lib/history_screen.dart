// AgriSense AI - History screen
// Shows every past reading so a farmer can see how their field changed
// over days — "4-5 days ago vs today."

import 'package:flutter/material.dart';
import 'models.dart';
import 'api_service.dart';
import 'theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Reading>? _readings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ApiService.fetchHistory();
      setState(() => _readings = data);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        color: AppColors.moss,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(child: Text('Could not load history.\n$_error', textAlign: TextAlign.center)),
        ],
      );
    }
    if (_readings == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.moss));
    }
    if (_readings!.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.history_rounded, size: 56, color: AppColors.moss.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Center(child: Text('No readings yet — add your first one.')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _readings!.length,
      itemBuilder: (context, index) {
        final reading = _readings![index];
        // Compare against the NEXT item in the (newest-first) list = the previous reading in time.
        final previous = index + 1 < _readings!.length ? _readings![index + 1] : null;
        return _HistoryCard(reading: reading, previous: previous, isLatest: index == 0);
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Reading reading;
  final Reading? previous;
  final bool isLatest;

  const _HistoryCard({required this.reading, this.previous, required this.isLatest});

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _delta(String label, double current, double? prev, String unit) {
    String arrow = '';
    Color color = AppColors.inkMuted;
    if (prev != null) {
      final diff = current - prev;
      if (diff.abs() >= 0.1) {
        arrow = diff > 0 ? ' ↑${diff.toStringAsFixed(1)}' : ' ↓${diff.abs().toStringAsFixed(1)}';
        color = diff > 0 ? AppColors.healthy : AppColors.alert;
      }
    }
    return RichText(
      text: TextSpan(
        style: AppTheme.mono(size: 13, weight: FontWeight.w500, color: AppColors.ink),
        children: [
          TextSpan(text: '$label ${current.toStringAsFixed(1)}$unit'),
          if (arrow.isNotEmpty) TextSpan(text: arrow, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.moss.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_capitalize(reading.crop)} · ${reading.district}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (isLatest) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.ochre.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Latest', style: TextStyle(fontSize: 10, color: AppColors.ochre, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          Text(
            reading.timestamp.split('.')[0].replaceAll('T', '  '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _delta('N', reading.nitrogen, previous?.nitrogen, ''),
              _delta('P', reading.phosphorus, previous?.phosphorus, ''),
              _delta('K', reading.potassium, previous?.potassium, ''),
              _delta('Moisture', reading.soilMoisture, previous?.soilMoisture, '%'),
              _delta('Temp', reading.temperature, previous?.temperature, '°C'),
            ],
          ),
        ],
      ),
    );
  }
}