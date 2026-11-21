// 名前（`_label` ほか）は private だが、**`this._label` には書けない**
// ——Dart は名前付き引数を `_` で始められない。
// ignore_for_file: prefer_initializing_formals

/// **キャリアを跨いで追いかけるもの。**
///
/// 称号（[Award]）は1つのキャリアの中の出来事で、どれも「多いほど良い」。
/// 殿堂の記録（[HallRecord]）も通算ゴールや通算出場で、**同じ遊び方を
/// 繰り返すほど伸びる**。つまり、2人目の選手を作る理由がどこにも無かった。
///
/// 挑戦は逆に、**違う形のキャリアでしか達成できないもの**だけを並べる。
/// 1つのクラブに留まれば優勝は遠く、渡り歩けば通算出場は伸びない。
/// 達成したかどうかは引退した選手（[Legend]）から判定するので、
/// 遊び方を先に宣言する必要はない。**やってみたら達成していた**、でいい。
library;

import '../l10n/lang.dart';
import 'competition.dart';
import 'legend.dart';

/// 挑戦1つ。
enum Challenge {
  oneClub(Say('一途', 'One club man'), Say('1つのクラブだけで300試合', '300 appearances for a single club'), Say('移籍すれば強いクラブへ行けるが、それでは終わらない記録がある。', 'A transfer would take you to a stronger club, but some records need you to stay.')),
  wanderer(Say('渡り鳥', 'Wanderer'), Say('4つの国でプレーする', 'Play in four countries'), Say('言葉も制度も違う場所へ、4回移る。', 'Four moves to places with a different language and different rules.')),
  fromBelow(
    Say('叩き上げ', 'Up through the ranks'),
    Say('最初のクラブと一緒に1部へ上がる', 'Go up to the top flight with your first club'),
    Say('強いクラブに移れば1部には立てる。そうではなく、'
        '最初に袖を通したクラブを連れて上がる。', 'Move to a strong club and you will reach the top flight. Instead, take the first shirt you wore up with you.'),
  ),
  lateBloom(Say('大器晩成', 'Late bloomer'), Say('30歳以降に総合力のピークを迎える', 'Peak after 30'), Say('若いうちに伸び切らなかった選手の道。', 'The path of a player who did not grow into it young.')),
  uncrowned(Say('無冠の名手', 'Uncrowned'), Say('タイトルを1つも獲らずに総合力80へ', 'Reach 80 overall without a single title'), Say('チームが勝てなくても、その選手が優れていたことはある。', 'A team can fail to win and the player still be a great one.')),
  marksman(Say('点取り屋', 'Goalscorer'), Say('通算200ゴール', '200 career goals'), Say('', '')),
  ironman(Say('鉄人', 'Iron man'), Say('通算600試合', '600 career appearances'), Say('怪我をせず、外されず、長く。', 'No injuries, never dropped, for a long time.')),
  worldChampion(Say('世界一', 'World champion'), Say('世界大会を制する', 'Win the world tournament'), Say('', '')),
  faceOfTheNation(Say('代表の顔', 'The face of the nation'), Say('代表60キャップ', '60 caps'), Say('', ''));

  const Challenge(Say label, Say requirement, Say note)
    : _label = label,
      _requirement = requirement,
      _note = note;

  final Say _label;

  String get label => _label.t;

  /// 何をすれば達成なのか。**判定と同じ言葉で書く。**
  final Say _requirement;

  String get requirement => _requirement.t;

  /// 補足。無ければ出さない。
  final Say _note;

  String get note => _note.t;

  /// その選手が達成しているか。
  ///
  /// **引退した記録だけで判定する。** 途中経過で判定すると、
  /// 「あと1試合」で引退した選手が達成扱いになる。
  bool clearedBy(Legend legend) => switch (this) {
    Challenge.oneClub => legend.spells.length == 1 && legend.appearances >= 300,
    // 国を持たせる前に引退した選手は空文字なので、数に入らない。
    Challenge.wanderer =>
      legend.spells
              .map((s) => s.countryId)
              .where((c) => c.isNotEmpty)
              .toSet()
              .length >=
          4,
    // 最初の区切りの部が1まで上がっていれば、そのクラブと一緒に上がった。
    Challenge.fromBelow =>
      legend.firstTier >= 2 &&
          legend.spells.isNotEmpty &&
          legend.spells.first.tier <= 1,
    Challenge.lateBloom => legend.peakAge >= 30,
    Challenge.uncrowned => legend.titles == 0 && legend.peakOverall >= 80,
    Challenge.marksman => legend.goals >= 200,
    Challenge.ironman => legend.appearances >= 600,
    Challenge.worldChampion => legend.worldCupBest == WorldCupStage.winner,
    Challenge.faceOfTheNation => legend.caps >= 60,
  };

  /// **宣言して狙ったときの、引退時の上乗せ（殿堂ポイント）。**
  ///
  /// **「普通に遊んだときの到達率」ではなく「狙ったときの到達率」で値を付ける。**
  /// 宣言するのは狙う人なので、狙っても届かないものほど重い。
  /// `test/challenge_sim.dart` が4つの遊び方（普通／動かない／遅咲き／攻めきる）
  /// で360キャリアを回し、**その中の一番良い到達率**を出す:
  ///
  /// | 挑戦 | 狙ったときの到達率 | 上乗せ |
  /// |---|---|---|
  /// | 一途 | 100%（動かない） | 8 |
  /// | 叩き上げ | 84%（動かない） | 10 |
  /// | 大器晩成 | 70%（遅咲き） | 12 |
  /// | 鉄人 | 49%（動かない） | 16 |
  /// | 渡り鳥 | 39%（遅咲き） | 18 |
  /// | 点取り屋 | 33%（動かない） | 20 |
  /// | 無冠の名手 | 17%（動かない） | 26 |
  /// | 代表の顔 | 14%（動かない） | 28 |
  /// | 世界一 | 10%（狙っても動かない） | 30 |
  ///
  /// 前の表は一度きりの仮設スクリプトで測った値で、**鉄人が 3% のつもりで
  /// 30pt のまま**だった。実際には通算出場が伸びて 24%（狙えば49%）まで
  /// 緩んでおり、一途（15pt・狙えば100%）の倍を払う一番おいしい宣言に
  /// なっていた。測り直す仕組みを残しておかないと、値は静かにずれる。
  int get declaredBonus => switch (this) {
    Challenge.oneClub => 8,
    Challenge.fromBelow => 10,
    Challenge.lateBloom => 12,
    Challenge.ironman => 16,
    Challenge.wanderer => 18,
    Challenge.marksman => 20,
    Challenge.uncrowned => 26,
    Challenge.faceOfTheNation => 28,
    Challenge.worldChampion => 30,
  };

  static Challenge? byName(String name) {
    for (final c in Challenge.values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
