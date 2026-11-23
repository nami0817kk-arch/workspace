// ignore_for_file: non_constant_identifier_names, constant_identifier_names
part of 'game.dart';

/// 実績（節目）の定義。名前と説明は日本語で持ち、見せるときに今の言語にする
class AchDef {
  final String id, nJa, dJa;
  const AchDef(this.id, this.nJa, this.dJa);
  String get n => de(nJa);
  String get d => de(dJa);
}

/// 実績の一覧（図鑑の「実績」に、この順で並ぶ）
const List<AchDef> ACHS = [
  AchDef('first_biz', '初めての事業', '最初の事業を始める'),
  AchDef('partner', '初めての相棒', '株を渡して相棒を口説く'),
  AchDef('staff5', '5人の部下', '部下を5人かかえる'),
  AchDef('biz5', '5つの事業', '事業を同時に5つ持つ'),
  AchDef('ind20', '20の業種', '20の業種を手がける'),
  AchDef('syn1', '初めてのシナジー', 'シナジーを1つ見つける'),
  AchDef('syn10', 'シナジー10個', 'シナジーを10個見つける'),
  AchDef('bigsyn', '大シナジー完成','大シナジーを1つ完成させる'),
  AchDef('ipo', '上場', '株式を上場する'),
  AchDef('abroad1', '初めての海外', '事業を海外に出す'),
  AchDef('abroad10', '海外10か国', '海外の10か国に事業を出す'),
  AchDef('sub1', '初めての子会社', '他社の株を50%超握るか、事業を分社する'),
  AchDef('holding', '持株会社', '持株会社になる'),
  AchDef('cap1t', '時価総額1兆円', '時価総額が1兆円に届く'),
  AchDef('cap100t', '時価総額100兆円', '時価総額が100兆円に届く'),
  AchDef('rank100', '世界100位', '世界の企業ランキングで100位以内に入る'),
  AchDef('rank10', '世界10位', '世界の企業ランキングで10位以内に入る'),
  AchDef('rank1', '世界1位', '世界の企業ランキングで1位になる'),
  AchDef('rival_buy', '宿敵を買収', '宿敵の会社を子会社にするか、合併する'),
  AchDef('resell', '売って再起業', '会社を丸ごと売って、もう一度起業する'),
  AchDef('rebirth', '倒産から再起', '倒産したあと、ゼロからやり直す'),
  AchDef('years50', '50年', '創業から50年遊ぶ'),
  AchDef('gen3', '3代目', '社長が3代続く'),
];

final Map<String, AchDef> achm = {for (final a in ACHS) a.id: a};

/// 実績と、手がけたことのある業種の記録（1.0.0+15 から）。
/// 見るだけの記録で、仕組みの数字には使わない。乱数も使わない。[Game.extras] を切ると何もしない
extension GameAchieve on Game {
  /// 今の状態で条件を満たしている実績の id
  Set<String> achMet() {
    bool hist(bool Function(Chron) f) => history.any(f);
    final abroad = <String>{for (final b in biz) ...ctryOf(b)}..remove(home);
    final rivalBought = cos.any((c) => c.rival != null && c.alive && c.parent == 'player') ||
        hist((e) => (e.k == 'buy' || e.k == 'swap' || e.k == 'merge') && msgKey(e.m).contains('（宿敵）'));
    return {
      if (everBiz || biz.isNotEmpty) 'first_biz',
      if (partners().isNotEmpty || hist((e) => e.k == 'partner')) 'partner',
      if (staff.length >= 5) 'staff5',
      if (biz.length >= 5) 'biz5',
      if (everInd.length >= 20) 'ind20',
      if (found.isNotEmpty) 'syn1',
      if (found.length >= 10) 'syn10',
      if (big.isNotEmpty) 'bigsyn',
      if (listed || hist((e) => e.k == 'ipo' && msgKey(e.m).startsWith('株式を上場した'))) 'ipo',
      if (abroad.isNotEmpty || hist((e) => e.k == 'abroad')) 'abroad1',
      if (abroad.length >= 10) 'abroad10',
      if (subs().isNotEmpty || hist((e) => e.k == 'buy' || e.k == 'local')) 'sub1',
      if (holding) 'holding',
      if (math.max(maxCap, cap) >= 1e12) 'cap1t',
      if (math.max(maxCap, cap) >= 1e14) 'cap100t',
      if (peakRank <= 100) 'rank100',
      if (peakRank <= 10) 'rank10',
      if (peakRank <= 1) 'rank1',
      if (rivalBought) 'rival_buy',
      if (serial > 0 || hist((e) => e.k == 'sold')) 'resell',
      if (hist((e) => e.k == 'rebirth')) 'rebirth',
      if (year - startYear >= 50) 'years50',
      if (gen >= 3) 'gen3',
    };
  }

  /// 今持っている事業（子会社の分も）を、手がけたことのある業種に足す
  void noteInds() {
    if (!extras) return;
    for (final b in biz) {
      everInd.add(b.ind);
    }
    for (final c in subs()) {
      for (final b in c.biz) {
        everInd.add(b.ind);
      }
    }
  }

  /// 新しく満たした実績を記録して返す（一覧の順）。[silent] は古いセーブを読んだとき：年月なし（0）で達成済みにする
  List<AchDef> achCheck({bool silent = false}) {
    if (!extras) return const [];
    noteInds();
    final met = achMet();
    final out = <AchDef>[];
    for (final a in ACHS) {
      if (ach.containsKey(a.id) || !met.contains(a.id)) continue;
      ach[a.id] = silent ? 0 : year * 100 + q;
      out.add(a);
    }
    return out;
  }

  /// 実績を達成した年と月（まだなら null。古いセーブから分かった分は (0, 0)）
  (int, int)? achWhen(String id) {
    final v = ach[id];
    return v == null ? null : (v ~/ 100, v % 100);
  }

  /// その業種を手がけたことがあるか（今持っているものも含む）
  bool handled(String ind) => everInd.contains(ind) || biz.any((b) => b.ind == ind);
}
