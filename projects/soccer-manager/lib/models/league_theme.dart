import '../l10n/tr.dart';

/// 新規クラブ作成時に選べる国(実在の5か国のリーグに寄せる)。
enum LeagueTheme { england, spain, germany, italy, france }

/// 国籍が EU の国か(5か国のうちイングランドだけが EU の外)。
/// 登録の決まり(スペイン・イタリア・フランスの「EU 外の選手」の枠)と、
/// 18歳未満の国際移籍の例外(EU の中の16〜17歳)に使う。英国籍の選手は
/// EU 外として数える(実在の決まり)。
bool isEuNation(LeagueTheme t) => t != LeagueTheme.england;

/// [age]歳の選手が国[from]から国[to]へ移れるか(18歳未満の国際移籍の禁止)。
/// 同じ国の中・18歳以上なら移れる。FIFA の例外: EU の中の移籍なら16〜17歳も
/// 移れる(2026-11-22 に入れた。それまでは18歳未満は一律に不可)。
bool minorMayMoveBetween(int age, LeagueTheme from, LeagueTheme to) {
  if (age >= 18 || from == to) return true;
  return age >= 16 && isEuNation(from) && isEuNation(to);
}

/// 大陸大会の名前。[level] 1 = チャンピオンズカップ(実在の CL にあたる)、
/// 2 = ヨーロッパカップ(EL にあたる)。実在の名前から少し変えたもの。
String continentalCupName(int level) => level <= 1
    ? Tr.pick('ヨーロピアン・チャンピオンズカップ', 'European Champions Cup')
    : Tr.pick('ヨーロッパ・カップ', 'Europa Cup');

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

  /// リーグカップがある国か。実在ではイングランドだけ(1〜3部のクラブが
  /// 出る。2026-11-22)。
  bool get hasLeagueCup => this == LeagueTheme.england;

  /// リーグカップの名前(イングランドだけ)。実在の名前から少し変えたもの。
  String get leagueCupName => Tr.pick('イングリッシュ・リーグカップ', 'English League Cup');

  /// 勝ち点で並んだとき、得失点差を直接対決より先に見るか(イングランド・
  /// ドイツ・フランス)。スペイン・イタリアは直接対決が先。
  bool get goalDifferenceFirst =>
      this == LeagueTheme.england ||
      this == LeagueTheme.germany ||
      this == LeagueTheme.france;

  /// スーパーカップを4クラブで1月ごろに行う国か(スペイン・イタリア)。
  /// ほかの国は、1部の王者とカップの王者の1試合を開幕前に行う。
  bool get fourClubSuperCup =>
      this == LeagueTheme.spain || this == LeagueTheme.italy;

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

/// 昇格プレーオフの試合の形(国ごと。2026-11-22)。
enum PlayoffFormat {
  /// 準決勝も決勝も1試合(引き分けはPK戦)。それまでの形。
  singleMatches,

  /// イングランド: 準決勝は2試合合計(並べば延長・PK戦)、決勝は1試合
  /// (並べば延長・PK戦)。
  englishTwoLegSemis,

  /// スペイン・イタリア: すべて2試合合計で、合計で並べば順位が上の
  /// クラブが勝ち上がる。
  twoLegsHigherSeed,

  /// スペインの3部(1部RFEF): 2試合合計で、合計で並べば延長戦、それでも
  /// 並べば順位が上のクラブ(PK戦は無い)。[PromotionRules.playoffSpots]が
  /// 2なら、準決勝に当たる2つの対戦の勝者がどちらも上がる(2026-11-22)。
  twoLegsExtraTimeHigherSeed,

  /// イタリアの3部(セリエC): 1回戦は順位が上のホームで1試合(並べば
  /// 延長なしで順位が上)、準決勝は2試合合計(並べば順位が上)、決勝は
  /// 2試合合計(並べば延長戦、それでも並べばPK戦。2026-11-22)。
  serieC,
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
  /// (autoUp+1 位)が戦い、勝った方が上の部に入る。
  final bool relegationPlayoff;

  /// 昇格プレーオフの試合の形。
  final PlayoffFormat playoffFormat;

  /// 入れ替え戦を2試合合計で行うか(ドイツ。並べば延長・PK戦)。false なら
  /// 1試合。
  final bool relegationPlayoffTwoLegs;

