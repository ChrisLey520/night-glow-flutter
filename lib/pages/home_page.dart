import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'album_page.dart';

import '../models/color_model.dart';
import '../models/preset_data.dart';
import '../models/custom_image_preset.dart';
import '../repositories/custom_preset_repository.dart';
import '../repositories/local_custom_preset_repository.dart';
import '../utils/state_store.dart';
import '../utils/brightness_manager.dart';
import '../utils/membership_manager.dart';
import '../widgets/camera_view.dart';
import '../widgets/control_panel.dart';
import '../widgets/preview_window.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/membership_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final StateStore _store = StateStore();
  final CustomPresetRepository _customRepo = LocalCustomPresetRepository();
  late MembershipManager _membership;

  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // Fill light state
  Color _fillColor = Colors.white;
  double _screenBrightness = 1.0;
  int _selectedIndex = 0;
  ColorModel _customColor = const ColorModel(hue: 0, saturation: 1.0, brightness: 1.0);

  // Custom image presets
  List<CustomImagePreset> _customPresets = [];
  String? _selectedCustomPresetId;

  // Preview window — default 16:9 (h = w × 16/9); x/y = -1 means "center on first build"
  double _previewX = -1;
  double _previewY = -1;
  double _previewW = 160;
  double _previewH = 285;

  // Settings
  bool _mirrorCapture = false;
  bool _motionPhoto = false;

  // UI state
  bool _showControlPanel = false;
  bool _showMembershipModal = false;
  bool _showTestDrawer = false;
  bool _addingPreset = false;
  XFile? _pendingImage;
  String _pendingImageName = '';
  String? _pendingImageNameError;
  String _lastPhotoPath = '';

  // Video state
  bool _isVideoMode = false;
  bool _isRecording = false;

  // IAP stream
  StreamSubscription<List<PurchaseDetails>>? _iapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    _membership = MembershipManager(_store);
    _listenIAP();
    _loadSavedState();

    if (mounted) setState(() {});

    await Future.wait([
      _membership.init(),
      _requestPermissions().then((_) => _initCamera()),
      _customRepo.loadAll().then((list) {
        _customPresets = list;
        final savedId = _store.selectedCustomPresetId;
        if (savedId != null &&
            list.any((p) => p.id == savedId)) {
          _selectedCustomPresetId = savedId;
          _updateFillColorFromCustom(
              list.firstWhere((p) => p.id == savedId));
        }
      }),
    ]);

    await BrightnessManager.setFullBrightness();
    await BrightnessManager.setBrightness(_screenBrightness);

    if (mounted) setState(() {});
  }

  void _loadSavedState() {
    _selectedIndex = _store.selectedIndex;
    _previewX = _store.previewX;
    _previewY = _store.previewY;
    _previewW = _store.previewW;
    _previewH = _store.previewH;
    _mirrorCapture = _store.mirrorCapture;
    _screenBrightness = _store.screenBrightness;
    _customColor = ColorModel(
      hue: _store.hue,
      saturation: _store.saturation,
      brightness: _store.colorBrightness,
    );
    _updateFillColor();
  }

  void _updateFillColor() {
    // Custom image preset takes priority over built-in presets
    if (_selectedCustomPresetId != null) return;
    final preset = kPresets[_selectedIndex];
    if (preset.isCustom) {
      _fillColor = _customColor.toColor();
    } else {
      _fillColor = preset.color.toColor();
    }
  }

  void _updateFillColorFromCustom(CustomImagePreset preset) {
    // Image fill is handled in build() via _selectedCustomPresetId;
    // set _fillColor to transparent so the image layer shows through.
    _fillColor = Colors.transparent;
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Prefer front camera for selfie fill light
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraCtrl = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraCtrl!.initialize();
      // Disable flash to prevent the white-screen shutter animation on iOS
      await _cameraCtrl!.setFlashMode(FlashMode.off);
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _listenIAP() {
    _iapSubscription = InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        bool anyPurchased = false;
        for (final p in purchases) {
          try {
            await _membership.applyPurchase(p);
            if (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored) {
              anyPurchased = true;
            }
          } catch (e) {
            debugPrint('IAP applyPurchase error: $e');
          }
        }
        if (!mounted) return;
        // Fix: close the modal only after the purchase is actually confirmed
        // via the stream, not optimistically in the purchase() call.
        if (anyPurchased && _showMembershipModal) {
          setState(() => _showMembershipModal = false);
        } else {
          setState(() {});
        }
      },
      onError: (Object error) {
        debugPrint('IAP purchaseStream error: $error');
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // Fix #4: null out reference and reset ready flag so stale controller
      // is not used by CameraView or double-disposed in dispose()
      _cameraCtrl?.dispose();
      _cameraCtrl = null;
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      BrightnessManager.setBrightness(_screenBrightness);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraCtrl?.dispose();
    _iapSubscription?.cancel();
    BrightnessManager.resetBrightness();
    super.dispose();
  }

  void _onPresetSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedCustomPresetId = null;
      _updateFillColor();
    });
    _store.saveSelectedIndex(index);
    _store.saveSelectedCustomPresetId(null);
    if (kPresets[index].isCustom) {
      _store.saveColor(_customColor);
    }
  }

  void _onCustomPresetSelected(CustomImagePreset preset) {
    setState(() {
      _selectedCustomPresetId = preset.id;
      _updateFillColorFromCustom(preset);
    });
    _store.saveSelectedCustomPresetId(preset.id);
  }

  void _onCustomPresetsChanged(List<CustomImagePreset> presets) {
    setState(() {
      _customPresets = presets;
      // If the selected preset was removed, fall back to first built-in
      if (_selectedCustomPresetId != null &&
          !presets.any((p) => p.id == _selectedCustomPresetId)) {
        _selectedCustomPresetId = null;
        _store.saveSelectedCustomPresetId(null);
        _updateFillColor();
      }
    });
  }

  void _onAddImage(XFile image) {
    setState(() {
      _pendingImage = image;
      _pendingImageName = '';
      _pendingImageNameError = null;
    });
  }

  Future<void> _confirmPendingImage() async {
    final image = _pendingImage;
    if (image == null) return;
    final name = _pendingImageName.trim();
    if (name.isEmpty) {
      setState(() => _pendingImageNameError = '名称不能为空');
      return;
    }
    if (_customPresets.any((p) => p.name == name)) {
      setState(() => _pendingImageNameError = '名称已存在');
      return;
    }
    setState(() { _pendingImage = null; _addingPreset = true; });
    try {
      final preset = await _customRepo.add(
        name: name,
        sourceFile: File(image.path),
      );
      if (!mounted) return;
      final updated = [..._customPresets, preset];
      _onCustomPresetsChanged(updated);
      _onCustomPresetSelected(preset);
    } finally {
      if (mounted) setState(() => _addingPreset = false);
    }
  }

  void _cancelPendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingImageName = '';
      _pendingImageNameError = null;
    });
  }

  void _onColorChanged(ColorModel color) {
    setState(() {
      _customColor = color;
      _fillColor = color.toColor();
    });
    _store.saveColor(color);
  }

  void _onBrightnessChanged(double value) {
    setState(() => _screenBrightness = value);
    BrightnessManager.setBrightness(value);
    _store.saveScreenBrightness(value);
  }

  void _onPreviewLayout(double x, double y, double w, double h) {
    setState(() {
      _previewX = x;
      _previewY = y;
      _previewW = w;
      _previewH = h;
    });
    _store.savePreviewLayout(x, y, w, h);
  }

  void _onMirrorChanged(bool value) {
    setState(() => _mirrorCapture = value);
    _store.saveMirrorCapture(value);
  }

  double get _fillSaturation {
    final preset = kPresets[_selectedIndex];
    if (preset.isCustom) return _customColor.saturation;
    return preset.color.saturation;
  }

  void _showMembership() {
    setState(() {
      _showMembershipModal = true;
      _showControlPanel = false;
      _showTestDrawer = false;
    });
  }

  Future<void> _openAlbum() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlbumPage()),
    );
  }

  Future<void> _toggleVideoMode() async {
    if (_isRecording) return;
    setState(() => _isVideoMode = !_isVideoMode);
  }

  Future<void> _startRecording() async {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      await ctrl.prepareForVideoRecording();
      await ctrl.startVideoRecording();
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('startRecording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    final ctrl = _cameraCtrl;
    if (ctrl == null) return;
    try {
      final file = await ctrl.stopVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _lastPhotoPath = file.path;
        });
      }
      await Gal.putVideo(file.path);
    } catch (e) {
      debugPrint('stopRecording error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // First launch (no saved position): center the preview window
    if (_previewX < 0) {
      _previewX = (size.width - _previewW) / 2;
      _previewY = (size.height - _previewH) / 2;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen fill light background
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size.width,
            height: size.height,
            color: _selectedCustomPresetId != null
                ? Colors.transparent
                : _fillColor,
          ),

          // Custom image background (replaces solid color when active)
          if (_selectedCustomPresetId != null)
            Builder(builder: (_) {
              final preset = _customPresets
                  .where((p) => p.id == _selectedCustomPresetId)
                  .firstOrNull;
              if (preset == null) return const SizedBox.shrink();
              return Positioned.fill(
                child: Image.file(
                  File(preset.localPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.black),
                ),
              );
            }),

          // PreviewWindow is a direct child of Stack so its internal Positioned
          // correctly receives StackParentData. IgnorePointer lives inside.
          PreviewWindow(
            cameraController: _cameraReady ? _cameraCtrl : null,
            initialX: _previewX,
            initialY: _previewY,
            initialW: _previewW,
            initialH: _previewH,
            mirrorMode: _mirrorCapture,
            ignoring: _showControlPanel || _showTestDrawer || _showMembershipModal,
            onLayoutChanged: _onPreviewLayout,
          ),

          // Bottom camera controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: CameraView(
                cameraController: _cameraCtrl,
                mirrorCapture: _mirrorCapture,
                fillSaturation: _fillSaturation,
                motionPhoto: _motionPhoto,
                isVideoMode: _isVideoMode,
                isRecording: _isRecording,
                lastPhotoPath: _lastPhotoPath,
                onToggleControlPanel: () {
                  setState(() => _showControlPanel = !_showControlPanel);
                },
                onOpenAlbum: _openAlbum,
                onMotionPhotoChange: (v) => setState(() => _motionPhoto = v),
                onToggleMode: _toggleVideoMode,
                onStartVideo: _startRecording,
                onStopVideo: _stopRecording,
              ),
            ),
          ),

          // Settings button — SafeArea ensures it sits below the status bar /
          // notch / Dynamic Island on all devices.
          SafeArea(
            bottom: false,
            left: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 58),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _showTestDrawer = true;
                    _showControlPanel = false;
                  }),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Control panel (slides up from bottom) with outside-tap barrier
          if (_showControlPanel)
            Positioned.fill(
              child: Stack(
                children: [
                  // Transparent barrier — tapping outside the panel closes it
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        debugPrint('CONTROL BARRIER onTap → closing');
                        setState(() => _showControlPanel = false);
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _AnimatedSlideUp(
                      child: ControlPanel(
                        selectedIndex: _selectedIndex,
                        customColor: _customColor,
                        screenBrightness: _screenBrightness,
                        memberLevel: _membership.level,
                        selectedCustomPresetId: _selectedCustomPresetId,
                        customPresets: _customPresets,
                        repository: _customRepo,
                        isAddingPreset: _addingPreset,
                        onPresetSelected: _onPresetSelected,
                        onColorChanged: _onColorChanged,
                        onBrightnessChanged: _onBrightnessChanged,
                        onMembershipRequired: _showMembership,
                        onCustomSelected: _onCustomPresetSelected,
                        onCustomPresetsChanged: _onCustomPresetsChanged,
                        onAddImage: _onAddImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Membership modal (slides from bottom)
          if (_showMembershipModal)
            Positioned.fill(
              child: MembershipModal(
                currentLevel: _membership.level,
                membershipManager: _membership,
                onClose: () => setState(() => _showMembershipModal = false),
                // onPurchased is intentionally omitted: modal is closed by
                // _listenIAP only after purchaseStream confirms the purchase.
                onPurchased: () {},
              ),
            ),

          // Settings drawer — triggered by the bug-icon button in CameraView.
          // Uses the same barrier+slide pattern as the control panel.
          if (_showTestDrawer)
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showTestDrawer = false),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _AnimatedSlideRight(
                      child: SettingsDrawer(
                        memberLevel: _membership.level,
                        mirrorCapture: _mirrorCapture,
                        previewX: _previewX,
                        previewY: _previewY,
                        previewW: _previewW,
                        previewH: _previewH,
                        onClose: () => setState(() => _showTestDrawer = false),
                        onMirrorChanged: _onMirrorChanged,
                        onPreviewLayoutChanged: _onPreviewLayout,
                        onMembershipUpgrade: _showMembership,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Inline naming UI — rendered directly in the Stack so it never
          // depends on Navigator/showDialog and works regardless of iOS timing.
          if (_pendingImage != null)
            Positioned.fill(
              child: _AddPresetSheet(
                imageFile: File(_pendingImage!.path),
                name: _pendingImageName,
                nameError: _pendingImageNameError,
                onNameChanged: (v) => setState(() {
                  _pendingImageName = v;
                  _pendingImageNameError = null;
                }),
                onConfirm: _confirmPendingImage,
                onCancel: _cancelPendingImage,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Inline add-preset sheet (no Navigator/showDialog) ────────────────────────

class _AddPresetSheet extends StatelessWidget {
  final File imageFile;
  final String name;
  final String? nameError;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _AddPresetSheet({
    required this.imageFile,
    required this.name,
    required this.nameError,
    required this.onNameChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb taps inside the card
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('添加自定义背景',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      imageFile,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(Icons.broken_image,
                            color: Colors.white38, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: onNameChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '输入名称',
                      hintStyle: const TextStyle(color: Colors.white38),
                      errorText: nameError,
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('取消',
                            style: TextStyle(color: Colors.white38)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onConfirm,
                        child: const Text('确定',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSlideUp extends StatefulWidget {
  final Widget child;
  const _AnimatedSlideUp({required this.child});

  @override
  State<_AnimatedSlideUp> createState() => _AnimatedSlideUpState();
}

class _AnimatedSlideUpState extends State<_AnimatedSlideUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _anim, child: widget.child);
  }
}

class _AnimatedSlideRight extends StatefulWidget {
  final Widget child;
  const _AnimatedSlideRight({required this.child});

  @override
  State<_AnimatedSlideRight> createState() => _AnimatedSlideRightState();
}

class _AnimatedSlideRightState extends State<_AnimatedSlideRight>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _anim, child: widget.child);
  }
}
