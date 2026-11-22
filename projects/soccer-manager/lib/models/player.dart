
import 'player_instruction.dart';
import 'player_traits.dart';
import 'attributes.dart';
import 'card_rules.dart';
import 'enum_json.dart';
import '../l10n/tr.dart';
import '../logic/economy_scale.dart';

/// Football Manager風の詳細ポジション（14種類）。
enum Position { gk, dr, dc, dl, wbr, wbl, dm, mr, mc, ml, amr, amc, aml, st }

/// 負傷の種類。種類ごとに典型的な療養期間が異なる。
///
/// 2026-11-22 に長期の怪我(骨折・前十字靭帯断裂・アキレス腱断裂)を足した。
/// それまでは最長でも約12週で、実際のサッカーにある「シーズンの大半を
/// 棒に振る怪我」が無かった。長期の怪我はまれ(1季に1クラブ0〜2人ほど)。
/// 保存の名前は enum の名前なので、並びの最後に足す(古いセーブも読める)。
enum InjuryType { bruise, muscle, ligament, fracture, acl, achilles }

extension InjuryTypeInfo on InjuryType {
  String get label => switch (this) {
        InjuryType.bruise => Tr.pick('打撲', 'Bruise'),
        InjuryType.muscle => Tr.pick('肉離れ', 'Torn muscle'),
        InjuryType.ligament => Tr.pick('靭帯損傷', 'Ligament damage'),
        InjuryType.fracture => Tr.pick('骨折', 'Fracture'),
        InjuryType.acl => Tr.pick('前十字靭帯断裂', 'Ruptured cruciate ligament'),
        InjuryType.achilles => Tr.pick('アキレス腱断裂', 'Ruptured Achilles tendon'),
      };

  /// 典型的な療養期間(週)の範囲。長期の怪我は実際の復帰までの目安
  /// (骨折 2〜3か月・前十字靭帯 6〜9か月・アキレス腱 6〜9か月)。
  (int min, int max) get durationRange => switch (this) {
        InjuryType.bruise => (1, 2),
        InjuryType.muscle => (2, 5),
        InjuryType.ligament => (4, 10),
        InjuryType.fracture => (8, 13),
        InjuryType.acl => (26, 39),
        InjuryType.achilles => (26, 39),
      };

  /// 長期離脱(2か月以上)になる怪我か。
  bool get isLongTerm => switch (this) {
        InjuryType.fracture || InjuryType.acl || InjuryType.achilles => true,
        _ => false,
      };
}

/// 大分類（GK/DEF/MID/ATT）。試合シミュレーションの攻撃力・守備力算出や
/// トレーニング成長率の判定など、粗い分類で十分な処理に用いる。
enum PositionGroup { gk, def, mid, att }

extension PositionLabel on Position {
  String get label {
    switch (this) {
      case Position.gk:
        return 'GK';
      case Position.dr:
        return 'DR';
      case Position.dc:
        return 'DC';
      case Position.dl:
        return 'DL';
      case Position.wbr:
        return 'WBR';
      case Position.wbl:
        return 'WBL';
      case Position.dm:
        return 'DM';
      case Position.mr:
        return 'MR';
      case Position.mc:
        return 'MC';
      case Position.ml:
        return 'ML';
      case Position.amr:
        return 'AMR';
      case Position.amc:
        return 'AMC';
      case Position.aml:
        return 'AML';
      case Position.st:
        return 'ST';
    }
  }

  /// ポジションの正式名称。表示言語に応じて日本語/英語で返す。
  String get fullLabel {
    switch (this) {
      case Position.gk:
        return Tr.pick('ゴールキーパー', 'Goalkeeper');
      case Position.dr:
        return Tr.pick('右サイドバック', 'Right Back');
      case Position.dc:
        return Tr.pick('センターバック', 'Centre Back');
      case Position.dl:
        return Tr.pick('左サイドバック', 'Left Back');
      case Position.wbr:
        return Tr.pick('右ウイングバック', 'Right Wing Back');
      case Position.wbl:
        return Tr.pick('左ウイングバック', 'Left Wing Back');
      case Position.dm:
        return Tr.pick('守備的MF', 'Defensive Midfielder');
      case Position.mr:
        return Tr.pick('右MF', 'Right Midfielder');
      case Position.mc:
        return Tr.pick('センターMF', 'Central Midfielder');
      case Position.ml:
        return Tr.pick('左MF', 'Left Midfielder');
      case Position.amr:
        return Tr.pick('右トップ下', 'Right Attacking Midfielder');
      case Position.amc:
        return Tr.pick('トップ下', 'Attacking Midfielder');
      case Position.aml:
        return Tr.pick('左トップ下', 'Left Attacking Midfielder');
      case Position.st:
        return Tr.pick('ストライカー', 'Striker');
    }
  }

  PositionGroup get group {
    switch (this) {
      case Position.gk:
        return PositionGroup.gk;
      case Position.dr:
      case Position.dc:
      case Position.dl:
      case Position.wbr:
      case Position.wbl:
        return PositionGroup.def;
      case Position.dm:
      case Position.mr:
      case Position.mc:
      case Position.ml:
        return PositionGroup.mid;
      case Position.amr:
      case Position.amc:
      case Position.aml:
      case Position.st:
        return PositionGroup.att;
    }
  }
}

/// 選手の戦術上のデューティ(役割の重心)。攻撃/守備の貢献度に補正がかかる。
enum PlayerDuty { defend, support, attack }

/// スカッド・ステータス(出場機会の約束)。選手にどの立場を約束するかで、
/// ベンチに置いたときの不満の増え方と、契約交渉で求める週給が変わる。
enum SquadStatus { keyPlayer, regular, rotation, prospect }

extension SquadStatusInfo on SquadStatus {
  String get label => switch (this) {
        SquadStatus.keyPlayer => Tr.pick('キープレイヤー', 'Key Player'),
        SquadStatus.regular => Tr.pick('主力', 'First Team'),
        SquadStatus.rotation => Tr.pick('ローテーション', 'Squad Rotation'),
        SquadStatus.prospect => Tr.pick('育成枠', 'Prospect'),
      };

  String get description => switch (this) {
        SquadStatus.keyPlayer => Tr.pick('毎試合の出場を約束。外すと大きく不満だが、給与要求も高い',
            'Promised a start every match. Leaving them out upsets them badly, and they demand high wages.'),
        SquadStatus.regular => Tr.pick('基本的に出場を想定する標準の立場',
            'The standard billing: expected to play most weeks.'),
        SquadStatus.rotation => Tr.pick('出場は状況次第。ベンチでも不満が溜まりにくい',
            'Plays as circumstances allow. Rarely unsettled by a spell on the bench.'),
        SquadStatus.prospect => Tr.pick('出場より育成優先。不満はほぼ溜まらず給与も控えめ',
            'Development before minutes. Barely ever unsettled, and cheap on wages.'),
      };

  /// ベンチに置いたときの不満増加に掛かる倍率。
  double get benchExpectationFactor => switch (this) {
        SquadStatus.keyPlayer => 1.6,
        SquadStatus.regular => 1.0,
        SquadStatus.rotation => 0.5,
        SquadStatus.prospect => 0.2,
      };

  /// 契約交渉で求める週給に掛かる倍率(立場が上なほど高い)。
  double get wageFactor => switch (this) {
        SquadStatus.keyPlayer => 1.15,
        SquadStatus.regular => 1.0,
        SquadStatus.rotation => 0.92,
        SquadStatus.prospect => 0.85,
      };
}

extension PlayerDutyInfo on PlayerDuty {
  String get label => switch (this) {
        PlayerDuty.defend => Tr.pick('守備的', 'Defend'),
        PlayerDuty.support => Tr.pick('バランス', 'Support'),
        PlayerDuty.attack => Tr.pick('攻撃的', 'Attack'),
      };

  String get description => switch (this) {
        PlayerDuty.defend => Tr.pick('守備力にボーナスが付く代わりに攻撃力が手薄になる。守備を安定させたい選手向け。',
            'Gains a defensive bonus at the cost of attacking output. For players you want holding the line.'),
        PlayerDuty.support => Tr.pick('攻守どちらにも偏らない標準設定。',
            'The balanced default, favouring neither attack nor defence.'),
        PlayerDuty.attack => Tr.pick(
            '攻撃力にボーナスが付く代わりに守備力が手薄になる。得点への関与を増やしたい選手向け。',
            'Gains an attacking bonus at the cost of defensive cover. For players you want involved in goals.'),
      };
}

/// 選手のプレースタイル(ロール)。デューティ(攻守の重心)とは別に、
/// どの能力値を活かしたプレーを得意とするかを表す。役割に適した能力値が
/// 高いほど攻撃/守備への貢献度にボーナスが、低いと逆にペナルティがかかる。
enum PlayerRole {
  standard,
  sweeperKeeper,
  shotStopper,
  commandingKeeper,
  ballPlayingDefender,
  stopper,
  libero,
  fullBack,
  wingBack,
  playmaker,
  boxToBox,
  anchorMan,
  wideMidfielder,
  mezzala,
  poacher,
  targetMan,
  insideForward,
  wingerCrosser,
  deepLyingForward,
  completeForward,
}

extension PlayerRoleInfo on PlayerRole {
  String get label => switch (this) {
        PlayerRole.standard => Tr.pick('標準', 'Standard'),
        PlayerRole.sweeperKeeper => Tr.pick('スイーパーキーパー', 'Sweeper Keeper'),
        PlayerRole.shotStopper => Tr.pick('シュートストッパー', 'Shot Stopper'),
        PlayerRole.commandingKeeper => Tr.pick('制空型GK', 'Commanding Keeper'),
        PlayerRole.ballPlayingDefender =>
          Tr.pick('ビルドアップCB', 'Ball Playing Defender'),
        PlayerRole.stopper => Tr.pick('ストッパー', 'Stopper'),
        PlayerRole.libero => Tr.pick('リベロ', 'Libero'),
        PlayerRole.fullBack => Tr.pick('攻撃参加型SB', 'Full Back'),
        PlayerRole.wingBack => Tr.pick('突破型WB', 'Wing Back'),
        PlayerRole.playmaker => Tr.pick('プレーメイカー', 'Playmaker'),
        PlayerRole.boxToBox => Tr.pick('ボックストゥボックス', 'Box to Box'),
        PlayerRole.anchorMan => Tr.pick('アンカー', 'Anchor Man'),
        PlayerRole.wideMidfielder => Tr.pick('ワイドMF', 'Wide Midfielder'),
        PlayerRole.mezzala => Tr.pick('インサイドハーフ', 'Inside Forward'),
        PlayerRole.poacher => Tr.pick('ポーチャー', 'Poacher'),
        PlayerRole.targetMan => Tr.pick('ターゲットマン', 'Target Man'),
        PlayerRole.insideForward => Tr.pick('カットインアタッカー', 'Inverted Winger'),
        PlayerRole.wingerCrosser => Tr.pick('クロッサー', 'Winger'),
        PlayerRole.deepLyingForward => Tr.pick('偽9番', 'False Nine'),
        PlayerRole.completeForward => Tr.pick('オールラウンドFW', 'Complete Forward'),
      };

