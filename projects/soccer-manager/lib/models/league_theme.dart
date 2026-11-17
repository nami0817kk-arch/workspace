import '../l10n/tr.dart';

/// 新規クラブ作成時に選べるリーグの雰囲気(架空名で再現した5つの国風リーグ)。
enum LeagueTheme { england, spain, germany, italy, france }

extension LeagueThemeInfo on LeagueTheme {
  /// リーグの表示名。
  String get label {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('アルビオン・リーグ', 'Albion League');
      case LeagueTheme.spain:
        return Tr.pick('イベリア・リーグ', 'Iberia League');
      case LeagueTheme.germany:
        return Tr.pick('ゲルマニア・リーグ', 'Germania League');
      case LeagueTheme.italy:
        return Tr.pick('アペニン・リーグ', 'Apennine League');
      case LeagueTheme.france:
        return Tr.pick('ガリア・リーグ', 'Gallia League');
    }
  }

  /// どの国をイメージしたリーグかの補足表示。
  /// 英語は "Albion League (England-inspired)" だと選択チップの幅に
  /// 収まらないため、国名だけにする。「風」であることは架空のリーグ名を
  /// 見れば分かる。
  String get flavorLabel {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('イングランド風', 'England');
      case LeagueTheme.spain:
        return Tr.pick('スペイン風', 'Spain');
      case LeagueTheme.germany:
        return Tr.pick('ドイツ風', 'Germany');
      case LeagueTheme.italy:
        return Tr.pick('イタリア風', 'Italy');
      case LeagueTheme.france:
        return Tr.pick('フランス風', 'France');
    }
  }

  /// この国風テーマにおける国内カップ戦の名称(リーグ名の語幹に由来する)。
  String get domesticCupName {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('アルビオン杯', 'Albion Cup');
      case LeagueTheme.spain:
        return Tr.pick('イベリア杯', 'Iberia Cup');
      case LeagueTheme.germany:
        return Tr.pick('ゲルマニア杯', 'Germania Cup');
      case LeagueTheme.italy:
        return Tr.pick('アペニン杯', 'Apennine Cup');
      case LeagueTheme.france:
        return Tr.pick('ガリア杯', 'Gallia Cup');
    }
  }
}

/// 上の部と下の部の入れ替えの決まり。
class PromotionRules {
  /// 上の部から自動で落ちるクラブ数。
  final int autoDown;

  /// 下の部から自動で上がるクラブ数。
  final int autoUp;

  /// 下の部の昇格プレーオフに出るクラブ数(0なら無し。4なら準決勝と決勝)。
  final int playoffPool;

  /// 入れ替え戦があるか。上の部の(下から autoDown+1 番目)と、下の部の
  /// (autoUp+1 位)が1試合を戦い、勝った方が上の部に入る。
  final bool relegationPlayoff;

  const PromotionRules({
    required this.autoDown,
    required this.autoUp,
    this.playoffPool = 0,
    this.relegationPlayoff = false,
  });

  /// 降格圏(入れ替え戦の枠を含む)の広さ。
  int get relegationZone => autoDown + (relegationPlayoff ? 1 : 0);

  /// これまでの決まり(3降格・2自動昇格+プレーオフ4チーム)。
  static const standard =
      PromotionRules(autoDown: 3, autoUp: 2, playoffPool: 4);
}

/// 国ごとのリーグの形。実在の国のピラミッドに寄せる(5部まで)。
extension LeagueStructure on LeagueTheme {
  /// 1部から5部までのクラブ数。
  List<int> get teamsByTier => switch (this) {
        LeagueTheme.england => const [20, 24, 24, 24, 24],
        LeagueTheme.spain => const [20, 22, 20, 20, 18],
        LeagueTheme.germany => const [18, 18, 20, 18, 18],
        LeagueTheme.italy => const [20, 20, 20, 20, 18],
        LeagueTheme.france => const [18, 18, 18, 16, 16],
      };

  int teamsInTier(int tier) => teamsByTier[(tier - 1).clamp(0, 4)];

  /// [upperTier]部と、その1つ下の部の入れ替えの決まり。
  PromotionRules rulesBelow(int upperTier) {
    const playoff = PromotionRules.standard;
    switch (this) {
      case LeagueTheme.england:
        return switch (upperTier) {
          3 => const PromotionRules(autoDown: 4, autoUp: 3, playoffPool: 4),
          4 => const PromotionRules(autoDown: 2, autoUp: 1, playoffPool: 4),
          _ => playoff,
        };
      case LeagueTheme.spain:
      case LeagueTheme.italy:
        return switch (upperTier) {
          2 => const PromotionRules(autoDown: 4, autoUp: 3, playoffPool: 4),
          _ => playoff,
        };
      case LeagueTheme.germany:
      case LeagueTheme.france:
        return switch (upperTier) {
          1 || 2 => const PromotionRules(
              autoDown: 2, autoUp: 2, relegationPlayoff: true),
          3 => this == LeagueTheme.germany
              ? const PromotionRules(autoDown: 4, autoUp: 3, playoffPool: 4)
              : playoff,
          _ => playoff,
        };
    }
  }

  /// 入れ替えの決まりの短い説明(順位表の下に出す)。
  String describeRules(int upperTier) {
    final r = rulesBelow(upperTier);
    final up = r.playoffPool > 0
        ? Tr.pick(
            '上位${r.autoUp}クラブが自動昇格、続く${r.playoffPool}クラブがプレーオフで1枠',
            'top ${r.autoUp} go up, the next ${r.playoffPool} play off for one more place')
        : Tr.pick('上位${r.autoUp}クラブが自動昇格', 'top ${r.autoUp} go up');
    final down = r.relegationPlayoff
        ? Tr.pick('下位${r.autoDown}クラブが降格、その上の1クラブは入れ替え戦',
            'bottom ${r.autoDown} go down, the one above plays a relegation play-off')
        : Tr.pick('下位${r.autoDown}クラブが降格', 'bottom ${r.autoDown} go down');
    return Tr.pick('$upperTier部と${upperTier + 1}部: $down。$up。',
        'Tiers $upperTier and ${upperTier + 1}: $down; $up.');
  }
}
