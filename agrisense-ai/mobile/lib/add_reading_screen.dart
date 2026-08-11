// AgriSense AI - Add Reading screen
// Where a farmer (or faculty-provided data) gets typed in directly —
// no developer tools required.

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';
import 'theme.dart';
import 'weather_service.dart';

class AddReadingScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const AddReadingScreen({super.key, required this.onSaved});

  @override
  State<AddReadingScreen> createState() => _AddReadingScreenState();
}

class _AddReadingScreenState extends State<AddReadingScreen> {
  final _formKey = GlobalKey<FormState>();

  String _crop = 'soybean';
  String _soilType = 'black_cotton';
  String _district = 'Dewas';
  final _nitrogenCtrl = TextEditingController();
  final _phosphorusCtrl = TextEditingController();
  final _potassiumCtrl = TextEditingController();
  final _moistureCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _humidityCtrl = TextEditingController();

  bool _submitting = false;
  bool _fetchingWeather = false;

  static const _crops = ['soybean', 'wheat'];
  static const _soilTypes = ['black_cotton', 'alluvial'];
  static const _districts = ['Dewas', 'Indore', 'Bhopal', 'Ujjain', 'Sehore', 'Vidisha'];

  @override
  void dispose() {
    for (final c in [_nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl, _moistureCtrl, _tempCtrl, _humidityCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autoFillWeather() async {
    setState(() => _fetchingWeather = true);
    try {
      final weather = await WeatherService.fetchCurrent(_district);
      setState(() {
        _tempCtrl.text = weather.temperature.toStringAsFixed(1);
        _humidityCtrl.text = weather.humidity.toStringAsFixed(0);
        _fetchingWeather = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Live weather for $_district filled in'), backgroundColor: AppColors.healthy),
      );
    } catch (e) {
      setState(() => _fetchingWeather = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not fetch weather: $e'), backgroundColor: AppColors.alert),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final result = await ApiService.submitReading(
        soilType: _soilType,
        nitrogen: double.parse(_nitrogenCtrl.text),
        phosphorus: double.parse(_phosphorusCtrl.text),
        potassium: double.parse(_potassiumCtrl.text),
        soilMoisture: double.parse(_moistureCtrl.text),
        temperature: double.parse(_tempCtrl.text),
        humidity: double.parse(_humidityCtrl.text),
        district: _district,
        crop: _crop,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showResultSheet(result);
      for (final c in [_nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl, _moistureCtrl, _tempCtrl, _humidityCtrl]) {
        c.clear();
      }
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: AppColors.alert),
      );
    }
  }

  Future<void> _showResultSheet(ReadingWithAdvisory result) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.healthy),
                  const SizedBox(width: 8),
                  Text('Reading saved', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              ...result.advisories.map((a) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.severityColor(a.severity).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.category[0].toUpperCase() + a.category.substring(1),
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.severityColor(a.severity)),
                        ),
                        const SizedBox(height: 4),
                        Text(a.message),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.moss, minimumSize: const Size.fromHeight(48)),
                child: const Text('View on dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Reading')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Crop & location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _dropdownRow('Crop', _crop, _crops, (v) => setState(() => _crop = v!)),
            const SizedBox(height: 10),
            _dropdownRow('Soil type', _soilType, _soilTypes, (v) => setState(() => _soilType = v!),
                labelFor: (s) => s.replaceAll('_', ' ')),
            const SizedBox(height: 10),
            _dropdownRow('District', _district, _districts, (v) => setState(() => _district = v!)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sensor values', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _fetchingWeather ? null : _autoFillWeather,
                  icon: _fetchingWeather
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_sync_rounded, size: 18),
                  label: const Text('Auto-detect weather'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ochre),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField('Nitrogen (N)', 'kg/ha', _nitrogenCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _numberField('Phosphorus (P)', 'kg/ha', _phosphorusCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField('Potassium (K)', 'kg/ha', _potassiumCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _numberField('Soil moisture', '%', _moistureCtrl)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField('Temperature', '°C', _tempCtrl)),
                const SizedBox(width: 10),
                Expanded(child: _numberField('Humidity', '%', _humidityCtrl)),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.moss, minimumSize: const Size.fromHeight(52)),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save reading & get advice'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownRow(String label, String value, List<String> options, ValueChanged<String?> onChanged,
      {String Function(String)? labelFor}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: options
          .map((o) => DropdownMenuItem(
                value: o,
                child: Text(_capitalize(labelFor != null ? labelFor(o) : o)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _numberField(String label, String suffix, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (double.tryParse(value) == null) return 'Enter a number';
        return null;
      },
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}