  String get description => switch (this) {
        PlayerRole.standard =>
          Tr.pick('特定のプレースタイルを指定しない', 'No particular playing style.'),
        PlayerRole.sweeperKeeper => Tr.pick('キック・ハンドリングを活かしたビルドアップ参加型のGK',
            'A keeper who joins the build-up, using kicking and handling.'),
        PlayerRole.shotStopper => Tr.pick('反射神経とワン・オン・ワンの強さで難しいシュートを止めるGK',
            'A keeper who saves the hard ones through reflexes and one-on-one strength.'),
        PlayerRole.commandingKeeper => Tr.pick('空中戦の制圧力でクロス・セットプレーに強いGK',
            'A keeper who dominates the air, strong against crosses and set pieces.'),
        PlayerRole.ballPlayingDefender => Tr.pick('パス・視野を活かして後方から組み立てるCB',
            'A centre back who builds from the back with passing and vision.'),
        PlayerRole.stopper => Tr.pick('タックル・積極性を活かして潰しにかかるCB',
            'A centre back who steps out to win the ball with tackling and aggression.'),
        PlayerRole.libero => Tr.pick('読みの鋭さでカバーリングし、危機を未然に防ぐDF',
            'A defender who reads danger early and covers before it develops.'),
        PlayerRole.fullBack => Tr.pick('スタミナを活かして上下動を繰り返す攻撃参加型のSB/WB',
            'A full back or wing back who gets up and down the flank all match.'),
        PlayerRole.wingBack => Tr.pick('スピードと仕掛けでサイドを切り裂くWB',
            'A wing back who cuts the flank open with pace and dribbling.'),
        PlayerRole.playmaker => Tr.pick('パス・視野で崩しの起点となるMF',
            'A midfielder who starts the breakthrough with passing and vision.'),
        PlayerRole.boxToBox => Tr.pick('スタミナ・運動量で攻守にわたって働くMF',
            'A midfielder who covers both ends through stamina and work rate.'),
        PlayerRole.anchorMan => Tr.pick('タックルとポジショニングで潰し役に徹する守備的MF',
            'A holding midfielder who screens the defence with tackling and positioning.'),
        PlayerRole.wideMidfielder => Tr.pick('クロスとスピードでサイドからチャンスを演出するMF',
            'A midfielder who creates from wide with crossing and pace.'),
        PlayerRole.mezzala => Tr.pick('ドリブルで持ち運び、攻撃参加するインサイドハーフ',
            'An inside forward who carries the ball and joins the attack.'),
        PlayerRole.poacher => Tr.pick('フィニッシュ・オフザボールで得点を狙うFW',
            'A forward who hunts goals through finishing and movement off the ball.'),
        PlayerRole.targetMan => Tr.pick('ヘディング・強さを活かした起点となるFW',
            'A forward who holds the ball up with heading and strength.'),
        PlayerRole.insideForward => Tr.pick('ドリブルと中央への仕掛けでゴールに迫るFW',
            'A forward who dribbles infield to threaten goal.'),
        PlayerRole.wingerCrosser => Tr.pick('クロスとスピードでチャンスを供給するウイング',
            'A winger who supplies chances with crossing and pace.'),
        PlayerRole.deepLyingForward => Tr.pick('下がってパス・視野で組み立てに参加するFW',
            'A forward who drops deep to join the build-up with passing and vision.'),
        PlayerRole.completeForward => Tr.pick('技術と冷静さを兼ね備えたオールラウンドなFW',
            'An all-round forward combining technique with composure.'),
      };

  /// このロールを選択できるポジション大分類(standardは全ポジション共通)。
  List<PositionGroup> get allowedGroups => switch (this) {
        PlayerRole.standard => PositionGroup.values,
        PlayerRole.sweeperKeeper ||
        PlayerRole.shotStopper ||
        PlayerRole.commandingKeeper =>
          [PositionGroup.gk],
        PlayerRole.ballPlayingDefender ||
        PlayerRole.stopper ||
        PlayerRole.libero ||
        PlayerRole.fullBack ||
        PlayerRole.wingBack =>
          [PositionGroup.def],
        PlayerRole.playmaker ||
        PlayerRole.boxToBox ||
        PlayerRole.anchorMan ||
        PlayerRole.wideMidfielder ||
        PlayerRole.mezzala =>
          [PositionGroup.mid],
        PlayerRole.poacher ||
        PlayerRole.targetMan ||
        PlayerRole.insideForward ||
        PlayerRole.wingerCrosser ||
        PlayerRole.deepLyingForward ||
        PlayerRole.completeForward =>
          [PositionGroup.att],
      };

  /// このロールの適性を判定する際に重視する能力値(2項目の平均で評価)。
  List<String> get keyAttributes => switch (this) {
        PlayerRole.standard => const [],
        PlayerRole.sweeperKeeper => const [
            AttributeKeys.kicking,
            AttributeKeys.commandOfArea,
          ],
        PlayerRole.shotStopper => const [
            AttributeKeys.reflexes,
            AttributeKeys.oneOnOnes,
          ],
        PlayerRole.commandingKeeper => const [
            AttributeKeys.aerialReach,
            AttributeKeys.handling,
          ],
        PlayerRole.ballPlayingDefender => const [
            AttributeKeys.passing,
            AttributeKeys.vision,
          ],
        PlayerRole.stopper => const [
            AttributeKeys.tackling,
            AttributeKeys.aggression,
          ],
        PlayerRole.libero => const [
            AttributeKeys.anticipation,
            AttributeKeys.positioning,
          ],
        PlayerRole.fullBack => const [
            AttributeKeys.crossing,
            AttributeKeys.stamina,
          ],
        PlayerRole.wingBack => const [
            AttributeKeys.pace,
            AttributeKeys.dribbling
          ],
        PlayerRole.playmaker => const [
            AttributeKeys.vision,
            AttributeKeys.passing
          ],
        PlayerRole.boxToBox => const [
            AttributeKeys.stamina,
            AttributeKeys.workRate,
          ],
        PlayerRole.anchorMan => const [
            AttributeKeys.tackling,
            AttributeKeys.positioning,
          ],
        PlayerRole.wideMidfielder => const [
            AttributeKeys.crossing,
            AttributeKeys.pace,
          ],
        PlayerRole.mezzala => const [
            AttributeKeys.dribbling,
            AttributeKeys.offTheBall,
          ],
        PlayerRole.poacher => const [
            AttributeKeys.finishing,
            AttributeKeys.offTheBall,
          ],
        PlayerRole.targetMan => const [
            AttributeKeys.heading,
            AttributeKeys.strength,
          ],
        PlayerRole.insideForward => const [
            AttributeKeys.dribbling,
            AttributeKeys.longShots,
          ],
        PlayerRole.wingerCrosser => const [
            AttributeKeys.crossing,
            AttributeKeys.pace,
          ],
        PlayerRole.deepLyingForward => const [
            AttributeKeys.passing,
            AttributeKeys.vision,
          ],
        PlayerRole.completeForward => const [
            AttributeKeys.technique,
            AttributeKeys.composure,
          ],
      };
}

/// 選手の性格。不満度(happiness)の変動しやすさや移籍希望の出やすさに影響する。
enum PlayerPersonality {
  professional,
  balanced,
  ambitious,
  temperamental,
  loyal,
  modelCitizen,
  resolute,
  spirited,
  determined,
  driven,
  perfectionist,
  laidBack,
  easilyDiscouraged,
  volatile,
  unambitious,
  lowDetermination,
  fairlyProfessional,
  veryAmbitious,
  mercenary,
  clubLegendType,
}

extension PlayerPersonalityInfo on PlayerPersonality {
  String get label => switch (this) {
        PlayerPersonality.professional => Tr.pick('プロフェッショナル', 'Professional'),
        PlayerPersonality.balanced => Tr.pick('バランス型', 'Balanced'),
        PlayerPersonality.ambitious => Tr.pick('野心家', 'Ambitious'),
        PlayerPersonality.temperamental => Tr.pick('気分屋', 'Temperamental'),
        PlayerPersonality.loyal => Tr.pick('忠誠心の強い選手', 'Loyal'),
        PlayerPersonality.modelCitizen => Tr.pick('模範選手', 'Model Professional'),
        PlayerPersonality.resolute => Tr.pick('動じない性格', 'Unflappable'),
        PlayerPersonality.spirited => Tr.pick('闘争心旺盛', 'Fighter'),
        PlayerPersonality.determined => Tr.pick('負けず嫌い', 'Driven'),
        PlayerPersonality.driven => Tr.pick('成り上がり志向', 'Self-Promoting'),
        PlayerPersonality.perfectionist => Tr.pick('完璧主義', 'Perfectionist'),
        PlayerPersonality.laidBack => Tr.pick('おおらか', 'Easygoing'),
        PlayerPersonality.easilyDiscouraged => Tr.pick('メンタルが弱い', 'Fragile'),
        PlayerPersonality.volatile => Tr.pick('非常に不安定', 'Highly Volatile'),
        PlayerPersonality.unambitious => Tr.pick('向上心が低い', 'Unambitious'),
        PlayerPersonality.lowDetermination => Tr.pick('根性がない', 'Faint-Hearted'),
        PlayerPersonality.fairlyProfessional =>
          Tr.pick('まずまず堅実', 'Fairly Professional'),
        PlayerPersonality.veryAmbitious => Tr.pick('非常に野心的', 'Very Ambitious'),
        PlayerPersonality.mercenary => Tr.pick('契約至上主義', 'Money Motivated'),
        PlayerPersonality.clubLegendType =>
          Tr.pick('生え抜き気質', 'Devoted to the Club'),
      };

  String get description => switch (this) {
        PlayerPersonality.professional => Tr.pick('不満が溜まりにくく、安定した意欲を保つ',
            'Rarely becomes unsettled and keeps a steady level of motivation.'),
        PlayerPersonality.balanced =>
          Tr.pick('標準的な反応を示す', 'Reacts in the ordinary way.'),
        PlayerPersonality.ambitious => Tr.pick('ベンチや低成績にすぐ不満を抱く',
            'Quickly grows unhappy on the bench or after poor results.'),
        PlayerPersonality.temperamental => Tr.pick('状況次第で気分が大きく変動する',
            'Swings sharply in mood depending on how things are going.'),
        PlayerPersonality.loyal => Tr.pick('多少の不満があってもクラブに留まりやすい',
            'Tends to stay at the club even when somewhat unhappy.'),
        PlayerPersonality.modelCitizen => Tr.pick('常に高い意欲を保ち、若手の手本となる',
            'Keeps motivation high at all times and sets the example for younger players.'),
        PlayerPersonality.resolute => Tr.pick('逆境でも動揺せず冷静さを保つ',
            'Stays calm and unshaken when things turn against the team.'),
        PlayerPersonality.spirited => Tr.pick('困難な状況でも闘争心を燃やして奮起する',
            'Digs in and fights harder the more difficult the situation.'),
        PlayerPersonality.determined => Tr.pick('結果へのこだわりが強く、成長への意欲も高い',
            'Cares deeply about results and is eager to keep improving.'),
        PlayerPersonality.driven => Tr.pick('自らの評価・待遇の向上に強くこだわる',
            'Pushes hard for a better standing and better terms.'),
        PlayerPersonality.perfectionist => Tr.pick(
            'ベンチや低評価に強い不満を抱く一方、自己研鑽への意欲は高い',
            'Deeply resents the bench and poor ratings, but works relentlessly on their game.'),
        PlayerPersonality.laidBack => Tr.pick('何事にも動じないが、向上心もやや控えめ',
            'Nothing rattles them, though their drive to improve is modest.'),
        PlayerPersonality.easilyDiscouraged => Tr.pick(
            '結果が振るわないとすぐに意気消沈する', 'Loses heart quickly when results go badly.'),
        PlayerPersonality.volatile => Tr.pick('気分の浮き沈みが極端で、扱いが難しい',
            'Extreme highs and lows, and difficult to manage.'),
        PlayerPersonality.unambitious => Tr.pick('現状に満足しやすく、成長への意欲は控えめ',
            'Content with their lot, with little appetite for improvement.'),
        PlayerPersonality.lowDetermination => Tr.pick(
            '困難な状況で粘り強さに欠ける', 'Lacks resilience when the going gets hard.'),
        PlayerPersonality.fairlyProfessional => Tr.pick(
            'プロフェッショナルとバランス型の中間的な気質',
            'A temperament sitting between professional and balanced.'),
        PlayerPersonality.veryAmbitious => Tr.pick('常により高みを目指し、現状への不満を抱きやすい',
            'Always chasing the next level, and easily dissatisfied with the present.'),
        PlayerPersonality.mercenary => Tr.pick('待遇・移籍金への関心が非常に強い',
            'Intensely interested in terms and transfer money.'),
        PlayerPersonality.clubLegendType => Tr.pick(
            'クラブへの忠誠心が非常に強く、多少の不満では移籍を望まない',
            'Fiercely loyal to the club, and will not push for a move over minor grievances.'),
      };

