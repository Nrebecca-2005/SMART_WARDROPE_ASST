import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../database/tables.dart';
import '../../models/clothing_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/ai_service.dart';
import '../../services/camera_service.dart';
import '../../widgets/custom_button.dart';

/// The final step of the existing capture flow. It writes through
/// [WardrobeProvider] to the application's existing SQLite database.
class AddClothingScreen extends StatefulWidget {
  final String? initialImagePath;

  const AddClothingScreen({super.key, this.initialImagePath});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _cameraService = CameraService();
  final _aiService = AiService();

  String? _imagePath;
  bool _isLoadingOptions = true;
  bool _isSaving = false;
  bool _isAnalyzing = false;
  bool _isDetecting = false;
  AiDetectionResult? _detection;
  String? _aiAnalysisMessage;
  AiClothingAnalysis? _aiAnalysis;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _colors = [];
  List<Map<String, dynamic>> _styles = [];
  int? _categoryId;
  int? _colorId;
  int? _styleId;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await Future.wait([
        db.query(TableNames.categories, orderBy: 'category_name'),
        db.query(TableNames.colors, orderBy: 'color_name'),
        db.query(TableNames.occasions, orderBy: 'occasion_name'),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0];
        _colors = results[1];
        _styles = results[2];
        _categoryId = _categories.isNotEmpty
            ? _categories.first['category_id'] as int
            : null;
        _colorId = _colors.isNotEmpty ? _colors.first['color_id'] as int : null;
        _styleId = _styles.isNotEmpty
            ? _styles.first['occasion_id'] as int
            : null;
        _isLoadingOptions = false;
      });
      if (_imagePath != null) {
        await _runClothingAnalysis();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOptions = false);
      _showMessage(
        'Could not load clothing options. Please try again.',
        error: true,
      );
    }
  }

  Future<void> _runClothingAnalysis() async {
    final path = _imagePath;
    if (path == null) return;

    setState(() {
      _isAnalyzing = true;
      _aiAnalysisMessage = null;
    });

    try {
      final analysis = await _aiService.analyzeClothing(path);
      if (!mounted) return;
      setState(() {
        _aiAnalysis = analysis;
        _categoryId =
            _matchLookupId(_categories, 'category_name', analysis.category) ??
            _categoryId;
        _colorId =
            _matchLookupId(_colors, 'color_name', analysis.color) ?? _colorId;
        _styleId =
            _matchLookupId(
              _styles,
              'occasion_name',
              _mapStyle(analysis.style),
            ) ??
            _styleId;
        _aiAnalysisMessage =
            'AI suggests ${analysis.category} (${analysis.style}). You can change any field below.';
        _isAnalyzing = false;
      });
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiAnalysisMessage = error.message;
        _isAnalyzing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiAnalysisMessage =
            'Clothing analysis is unavailable. Enter the details manually.';
        _isAnalyzing = false;
      });
    }
  }

  String _mapStyle(String style) {
    return switch (style.toLowerCase()) {
      'formal' => 'Formal',
      'casual' => 'Casual',
      'sportswear' => 'Sports',
      'outdoor' => 'Travel',
      _ => style,
    };
  }

  int? _matchLookupId(
    List<Map<String, dynamic>> rows,
    String nameKey,
    String suggestion,
  ) {
    final normalized = suggestion.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    for (final row in rows) {
      final name = (row[nameKey] as String).toLowerCase();
      if (name == normalized ||
          name.contains(normalized) ||
          normalized.contains(name)) {
        final idKey = nameKey == 'category_name'
            ? 'category_id'
            : nameKey == 'color_name'
            ? 'color_id'
            : 'occasion_id';
        return row[idKey] as int;
      }
    }

    const aliases = {
      'trousers': 'trouser',
      'sneakers': 'sneakers',
      'shoes': 'shoes',
      't-shirt': 't-shirt',
      'accessory': 'cap',
    };
    final alias = aliases[normalized];
    if (alias != null) {
      return _matchLookupId(rows, nameKey, alias);
    }
    return null;
  }

  Future<void> _choosePhoto() async {
    final path = await Navigator.of(context).pushNamed('/camera') as String?;
    if (!mounted || path == null) return;

    // Step 1: YOLO detection/localization. On failure we fall back to the
    // original photo so the flow never breaks.
    final detectionInput = await _runDetection(path);
    if (!mounted) return;

    final processed = await Navigator.of(
      context,
    ).pushNamed('/background-removal-preview', arguments: detectionInput);
    if (!mounted) return;
    if (processed == '__retake__') {
      await _choosePhoto();
      return;
    }
    if (processed is String && processed.isNotEmpty) {
      setState(() => _imagePath = processed);
      await _runClothingAnalysis();
    }
  }

  /// Runs YOLOv8 detection and returns the image path to continue with:
  /// the cropped primary detection when available, otherwise the original.
  Future<String> _runDetection(String path) async {
    setState(() {
      _isDetecting = true;
      _detection = null;
    });
    try {
      final detection = await _aiService.detectClothing(path);
      if (!mounted) return path;
      setState(() {
        _detection = detection;
        _isDetecting = false;
      });
      return detection.croppedImagePath ?? path;
    } on AiServiceException {
      if (mounted) setState(() => _isDetecting = false);
      return path;
    } catch (_) {
      if (mounted) setState(() => _isDetecting = false);
      return path;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagePath == null || _categoryId == null || _colorId == null) {
      _showMessage(
        'Add a photo, category, and color before saving.',
        error: true,
      );
      return;
    }
    final userId = context.read<AuthProvider>().currentUser?.userId;
    if (userId == null) {
      _showMessage('Please sign in before adding clothing.', error: true);
      return;
    }

    setState(() => _isSaving = true);
    final savedImagePath = await _cameraService.saveImageToApp(_imagePath!);
    if (!mounted) return;
    if (savedImagePath == null) {
      setState(() => _isSaving = false);
      _showMessage(
        'Could not save the selected image. Please try again.',
        error: true,
      );
      return;
    }

    final added = await context.read<WardrobeProvider>().addClothingItem(
      ClothingItem(
        userId: userId,
        categoryId: _categoryId!,
        colorId: _colorId!,
        occasionId: _styleId,
        clothingName: _nameController.text.trim(),
        imagePath: savedImagePath,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (added) {
      Navigator.of(context).pop(true);
    } else {
      _showMessage(
        'Could not save this clothing item. Please try again.',
        error: true,
      );
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Clothing Details')),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildPhotoPicker(),
                    if (_isDetecting || _detection != null) ...[
                      const SizedBox(height: 12),
                      _buildDetectionCard(),
                    ],
                    if (_isAnalyzing) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Analyzing clothing with FashionCLIP…'),
                    ],
                    if (_aiAnalysisMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildAiSuggestionCard(),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: _decoration(
                        'Clothing name',
                        'e.g. White shirt',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a clothing name.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      'Category',
                      _categories,
                      'category_id',
                      'category_name',
                      _categoryId,
                      (value) => setState(() => _categoryId = value),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      'Color',
                      _colors,
                      'color_id',
                      'color_name',
                      _colorId,
                      (value) => setState(() => _colorId = value),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(
                      'Style',
                      _styles,
                      'occasion_id',
                      'occasion_name',
                      _styleId,
                      (value) => setState(() => _styleId = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: _decoration(
                        'Description (optional)',
                        'Add any useful details',
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 28),
                    CustomButton(
                      label: 'Save to Wardrobe',
                      icon: Icons.check_circle_outline,
                      isLoading: _isSaving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetectionCard() {
    final detection = _detection;
    final primary = detection?.primary;
    final String message;
    if (_isDetecting) {
      message = 'Detecting the clothing object with YOLOv8…';
    } else if (primary != null) {
      final confidence = (primary.confidence * 100).toStringAsFixed(0);
      message =
          'YOLOv8 detected "${primary.label}" with $confidence% confidence. '
          'The image was cropped to this object for background removal.';
    } else {
      message =
          'YOLOv8 did not detect a distinct object, so no detection is shown. '
          'Continuing with the full photo — Fashion-CLIP will classify the '
          'clothing category, style and colour.';
    }

    return Card(
      color: AppColors.secondary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isDetecting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.center_focus_strong,
                color: AppColors.secondary,
                size: 18,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Object detection (YOLOv8)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSuggestionCard() {
    final analysis = _aiAnalysis;
    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'AI suggestion (editable)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_aiAnalysisMessage ?? ''),
            if (analysis != null) ...[
              const SizedBox(height: 8),
              Text(
                'Category confidence: ${(analysis.categoryConfidence * 100).toStringAsFixed(0)}% • '
                'Style confidence: ${(analysis.styleConfidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() => InkWell(
    onTap: _choosePhoto,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imagePath == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 42,
                  color: AppColors.primary,
                ),
                SizedBox(height: 10),
                Text('Take or select a clothing photo'),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(_imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary,
                      size: 42,
                    ),
                  ),
                ),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ),
              ],
            ),
    ),
  );

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );

  Widget _dropdown(
    String label,
    List<Map<String, dynamic>> values,
    String idKey,
    String nameKey,
    int? selected,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    initialValue: selected,
    decoration: _decoration(label, ''),
    items: values
        .map(
          (item) => DropdownMenuItem(
            value: item[idKey] as int,
            child: Text(item[nameKey] as String),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}
