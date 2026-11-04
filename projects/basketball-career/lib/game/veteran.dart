// ベテランの役割: プロの33歳から、チームでの役割を自分で選ぶ。衰えを「選択」に変えて、最後の数年に意味を持たせる。
//
// どれも一長一短。エースは今までどおり。切り札は控えに回る代わりに、衰えと連戦の疲れが小さく、出てきて流れを変える(味方+)。
// 指導役は若手を育てて味方が強くなり、チームワークが薄れない代わりに、自分の衰えが少し早い。

/// 役割を選べるようになる年齢(プロ)。
const veteranAge = 33;

enum VeteranRole {
  ace('エースのまま', '今までどおり先発で、得点の中心を担う。'),
  sixth('6人目の切り札', '控えに回る。衰えと連戦の疲れが小さく、出てきて流れを変える(味方 +1.0)。'),
  mentor('若手の指導役', '若手を育てる。味方 +1.5、チームワークが薄れず、コーチとの信頼も上がる。自分の衰えは少し早い。');

  const VeteranRole(this.label, this.description);
  final String label;
  final String description;

  /// 大会の味方の強さへの加算。
  double get teamBonus => switch (this) {
        VeteranRole.ace => 0,
        VeteranRole.sixth => 1.0,
        VeteranRole.mentor => 1.5,
      };

  /// 衰え(能力の減り)の倍率。
  double get decline => switch (this) {
        VeteranRole.ace => 1.0,
        VeteranRole.sixth => 0.75,
        VeteranRole.mentor => 1.15,
      };

  /// 大会の連戦で残る疲れの倍率。
  double get tournamentFatigue => this == VeteranRole.sixth ? 0.5 : 1.0;

  /// 控え(ベンチスタート)に回るか。
  bool get bench => this == VeteranRole.sixth;

  /// チームワークが毎ターン薄れないか。
  bool get keepsTeamwork => this == VeteranRole.mentor;

  /// エンディングの一文。
  String get epilogue => switch (this) {
        VeteranRole.ace => '最後の年まで、チームの顔として先発のコートに立ち続けた。',
        VeteranRole.sixth => '晩年は6人目の切り札として、ベンチから試合の流れを変え続けた。',
        VeteranRole.mentor => '晩年は若手の指導役を買って出た。その教えを受けた選手たちが、次の時代のチームを支えた。',
      };

  static VeteranRole? fromName(Object? name) {
    for (final r in VeteranRole.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// おすすめの役割: 総合が控えの線より低い(どのみち控えになる)なら切り札、そうでなければエース。
VeteranRole suggestedVeteranRole(double overall, double? benchLine) =>
    benchLine != null && overall < benchLine ? VeteranRole.sixth : VeteranRole.ace;
