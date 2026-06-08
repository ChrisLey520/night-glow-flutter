import 'package:flutter/material.dart';
import '../models/membership_level.dart';
import '../repositories/purchase/purchase_repository.dart';
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
  List<PurchaseProduct> _products = [];
  bool _productsLoaded = false;
  bool _loadError = false;
  bool _purchasing = false;
  bool _restoring = false;

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
    if (widget.currentLevel == MembershipLevel.vip) {
      _selectedTab = 1;
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() { _productsLoaded = false; _loadError = false; });
    final products = await widget.membershipManager.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _productsLoaded = true;
      _loadError = products.isEmpty;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) => widget.onClose());
  }

  PurchaseProduct? _productFor(int tabIndex) {
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
    await widget.membershipManager.purchase(product);
    if (mounted) setState(() => _purchasing = false);
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await widget.membershipManager.restorePurchases();
    if (mounted) setState(() => _restoring = false);
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                  if (widget.currentLevel == MembershipLevel.normal)
                    Row(
                      children: [
                        _tab(0, 'VIP'),
                        const SizedBox(width: 12),
                        _tab(1, 'SVIP'),
                      ],
                    ),
                  if (widget.currentLevel == MembershipLevel.vip)
                    Row(children: [_tab(1, 'SVIP')]),
                  const SizedBox(height: 16),
                  // Benefits
                  _benefits(),
                  const SizedBox(height: 20),
                  // Purchase button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _buildOnPressed(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _loadError
                            ? Colors.white12
                            : _selectedTab == 0
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFFF8C00),
                        foregroundColor:
                            _loadError ? Colors.white70 : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.white24,
                      ),
                      child: _buildPurchaseButtonChild(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Apple required: subscription terms
                  _subscriptionTerms(),
                  const SizedBox(height: 4),
                  // Restore & close row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: (_restoring || _purchasing) ? null : _restore,
                        child: _restoring
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white38,
                                ),
                              )
                            : const Text(
                                '恢复购买',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 13),
                              ),
                      ),
                      TextButton(
                        onPressed: _close,
                        child: const Text(
                          '暂不升级',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  SafeArea(top: false, child: const SizedBox(height: 8)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  VoidCallback? _buildOnPressed() {
    if (_purchasing || _restoring) return null;
    if (_loadError) return _loadProducts;
    if (!_productsLoaded) return null;
    if (_isAlreadyOwned(_selectedTab)) return null;
    return _purchase;
  }

  Widget _buildPurchaseButtonChild() {
    if (_purchasing) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
      );
    }
    if (!_productsLoaded) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
      );
    }
    if (_loadError) {
      return const Text('加载失败，点击重试',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white70));
    }
    final product = _productFor(_selectedTab);
    final label = _selectedTab == 0 ? 'VIP' : 'SVIP';
    final price = product?.price ?? (_selectedTab == 0 ? 'VIP' : 'SVIP');
    return Text(
      '订阅 $label · $price/年',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  bool _isAlreadyOwned(int tabIndex) {
    final target =
        tabIndex == 0 ? MembershipLevel.vip : MembershipLevel.svip;
    return widget.currentLevel.value >= target.value;
  }

  Widget _tab(int index, String title) {
    final active = _selectedTab == index;
    final owned = _isAlreadyOwned(index);
    final product = _productFor(index);
    final priceStr = product?.price ??
        (index == 0
            ? kLevelPrices[MembershipLevel.vip.value]
            : kLevelPrices[MembershipLevel.svip.value]);
    final levelColor = index == 0
        ? const Color(0xFFFFD700)
        : const Color(0xFFFF8C00);
    return Expanded(
      child: GestureDetector(
        onTap: owned ? null : () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? levelColor : Colors.white24,
              width: active ? 2 : 1,
            ),
            color: owned
                ? Colors.white.withValues(alpha: 0.02)
                : active
                    ? levelColor.withValues(alpha: 0.12)
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
                          ? levelColor
                          : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                owned ? '已拥有' : '$priceStr/年',
                style: TextStyle(
                  color: owned
                      ? Colors.white24
                      : active
                          ? levelColor.withValues(alpha: 0.8)
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
    final items = _selectedTab == 0
        ? kLevelBenefits[MembershipLevel.vip.value]
        : kLevelBenefits[MembershipLevel.svip.value];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((b) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                Text(b,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _subscriptionTerms() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        widget.membershipManager.repo.subscriptionTermsText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
