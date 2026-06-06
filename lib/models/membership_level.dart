enum MembershipLevel {
  normal(0),
  vip(1),
  svip(2);

  final int value;
  const MembershipLevel(this.value);

  static MembershipLevel fromValue(int v) {
    return MembershipLevel.values.firstWhere(
      (e) => e.value == v,
      orElse: () => MembershipLevel.normal,
    );
  }
}

class MembershipProducts {
  static const String vipProductId = 'night_glow_vip_yearly';
  static const String svipProductId = 'night_glow_svip_yearly';
}
