import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/membership_level.dart';
import '../utils/membership_manager.dart';

class MembershipModal extends StatefulWidget {
  final MembershipLevel currentLevel;
  final MembershipManager membershipManager;
  final VoidCallback onClose;
  final VoidCallback onPurchased;

  const MembershipModal({
    super.key,
    required this.currentLevel,
    required this.membershipManager,
    required this.onClose,
    required this.onPurchased,
  });

  @override
  State<MembershipModal> createState() => _MembershipModalState();
}

class _MembershipModalState extends State<MembershipModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  int _selectedTab = 0;
  List<ProductDetails> _products = [];
  bool _productsLoaded = false;
  bool _purchasing = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _productsLoaded = false);
    final products = await widget.membershipManager.loadProducts();
    if (mounted) setState(() { _products = products; _productsLoaded = true; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) => widget.onClose());
  }

  ProductDetails? _productFor(int tabIndex) {
    final id = tabIndex == 0
        ? MembershipProducts.vipProductId
        : MembershipProducts.svipProductId;
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _purchase() async {
    final product = _productFor(_selectedTab);
    if (product == null) return;
    setState(() => _purchasing = true);
    // Fix: purchase() returning true only means the IAP request was submitted.
    // The actual result arrives via purchaseStream. We do NOT close the modal
    // here — let the stream handler (HomePage._listenIAP) trigger onPurchased
    // after real confirmation. We only clear the spinner.
    await widget.membershipManager.purchase(product);
    if (mounted) setState(() => _purchasing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          child: Container(color: Colors.black54),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    '升级会员',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab selector
                  Row(
                    children: [
                      _tab(0, 'VIP', '¥1/年'),
                      const SizedBox(width: 12),
                      _tab(1, 'SVIP', '¥2/年'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Benefits
                  _benefits(),
                  const SizedBox(height: 20),
                  // Purchase button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_purchasing || !_productsLoaded || _isAlreadyOwned(_selectedTab))
                          ? null
                          : _purchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.amber[900],
                      ),
                      child: _purchasing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : Text(
                              _selectedTab == 0
                                  ? '订阅 VIP - ¥1/年'
                                  : '订阅 SVIP - ¥2/年',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _close,
                    child: const Text(
                      '暂不升级',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isAlreadyOwned(int tabIndex) {
    // Fix: disable purchasing a tier the user already owns or has exceeded
    final targetLevel = tabIndex == 0 ? MembershipLevel.vip : MembershipLevel.svip;
    return widget.currentLevel.value >= targetLevel.value;
  }

  Widget _tab(int index, String title, String price) {
    final active = _selectedTab == index;
    final owned = _isAlreadyOwned(index);
    return Expanded(
      child: GestureDetector(
        onTap: owned ? null : () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.amber : Colors.white24,
              width: active ? 2 : 1,
            ),
            color: owned
                ? Colors.white.withValues(alpha: 0.02)
                : active
                    ? Colors.amber.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
          ),
          child: Column(
            children: [
              Text(
                owned ? '$title ✓' : title,
                style: TextStyle(
                  color: owned
                      ? Colors.white38
                      : active
                          ? Colors.amber
                          : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                owned ? '已拥有' : price,
                style: TextStyle(
                  color: owned
                      ? Colors.white24
                      : active
                          ? Colors.amber[300]
                          : Colors.white38,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefits() {
    final vipBenefits = [
      '✓ 全部9种预设色彩',
      '✓ 无广告体验',
      '✗ 自定义色轮（SVIP专属）',
    ];
    final svipBenefits = [
      '✓ 全部9种预设色彩',
      '✓ 无广告体验',
      '✓ 360° 自定义色轮',
    ];
    final items = _selectedTab == 0 ? vipBenefits : svipBenefits;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Column(
        children: items.map((b) {
          final positive = b.startsWith('✓');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  positive ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: positive ? Colors.greenAccent : Colors.white24,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  b.substring(2),
                  style: TextStyle(
                    color: positive ? Colors.white : Colors.white38,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