  double get benchSensitivity => switch (this) {
        PlayerPersonality.professional => 0.6,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.ambitious => 1.5,
        PlayerPersonality.temperamental => 1.3,
        PlayerPersonality.loyal => 0.8,
        PlayerPersonality.modelCitizen => 0.5,
        PlayerPersonality.resolute => 0.65,
        PlayerPersonality.spirited => 0.9,
        PlayerPersonality.determined => 0.7,
        PlayerPersonality.driven => 1.1,
        PlayerPersonality.perfectionist => 1.2,
        PlayerPersonality.laidBack => 0.6,
        PlayerPersonality.easilyDiscouraged => 1.4,
        PlayerPersonality.volatile => 1.6,
        PlayerPersonality.unambitious => 0.7,
        PlayerPersonality.lowDetermination => 1.0,
        PlayerPersonality.fairlyProfessional => 0.8,
        PlayerPersonality.veryAmbitious => 1.7,
        PlayerPersonality.mercenary => 1.2,
        PlayerPersonality.clubLegendType => 0.55,
      };

  double get wageSensitivity => switch (this) {
        PlayerPersonality.professional => 0.7,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.ambitious => 1.3,
        PlayerPersonality.temperamental => 1.2,
        PlayerPersonality.loyal => 0.7,
        PlayerPersonality.modelCitizen => 0.6,
        PlayerPersonality.resolute => 0.85,
        PlayerPersonality.spirited => 0.95,
        PlayerPersonality.determined => 0.9,
        PlayerPersonality.driven => 1.35,
        PlayerPersonality.perfectionist => 1.0,
        PlayerPersonality.laidBack => 0.6,
        PlayerPersonality.easilyDiscouraged => 1.1,
        PlayerPersonality.volatile => 1.3,
        PlayerPersonality.unambitious => 0.6,
        PlayerPersonality.lowDetermination => 1.0,
        PlayerPersonality.fairlyProfessional => 0.85,
        PlayerPersonality.veryAmbitious => 1.5,
        PlayerPersonality.mercenary => 1.6,
        PlayerPersonality.clubLegendType => 0.65,
      };

  double get resultSensitivity => switch (this) {
        PlayerPersonality.professional => 0.7,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.ambitious => 1.4,
        PlayerPersonality.temperamental => 1.2,
        PlayerPersonality.loyal => 0.8,
        PlayerPersonality.modelCitizen => 0.6,
        PlayerPersonality.resolute => 0.65,
        PlayerPersonality.spirited => 0.85,
        PlayerPersonality.determined => 0.7,
        PlayerPersonality.driven => 1.15,
        PlayerPersonality.perfectionist => 1.1,
        PlayerPersonality.laidBack => 0.6,
        PlayerPersonality.easilyDiscouraged => 1.5,
        PlayerPersonality.volatile => 1.5,
        PlayerPersonality.unambitious => 0.7,
        PlayerPersonality.lowDetermination => 1.0,
        PlayerPersonality.fairlyProfessional => 0.85,
        PlayerPersonality.veryAmbitious => 1.6,
        PlayerPersonality.mercenary => 1.1,
        PlayerPersonality.clubLegendType => 0.7,
      };

  /// 不満度がこの値を下回ると移籍を希望し始める。
  int get transferRequestThreshold => switch (this) {
        PlayerPersonality.loyal => 10,
        PlayerPersonality.professional => 15,
        PlayerPersonality.balanced => 20,
        PlayerPersonality.temperamental => 25,
        PlayerPersonality.ambitious => 30,
        PlayerPersonality.modelCitizen => 8,
        PlayerPersonality.resolute => 12,
        PlayerPersonality.spirited => 18,
        PlayerPersonality.determined => 14,
        PlayerPersonality.driven => 28,
        PlayerPersonality.perfectionist => 20,
        PlayerPersonality.laidBack => 15,
        PlayerPersonality.easilyDiscouraged => 22,
        PlayerPersonality.volatile => 28,
        PlayerPersonality.unambitious => 10,
        PlayerPersonality.lowDetermination => 18,
        PlayerPersonality.fairlyProfessional => 17,
        PlayerPersonality.veryAmbitious => 35,
        PlayerPersonality.mercenary => 38,
        PlayerPersonality.clubLegendType => 5,
      };

  /// トレーニングでの成長効率倍率。プロフェッショナルな選手ほど自主練習に
  /// 励んで伸びやすく、気分屋は取り組みにムラがあり伸び悩みやすい。
  double get growthFactor => switch (this) {
        PlayerPersonality.professional => 1.15,
        PlayerPersonality.ambitious => 1.08,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.loyal => 0.97,
        PlayerPersonality.temperamental => 0.85,
        PlayerPersonality.modelCitizen => 1.2,
        PlayerPersonality.resolute => 1.05,
        PlayerPersonality.spirited => 1.12,
        PlayerPersonality.determined => 1.18,
        PlayerPersonality.driven => 1.1,
        PlayerPersonality.perfectionist => 1.15,
        PlayerPersonality.laidBack => 0.85,
        PlayerPersonality.easilyDiscouraged => 0.85,
        PlayerPersonality.volatile => 0.8,
        PlayerPersonality.unambitious => 0.8,
        PlayerPersonality.lowDetermination => 0.78,
        PlayerPersonality.fairlyProfessional => 1.08,
        PlayerPersonality.veryAmbitious => 1.05,
        PlayerPersonality.mercenary => 0.95,
        PlayerPersonality.clubLegendType => 0.98,
      };

  /// 想定移籍金への性格による倍率。プロ意識・野心の高さは他クラブからの
  /// 評価(=市場価値)を押し上げ、気分屋は「扱いにくさ」を敬遠されて
  /// 割り引かれる。忠誠心は移籍する気の薄さから買い手がつきにくい。
  double get marketValueFactor => switch (this) {
        PlayerPersonality.professional => 1.1,
        PlayerPersonality.ambitious => 1.08,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.loyal => 0.95,
        PlayerPersonality.temperamental => 0.88,
        PlayerPersonality.modelCitizen => 1.12,
        PlayerPersonality.resolute => 1.03,
        PlayerPersonality.spirited => 1.05,
        PlayerPersonality.determined => 1.05,
        PlayerPersonality.driven => 1.1,
        PlayerPersonality.perfectionist => 1.05,
        PlayerPersonality.laidBack => 0.95,
        PlayerPersonality.easilyDiscouraged => 0.9,
        PlayerPersonality.volatile => 0.85,
        PlayerPersonality.unambitious => 0.9,
        PlayerPersonality.lowDetermination => 0.95,
        PlayerPersonality.fairlyProfessional => 1.03,
        PlayerPersonality.veryAmbitious => 1.12,
        PlayerPersonality.mercenary => 1.15,
        PlayerPersonality.clubLegendType => 0.9,
      };
}

/// 選手の特性。性格(不満度・成長)とは別に、試合の内容(相手の力量差・
/// ホーム/アウェイ・天候・コンディション・年齢・各種能力値の高さ・
/// 調子の波)によって当日のパフォーマンスに補正がかかる。能力値が同じ
/// 選手同士でも結果に差が出るようにするための要素。持たない選手も多い。
enum PlayerTrait {
  // 対戦相手との相対的な実力差
  giantKiller,
  frontRunner,
  underdogSpirit,
  dominantForce,
  // 対戦相手の絶対的な実力
  bigGameHunter,
  bullyBall,
  // ホーム/アウェイ
  homeBoy,
  roadWarrior,
  // 天候
  rainMaster,
  windMaster,
  heatwaveMaster,
  snowMaster,
  fairWeatherPlayer,
  // 疲労・コンディション
  ironLungs,
  freshLegs,
  confidentMind,
  clutchNerves,
  contentPlayer,
  sharpShooter,
  rustyButReady,
  // 年齢
  wonderkid,
  oldHead,
  primeTime,
  // メンタル属性依存
  warriorSpirit,
  calmHead,
  leaderOnPitch,
  // 波・安定性
  streaky,
  volatileTalent,
  metronome,
  // 技術・フィジカル属性依存
  visionary,
  paceMerchant,
  powerhouse,
  enginesRunning,
  silkyDribbler,
  playmakerTrait,
  ballWinner,
  shadowMarker,
  clinicalFinisher,
  distanceShooter,
  aerialThreat,
  showman,
  sureTouch,
  crossSpecialist,
  setPieceMaestro,
  clockwork,
  decisiveMind,
  teamPlayer,
  tirelessRunner,
  explosiveStart,
  fearlessDefender,
  // サッカー漫画のような劇的な特性(複合条件・GK属性の活用)
  divineReflexes,
  awayDayHero,
  risingPhoenix,
  veteranAce,
}

extension PlayerTraitInfo on PlayerTrait {
  String get label => switch (this) {
        PlayerTrait.giantKiller => Tr.pick('格上キラー', 'Giant Killer'),
        PlayerTrait.frontRunner => Tr.pick('横綱相撲', 'Front Runner'),
        PlayerTrait.underdogSpirit => Tr.pick('判官びいき', "Underdog's Friend"),
        PlayerTrait.dominantForce => Tr.pick('圧倒的優位', 'Ruthless Favourite'),
        PlayerTrait.bigGameHunter => Tr.pick('ビッグゲームハンター', 'Big Game Hunter'),
        PlayerTrait.bullyBall => Tr.pick('弱者いじめ', 'Flat Track Bully'),
        PlayerTrait.homeBoy => Tr.pick('我が家が一番', 'Home Comforts'),
        PlayerTrait.roadWarrior => Tr.pick('遠征上等', 'Road Warrior'),
        PlayerTrait.rainMaster => Tr.pick('雨のスペシャリスト', 'Rain Specialist'),
        PlayerTrait.windMaster => Tr.pick('強風マイスター', 'Master of the Gale'),
        PlayerTrait.heatwaveMaster => Tr.pick('猛暑をものともせず', 'Heatproof'),
        PlayerTrait.snowMaster => Tr.pick('雪上のアーティスト', 'Artist on Snow'),
        PlayerTrait.fairWeatherPlayer => Tr.pick('快晴主義', 'Fair Weather Player'),
        PlayerTrait.ironLungs => Tr.pick('鉄の肺', 'Iron Lungs'),
        PlayerTrait.freshLegs => Tr.pick('フレッシュレッグ', 'Fresh Legs'),
        PlayerTrait.confidentMind => Tr.pick('自信家', 'Confident'),
        PlayerTrait.clutchNerves => Tr.pick('逆境をはねのける', 'Defies Adversity'),
        PlayerTrait.contentPlayer => Tr.pick('満ち足りた心', 'Contented Mind'),
        PlayerTrait.sharpShooter => Tr.pick('絶好調', 'In the Zone'),
        PlayerTrait.rustyButReady => Tr.pick('錆びついても衰えぬ', 'Never Rusts'),
        PlayerTrait.wonderkid => Tr.pick('若き才能', 'Young Talent'),
        PlayerTrait.oldHead => Tr.pick('百戦錬磨', 'Battle Hardened'),
        PlayerTrait.primeTime => Tr.pick('脂の乗った時期', 'At His Peak'),
        PlayerTrait.warriorSpirit => Tr.pick('闘将', 'Warrior'),
        PlayerTrait.calmHead => Tr.pick('冷静沈着', 'Ice Cool'),
        PlayerTrait.leaderOnPitch =>
          Tr.pick('ピッチの統率者', 'Commander on the Pitch'),
        PlayerTrait.streaky => Tr.pick('波がある', 'Streaky'),
        PlayerTrait.volatileTalent => Tr.pick('気分屋の天才', 'Volatile Talent'),
        PlayerTrait.metronome => Tr.pick('メトロノーム', 'Metronome'),
        PlayerTrait.visionary => Tr.pick('視野の魔術師', 'Vision Magician'),
        PlayerTrait.paceMerchant => Tr.pick('スピードスター', 'Speed Merchant'),
        PlayerTrait.powerhouse => Tr.pick('パワーハウス', 'Powerhouse'),
        PlayerTrait.enginesRunning => Tr.pick('尽きぬスタミナ', 'Endless Stamina'),
        PlayerTrait.silkyDribbler => Tr.pick('華麗なドリブラー', 'Elegant Dribbler'),
        PlayerTrait.playmakerTrait => Tr.pick('司令塔の才', 'Natural Playmaker'),
        PlayerTrait.ballWinner => Tr.pick('ボールハンター', 'Ball Hunter'),
        PlayerTrait.shadowMarker => Tr.pick('影のマーカー', 'Shadow Marker'),
        PlayerTrait.clinicalFinisher =>
          Tr.pick('冷徹なフィニッシャー', 'Clinical Finisher'),
        PlayerTrait.distanceShooter =>
          Tr.pick('ロングレンジシューター', 'Long Range Shooter'),
        PlayerTrait.aerialThreat => Tr.pick('空中戦の脅威', 'Aerial Threat'),
        PlayerTrait.showman => Tr.pick('ショーマン', 'Showman'),
        PlayerTrait.sureTouch => Tr.pick('確かなファーストタッチ', 'Sure First Touch'),
        PlayerTrait.crossSpecialist => Tr.pick('クロスの名手', 'Master Crosser'),
        PlayerTrait.setPieceMaestro =>
          Tr.pick('セットプレーの達人', 'Set Piece Specialist'),
        PlayerTrait.clockwork => Tr.pick('予測の天才', 'Gifted Reader of the Game'),
        PlayerTrait.decisiveMind => Tr.pick('的確な判断', 'Sound Decision Maker'),
        PlayerTrait.teamPlayer => Tr.pick('献身的なチームワーク', 'Selfless Team Player'),
        PlayerTrait.tirelessRunner => Tr.pick('尽きせぬ運動量', 'Tireless Runner'),
        PlayerTrait.explosiveStart =>
          Tr.pick('爆発的な加速', 'Explosive Acceleration'),
        PlayerTrait.fearlessDefender =>
          Tr.pick('恐れを知らぬ守備', 'Fearless Defender'),
        PlayerTrait.divineReflexes => Tr.pick('神がかった反応', 'Miracle Reflexes'),
        PlayerTrait.awayDayHero =>
          Tr.pick('アウェイの逆境児', 'Thrives on Hostile Grounds'),
        PlayerTrait.risingPhoenix => Tr.pick('不屈の闘志', 'Indomitable Spirit'),
        PlayerTrait.veteranAce => Tr.pick('伝説のベテランエース', 'Legendary Old Head'),
      };