  /// プレーオフの最上位と次のクラブの勝ち点の差がこれ以上なら、プレーオフを
  /// 行わず最上位が昇格する(イタリアの2部は14点。0なら無し)。
  final int playoffSkipGap;

  /// プレーオフで上がれるクラブ数(1なら決勝の勝者だけ。2なら準決勝に
  /// 当たる2つの対戦の勝者が上がり、決勝は行わない)。
  final int playoffSpots;

  /// 入れ替え戦に出る下の部のクラブを決めるプレーオフに出るクラブ数
  /// (自動昇格のすぐ下から)。1なら自動昇格のすぐ下がそのまま出る。3なら
  /// 4番手対5番手(1試合)の勝者が3番手と戦い(1試合)、その勝者が出る
  /// (フランスの1部と2部の間。2部の3〜5位。2026-11-22)。
  final int relegationPlayoffQualifiers;

  /// 上の部の降格プレーアウトがあるか(イタリアの2部。2026-11-22)。自動降格
  /// ([autoDown])のすぐ上の2クラブ(セリエBの16位と17位)が2試合合計で
  /// 戦い、負けた方が下の部へ落ちる。合計で並べば順位が上が残る。
  final bool relegationPlayout;

  /// プレーアウトの2クラブの勝ち点の差がこれ以上なら、行わずに下のクラブが
  /// 落ちる(イタリアの2部は4点。0なら差を見ない)。
  final int playoutSkipGap;

  const PromotionRules({
    required this.autoDown,
    required this.autoUp,
    this.playoffPool = 0,
    this.relegationPlayoff = false,
    this.playoffFormat = PlayoffFormat.singleMatches,
    this.relegationPlayoffTwoLegs = false,
    this.playoffSkipGap = 0,
    this.playoffSpots = 1,
    this.relegationPlayoffQualifiers = 1,
    this.relegationPlayout = false,
    this.playoutSkipGap = 0,
  });

  /// 下の部から上がるクラブ数(入れ替え戦の分は除く)。
  int get promotionPlaces => autoUp + (playoffPool >= 4 ? playoffSpots : 0);

  /// 上の部から落ちるクラブ数(入れ替え戦の分は除き、プレーアウトで落ちる
  /// 1クラブは含む)。
  int get relegationPlaces => autoDown + (relegationPlayout ? 1 : 0);

