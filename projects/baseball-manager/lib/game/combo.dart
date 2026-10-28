import 'life.dart';

/// 行動の連携: 前のターンの行動が、次のターンの行動を強くする。
/// 同じ行動の繰り返し(特訓ばかり・練習と休養だけ)では起きず、行動を組み合わせるほど得になる。
enum Combo {
  insight('研究の成果', '研究のあと: 練習・特訓の経験点+20%'),
  drill('教えの反復', 'コーチに教わった能力を練習・特訓: 失敗が半分・経験点+10%'),
  recovery('超回復', '特訓のあと休養: 特訓した能力の経験点が入る'),
  homework('試合の課題', '練習試合のあと研究: コツが1つ多い'),
  cheer('仲間の声援', '交流のあと特訓: 失敗しにくく、やる気が下がらない');

  const Combo(this.label, this.hint);
  final String label;
  final String hint;

  /// 効き目だけの短い言い方(行動カードの1行に使う)。
  String get effect => switch (this) {
        Combo.insight => '経験点+$tComboInsight%',
        Combo.drill => '失敗が半分・経験点+$tComboDrill%',
        Combo.recovery => '特訓した能力の経験点',
        Combo.homework => 'コツ+1',
        Combo.cheer => '失敗が半分・やる気が下がらない',
      };
}

// ── バランス調整のつまみ(%)。`-DBAL_COMBO=false` で連携なし ──
const tComboOn = bool.fromEnvironment('BAL_COMBO', defaultValue: true);
const tComboInsight = int.fromEnvironment('BAL_CINS', defaultValue: 20);
const tComboDrill = int.fromEnvironment('BAL_CDRILL', defaultValue: 10);
const tComboDrillBad = int.fromEnvironment('BAL_CDBAD', defaultValue: 50);
const tComboRecovery = int.fromEnvironment('BAL_CREC', defaultValue: 6);

/// 前の行動 `prev`(重点 `prevFocus`)のあとに `next`(重点 `focus`)を選んだときの連携。なければ null。
Combo? comboOf(Plan? prev, Plan next, {Object? prevFocus, Object? focus}) {
  if (prev == null || !tComboOn) return null;
  final practice = next == Plan.train || next == Plan.special;
  return switch (prev) {
    Plan.study when practice => Combo.insight,
    Plan.lesson when practice && prevFocus == focus => Combo.drill,
    Plan.special when next == Plan.rest => Combo.recovery,
    Plan.match when next == Plan.study => Combo.homework,
    Plan.social when next == Plan.special => Combo.cheer,
    _ => null,
  };
}

/// 経験点にかかる倍率。
double comboExpMultiplier(Combo? c) => switch (c) {
      Combo.insight => 1 + tComboInsight / 100,
      Combo.drill => 1 + tComboDrill / 100,
      _ => 1.0,
    };

/// 練習の出来の「失敗」の確率にかかる倍率。
double comboBadFactor(Combo? c) => switch (c) {
      Combo.drill => tComboDrillBad / 100,
      Combo.cheer => 0.5,
      _ => 1.0,
    };

/// いま選ぶと連携になる行動と、その連携(画面の印に使う)。
Map<Plan, Combo> combosReady(Plan? prev, {Object? prevFocus, Object? focus}) => {
      for (final p in Plan.values)
        if (comboOf(prev, p, prevFocus: prevFocus, focus: focus) case final c?)
          p: c,
    };