  String get description => switch (this) {
        PlayerTrait.giantKiller => Tr.pick('自チームより格上の相手との試合でパフォーマンスが上がる。',
            'Raises their game against opponents stronger than their own side.'),
        PlayerTrait.frontRunner => Tr.pick('自チームより格下の相手との試合でパフォーマンスが上がる。',
            'Raises their game against opponents weaker than their own side.'),
        PlayerTrait.underdogSpirit => Tr.pick('大きく格上の相手との大金星がかかる試合で、特に奮起する。',
            'Rises to the occasion when a famous upset is on the line.'),
        PlayerTrait.dominantForce => Tr.pick('大きく格下の相手に対し、危なげなく実力を発揮する。',
            'Sees off far weaker opposition without any alarm.'),
        PlayerTrait.bigGameHunter => Tr.pick('相手の実力が高いほど燃えるタイプで、強豪との試合で輝く。',
            'The stronger the opponent, the more they fire up. Shines against the best.'),
        PlayerTrait.bullyBall => Tr.pick('実力の劣る相手には容赦なく、着実に力を発揮する。',
            'Shows no mercy to weaker opposition and delivers reliably.'),
        PlayerTrait.homeBoy => Tr.pick('ホームゲームで観客の後押しを受けて力を発揮する。',
            'Feeds off the home crowd and performs at home.'),
        PlayerTrait.roadWarrior => Tr.pick('アウェイゲームでも物怖じせず、普段通りの力を出せる。',
            'Unfazed away from home and plays to their usual level.'),
        PlayerTrait.rainMaster => Tr.pick('雨天の試合でも足元が乱れず、パフォーマンスを落とさない。',
            'Keeps their footing in the rain without dropping off.'),
        PlayerTrait.windMaster => Tr.pick('強風下でもボールコントロールを乱さない。',
            'Keeps control of the ball even in a strong wind.'),
        PlayerTrait.heatwaveMaster => Tr.pick(
            '猛暑の試合でも運動量が落ちにくい。', 'Holds their work rate even in fierce heat.'),
        PlayerTrait.snowMaster => Tr.pick('雪の中でも普段以上の輝きを見せる稀有な選手。',
            'A rare player who shines even brighter in the snow.'),
        PlayerTrait.fairWeatherPlayer => Tr.pick('天候の良い試合でこそ本領を発揮する。',
            'Comes into their own when the weather is fine.'),
        PlayerTrait.ironLungs => Tr.pick('疲労が溜まった状態でも動きが落ちない。',
            'Does not slow down even when fatigue has set in.'),
        PlayerTrait.freshLegs =>
          Tr.pick('疲労が少ない状態では特に鋭さを増す。', 'Especially sharp when fresh.'),
        PlayerTrait.confidentMind => Tr.pick('士気が高いときにさらに調子を上げる。',
            'Lifts their level further when morale is high.'),
        PlayerTrait.clutchNerves => Tr.pick('士気が落ち込んでいてもむしろ闘志を燃やす。',
            'Fires up rather than folds when morale is low.'),
        PlayerTrait.contentPlayer => Tr.pick('クラブへの満足度が高いと安定した力を発揮する。',
            'Performs consistently while happy at the club.'),
        PlayerTrait.sharpShooter => Tr.pick('マッチシャープネスが最高潮のときに爆発的な力を見せる。',
            'Explosive when match sharpness is at its peak.'),
        PlayerTrait.rustyButReady => Tr.pick('実戦感覚が鈍っていても崩れない安定感を持つ。',
            'Holds their standard even when short of match sharpness.'),
        PlayerTrait.wonderkid => Tr.pick(
            '若さゆえの勢いでプレーに勢いが出る。', 'Plays with the momentum that youth brings.'),
        PlayerTrait.oldHead => Tr.pick('豊富な経験に裏打ちされた読みでプレーする。',
            'Plays on a reading of the game built from long experience.'),
        PlayerTrait.primeTime => Tr.pick(
            '選手としての全盛期にひときわ輝く。', 'Shines brightest in their prime years.'),
        PlayerTrait.warriorSpirit => Tr.pick('闘志の高さがそのままプレーの迫力に変わる。',
            'Turns sheer determination into the force of their play.'),
        PlayerTrait.calmHead => Tr.pick('冷静さが持ち味で、大舞台でも動じない。',
            'Composure is their hallmark, and the big stage does not shake them.'),
        PlayerTrait.leaderOnPitch => Tr.pick('統率力の高さでチーム全体を引っ張る。',
            'Drags the whole team along through sheer leadership.'),
        PlayerTrait.streaky => Tr.pick('調子の波が激しく、試合ごとのパフォーマンスのブレが大きい。',
            'Runs hot and cold, with wide swings between matches.'),
        PlayerTrait.volatileTalent => Tr.pick('極端に調子の良し悪しが分かれる、より波の激しいタイプ。',
            'Swings even harder between brilliant and dreadful.'),
        PlayerTrait.metronome => Tr.pick('常に安定したパフォーマンスを崩さない。',
            'Never departs from a consistent level of performance.'),
        PlayerTrait.visionary => Tr.pick(
            '卓越した視野でチャンスを作り出す。', 'Creates chances through outstanding vision.'),
        PlayerTrait.paceMerchant => Tr.pick(
            'スピードを活かしたプレーで違いを生む。', 'Makes the difference through sheer pace.'),
        PlayerTrait.powerhouse => Tr.pick('圧倒的なフィジカルの強さで相手を圧倒する。',
            'Overpowers opponents with sheer physical strength.'),
        PlayerTrait.enginesRunning => Tr.pick('豊富なスタミナで最後まで運動量を落とさない。',
            'Keeps running to the final whistle on deep reserves of stamina.'),
        PlayerTrait.silkyDribbler => Tr.pick('卓越したドリブルで局面を打開する。',
            'Breaks the game open with outstanding dribbling.'),
        PlayerTrait.playmakerTrait => Tr.pick(
            '高いパス精度でチームの攻撃を組み立てる。', 'Builds the attack with precise passing.'),
        PlayerTrait.ballWinner => Tr.pick(
            '鋭いタックルで相手からボールを奪う。', 'Wins the ball back with sharp tackling.'),
        PlayerTrait.shadowMarker => Tr.pick('高いマーキング能力で相手を封じ込める。',
            'Shuts opponents out with excellent marking.'),
        PlayerTrait.clinicalFinisher => Tr.pick('決定力の高さでチャンスを確実に決めきる。',
            'Puts chances away with reliable finishing.'),
        PlayerTrait.distanceShooter => Tr.pick('遠目からのシュートで違いを見せる。',
            'Makes the difference with shots from distance.'),
        PlayerTrait.aerialThreat => Tr.pick('高い制空力でセットプレーの脅威となる。',
            'A threat at set pieces through dominance in the air.'),
        PlayerTrait.showman => Tr.pick('閃きのあるプレーで観客を沸かせる。',
            'Lifts the crowd with flashes of inspiration.'),
        PlayerTrait.sureTouch => Tr.pick('正確なファーストタッチでプレーの精度を高める。',
            'Raises the quality of everything with a clean first touch.'),
        PlayerTrait.crossSpecialist => Tr.pick(
            '精度の高いクロスでチャンスを演出する。', 'Creates chances with accurate crossing.'),
        PlayerTrait.setPieceMaestro => Tr.pick('フリーキックの精度で得点機会を作る。',
            'Manufactures chances with accurate free kicks.'),
        PlayerTrait.clockwork => Tr.pick('鋭い予測でプレーの一歩先を読む。',
            'Reads the game a step ahead through sharp anticipation.'),
        PlayerTrait.decisiveMind => Tr.pick('高い判断力で最適なプレーを選択する。',
            'Picks the right option through excellent decision-making.'),
        PlayerTrait.teamPlayer =>
          Tr.pick('高いチームワークでチームに貢献する。', 'Contributes through strong teamwork.'),
        PlayerTrait.tirelessRunner => Tr.pick('豊富な運動量でピッチを走り回る。',
            'Covers every blade of grass on a huge work rate.'),
        PlayerTrait.explosiveStart => Tr.pick('鋭い加速力で相手を置き去りにする。',
            'Leaves opponents behind with fierce acceleration.'),
        PlayerTrait.fearlessDefender => Tr.pick('勇敢さを武器に体を張ったプレーを見せる。',
            'Puts their body on the line through sheer bravery.'),
        PlayerTrait.divineReflexes => Tr.pick('神がかった反応速度で、並みのシュートを寄せ付けない守護神。',
            'Reflexes so quick that ordinary shots never trouble them.'),
        PlayerTrait.awayDayHero => Tr.pick('アウェイでの大きな逆境ほど、燃え上がって真価を発揮する。',
            'The more hostile the away ground, the more they come alive.'),
        PlayerTrait.risingPhoenix => Tr.pick('苦境で意気消沈するどころか、そこから闘志を燃やして這い上がる。',
            'Rather than sink in adversity, they fight their way back out of it.'),
        PlayerTrait.veteranAce => Tr.pick('経験を積んだベテランが、大一番でこそその真価を見せつける。',
            'A seasoned veteran who proves their worth when it matters most.'),
      };
}

/// 選手特性の分類。特性は加入した時点で決まり、あとから身に付くことはない。
/// - [technical]: 具体的な技術・フィジカルの能力値と結びついた持ち味。
/// - [personality]: 対戦相手・状況への向き合い方など、メンタル面の資質。
/// - [talent]: 天候・年齢・調子の波など、生まれ持った資質。
enum PlayerTraitCategory { technical, personality, talent }

extension PlayerTraitCategoryInfo on PlayerTraitCategory {
  String get label => switch (this) {
        PlayerTraitCategory.technical => Tr.pick('技術', 'Technical'),
        PlayerTraitCategory.personality => Tr.pick('性格', 'Personality'),
        PlayerTraitCategory.talent => Tr.pick('才能', 'Natural'),
      };
}

