// AgriSense AI - Diagnose screen
// Snap or upload a leaf photo -> real pretrained model (via backend) ->
// healthy / diseased result. Not a lab diagnosis — a first-check tool.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'models.dart';
import 'theme.dart';

class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key});

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  Uint8List? _imageBytes;
  String? _filename;
  bool _loading = false;
  String? _error;
  Diagnosis? _result;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _filename = file.name;
      _result = null;
      _error = null;
    });
  }

  Future<void> _diagnose() async {
    if (_imageBytes == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.diagnoseImage(_imageBytes!, _filename ?? 'leaf.jpg');
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _filename = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnose Leaf')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_imageBytes == null) _buildPickPrompt() else _buildPreview(),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(_result!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.alert.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: AppColors.alert)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickPrompt() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.image_search_rounded, size: 64, color: AppColors.moss.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text('Take or upload a leaf photo', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Get a first check for common signs of disease. This is not a lab diagnosis.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text('Take photo'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.moss, minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from gallery'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.moss, minimumSize: const Size.fromHeight(50)),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(_imageBytes!, height: 260, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.inkMuted, minimumSize: const Size.fromHeight(48)),
                child: const Text('Retake'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _loading ? null : _diagnose,
                style: FilledButton.styleFrom(backgroundColor: AppColors.moss, minimumSize: const Size.fromHeight(48)),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Diagnose'),
              ),
            ),
          ],
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          Text(
            'First check can take ~20s while the model warms up.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildResultCard(Diagnosis result) {
    final color = result.healthy ? AppColors.healthy : AppColors.alert;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(result.healthy ? Icons.check_circle_rounded : Icons.warning_rounded, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.healthy ? 'Looks healthy' : 'Possible ${result.condition}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.crop ?? 'Crop'} · ${result.confidence.toStringAsFixed(0)}% confidence',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Text(result.advice, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}