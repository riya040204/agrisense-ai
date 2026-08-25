// AgriSense AI - Crop Journey
// "Day 1: sow seed. Day 12: check progress." This screen tracks days since
// sowing, shows the real growth stage the crop is in, and what's critical
// right now — combined with the latest actual sensor reading.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'crop_stages.dart';
import 'models.dart';
import 'api_service.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  DateTime? _sowingDate;
  String _crop = 'soybean';
  ReadingWithAdvisory? _latest;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('sowing_date_millis');
    final storedCrop = prefs.getString('sowing_crop');

    ReadingWithAdvisory? latest;
    try {
      latest = await ApiService.fetchLatestWithAdvisory();
    } catch (_) {
      // fine — journey can still show the sowing countdown without a reading
    }

    setState(() {
      _sowingDate = millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
      _crop = storedCrop ?? latest?.reading.crop ?? 'soybean';
      _latest = latest;
      _loading = false;
    });
  }

  Future<void> _setSowingDate(DateTime date, String crop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sowing_date_millis', date.millisecondsSinceEpoch);
    await prefs.setString('sowing_crop', crop);
    setState(() {
      _sowingDate = date;
      _crop = crop;
    });
  }

  Future<void> _pickSowingDate() async {
    String tempCrop = _crop;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 200)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    // Quick crop confirm alongside the date.
    final confirmedCrop = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Which crop?'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: ['soybean', 'wheat'].map((c) {
              return RadioListTile<String>(
                title: Text(c[0].toUpperCase() + c.substring(1)),
                value: c,
                groupValue: tempCrop,
                onChanged: (v) => setDialogState(() => tempCrop = v!),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, tempCrop), child: const Text('Start')),
        ],
      ),
    );
    if (confirmedCrop == null) return;
    _setSowingDate(date, confirmedCrop);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Journey')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.moss))
          : _sowingDate == null
              ? _buildStartPrompt()
              : _buildJourney(),
    );
  }

  Widget _buildStartPrompt() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.grass_rounded, size: 64, color: AppColors.moss.withValues(alpha: 0.4)),
        const SizedBox(height: 20),
        Text('Start your crop journey', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(
          'Tell us when you sowed, and every reading you add from now on will show '
          'exactly what growth stage your crop is in and what it needs.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _pickSowingDate,
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Set sowing date'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.moss, minimumSize: const Size.fromHeight(50)),
        ),
      ],
    );
  }

  Widget _buildJourney() {
    final daysAfterSowing = DateTime.now().difference(_sowingDate!).inDays;
    final stage = currentStage(_crop, daysAfterSowing);
    final stages = cropStages[_crop] ?? cropStages['soybean']!;
    final totalDays = stages.last.endDay;
    final progress = (daysAfterSowing / totalDays).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.moss, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Day $daysAfterSowing', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                  TextButton(
                    onPressed: _pickSowingDate,
                    child: const Text('Change', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
              Text(
                '${_crop[0].toUpperCase()}${_crop.substring(1)} · sown ${_sowingDate!.toIso8601String().split('T')[0]}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: AppColors.ochre,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (stage != null) _StageCard(stage: stage, daysAfterSowing: daysAfterSowing),
        const SizedBox(height: 20),
        Text('Stage timeline', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ...stages.map((s) => _TimelineRow(stage: s, isCurrent: s == stage, daysAfterSowing: daysAfterSowing)),
        if (_latest != null) ...[
          const SizedBox(height: 24),
          Text('Latest reading vs. what this stage needs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ..._latest!.advisories.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.severityColor(a.severity).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(a.message, style: Theme.of(context).textTheme.bodySmall),
              )),
        ],
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  final GrowthStage stage;
  final int daysAfterSowing;
  const _StageCard({required this.stage, required this.daysAfterSowing});

  IconData get _icon {
    if (stage.name.contains('Germination')) return Icons.spa_outlined;
    if (stage.name.contains('Vegetative') || stage.name.contains('Tillering')) return Icons.grass_rounded;
    if (stage.name.contains('Flowering')) return Icons.local_florist_rounded;
    if (stage.name.contains('Pod') || stage.name.contains('Jointing')) return Icons.eco_rounded;
    if (stage.name.contains('Filling')) return Icons.agriculture_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = stage.criticalForWater ? AppColors.watch : AppColors.healthy;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(_icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(stage.name, style: Theme.of(context).textTheme.titleMedium),
                    if (stage.criticalForWater) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.watch.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Critical for water', style: TextStyle(fontSize: 10, color: AppColors.watch, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(stage.note, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final GrowthStage stage;
  final bool isCurrent;
  final int daysAfterSowing;
  const _TimelineRow({required this.stage, required this.isCurrent, required this.daysAfterSowing});

  @override
  Widget build(BuildContext context) {
    final isPast = daysAfterSowing > stage.endDay;
    final color = isCurrent ? AppColors.moss : (isPast ? AppColors.inkMuted : AppColors.inkMuted.withValues(alpha: 0.4));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isPast ? Icons.check_circle_rounded : (isCurrent ? Icons.radio_button_checked_rounded : Icons.circle_outlined),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${stage.name}  (Day ${stage.startDay}-${stage.endDay})',
              style: TextStyle(color: color, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}