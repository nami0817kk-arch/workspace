import '../l10n/tr.dart';

/// 理事会がクラブに求める路線。
///
/// これまで理事会が見ていたのは順位だけだった。勝ってさえいれば、
/// 高齢の選手ばかりで固めても、若手を一度も使わなくても何も言われない。
/// クラブとしてどう戦うかという制約が無く、経営が薄くなっていた。
///
/// 路線はシーズン開始時に決まり、その年の評価に順位と並んで効く。
enum ClubVision {
  /// 特に路線を定めない。順位だけで評価される(従来と同じ)。
  none,

  /// 若手の育成。23歳以下に出場機会を与えることを求められる。
  developYouth,

  /// 攻撃的なサッカー。守りに入る戦い方を嫌う。
  attackingFootball,

  /// 堅実な経営。赤字を出さないことを求められる。
  financialProudence,
}

extension ClubVisionInfo on ClubVision {
  String get label => switch (this) {
        ClubVision.none => Tr.pick('特になし', 'No particular direction'),
        ClubVision.developYouth => Tr.pick('若手の育成', 'Develop youth'),
        ClubVision.attackingFootball =>
          Tr.pick('攻撃的なサッカー', 'Attacking football'),
        ClubVision.financialProudence => Tr.pick('堅実な経営', 'Sound finances'),
      };

  /// 理事会が何を見ているか。達成条件をそのまま書く。
  String get requirement => switch (this) {
        ClubVision.none =>
          Tr.pick('順位のみで評価されます。', 'You are judged on the league table alone.'),
        ClubVision.developYouth => Tr.pick(
            '23歳以下の選手を、スタメンに常時$youthStartersRequired人以上置くこと。',
            'Keep at least $youthStartersRequired players aged 23 or under in your XI.'),
        ClubVision.attackingFootball => Tr.pick(
            '姿勢を「守備的」にしないこと。守りに入った試合は評価を落とします。',
            'Do not set up defensively. Sitting back costs you.'),
        ClubVision.financialProudence =>
          Tr.pick('資金を赤字にしないこと。', 'Do not let the bank balance go negative.'),
      };

  /// 若手育成で求められるスタメン中の23歳以下の人数。
  static const int youthStartersRequired = 3;

  /// 路線を守れているときの、節ごとの信頼度への加算。
  int get satisfiedBonus => this == ClubVision.none ? 0 : 1;

  /// 守れていないときの、節ごとの信頼度への減算。
  ///
  /// 加算より大きい。守って当たり前のことなので、守っても大きくは
  /// 褒められないが、破ると目に見えて評価が下がる。
  int get violatedPenalty => this == ClubVision.none ? 0 : 2;
}