/// 各選手特性がどの分類に属するか。
/// 技術: 特定の技術・フィジカル能力値に直結するもの。
/// 性格: 対戦相手・状況への向き合い方やメンタル面の資質。
/// 才能: 天候・年齢・調子の波など、選手自身の生まれ持った資質や外的条件に
///   左右されるもの。
extension PlayerTraitCategoryOf on PlayerTrait {
  PlayerTraitCategory get category => switch (this) {
        PlayerTrait.giantKiller => PlayerTraitCategory.personality,
        PlayerTrait.frontRunner => PlayerTraitCategory.personality,
        PlayerTrait.underdogSpirit => PlayerTraitCategory.personality,
        PlayerTrait.dominantForce => PlayerTraitCategory.personality,
        PlayerTrait.bigGameHunter => PlayerTraitCategory.personality,
        PlayerTrait.bullyBall => PlayerTraitCategory.personality,
        PlayerTrait.homeBoy => PlayerTraitCategory.personality,
        PlayerTrait.roadWarrior => PlayerTraitCategory.personality,
        PlayerTrait.rainMaster => PlayerTraitCategory.talent,
        PlayerTrait.windMaster => PlayerTraitCategory.talent,
        PlayerTrait.heatwaveMaster => PlayerTraitCategory.talent,
        PlayerTrait.snowMaster => PlayerTraitCategory.talent,
        PlayerTrait.fairWeatherPlayer => PlayerTraitCategory.talent,
        PlayerTrait.ironLungs => PlayerTraitCategory.talent,
        PlayerTrait.freshLegs => PlayerTraitCategory.talent,
        PlayerTrait.confidentMind => PlayerTraitCategory.personality,
        PlayerTrait.clutchNerves => PlayerTraitCategory.personality,
        PlayerTrait.contentPlayer => PlayerTraitCategory.personality,
        PlayerTrait.sharpShooter => PlayerTraitCategory.technical,
        PlayerTrait.rustyButReady => PlayerTraitCategory.talent,
        PlayerTrait.wonderkid => PlayerTraitCategory.talent,
        PlayerTrait.oldHead => PlayerTraitCategory.talent,
        PlayerTrait.primeTime => PlayerTraitCategory.talent,
        PlayerTrait.warriorSpirit => PlayerTraitCategory.personality,
        PlayerTrait.calmHead => PlayerTraitCategory.personality,
        PlayerTrait.leaderOnPitch => PlayerTraitCategory.personality,
        PlayerTrait.streaky => PlayerTraitCategory.talent,
        PlayerTrait.volatileTalent => PlayerTraitCategory.talent,
        PlayerTrait.metronome => PlayerTraitCategory.talent,
        PlayerTrait.visionary => PlayerTraitCategory.technical,
        PlayerTrait.paceMerchant => PlayerTraitCategory.technical,
        PlayerTrait.powerhouse => PlayerTraitCategory.technical,
        PlayerTrait.enginesRunning => PlayerTraitCategory.technical,
        PlayerTrait.silkyDribbler => PlayerTraitCategory.technical,
        PlayerTrait.playmakerTrait => PlayerTraitCategory.technical,
        PlayerTrait.ballWinner => PlayerTraitCategory.technical,
        PlayerTrait.shadowMarker => PlayerTraitCategory.technical,
        PlayerTrait.clinicalFinisher => PlayerTraitCategory.technical,
        PlayerTrait.distanceShooter => PlayerTraitCategory.technical,
        PlayerTrait.aerialThreat => PlayerTraitCategory.technical,
        PlayerTrait.showman => PlayerTraitCategory.personality,
        PlayerTrait.sureTouch => PlayerTraitCategory.technical,
        PlayerTrait.crossSpecialist => PlayerTraitCategory.technical,
        PlayerTrait.setPieceMaestro => PlayerTraitCategory.technical,
        PlayerTrait.clockwork => PlayerTraitCategory.technical,
        PlayerTrait.decisiveMind => PlayerTraitCategory.personality,
        PlayerTrait.teamPlayer => PlayerTraitCategory.personality,
        PlayerTrait.tirelessRunner => PlayerTraitCategory.technical,
        PlayerTrait.explosiveStart => PlayerTraitCategory.technical,
        PlayerTrait.fearlessDefender => PlayerTraitCategory.personality,
        PlayerTrait.divineReflexes => PlayerTraitCategory.technical,
        PlayerTrait.awayDayHero => PlayerTraitCategory.personality,
        PlayerTrait.risingPhoenix => PlayerTraitCategory.personality,
        PlayerTrait.veteranAce => PlayerTraitCategory.talent,
      };
}

/// 選手の成長タイプ。年齢に応じた伸びやすさ・衰え始める時期の傾向を表す。
/// 早熟は若いうちに一気に伸びて衰えも早く、大器晩成は伸びが遅い代わりに
/// 長く成長・活躍できる。育成方針(誰を我慢して使い続けるか)に戦略性を
/// もたらす要素。
enum PlayerGrowthType { early, balanced, late }

extension PlayerGrowthTypeInfo on PlayerGrowthType {
  String get label => switch (this) {
        PlayerGrowthType.early => Tr.pick('早熟', 'Early Developer'),
        PlayerGrowthType.balanced => Tr.pick('標準', 'Standard'),
        PlayerGrowthType.late => Tr.pick('大器晩成', 'Late Bloomer'),
      };

  String get description => switch (this) {
        PlayerGrowthType.early => Tr.pick('若いうちの伸びが早い一方、衰え始めるのも早い',
            'Improves quickly when young, but starts to decline early too.'),
        PlayerGrowthType.balanced => Tr.pick('年齢による伸び・衰えの標準的なカーブをたどる',
            'Follows the standard curve of improvement and decline with age.'),
        PlayerGrowthType.late => Tr.pick('若いうちの伸びは遅いが、その分長く成長し衰えも遅い',
            'Slow to improve when young, but grows for longer and declines later.'),
      };
}

/// 旧バージョン（gk/df/mf/fwの4区分）のセーブデータからポジション名を解決する。
Position parsePosition(String raw) {
  switch (raw) {
    case 'df':
      return Position.dc;
    case 'mf':
      return Position.mc;
    case 'fw':
      return Position.st;
    default:
      try {
        return Position.values.byName(raw);
      } catch (_) {
        return Position.mc;
      }
  }
}

class Player {
  final String id;
  String name;
  int age;
  Position position;

  /// 主ポジションほどではないが無理なくこなせるポジション（0〜2個程度）。
  List<Position> secondaryPositions;

  /// 技術・メンタル・フィジカル・GKの詳細能力値（[AttributeKeys.all]の42項目、1-99）。
  Map<String, int> attributes;

  int potential;
  int fatigue;
  int morale;
  int injuryWeeks;

  /// 負傷の今の1週のうち、もう過ぎた日数(0〜6)。怪我は日数で治る
  /// (離脱「◯週」は7日×週)。7日たつごとに[injuryWeeks]が1つ減る。
  /// 負傷していなければ0。
  int injuryDays;

  /// 現在負傷している場合の負傷の種類(負傷していない場合はnull)。
  InjuryType? injuryType;

  /// 過去に負ったことのある負傷の種類ごとの回数。再負傷のリスク判定に使う。
  Map<String, int> injuryHistoryCounts;

  /// 今季のリーグ戦の警告の数(季末に0に戻る。2026-11-23 から)。何枚目で
  /// 何試合の出場停止になるかは国で違う([CardRules])。それまでは5枚で
  /// 1試合の出場停止になり0に戻す数え方で、全大会の警告を数えていた
  /// (古いセーブの値は、そのまま今季の枚数として読む)。
  int yellowCards;

  /// リーグ戦の出場停止の残り試合数(0なら出場停止でない)。リーグ戦で
  /// 消化する。退場は1試合(暴力行為は3試合)、警告の累積は国の決まり。
  int suspendedMatches;

  /// 今季の国内カップ戦(国内カップ・リーグカップ・スーパーカップ)の警告の数。
  int cupYellowCards;

  /// 国内カップ戦の出場停止の残り試合数(国内カップ戦で消化する)。
  int cupSuspendedMatches;

  /// 今季の大陸大会の警告の数。
  int continentalYellowCards;

  /// 大陸大会の出場停止の残り試合数(大陸大会で消化する)。
  int continentalSuspendedMatches;

  /// [c]の大会の今季の警告の数。
  int yellowCardsIn(CardCompetition c) => switch (c) {
        CardCompetition.league => yellowCards,
        CardCompetition.cup => cupYellowCards,
        CardCompetition.continental => continentalYellowCards,
      };

  void setYellowCardsIn(CardCompetition c, int value) {
    switch (c) {
      case CardCompetition.league:
        yellowCards = value;
      case CardCompetition.cup:
        cupYellowCards = value;
      case CardCompetition.continental:
        continentalYellowCards = value;
    }
  }

  /// [c]の大会の出場停止の残り試合数。
  int suspendedIn(CardCompetition c) => switch (c) {
        CardCompetition.league => suspendedMatches,
        CardCompetition.cup => cupSuspendedMatches,
        CardCompetition.continental => continentalSuspendedMatches,
      };

  void setSuspendedIn(CardCompetition c, int value) {
    switch (c) {
      case CardCompetition.league:
        suspendedMatches = value;
      case CardCompetition.cup:
        cupSuspendedMatches = value;
      case CardCompetition.continental:
        continentalSuspendedMatches = value;
    }
  }

  /// 季末に、全大会の警告の数を0に戻す(出場停止の残りは次の季へ持ち越す)。
  void resetSeasonYellowCards() {
    yellowCards = 0;
    cupYellowCards = 0;
    continentalYellowCards = 0;
  }

  /// 通算出場試合数・通算得点数(公式戦・カップ戦。親善試合は含まない)。
  int careerAppearances;
  int careerGoals;

  /// 週俸（万円）
  int wage;

  /// 契約の満了日の年。契約は「この年の6月30日まで」。
  ///
  /// 以前は残り年数で持ち、シーズン末に1つ減らしていた。実在の契約と同じく
  /// 満了日で持つ。7月1日に新しいシーズンへ入ったとき、満了日を過ぎた
  /// 選手は自由契約になる。
  int contractEndYear;

  /// 残り年数を数える基準の年(今のシーズンが終わる年。第1季は2027)。
  ///
  /// 選手は今日の日付を知らないので、ゲームの側がシーズンの切り替わり・
  /// 読み込み・新規開始のたびに合わせる(GameState._syncContractClock)。
  /// 保存はしない。保存するのは満了の年だけ。
  static int contractClockYear = defaultContractClockYear;

  /// 第1季(2026/27)が終わる年。
  static const int defaultContractClockYear = 2027;

  /// [season]季が終わる年(6月30日の年)。
  static int seasonEndYearOf(int season) => defaultContractClockYear + season - 1;

  /// 今のシーズンを含めた契約の残りのシーズン数。1なら今のシーズン末
  /// (6月30日)で満了する。0は満了済み(フリーエージェント)。
  int get contractYearsRemaining {
    final years = contractEndYear - contractClockYear + 1;
    return years < 0 ? 0 : years;
  }

  /// 残りのシーズン数で満了の年を決める(1なら今のシーズン末)。
  set contractYearsRemaining(int years) =>
      contractEndYear = contractClockYear + years - 1;

  /// クラブ側の1年延長オプションが付いているか。満了の年の3月31日までに
  /// 行使すると、同じ年俸で満了が1年延びる。行使しなければ消える。
  bool contractOption;

  /// 「契約を延長しない」と言い出した選手か(残り1年に入ったときに決まる)。
  /// 更新の交渉に応じない。売るか、満了でただで失うかになる。
  bool refusesRenewal;

  /// 性格。不満度の変動しやすさ・移籍希望の出やすさに影響する。
  PlayerPersonality personality;

  /// 不満度（0-100）。低いほど移籍を希望しやすくなる。
  int happiness;

  /// ローンでの加入かどうか。ローン選手は契約更新・放出の対象外で、
  /// [loanWeeksRemaining]が0になると自動的にチームを離れる。
  bool isLoan;

