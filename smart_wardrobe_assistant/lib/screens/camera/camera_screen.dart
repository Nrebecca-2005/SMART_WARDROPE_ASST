// Camera Module — Rebecca
// Screens: CameraScreen, GalleryScreen, ImagePreviewScreen
// Implemented by: Rebecca

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/camera_service.dart';
import '../../widgets/loading_widget.dart';
import 'gallery_screen.dart';
import 'image_preview_screen.dart';

/// Full-featured camera capture screen.
///
/// • Live [CameraPreview] with a frosted control bar at the bottom
/// • Front / rear camera toggle
/// • Flash mode toggle (off → auto → on)
/// • Gallery shortcut (opens [GalleryScreen])
/// • Capture button with ripple animation (opens [ImagePreviewScreen])
/// • Permission handling via [CameraService]
class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();

  CameraController? _controller;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _permissionDenied = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(index: _selectedCameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera({int index = 0}) async {
    if (widget.cameras.isEmpty) {
      setState(() => _permissionDenied = true);
      return;
    }

    final granted = await _cameraService.requestCameraPermission();
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }

    setState(() => _isCameraInitialized = false);

    await _controller?.dispose();

    _controller = CameraController(
      widget.cameras[index],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      if (!mounted) return;
      setState(() {
        _selectedCameraIndex = index;
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('CameraScreen init error: $e');
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _captureImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    final result = await _cameraService.capturePhoto(_controller!);

    if (!mounted) return;
    setState(() => _isCapturing = false);

    if (result.success && result.imagePath != null) {
      final selectedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(imagePath: result.imagePath!),
        ),
      );
      if (mounted && selectedPath != null) {
        Navigator.of(context).pop(selectedPath);
      }
    } else {
      _showError(result.errorMessage ?? 'Failed to capture image.');
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    await _initCamera(index: nextIndex);
  }

  Future<void> _cycleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final nextMode = modes[(modes.indexOf(_flashMode) + 1) % modes.length];

    await _controller!.setFlashMode(nextMode);
    setState(() => _flashMode = nextMode);
  }

  Future<void> _openGallery() async {
    final selectedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryScreen()),
    );
    if (mounted && selectedPath != null) {
      Navigator.of(context).pop(selectedPath);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.small.copyWith(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.off:
      default:
        return Icons.flash_off_rounded;
    }
  }

  String get _flashLabel {
    switch (_flashMode) {
      case FlashMode.always:
        return 'On';
      case FlashMode.auto:
        return 'Auto';
      default:
        return 'Off';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cameraControl),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      title: Text(
        'Camera',
        style: AppTextStyles.appBarTitle.copyWith(color: AppColors.cameraControl),
      ),
      actions: [
        // Flash toggle
        if (_isCameraInitialized)
          GestureDetector(
            onTap: _cycleFlash,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_flashIcon, color: AppColors.cameraControl, size: 22),
                  Text(
                    _flashLabel,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.cameraControl, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) return _buildPermissionDenied();
    if (!_isCameraInitialized) {
      return const LoadingWidget(
        message: 'Starting camera…',
        color: AppColors.cameraControl,
      );
    }

    return LoadingOverlay(
      isLoading: _isCapturing,
      message: 'Capturing…',
      child: Stack(
        fit: StackFit.loose,
        children: [
          // ── Camera preview ───────────────────────────────────────────────
          _buildCameraPreview(),

          // ── Top gradient (for appbar legibility) ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Bottom control bar ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControlBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return CameraPreview(_controller!);
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xE6000000), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery button
          _ControlButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            color: AppColors.secondary,
            onTap: _openGallery,
          ),

          // Shutter button
          _ShutterButton(
            isCapturing: _isCapturing,
            onTap: _captureImage,
          ),

          // Flip camera button
          _ControlButton(
            icon: Icons.flip_camera_ios_outlined,
            label: 'Flip',
            color: AppColors.cameraControl,
            onTap: widget.cameras.length > 1 ? _toggleCamera : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text('Camera Access Required', style: AppTextStyles.subheading),
              const SizedBox(height: 8),
              Text(
                'Please allow camera access in your device Settings to take photos.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => ph.openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(200, 52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

/// Small labelled icon button in the control bar.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.cameraControl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated shutter / capture button.
class _ShutterButton extends StatefulWidget {
  final bool isCapturing;
  final VoidCallback onTap;

  const _ShutterButton({required this.isCapturing, required this.onTap});

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _animController.forward();
  void _onTapUp(TapUpDetails _) {
    _animController.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _animController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isCapturing
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : Colors.white,
              ),
              child: widget.isCapturing
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// No standalone openAppSettings needed — ph.openAppSettings() used inline.
