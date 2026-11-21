import '../l10n/tr.dart';

/// 新規クラブ作成時に選べる国(実在の5か国のリーグに寄せる)。
enum LeagueTheme { england, spain, germany, italy, france }

/// 保存されたリーグ名([LeagueThemeInfo.label])から国を引く。表示の言語や、
/// 2026-11-22 に名前を実在へ寄せる前の名前(アルビオン・リーグなど)でも引ける。
LeagueTheme? leagueThemeFromName(String? name) {
  if (name == null) return null;
  for (final t in LeagueTheme.values) {
    if (t._allNames.contains(name)) return t;
  }
  return null;
}

extension LeagueThemeInfo on LeagueTheme {
  /// リーグの表示名(1部の名前。セーブにはこれを入れる)。2026-11-22 に、
  /// 実在の名前から少し変えたもの(プレミア・ディビジョンなど)にした。
  String get label => divisionName(1);

  /// [tier] 部の名前。実在の名前から少し変えたもの(2026-11-22)。
  String divisionName(int tier) {
    final t = tier.clamp(1, 3);
    final (ja, en) = _divisionNames[this]![t - 1];
    return Tr.pick(ja, en);
  }

  static const Map<LeagueTheme, List<(String, String)>> _divisionNames = {
    // i18n-ignore: 部の名前(日本語と英語の組)。
    LeagueTheme.england: [
      ('プレミア・ディビジョン', 'Premier Division'),
      ('チャンピオン・ディビジョン', 'Champion Division'),
      ('リーグ・ディビジョン1', 'League Division One'),
    ],
    // i18n-ignore: 部の名前(日本語と英語の組)。
    LeagueTheme.spain: [
      ('プリメーラ・リーガ', 'Primera Liga'),
      ('セグンダ・リーガ', 'Segunda Liga'),
      ('テルセーラ・リーガ', 'Tercera Liga'),
    ],
    // i18n-ignore: 部の名前(日本語と英語の組)。
    LeagueTheme.germany: [
      ('ブンデスリーグ1', 'Bundesliga One'),
      ('ブンデスリーグ2', 'Bundesliga Two'),
      ('ドイツ3部リーグ', 'German Third League'),
    ],
    // i18n-ignore: 部の名前(日本語と英語の組)。
    LeagueTheme.italy: [
      ('セリエ・プリマ', 'Serie Prima'),
      ('セリエ・セコンダ', 'Serie Seconda'),
      ('セリエ・テルツァ', 'Serie Terza'),
    ],
    // i18n-ignore: 部の名前(日本語と英語の組)。
    LeagueTheme.france: [
      ('リーグ・プルミエール', 'Ligue Premiere'),
      ('リーグ・ドゥジエーム', 'Ligue Deuxieme'),
      ('ナシオナル・リーグ', 'Nationale League'),
    ],
  };

  /// 国の名前(リーグを選ぶ画面で、リーグ名に添える)。
  String get flavorLabel {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('イングランド', 'England');
      case LeagueTheme.spain:
        return Tr.pick('スペイン', 'Spain');
      case LeagueTheme.germany:
        return Tr.pick('ドイツ', 'Germany');
      case LeagueTheme.italy:
        return Tr.pick('イタリア', 'Italy');
      case LeagueTheme.france:
        return Tr.pick('フランス', 'France');
    }
  }

  /// 国内カップ戦の名前。実在の名前から少し変えたもの(2026-11-22)。
  String get domesticCupName {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('イングランド協会カップ', 'English Association Cup');
      case LeagueTheme.spain:
        return Tr.pick('コパ・デ・エスパーニャ', 'Copa de Espana');
      case LeagueTheme.germany:
        return Tr.pick('ドイツ連盟カップ', 'German Federation Cup');
      case LeagueTheme.italy:
        return Tr.pick('コッパ・ナツィオナーレ', 'Coppa Nazionale');
      case LeagueTheme.france:
        return Tr.pick('クープ・ナシオナル', 'Coupe Nationale');
    }
  }

  /// この国のリーグとして保存されたことのある名前(日英・前の名前)。
  Set<String> get _allNames {
    final (ja, en) = _divisionNames[this]![0];
    // i18n-ignore: 前の名前(古いセーブのリーグ名を引くため)。
    final old = switch (this) {
      LeagueTheme.england => const ['アルビオン・リーグ', 'Albion League'],
      LeagueTheme.spain => const ['イベリア・リーグ', 'Iberia League'],
      LeagueTheme.germany => const ['ゲルマニア・リーグ', 'Germania League'],
      LeagueTheme.italy => const ['アペニン・リーグ', 'Apennine League'],
      LeagueTheme.france => const ['ガリア・リーグ', 'Gallia League'],
    };
    return {ja, en, ...old};
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

/// 国ごとのリーグの形。実在の国のピラミッドの上から3つに寄せる
/// (3部まで。2026-11-22 に5部制から変えた)。
extension LeagueStructure on LeagueTheme {
  /// 1部から3部までのクラブ数。
  List<int> get teamsByTier => switch (this) {
        LeagueTheme.england => const [20, 24, 24],
        LeagueTheme.spain => const [20, 22, 20],
        LeagueTheme.germany => const [18, 18, 20],
        LeagueTheme.italy => const [20, 20, 20],
        LeagueTheme.france => const [18, 18, 18],
      };

  int teamsInTier(int tier) =>
      teamsByTier[(tier - 1).clamp(0, teamsByTier.length - 1)];

  /// [upperTier]部と、その1つ下の部の入れ替えの決まり(1部と2部、2部と3部)。
  PromotionRules rulesBelow(int upperTier) {
    const playoff = PromotionRules.standard;
    switch (this) {
      case LeagueTheme.england:
        return playoff;
      case LeagueTheme.spain:
      case LeagueTheme.italy:
        return switch (upperTier) {
          2 => const PromotionRules(autoDown: 4, autoUp: 3, playoffPool: 4),
          _ => playoff,
        };
      case LeagueTheme.germany:
      case LeagueTheme.france:
        return const PromotionRules(
            autoDown: 2, autoUp: 2, relegationPlayoff: true);
    }
  }

  /// 入れ替えの決まりの短い説明(順位表の下に出す)。
  String describeRules(int upperTier) {
    final r = rulesBelow(upperTier);
    final up = r.playoffPool > 0
        ? Tr.pick('上位${r.autoUp}クラブが自動昇格、続く${r.playoffPool}クラブがプレーオフで1枠',
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