  /// ローン期間の残り週数（ローン選手でない場合は0）。旧セーブの持ち方で、
  /// 今は[loanEndDate]で持つ。日付の無いローン(旧セーブを読んだ直後・
  /// テストで作った選手)だけがこの週数で数える。
  int loanWeeksRemaining;

  /// ローンが終わる日(この日になったら元のクラブへ戻る)。半年なら冬の窓が
  /// 開く日、1年ならシーズン末(6月30日)。ローン選手でなければ null。
  DateTime? loanEndDate;

  /// 他のクラブから借りている選手の、元のクラブの id。ローンが終わると
  /// そのクラブへ戻る。作り物の市場から借りた旧セーブの選手は null(戻る先が無い)。
  String? loanFromClubId;

  /// 借りる前の週俸。ローン中はこちらが6割だけ負担するので下げてある。
  /// 元のクラブへ戻る・買い取るときにこの額へ戻す。
  int? loanBaseWage;

  /// ローン契約に買取オプションが付いている場合の買取金額(万円)。
  /// ローン期間中いつでもこの金額を支払えば恒久的に完全移籍へ切り替えられる。
  /// 買取オプションがない通常のローンの場合はnull。
  int? loanBuyOptionFee;

  /// ローンに買取義務が付いているか(満了すると必ず買い取る)。
  bool loanObligation;

  /// リリース条項(解放金額、万円)。設定されている場合、他クラブがこの金額を
  /// 提示すると交渉なしで自動的に移籍が成立する。未設定はnull。
  int? releaseClause;

  /// 代表召集で一時離脱している残り週数(0なら招集されていない)。
  /// 招集中はスタメン・自動編成の対象外になる。
  int internationalDutyWeeksRemaining;

  /// 夏の代表の大会(ワールドカップ・大陸選手権)のあとの休みで、まだ
  /// クラブに合流していない。合流の日まで試合に出せない。
  bool onTournamentLeave;

  /// 夏の大会の活躍で上がった市場価値(%)。次のシーズンの始まりで消える。
  int tournamentBoostPct;

  /// 戦術上のデューティ(守備的/バランス/攻撃的)。試合エンジンの攻守貢献度に補正がかかる。
  PlayerDuty duty;

  /// スカッド・ステータス(出場機会の約束)。旧セーブは「主力」扱い。
  SquadStatus squadStatus;

  /// 加入のときに約束した序列(キープレイヤーか主力のときだけ)。先発から
  /// 外し続けたり序列を下げたりすると、約束を破ったことになる。
  SquadStatus? promisedStatus;

  /// 今の週俸を、序列を条件に交渉して決めたとき(更新の交渉・移籍の条件)の
  /// 序列。契約の途中でこれより上の序列へ上げると、選手は週俸の見直しを
  /// 求める(上がる)。null は序列を条件にしていない週俸(獲得したまま・
  /// 旧セーブ)で、標準の[SquadStatus.regular]として扱う。
  SquadStatus? wageStatus;

  /// 約束した選手が、出られるのに先発から外れた節の数(続けて)。
  int promiseMisses;

  /// 約束を破られた(移籍を願い出ている)。
  bool promiseBroken;

  /// 移籍リストに登録されているか。登録中は他クラブからのオファーが来やすくなる。
  bool isTransferListed;

  /// 他クラブへローン放出中かどうかの残り週数(0なら放出されていない)。
  /// 放出中はスタメン・自動編成の対象外で、週俸は放出先クラブが負担する。
  int loanedOutWeeksRemaining;
  String? loanedOutToClubName;

  /// 他クラブへ貸している選手が戻る日。日付の無い貸し出し(旧セーブ・
  /// テストで作った選手)は[loanedOutWeeksRemaining]で数える。
  DateTime? loanedOutUntil;

  /// 貸し出しに「冬の窓で呼び戻せる」条項が付いているか。
  bool loanRecallClause;

  /// 締切の時点で登録の名簿から外れた選手か。次の窓が開くまで公式戦に
  /// 出られない(自動編成からも外す)。
  bool notRegistered;

  /// オーナーが「締切の名簿から外す」と決めた選手か。登録の枠を超えて
  /// いるときだけ効く(超えていなければ誰も外さない)。
  bool leaveOffRegistration;

  /// 移籍市場の選手が今いる国([LeagueTheme]の name)。18歳未満は国を
  /// またいで移れないので、自国以外の18歳未満は獲れない。
  String? originLeague;

  /// 国籍(LeagueTheme の name)。国をまたいで移るときに覚える。それまでは
  /// null で、GameState.nationalityOf が今いるリーグから決める。
  String? nation;

  /// 移籍市場にスカウティング候補として掲載されている選手の現所属クラブ名
  /// (表示専用。自クラブの選手・フリーエージェントにはnull)。
  String? originClubName;

  /// 出場手当(万円)。契約更新時に決定され、リーグ公式戦でスタメン出場するたびに支払われる。
  int appearanceFee;

  /// 出来高: リーグ戦で1点取るごとに払う額(万円。0なら無し)。
  int goalBonus;

  /// 段階昇給: 季が変わるたびに週給を上げる割合(%。0なら無し)。
  int raisePct;

  /// プレースタイル(ロール)。デューティとは別に、活躍する能力値の傾向を表す。
  PlayerRole role;

  /// 怪我のしやすさ(1-20)。高いほど負傷しやすい。
  ///
  /// 同じ疲労・同じ基礎体力でも、壊れやすい選手と壊れにくい選手がいる。
  /// 補強のときに見るべき情報でありながら、これまでは全員同じ扱いだった。
  int injuryProneness;

  /// 育成型レンタル(出場機会を約束させた貸出)かどうか。
  ///
  /// 約束させると成長は大きくなるが、貸出先は見返りを求めるので
  /// レンタル料が入らない。ただ出すか、育てるために出すかの違い。
  bool loanedWithPlayingTime;

  /// 個別指示。ロールの上に重ねる細かい注文。未設定なら null。
  PlayerInstruction? instruction;

  /// 本職(主ポジション)以外のポジションで起用された際の慣れ度(0-100、
  /// Position.name → 慣れ度)。出場を重ねるごとに上昇し、攻撃/守備への
  /// ペナルティを徐々に軽減する。主ポジションは常に完全適性のため含まない。
  Map<String, int> positionFamiliarity;

  /// 直近の試合勘・コンディション(0-100)。出場を重ねると上昇し、
  /// ベンチ・怪我・出場停止が続くと緩やかに低下する。負傷から復帰した
  /// 直後は大きく下がる。試合エンジンのコンディション算出に用いる。
  int matchSharpness;

  /// ユース練習試合の通算出場数(昇格候補在籍中のみ加算)。昇格後も
  /// 記録として残る。旧セーブは0。
  int youthMatchApps;

  /// ユース練習試合の通算得点数。旧セーブは0。
  int youthMatchGoals;

  /// 直近のユース練習試合の評点(10点満点)。未出場・旧セーブは0。
  double lastYouthMatchRating;

  /// 自クラブのユース出身(生え抜き)か。昇格の手続きを踏んだ選手に付く。
  /// 買ってきた選手と、育てた選手を見分けるための印。旧セーブは false。
  bool academyGraduate;

  /// 国内で育った選手か(登録の決まりの「自国育成」)。生成時に決める。
  /// 自クラブのユース出身([academyGraduate])も国内育成として数える。
  bool homegrown;

  bool get isHomegrown => homegrown || academyGraduate;

  /// 旧セーブには印が無いので、id から決まった値を出す(読み込むたびに
  /// 変わらないように、文字列の hashCode ではなく文字コードの和を使う)。
  static bool homegrownFromId(String id) =>
      id.codeUnits.fold<int>(0, (a, c) => a + c) % 5 < 3;

  /// 国籍を決める id のハッシュ(GameState の国籍の見立てと共有する)。
  static int nationalityHash(String id) =>
      id.codeUnits.fold<int>(37, (a, c) => (a * 31 + c) % 1000003);

  /// 所属クラブの国とは別の国籍になる選手か(1割)。国籍を覚えていない
  /// 選手の国籍はこれで決まるので、生成のときに国内育成の印を付けるのにも使う。
  static bool foreignNationalFromId(String id) =>
      nationalityHash(id) % 10 == 0;

  /// 背番号。ユースから一軍へ昇格したとき、または移籍で加入したときに
  /// 割り当てる。旧セーブ・ユース在籍中は null。
  int? squadNumber;

  /// ローン放出(武者修行)を開始した時点の総合力。復帰時の成長レポート
  /// に使い、復帰後は0に戻す。0はローン中でない(旧セーブ含む)ことを表す。
  int loanStartOverall;

  /// 総合力の週次スナップショット(節送りごとに末尾へ追加、古い順)。
  /// 上限はTrainingEngine.overallHistoryLimit。自クラブの選手とユース
  /// 昇格候補のみ記録され、選手詳細の成長推移グラフに使う。旧セーブは空。
  List<int> overallHistory;

  /// 選手特性(格上キラー/横綱相撲/波がある)。持たない選手も多い(null)。
  PlayerTrait? trait;

  /// 直近の試合での特性由来のパフォーマンス倍率(1.0で補正なし)。
  /// [MatchEngine]が試合開始時に算出する一時的な値で、セーブデータには
  /// 保存しない(次の試合ごとに改めて算出される)。
  double matchFormMultiplier = 1.0;

  /// 今試合で既に[matchFormMultiplier]を算出済みかどうか。前後半を通して
  /// 同じ値を使うためのフラグで、セーブデータには保存しない。前半に出場
  /// しなかった選手(後半途中出場の交代選手等)が後半開始時に初めて
  /// [MatchEngine.lineupOf]に現れた場合のみ、この試合用に改めて算出する。
  bool matchFormRolledThisMatch = false;

  /// この試合で既に警告(イエローカード)を受けているかどうか。
  /// [MatchEngine.simulateMinutes]が試合の開始時(前半の1分)にだけリセット
  /// する一時的なフラグで、セーブデータには保存しない。ハーフタイムをまたいでも
  /// 消さないので、前半に1枚・後半に1枚でも2枚目は退場(レッドカード)になる。
  /// 以前は半ごとに消していて、前後半に1枚ずつでは退場にならなかった。
  bool yellowCardedThisMatch = false;

  /// 成長タイプ(早熟/標準/大器晩成)。年齢による伸びやすさ・衰え始める
  /// 時期の傾向を左右する。
  PlayerGrowthType growthType;

  /// 直近の週次トレーニングで「才能開花」(複数属性がまとまって伸びる
  /// 特別な成長)が発生したかどうか。[TrainingEngine]が週次トレーニング
  /// のたびに設定し直す一時的なフラグで、セーブデータには保存しない。
  bool hadBreakthroughThisWeek = false;

