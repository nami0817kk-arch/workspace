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

import 'competition.dart';
import 'legend.dart';

/// 挑戦1つ。
enum Challenge {
  oneClub('一途', '1つのクラブだけで300試合', '移籍すれば強いクラブへ行けるが、それでは終わらない記録がある。'),
  wanderer('渡り鳥', '4つの国でプレーする', '言葉も制度も違う場所へ、4回移る。'),
  fromBelow(
    '叩き上げ',
    '最初のクラブと一緒に1部へ上がる',
    '強いクラブに移れば1部には立てる。そうではなく、'
        '最初に袖を通したクラブを連れて上がる。',
  ),
  lateBloom('大器晩成', '30歳以降に総合力のピークを迎える', '若いうちに伸び切らなかった選手の道。'),
  uncrowned('無冠の名手', 'タイトルを1つも獲らずに総合力80へ', 'チームが勝てなくても、その選手が優れていたことはある。'),
  marksman('点取り屋', '通算200ゴール', ''),
  ironman('鉄人', '通算600試合', '怪我をせず、外されず、長く。'),
  worldChampion('世界一', '世界大会を制する', ''),
  faceOfTheNation('代表の顔', '代表60キャップ', '');

  const Challenge(this.label, this.requirement, this.note);

  final String label;

  /// 何をすれば達成なのか。**判定と同じ言葉で書く。**
  final String requirement;

  /// 補足。無ければ出さない。
  final String note;

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
