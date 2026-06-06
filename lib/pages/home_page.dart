import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/color_model.dart';
import '../models/preset_data.dart';
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
  late MembershipManager _membership;

  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // Fill light state
  Color _fillColor = Colors.white;
  double _screenBrightness = 1.0;
  int _selectedIndex = 0;
  ColorModel _customColor = const ColorModel(hue: 0, saturation: 1.0, brightness: 1.0);

  // Preview window
  double _previewX = 16;
  double _previewY = 80;
  double _previewW = 120;
  double _previewH = 160;

  // Settings
  bool _mirrorCapture = false;

  // UI state
  bool _showControlPanel = false;
  bool _showSettings = false;
  bool _showMembershipModal = false;

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
    // Fix #6: subscribe to purchaseStream BEFORE calling init() which triggers
    // restorePurchases(), so restored purchases are not missed on broadcast stream
    _listenIAP();
    await _membership.init();

    _loadSavedState();
    await _requestPermissions();
    await _initCamera();
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
    final preset = kPresets[_selectedIndex];
    if (preset.isCustom) {
      _fillColor = _customColor.toColor();
    } else {
      _fillColor = preset.color.toColor();
    }
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
      _updateFillColor();
    });
    _store.saveSelectedIndex(index);
    if (kPresets[index].isCustom) {
      _store.saveColor(_customColor);
    }
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

  void _showMembership() {
    setState(() {
      _showMembershipModal = true;
      _showControlPanel = false;
      _showSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen fill light background
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size.width,
            height: size.height,
            color: _fillColor,
          ),

          // Fix: RepaintBoundary isolates the camera preview texture from
          // parent rebuilds (brightness slider, timer setState, etc.)
          if (_cameraReady)
            RepaintBoundary(
              child: PreviewWindow(
                cameraController: _cameraCtrl,
                initialX: _previewX,
                initialY: _previewY,
                initialW: _previewW,
                initialH: _previewH,
                mirrorMode: _mirrorCapture,
                onLayoutChanged: _onPreviewLayout,
              ),
            ),

          // Bottom camera controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.8],
                ),
              ),
              child: SafeArea(
                top: false,
                child: CameraView(
                  cameraController: _cameraCtrl,
                  mirrorCapture: _mirrorCapture,
                  onToggleControlPanel: () {
                    setState(() {
                      _showControlPanel = !_showControlPanel;
                      if (_showControlPanel) _showSettings = false;
                    });
                  },
                  onToggleSettings: () {
                    setState(() {
                      _showSettings = !_showSettings;
                      if (_showSettings) _showControlPanel = false;
                    });
                  },
                ),
              ),
            ),
          ),

          // Control panel (slides up from bottom)
          if (_showControlPanel)
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
                  onPresetSelected: _onPresetSelected,
                  onColorChanged: _onColorChanged,
                  onBrightnessChanged: _onBrightnessChanged,
                  onMembershipRequired: _showMembership,
                ),
              ),
            ),

          // Settings drawer (slides from right)
          if (_showSettings)
            Positioned.fill(
              child: SettingsDrawer(
                memberLevel: _membership.level,
                mirrorCapture: _mirrorCapture,
                previewX: _previewX,
                previewY: _previewY,
                previewW: _previewW,
                previewH: _previewH,
                onClose: () => setState(() => _showSettings = false),
                onMirrorChanged: _onMirrorChanged,
                onPreviewLayoutChanged: _onPreviewLayout,
                onMembershipUpgrade: _showMembership,
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
        ],
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