  Player({
    required this.id,
    required this.name,
    required this.age,
    required this.position,
    required this.potential,
    List<Position>? secondaryPositions,
    Map<String, int>? attributes,
    this.fatigue = 0,
    this.morale = 75,
    this.injuryWeeks = 0,
    this.injuryDays = 0,
    this.injuryType,
    Map<String, int>? injuryHistoryCounts,
    this.yellowCards = 0,
    this.suspendedMatches = 0,
    this.cupYellowCards = 0,
    this.cupSuspendedMatches = 0,
    this.continentalYellowCards = 0,
    this.continentalSuspendedMatches = 0,
    this.careerAppearances = 0,
    this.careerGoals = 0,
    this.wage = 20,
    int? contractEndYear,
    int contractYearsRemaining = 2,
    this.contractOption = false,
    this.refusesRenewal = false,
    this.personality = PlayerPersonality.balanced,
    this.happiness = 70,
    this.isLoan = false,
    this.loanWeeksRemaining = 0,
    this.loanBuyOptionFee,
    this.loanObligation = false,
    this.releaseClause,
    this.internationalDutyWeeksRemaining = 0,
    this.onTournamentLeave = false,
    this.tournamentBoostPct = 0,
    this.duty = PlayerDuty.support,
    this.squadStatus = SquadStatus.regular,
    this.promisedStatus,
    this.wageStatus,
    this.promiseMisses = 0,
    this.promiseBroken = false,
    this.isTransferListed = false,
    this.loanedOutWeeksRemaining = 0,
    this.loanedOutToClubName,
    this.loanedOutUntil,
    this.loanRecallClause = false,
    this.notRegistered = false,
    this.leaveOffRegistration = false,
    this.originLeague,
    this.nation,
    this.loanEndDate,
    this.loanFromClubId,
    this.loanBaseWage,
    this.originClubName,
    this.appearanceFee = 0,
    this.goalBonus = 0,
    this.raisePct = 0,
    this.role = PlayerRole.standard,
    this.instruction,
    this.injuryProneness = 10,
    this.loanedWithPlayingTime = false,
    Map<String, int>? positionFamiliarity,
    this.matchSharpness = 80,
    this.youthMatchApps = 0,
    this.loanStartOverall = 0,
    List<int>? overallHistory,
    this.youthMatchGoals = 0,
    this.squadNumber,
    this.academyGraduate = false,
    this.homegrown = false,
    this.lastYouthMatchRating = 0,
    this.trait,
    this.growthType = PlayerGrowthType.balanced,
  })  : contractEndYear =
            contractEndYear ?? contractClockYear + contractYearsRemaining - 1,
        secondaryPositions = secondaryPositions ?? [],
        attributes = attributes ?? {for (final k in AttributeKeys.all) k: 50},
        positionFamiliarity = positionFamiliarity ?? {},
        injuryHistoryCounts = injuryHistoryCounts ?? {},
        overallHistory = overallHistory ?? [];

  /// このポジション（主・副とも）を無理なくこなせるか。
  bool canPlay(Position pos) =>
      position == pos || secondaryPositions.contains(pos);

  /// 指定ポジションでの慣れ度(0-100)。主ポジションは常に100。
  int familiarityFor(Position pos) =>
      pos == position ? 100 : (positionFamiliarity[pos.name] ?? 0);

  /// 本職外のポジションで出場した際、慣れ度を積み増す(上限100)。
  void growFamiliarity(Position pos, {int amount = 3}) {
    if (pos == position) return;
    final current = positionFamiliarity[pos.name] ?? 0;
    positionFamiliarity[pos.name] = (current + amount).clamp(0, 100);
  }

  /// 人柄の6つの軸(保存せず、id と性格から作る)。
  PlayerTraits get traits => PlayerTraits.of(id, personality);

  /// 不満度がこれを下回ると移籍を希望する。性格の閾値を、野心で上げ、
  /// 忠誠で下げる。
  int get transferRequestLine =>
      (personality.transferRequestThreshold + traits.transferLineShift)
          .clamp(0, 100);

  /// 移籍を希望しているか(不満度が線を下回った、または約束を破られた)。
  bool get wantsTransfer => promiseBroken || happiness < transferRequestLine;

  int attributeValue(String key) => attributes[key] ?? 50;

  /// 怪我のしやすさを3段階の語で表したもの。数値そのものは出さない。
  /// 医療の見立ては幅のあるものなので、細かい数字を装わない。
  String get injuryPronenessLabel => injuryProneness >= 14
      ? Tr.pick('高い', 'High')
      : injuryProneness <= 7
          ? Tr.pick('低い', 'Low')
          : Tr.pick('普通', 'Average');

  void setAttributeValue(String key, int value) {
    attributes[key] = value.clamp(1, 99);
  }

  int _weightedAverage(Map<String, int> weights) {
    var total = 0;
    var weightSum = 0;
    weights.forEach((key, weight) {
      total += attributeValue(key) * weight;
      weightSum += weight;
    });
    if (weightSum == 0) return 50;
    return (total / weightSum).round();
  }

  /// 攻撃力（シュート・崩し・オフザボールの複合値）。ひらめき(flair)は
  /// 意表を突く仕掛け、バランス(balance)は競り合い下でのドリブル/仕掛けの
  /// 質に寄与するため軽い重みで加える。
  int get attack => _weightedAverage({
        AttributeKeys.finishing: 3,
        AttributeKeys.longShots: 2,
        AttributeKeys.dribbling: 2,
        AttributeKeys.offTheBall: 2,
        AttributeKeys.composure: 1,
        AttributeKeys.pace: 1,
        AttributeKeys.flair: 1,
        AttributeKeys.balance: 1,
      });

  /// 守備力（対人・ポジショニングの複合値）。集中力(concentration)は
  /// 守備での注意散漫による失点を減らし、勇敢さ(bravery)は際どい競り合い・
  /// 最後の一枚での対応に寄与するため軽い重みで加える。
  int get defense => _weightedAverage({
        AttributeKeys.tackling: 3,
        AttributeKeys.marking: 3,
        AttributeKeys.positioning: 2,
        AttributeKeys.anticipation: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.aggression: 1,
        AttributeKeys.concentration: 1,
        AttributeKeys.bravery: 1,
      });

  /// 技術（パス・ボールコントロールの複合値）。連係(teamwork)は周囲との
  /// コンビネーションプレーの質に寄与するため軽い重みで加える。
  int get technique => _weightedAverage({
        AttributeKeys.passing: 3,
        AttributeKeys.firstTouch: 2,
        AttributeKeys.vision: 2,
        AttributeKeys.technique: 2,
        AttributeKeys.crossing: 1,
        AttributeKeys.decisions: 1,
        AttributeKeys.teamwork: 1,
      });

  /// スタミナ（持久力・運動量の複合値）
  int get stamina => _weightedAverage({
        AttributeKeys.stamina: 3,
        AttributeKeys.naturalFitness: 2,
        AttributeKeys.workRate: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.acceleration: 1,
      });

  /// ゴールキーピング(反応・ハイボール処理などの複合値)。GK以外にはあまり
  /// 意味を持たないが、GKの総合力・市場価値を正しく反映するために必要。
  int get goalkeeping => _weightedAverage({
        AttributeKeys.reflexes: 3,
        AttributeKeys.handling: 3,
        AttributeKeys.oneOnOnes: 2,
        AttributeKeys.aerialReach: 2,
        AttributeKeys.commandOfArea: 1,
        AttributeKeys.kicking: 1,
      });

  int get overall => position == Position.gk
      ? ((goalkeeping * 2 + defense + stamina) / 4).round()
      : ((attack + defense + technique + stamina) / 4).round();

  bool get isInjured => injuryWeeks > 0;

  /// いま行っている試合の大会([CardRules.current])で出場停止か。試合の外
  /// (画面)ではリーグ戦の出場停止。
  bool get isSuspended => suspendedIn(CardRules.current.competition) > 0;

  bool get isOnInternationalDuty =>
      internationalDutyWeeksRemaining > 0 || onTournamentLeave;

  /// 誕生日を2001年(うるう年でない年)に置いた日。月と日だけを使う。
  /// id から決まるので保存しない。2月29日生まれはいない。
  late final DateTime _birthday = _birthdayOf(id);

  static DateTime _birthdayOf(String id) {
    var h = 7;
    for (final c in id.codeUnits) {
      h = (h * 131 + c) & 0x3fffffff;
    }
    return DateTime(2001, 1, 1 + h % 365);
  }

  int get birthMonth => _birthday.month;
  int get birthDay => _birthday.day;

  /// [year]年の誕生日。
  DateTime birthdayIn(int year) => DateTime(year, birthMonth, birthDay);

  /// [before]の翌日から[after]まで(両端は前を含まず後を含む)に来た誕生日の数。
  int birthdaysBetween(DateTime before, DateTime after) {
    if (!after.isAfter(before)) return 0;
    var n = 0;
    for (var y = before.year; y <= after.year; y++) {
      final b = birthdayIn(y);
      if (b.isAfter(before) && !b.isAfter(after)) n++;
    }
    return n;
  }

  /// 他クラブへローン放出中で、自クラブの試合には出場できない状態かどうか。
  bool get isLoanedOut => loanedOutWeeksRemaining > 0;

  /// [marketValue]の算出根拠となる各内訳値。選手詳細画面で市場価値の
  /// 内訳を説明するために使う(marketValue自体もこれを使って計算する)。
  ({
    double base,
    double potentialBonus,
    double ageFactor,
    double personalityFactor,
    double leadershipFactor,
    double tournamentFactor,
  }) get marketValueBreakdown {
    // 能力に対して指数で伸びる(総合78で約5億、85で約17億、95で約100億)。
    final base = marketValueBase(overall);
    // 伸びしろ1あたり、基礎の3%を上乗せする。以前は1あたり15万円の
    // 足し算だったが、基礎が億の桁になると伸びしろが無いのと同じになる。
    final potentialBonus = base * (potential - overall).clamp(0, 40) * 0.03;
    double ageFactor;
    if (age <= 21) {
      ageFactor = 1.4;
    } else if (age <= 27) {
      ageFactor = 1.1;
    } else if (age <= 30) {
      ageFactor = 0.8;
    } else {
      ageFactor = 0.4;
    }
    // リーダーシップが高い選手は主将候補として、低い選手はロッカールームへの
    // 悪影響を懸念されてわずかに評価が振れる(±10%)。
    final leadershipFactor = 1 +
        (attributeValue(AttributeKeys.leadership) - 50).clamp(-50, 50) / 500;
    return (
      base: base.toDouble(),
      potentialBonus: potentialBonus.toDouble(),
      ageFactor: ageFactor,
      personalityFactor: personality.marketValueFactor,
      leadershipFactor: leadershipFactor,
      tournamentFactor: 1 + tournamentBoostPct / 100,
    );
  }

  /// 想定移籍金（万円）。年齢・現在能力・伸びしろから概算する。
  int get marketValue {
    final b = marketValueBreakdown;
    final value = (b.base + b.potentialBonus) *
        b.ageFactor *
        b.personalityFactor *
        b.leadershipFactor *
        b.tournamentFactor;
    return value.round().clamp(minMarketValue, maxMarketValue);
  }