  /// 降格圏(入れ替え戦・プレーアウトの枠を含む)の広さ。
  int get relegationZone =>
      autoDown + (relegationPlayoff ? 1 : 0) + (relegationPlayout ? 2 : 0);

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
  ///
  /// プレーオフ・入れ替え戦の試合の形は国ごと(2026-11-22): イングランドは
  /// 準決勝が2試合合計・決勝1試合、スペインは2試合合計で並べば上位、
  /// イタリアの2部は3〜8位の6クラブ(5位対8位・6位対7位の1試合から。
  /// 3位と4位の差が14点以上なら行わない)、ドイツの入れ替え戦は2試合合計。
  ///
  /// 2部と3部の間も実在に寄せる(2026-11-22)。実在の3部が組に分かれている
  /// 国(スペイン・イタリア)は、ゲームの3部が1つのリーグなので「組ごとの
  /// 優勝」を「上位の自動昇格」に読み替える。
  /// - イングランド(リーグ1→チャンピオンシップ): 自動2+プレーオフ1
  ///   (準決勝2試合合計・決勝1試合)。1部と2部の間と同じ。
  /// - スペイン(1部RFEF→2部): 2部から4降格。自動2(2つの組の優勝)+
  ///   3〜6位のプレーオフで2枠(2試合合計。並べば延長、それでも並べば順位が
  ///   上)。
  /// - ドイツ(3部→2部): 自動2+入れ替え戦(2試合合計)。1部と2部の間と同じ。
  /// - イタリア(セリエC→B): 2部から4降格(18〜20位の自動3+16位対17位の
  ///   プレーアウトの負け。勝ち点差4以上なら行わずに17位。2026-11-22)。
  ///   自動3(3つの組の優勝)+4〜9位のプレーオフで1枠([PlayoffFormat.serieC])。
  /// - フランス(ナショナル→リーグ2): 自動2+入れ替え戦。入れ替え戦は
  ///   1部と2部の間も含めて2試合合計。1部と2部の間は、2部の3〜5位の
  ///   プレーオフ(4位対5位→勝者対3位、どちらも1試合)の勝者が1部の16位と
  ///   戦う(2026-11-22)。
  PromotionRules rulesBelow(int upperTier) {
    switch (this) {
      case LeagueTheme.england:
        return const PromotionRules(
          autoDown: 3,
          autoUp: 2,
          playoffPool: 4,
          playoffFormat: PlayoffFormat.englishTwoLegSemis,
        );
      case LeagueTheme.spain:
        return switch (upperTier) {
          2 => const PromotionRules(
              autoDown: 4,
              autoUp: 2,
              playoffPool: 4,
              playoffSpots: 2,
              playoffFormat: PlayoffFormat.twoLegsExtraTimeHigherSeed,
            ),
          _ => const PromotionRules(
              autoDown: 3,
              autoUp: 2,
              playoffPool: 4,
              playoffFormat: PlayoffFormat.twoLegsHigherSeed,
            ),
        };
      case LeagueTheme.italy:
        return switch (upperTier) {
          2 => const PromotionRules(
              autoDown: 3,
              autoUp: 3,
              playoffPool: 6,
              playoffFormat: PlayoffFormat.serieC,
              relegationPlayout: true,
              playoutSkipGap: 4,
            ),
          _ => const PromotionRules(
              autoDown: 3,
              autoUp: 2,
              playoffPool: 6,
              playoffFormat: PlayoffFormat.twoLegsHigherSeed,
              playoffSkipGap: 14,
            ),
        };
      case LeagueTheme.germany:
        return const PromotionRules(
            autoDown: 2,
            autoUp: 2,
            relegationPlayoff: true,
            relegationPlayoffTwoLegs: true);
      case LeagueTheme.france:
        // 入れ替え戦(バラージュ)は2試合合計(第1戦は下の部のホーム。並べば
        // 延長・PK戦)。2026-11-22 までは1試合だった。1部と2部の間は、2部の
        // 3〜5位のプレーオフの勝者が入れ替え戦に出る。
        return PromotionRules(
            autoDown: 2,
            autoUp: 2,
            relegationPlayoff: true,
            relegationPlayoffTwoLegs: true,
            relegationPlayoffQualifiers: upperTier == 1 ? 3 : 1);
    }
  }

  /// 入れ替えの決まりの短い説明(順位表の下に出す)。
  String describeRules(int upperTier) {
    final r = rulesBelow(upperTier);
    final up = r.playoffPool > 0
        ? Tr.pick(
            '上位${r.autoUp}クラブが自動昇格、続く${r.playoffPool}クラブがプレーオフで${r.playoffSpots}枠',
            r.playoffSpots == 1
                ? 'top ${r.autoUp} go up, the next ${r.playoffPool} play off for one more place'
                : 'top ${r.autoUp} go up, the next ${r.playoffPool} play off for ${r.playoffSpots} more places')
        : r.relegationPlayoff && r.relegationPlayoffQualifiers >= 3
            ? Tr.pick(
                '上位${r.autoUp}クラブが自動昇格、続く${r.relegationPlayoffQualifiers}クラブのプレーオフの勝者が入れ替え戦へ',
                'top ${r.autoUp} go up, the next ${r.relegationPlayoffQualifiers} play off for a place in the relegation play-off')
            : Tr.pick('上位${r.autoUp}クラブが自動昇格', 'top ${r.autoUp} go up');
    final down = r.relegationPlayoff
        ? Tr.pick('下位${r.autoDown}クラブが降格、その上の1クラブは入れ替え戦',
            'bottom ${r.autoDown} go down, the one above plays a relegation play-off')
        : r.relegationPlayout
            ? Tr.pick(
                '下位${r.autoDown}クラブが降格、その上の2クラブはプレーアウト(負けた方が降格。勝ち点差${r.playoutSkipGap}以上なら下が降格)',
                'bottom ${r.autoDown} go down, the two above play a relegation play-out (the loser goes down; with a gap of ${r.playoutSkipGap} points or more, the lower club goes down)')
            : Tr.pick(
                '下位${r.autoDown}クラブが降格', 'bottom ${r.autoDown} go down');
    return Tr.pick('$upperTier部と${upperTier + 1}部: $down。$up。',
        'Tiers $upperTier and ${upperTier + 1}: $down; $up.');
  }
}