  /// セーブデータへの書き出し。既定値のままの項目は書き出さない
  /// (fromJson側がすべて`?? 既定値`で読むため、省略しても復元結果は同じ)。
  /// 5部×20クラブ=100クラブ・約1800選手を保存するため、1選手あたりの
  /// 数百バイトがセーブ全体では数百KBの差になる。実測では3.22MB→大幅に
  /// 縮小し、Web版のlocalStorage(オリジンあたり5MB程度)の上限に対する
  /// 余裕が生まれる。
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'age': age,
      'position': position.name,
      // AttributeKeys.all の並び順に沿った値だけの配列で保存する(キー名を
      // 省いた分だけセーブデータを大幅に圧縮できる)。並び順は
      // AttributeKeys.all に追記する形でのみ変更し、既存項目の順序を
      // 変えてはならない(変えると旧セーブの値が別の属性にずれてしまう)。
      'attributes': [for (final k in AttributeKeys.all) attributes[k] ?? 50],
      'potential': potential,
      // 満了の年。キーが無いのは旧セーブ(残り年数で持っていた)なので、
      // 必ず書き出す。
      'contractEndYear': contractEndYear,
    };
    // 既定値と異なるときだけ書き出す。
    void put(String key, Object? value, Object? defaultValue) {
      if (value == null || value == defaultValue) return;
      if (value is Iterable && value.isEmpty) return;
      if (value is Map && value.isEmpty) return;
      json[key] = value;
    }

    put('secondaryPositions', secondaryPositions.map((p) => p.name).toList(),
        null);
    put('fatigue', fatigue, 0);
    put('morale', morale, 75);
    put('injuryWeeks', injuryWeeks, 0);
    put('injuryDays', injuryDays, 0);
    put('injuryType', injuryType?.name, null);
    put('injuryHistoryCounts', injuryHistoryCounts, null);
    put('yellowCards', yellowCards, 0);
    put('suspendedMatches', suspendedMatches, 0);
    put('cupYellowCards', cupYellowCards, 0);
    put('cupSuspendedMatches', cupSuspendedMatches, 0);
    put('continentalYellowCards', continentalYellowCards, 0);
    put('continentalSuspendedMatches', continentalSuspendedMatches, 0);
    put('careerAppearances', careerAppearances, 0);
    put('careerGoals', careerGoals, 0);
    put('wage', wage, 20);
    put('contractOption', contractOption, false);
    put('refusesRenewal', refusesRenewal, false);
    put('personality', personality.name, PlayerPersonality.balanced.name);
    put('happiness', happiness, 70);
    put('isLoan', isLoan, false);
    put('loanWeeksRemaining', loanWeeksRemaining, 0);
    put('loanBuyOptionFee', loanBuyOptionFee, null);
    put('loanObligation', loanObligation, false);
    put('releaseClause', releaseClause, null);
    put('internationalDutyWeeksRemaining', internationalDutyWeeksRemaining, 0);
    put('onTournamentLeave', onTournamentLeave, false);
    put('tournamentBoostPct', tournamentBoostPct, 0);
    put('duty', duty.name, PlayerDuty.support.name);
    put('squadStatus', squadStatus.name, SquadStatus.regular.name);
    put('promisedStatus', promisedStatus?.name, null);
    put('wageStatus', wageStatus?.name, null);
    put('promiseMisses', promiseMisses, 0);
    put('promiseBroken', promiseBroken, false);
    put('isTransferListed', isTransferListed, false);
    put('loanedOutWeeksRemaining', loanedOutWeeksRemaining, 0);
    put('loanedOutToClubName', loanedOutToClubName, null);
    put('loanedOutUntil', _dateToJson(loanedOutUntil), null);
    put('loanRecallClause', loanRecallClause, false);
    put('notRegistered', notRegistered, false);
    put('leaveOffRegistration', leaveOffRegistration, false);
    put('originLeague', originLeague, null);
    put('nation', nation, null);
    put('loanEndDate', _dateToJson(loanEndDate), null);
    put('loanFromClubId', loanFromClubId, null);
    put('loanBaseWage', loanBaseWage, null);
    put('originClubName', originClubName, null);
    put('appearanceFee', appearanceFee, 0);
    put('goalBonus', goalBonus, 0);
    put('raisePct', raisePct, 0);
    put('role', role.name, PlayerRole.standard.name);
    put('instruction', instruction?.name, null);
    put('injuryProneness', injuryProneness, 10);
    put('loanedWithPlayingTime', loanedWithPlayingTime, false);
    put('positionFamiliarity', positionFamiliarity, null);
    put('matchSharpness', matchSharpness, 80);
    put('youthMatchApps', youthMatchApps, 0);
    put('loanStartOverall', loanStartOverall, 0);
    put('overallHistory', overallHistory, null);
    put('youthMatchGoals', youthMatchGoals, 0);
    put('lastYouthMatchRating', lastYouthMatchRating, 0);
    put('squadNumber', squadNumber, null);
    put('academyGraduate', academyGraduate, false);
    json['homegrown'] = homegrown;
    put('trait', trait?.name, null);
    put('growthType', growthType.name, PlayerGrowthType.balanced.name);
    return json;
  }

  /// 日付を「2026-08-15」の形で書き出す(時刻は持たない)。
  static String? _dateToJson(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _dateFromJson(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'];
    final Map<String, int> attributes;
    if (rawAttributes is List) {
      // 新形式: AttributeKeys.all の並び順の値配列。
      attributes = {
        for (int i = 0; i < AttributeKeys.all.length; i++)
          AttributeKeys.all[i]:
              (i < rawAttributes.length ? rawAttributes[i] as int? : null) ??
                  50,
      };
    } else if (rawAttributes is Map) {
      // 旧形式: キー名付きのMap(過去のセーブとの互換性のため引き続き読める)。
      attributes = {
        for (final k in AttributeKeys.all) k: (rawAttributes[k] as int?) ?? 50,
      };
    } else {
      attributes = _migrateLegacyAttributes(json);
    }

    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      position: parsePosition(json['position'] as String),
      secondaryPositions: (json['secondaryPositions'] as List?)
              ?.map((e) => parsePosition(e as String))
              .toList() ??
          [],
      attributes: attributes,
      potential: json['potential'] as int,
      fatigue: json['fatigue'] as int? ?? 0,
      morale: json['morale'] as int? ?? 75,
      injuryWeeks: json['injuryWeeks'] as int? ?? 0,
      injuryDays: json['injuryDays'] as int? ?? 0,
      injuryType: json['injuryType'] == null
          ? null
          : enumFromName(
              InjuryType.values,
              json['injuryType'] as String?,
              InjuryType.bruise,
            ),
      injuryHistoryCounts: (json['injuryHistoryCounts'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      yellowCards: json['yellowCards'] as int? ?? 0,
      suspendedMatches: json['suspendedMatches'] as int? ?? 0,
      cupYellowCards: json['cupYellowCards'] as int? ?? 0,
      cupSuspendedMatches: json['cupSuspendedMatches'] as int? ?? 0,
      continentalYellowCards: json['continentalYellowCards'] as int? ?? 0,
      continentalSuspendedMatches:
          json['continentalSuspendedMatches'] as int? ?? 0,
      careerAppearances: json['careerAppearances'] as int? ?? 0,
      careerGoals: json['careerGoals'] as int? ?? 0,
      wage: json['wage'] as int? ?? 20,
      contractEndYear: json['contractEndYear'] as int? ??
          contractEndYearFromYears(_migrateContractYears(json)),
      contractOption: json['contractOption'] as bool? ?? false,
      refusesRenewal: json['refusesRenewal'] as bool? ?? false,
      personality: enumFromName(
        PlayerPersonality.values,
        json['personality'] as String?,
        PlayerPersonality.balanced,
      ),
      happiness: json['happiness'] as int? ?? 70,
      isLoan: json['isLoan'] as bool? ?? false,
      loanWeeksRemaining: json['loanWeeksRemaining'] as int? ?? 0,
      loanBuyOptionFee: json['loanBuyOptionFee'] as int?,
      loanObligation: json['loanObligation'] as bool? ?? false,
      releaseClause: json['releaseClause'] as int?,
      internationalDutyWeeksRemaining:
          json['internationalDutyWeeksRemaining'] as int? ?? 0,
      onTournamentLeave: json['onTournamentLeave'] as bool? ?? false,
      tournamentBoostPct: json['tournamentBoostPct'] as int? ?? 0,
      duty: enumFromName(
        PlayerDuty.values,
        json['duty'] as String?,
        PlayerDuty.support,
      ),
      // 旧セーブには「怪我のしやすさ」が無い。普通(10)として読む。
      injuryProneness: json['injuryProneness'] as int? ?? 10,
      loanedWithPlayingTime:
          json['loanedWithPlayingTime'] as bool? ?? false,
      // 旧セーブには指示が無い。null(=指示なし)のまま読む。
      instruction: json['instruction'] == null
          ? null
          : enumFromName(
              PlayerInstruction.values,
              json['instruction'] as String?,
              PlayerInstruction.getForward,
            ),
      squadStatus: enumFromName(
        SquadStatus.values,
        json['squadStatus'] as String?,
        SquadStatus.regular,
      ),
      promisedStatus: json['promisedStatus'] == null
          ? null
          : enumFromName(SquadStatus.values,
              json['promisedStatus'] as String?, SquadStatus.regular),
      wageStatus: json['wageStatus'] == null
          ? null
          : enumFromName(SquadStatus.values, json['wageStatus'] as String?,
              SquadStatus.regular),
      promiseMisses: json['promiseMisses'] as int? ?? 0,
      promiseBroken: json['promiseBroken'] as bool? ?? false,
      isTransferListed: json['isTransferListed'] as bool? ?? false,
      loanedOutWeeksRemaining: json['loanedOutWeeksRemaining'] as int? ?? 0,
      loanedOutToClubName: json['loanedOutToClubName'] as String?,
      loanedOutUntil: _dateFromJson(json['loanedOutUntil']),
      loanRecallClause: json['loanRecallClause'] as bool? ?? false,
      notRegistered: json['notRegistered'] as bool? ?? false,
      leaveOffRegistration: json['leaveOffRegistration'] as bool? ?? false,
      originLeague: json['originLeague'] as String?,
      nation: json['nation'] as String?,
      loanEndDate: _dateFromJson(json['loanEndDate']),
      loanFromClubId: json['loanFromClubId'] as String?,
      loanBaseWage: json['loanBaseWage'] as int?,
      originClubName: json['originClubName'] as String?,
      appearanceFee: json['appearanceFee'] as int? ?? 0,
      goalBonus: json['goalBonus'] as int? ?? 0,
      raisePct: json['raisePct'] as int? ?? 0,
      role: enumFromName(
        PlayerRole.values,
        json['role'] as String?,
        PlayerRole.standard,
      ),
      positionFamiliarity: (json['positionFamiliarity'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      matchSharpness: json['matchSharpness'] as int? ?? 80,
      youthMatchApps: json['youthMatchApps'] as int? ?? 0,
      loanStartOverall: json['loanStartOverall'] as int? ?? 0,
      overallHistory:
          (json['overallHistory'] as List?)?.map((e) => e as int).toList() ??
              [],
      youthMatchGoals: json['youthMatchGoals'] as int? ?? 0,
      squadNumber: json['squadNumber'] as int?,
      academyGraduate: json['academyGraduate'] as bool? ?? false,
      homegrown: json['homegrown'] as bool? ??
          Player.homegrownFromId(json['id'] as String? ?? ''),
      lastYouthMatchRating:
          (json['lastYouthMatchRating'] as num?)?.toDouble() ?? 0,
      trait: json['trait'] == null
          ? null
          : enumFromName(
              PlayerTrait.values,
              json['trait'] as String?,
              PlayerTrait.streaky,
            ),
      growthType: enumFromName(
        PlayerGrowthType.values,
        json['growthType'] as String?,
        PlayerGrowthType.balanced,
      ),
    );
  }

  /// 旧セーブ（attack/defense/technique/staminaの4値のみ）からの移行用。
  /// 該当する系統の詳細項目にそれぞれの値を割り当て、それ以外は50で埋める。
  static Map<String, int> _migrateLegacyAttributes(Map<String, dynamic> json) {
    final legacyAttack = json['attack'] as int? ?? 50;
    final legacyDefense = json['defense'] as int? ?? 50;
    final legacyTechnique = json['technique'] as int? ?? 50;
    final legacyStamina = json['stamina'] as int? ?? 50;

    final map = {for (final k in AttributeKeys.all) k: 50};
    for (final k in [
      AttributeKeys.finishing,
      AttributeKeys.longShots,
      AttributeKeys.dribbling,
      AttributeKeys.offTheBall,
    ]) {
      map[k] = legacyAttack;
    }
    for (final k in [
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.anticipation,
    ]) {
      map[k] = legacyDefense;
    }
    for (final k in [
      AttributeKeys.passing,
      AttributeKeys.firstTouch,
      AttributeKeys.vision,
      AttributeKeys.technique,
    ]) {
      map[k] = legacyTechnique;
    }
    for (final k in [
      AttributeKeys.stamina,
      AttributeKeys.naturalFitness,
      AttributeKeys.workRate,
    ]) {
      map[k] = legacyStamina;
    }
    return map;
  }

  /// 残り年数(今のシーズンを含む)を満了の年に直す。旧セーブの年数は
  /// シーズン末に1つ減らし、0で退団する持ち方だった。残り1年は「今の
  /// シーズン末(6月30日)で満了」なので、満了の年は
  /// 今のシーズンが終わる年 + 残り年数 - 1。0年(フリーエージェント)は
  /// 前のシーズン末に満了済み。
  static int contractEndYearFromYears(int years) =>
      contractClockYear + years - 1;

  /// 旧セーブ(契約を週数で管理していた版)からの移行用。新フィールドが
  /// あればそれを使い、なければ旧フィールドの週数を年数に丸めて引き継ぐ。
  static int _migrateContractYears(Map<String, dynamic> json) {
    final years = json['contractYearsRemaining'] as int?;
    if (years != null) return years;
    final legacyWeeks = json['contractWeeksRemaining'] as int?;
    if (legacyWeeks == null) return 2;
    if (legacyWeeks <= 0) return 0;
    return (legacyWeeks / 52).ceil().clamp(1, 10);
  }
}
