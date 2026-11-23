/// 3部から抜け出せるかを測る(2026-11-23)。
///
/// **CI では回らない。** `test/` の外に置いてあるのは、これがテストではなく
/// 測定器だからで、時間が掛かる(1季あたり十数秒)。
///
///     flutter test tool/balance/promotion_balance_test.dart
///
/// 環境変数で範囲を絞れる:
///
/// - `PB_THEMES`   (既定 `england,germany,spain`)
/// - `PB_POLICIES` (既定 `none,lean,standard,invest`)
/// - `PB_SEEDS`    (既定 5。乱数は固定できないので、同じ条件を何回回すか)
/// - `PB_SEASONS`  (既定 10)
/// - `PB_OUT`      (結果を1行1件の JSON で書き足すファイル。任意)
///
/// 方針(オーナーの動き方):
///
/// - none     何もしない(出来事は1つ目の答え、提案は承認しない)
///
/// none 以外は、上の部のライセンスに要るスタジアムの段へ払えるうちに
/// 上げる(上げないと、昇格しても猶予の季の終わりに降格処分になる)。
/// 上位16人の満了が近い選手は自分で更新し、週給の10週分は使わずに残す
/// (2026-11-24。どちらも無いと、1季目の終わりに満了と給料の未払いで
/// 開幕の顔ぶれの3割前後が抜け、上位11人が上がらなかった)。
/// - lean     倹約。提案は承認し、SD に安い補強を1人だけ任せる。施設は触らない
/// - standard 標準。SD に予算の25%まで2人、施設(練習・ユース)を余裕があれば
///            上げ、スカウトとヘッドコーチを良い人に替える。スカウト網も使う
/// - invest   投資。補強45%・育成25%の配分、SD に40%まで3人、施設は早めに、
///            スタッフも良い人へ
///
/// 季ごとに、自クラブの部・順位、自クラブと各部の CPU の上位11人の平均の
/// 中央、人件費率、資金を出す。
library;

// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/club_license.dart';
import 'package:soccer_manager/models/budget_plan.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

List<String> _env(String key, String fallback) =>
    (Platform.environment[key] ?? fallback)
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

int _envInt(String key, int fallback) =>
    int.tryParse(Platform.environment[key] ?? '') ?? fallback;

/// クラブの上位11人の総合力の平均。
double _top11(Team t) {
  final xs = t.players.map((p) => p.overall).toList()
    ..sort((a, b) => b.compareTo(a));
  final top = xs.take(11).toList();
  if (top.isEmpty) return 0;
  return top.reduce((a, b) => a + b) / top.length;
}

double _median(List<double> xs) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

League? _leagueOfTier(GameState gs, int tier) {
  final s = gs.save!;
  if (s.currentDivisionTier == tier) return s.league;
  if (tier - 1 < s.otherDivisionLeagues.length) {
    return s.otherDivisionLeagues[tier - 1];
  }
  return null;
}

/// [tier] 部の CPU のクラブの上位11人の平均の中央。
double _cpuTop11Median(GameState gs, int tier) {
  final l = _leagueOfTier(gs, tier);
  if (l == null) return 0;
  return _median([
    for (final t in l.teams)
      if (t.id != gs.save!.userTeamId) _top11(t),
  ]);
}

Future<void> _approveProposals(GameState gs) async {
  for (final p in [...gs.save!.proposals]) {
    await gs.approveProposal(p.id);
  }
}

/// 手を付けずに残しておく資金(週給の10週分)。資金がマイナスになると
/// 給料の未払いで選手が契約を解除して出ていく。
int _reserve(GameState gs) => gs.weeklyWageBill * 10;

/// 使ってよい資金(手元 − 残しておく分)。
int _spendable(GameState gs) => gs.save!.budget - _reserve(gs);

/// 上位16人のうち、この季で契約が切れる31歳以下の選手の契約を更新する。
/// 監督の提案(主力だけ)を待つと、開幕の顔ぶれの半分近くが1季目の
/// 終わりに満了で抜けていた。
Future<void> _renewCore(GameState gs) async {
  final xs = [...gs.userTeam.players]
    ..sort((a, b) => b.overall.compareTo(a.overall));
  for (final p in xs.take(16)) {
    if (p.isLoan || p.age > 31 || p.contractYearsRemaining > 1) continue;
    if (_spendable(gs) <= 0) return;
    await gs.renewContract(p.id);
  }
}

Future<void> _keepBestIntake(GameState gs) async {
  final intake = [...gs.pendingYouthIntake]
    ..sort((a, b) => b.potential.compareTo(a.potential));
  for (final p in intake.take(2)) {
    await gs.keepYouthIntakePlayer(p.id);
  }
}

/// [role] を、今より水準の高い候補で週俸が払える人に替える。
Future<void> _upgradeStaff(GameState gs, StaffRole role,
    {required double budgetShare}) async {
  final cur = gs.staffFor(role);
  final curLevel = cur?.effectiveLevel ?? 0;
  final cands = gs.staffCandidatesFor(role)
    ..sort((a, b) => b.roleAbility.compareTo(a.roleAbility));
  for (final c in cands) {
    if (c.effectiveLevel <= curLevel) break;
    // 1年の週俸が使ってよい資金の [budgetShare] 以内。
    if (c.wage * 52 > _spendable(gs) * budgetShare) continue;
    if (await gs.hireStaff(c.id)) return;
  }
}

Future<void> _upgradeFacilities(GameState gs, double headroom) async {
  for (final type in [
    FacilityType.trainingGround,
    FacilityType.youthFacility
  ]) {
    final cost = gs.facilityUpgradeCostFor(type);
    if (cost <= 0) continue;
    if (_spendable(gs) > cost * headroom) await gs.upgradeFacility(type);
  }
}

/// スカウト網の候補から、即戦力(20歳以上。ユースの子は16〜19歳)を
/// 総合力の良い順に1人獲る。
/// スカウト網から獲った即戦力の人数(測定の表に出す)。
var _gemsSigned = 0;

/// 即戦力として獲った選手・ユースにいた選手の id(一軍の顔ぶれの出どころを
/// 数えるため)。
final _gemIds = <String>{};
final _youthIds = <String>{};

void _noteYouth(GameState gs) {
  for (final p in gs.save!.youthProspects) {
    _youthIds.add(p.id);
  }
  for (final p in gs.pendingYouthIntake) {
    _youthIds.add(p.id);
  }
}

Future<void> _useScoutNetwork(GameState gs, {bool refresh = false}) async {
  // スカウトを替えた直後は、顔ぶれが前のスカウトのまま。季の初めに
  // 一度だけ更新する(費用は払う)。
  if (refresh && gs.scoutLevel >= 3) await gs.refreshScoutCandidates();
  final pros = [
    for (final p in gs.scoutCandidates)
      if (p.age >= 20) p,
  ]..sort((a, b) => b.overall.compareTo(a.overall));
  for (final p in pros) {
    // 移籍金で資金を割ると、給料の未払いで選手が出ていく。相場の値で
    // 残しておく分を越えないかを見る(割引の前の値なので少し控えめ)。
    if (_spendable(gs) < p.marketValue) continue;
    if (await gs.scoutProspect(p.id)) {
      _gemsSigned++;
      _gemIds.add(p.id);
      return;
    }
  }
}

/// 上の部のライセンスに要るスタジアムの段へ、払えるなら上げておく。
/// 上げないと、昇格しても猶予の季の終わりに降格処分になる。
Future<void> _keepStadiumLicensed(GameState gs) async {
  final tier = gs.save!.currentDivisionTier;
  final need = ClubLicenseEngine.stadiumLevelFor(tier > 1 ? tier - 1 : 1);
  if (gs.licensedStadiumLevel >= need) return;
  final cost = gs.facilityUpgradeCostFor(FacilityType.stadium);
  if (cost > 0 && _spendable(gs) > cost * 1.2) {
    await gs.upgradeFacility(FacilityType.stadium);
  }
}

Future<void> _seasonStart(GameState gs, String policy) async {
  if (policy == 'none') return;
  await _keepStadiumLicensed(gs);
  await _renewCore(gs);
  final budget = _spendable(gs) < 0 ? 0 : _spendable(gs);
  switch (policy) {
    case 'lean':
      await _upgradeStaff(gs, StaffRole.sportingDirector, budgetShare: 0.05);
      await gs.updateSdBrief(
          active: true, maxFee: (budget * 0.10).round(), maxSignings: 1);
    case 'standard':
      await _upgradeStaff(gs, StaffRole.sportingDirector, budgetShare: 0.08);
      await _upgradeStaff(gs, StaffRole.headCoach, budgetShare: 0.08);
      await _upgradeStaff(gs, StaffRole.scout, budgetShare: 0.06);
      await _upgradeStaff(gs, StaffRole.youthCoach, budgetShare: 0.05);
      await _upgradeFacilities(gs, 3.0);
      await gs.updateSdBrief(
          active: true, maxFee: (budget * 0.25).round(), maxSignings: 2);
      await _useScoutNetwork(gs, refresh: true);
    case 'invest':
      await gs.setBudgetShare(BudgetCategory.signing, 45);
      await gs.setBudgetShare(BudgetCategory.youth, 25);
      await _upgradeStaff(gs, StaffRole.sportingDirector, budgetShare: 0.12);
      await _upgradeStaff(gs, StaffRole.headCoach, budgetShare: 0.12);
      await _upgradeStaff(gs, StaffRole.scout, budgetShare: 0.10);
      await _upgradeStaff(gs, StaffRole.youthCoach, budgetShare: 0.08);
      await _upgradeFacilities(gs, 1.6);
      await gs.updateSdBrief(
          active: true, maxFee: (budget * 0.40).round(), maxSignings: 3);
      await _useScoutNetwork(gs, refresh: true);
  }
  _noteYouth(gs);
  await _keepBestIntake(gs);
  await _approveProposals(gs);
}

Future<void> _playSeason(GameState gs, String policy) async {
  var guard = 0;
  var md = 0;
  while (!gs.save!.league.isSeasonComplete && guard++ < 200) {
    if (gs.saleReason != null) return;
    if (gs.pendingOwnerEvent != null) await gs.resolveOwnerEvent(0);
    if (gs.pendingBoardReviewMessage != null) await gs.dismissBoardReview();
    await gs.simulateAheadMatchdays(1);
    _noteYouth(gs);
    md++;
    if (policy != 'none' && md % 6 == 0) {
      await _approveProposals(gs);
      await _renewCore(gs);
      await _keepStadiumLicensed(gs);
      // 冬の窓の前にもう一度スカウト網を見る。
      if (md == 18 && (policy == 'standard' || policy == 'invest')) {
        await _useScoutNetwork(gs);
      }
    }
  }
}

void main() {
  defineRuns(
    themes: _env('PB_THEMES', 'england,germany,spain'),
    policies: _env('PB_POLICIES', 'none,lean,standard,invest'),
    seeds: _envInt('PB_SEEDS', 5),
    seasons: _envInt('PB_SEASONS', 10),
    out: Platform.environment['PB_OUT'],
  );
}

/// 測定を test として並べる。並べて回すときは、国と方針ごとに小さな
/// ファイルからこれを呼び、`flutter test -j N <フォルダ>` で回す。
void defineRuns({
  required List<String> themes,
  required List<String> policies,
  required int seeds,
  required int seasons,
  String? out,
  int seedOffset = 0,
}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.japanese;
  });

  for (final themeName in themes) {
    final theme = LeagueTheme.values.byName(themeName);
    for (final policy in policies) {
      for (var seed = seedOffset; seed < seedOffset + seeds; seed++) {
        test('測定: $themeName / $policy / #$seed', () async {
          _gemsSigned = 0;
          _gemIds.clear();
          _youthIds.clear();
          final gs = GameState();
          await gs.startNewGame('測定FC', theme: theme);
          final initialIds = {for (final p in gs.userTeam.players) p.id};
          var prevIds = {...initialIds};
          final names = {for (final p in gs.userTeam.players) p.id: p.name};
          final rows = <Map<String, Object?>>[];
          int? reached2;
          int? reached1;
          for (var s = 1; s <= seasons; s++) {
            await _seasonStart(gs, policy);
            await _playSeason(gs, policy);
            final save = gs.save!;
            final tier = save.currentDivisionTier;
            final rank = save.league.sortedStandings
                    .indexWhere((r) => r.teamId == save.userTeamId) +
                1;
            final ledger = gs.currentLedger;
            final row = <String, Object?>{
              'theme': themeName,
              'policy': policy,
              'seed': seed,
              'season': s,
              'tier': tier,
              'rank': rank,
              'user11': double.parse(_top11(gs.userTeam).toStringAsFixed(1)),
              'cpu3': double.parse(_cpuTop11Median(gs, 3).toStringAsFixed(1)),
              'cpu2': double.parse(_cpuTop11Median(gs, 2).toStringAsFixed(1)),
              'cpu1': double.parse(_cpuTop11Median(gs, 1).toStringAsFixed(1)),
              'wageRatio': (ledger.wageRatio * 100).round(),
              'budget': save.budget,
              'scout': gs.scoutLevel,
              'gems': _gemsSigned,
            };
            // 一軍の顔ぶれの出どころ(上位11人と、この季に入った人)。
            String src(String id) => initialIds.contains(id)
                ? 'init'
                : _gemIds.contains(id)
                    ? 'gem'
                    : _youthIds.contains(id)
                        ? 'youth'
                        : 'buy';
            final top = [...gs.userTeam.players]
              ..sort((a, b) => b.overall.compareTo(a.overall));
            final top11 = top.take(11).toList();
            for (final k in ['init', 'gem', 'youth', 'buy']) {
              row['top11_$k'] = top11.where((p) => src(p.id) == k).length;
            }
            final nowIds = {for (final p in gs.userTeam.players) p.id};
            final arrivals = [
              for (final p in gs.userTeam.players)
                if (!prevIds.contains(p.id)) p,
            ];
            for (final k in ['gem', 'youth', 'buy']) {
              final xs = arrivals.where((p) => src(p.id) == k).toList();
              row['in_$k'] = xs.length;
              row['in_${k}_ovr'] = xs.isEmpty
                  ? null
                  : (xs.map((p) => p.overall).reduce((a, b) => a + b) /
                          xs.length)
                      .round();
            }
            final goneIds = prevIds.difference(nowIds);
            row['out'] = goneIds.length;
            // 抜けた選手の訳(ニュースのうち、その選手の名前が出るもの)。
            row['out_why'] = [
              for (final id in goneIds)
                [
                  for (final n in save.newsLog.take(400))
                    if (n.text.contains(names[id] ?? '<不明>')) n.text,
                ].take(1).join(),
            ];
            row['squad'] = gs.userTeam.players.length;
            // SD があきらめた理由・獲った件数(ニュースから)。
            final recent = [
              for (final n in save.newsLog)
                if (n.season == save.league.season && n.context == 'SD') n,
            ];
            row['sd_signed'] =
                recent.where((n) => n.text.contains('の獲得をまとめた')).length;
            row['sd_gaveup'] = recent
                .where((n) =>
                    n.text.contains('の獲得をあきらめた') ||
                    n.text.contains('上限を超えるので降りた'))
                .length;
            row['sd_why'] = [
              for (final n in recent)
                if (n.text.contains('あきらめた') || n.text.contains('降りた')) n.text,
            ];
            row['sd_moves'] =
                recent.where((n) => n.text.contains('に動いた(')).length;
            prevIds = nowIds;
            for (final p in gs.userTeam.players) {
              names[p.id] = p.name;
            }
            rows.add(row);
            if (gs.saleReason != null) {
              row['sale'] = gs.saleReason.toString();
              break;
            }
            await gs.startNextSeason();
            final newTier = gs.save!.currentDivisionTier;
            if (newTier <= 2) reached2 ??= s;
            if (newTier <= 1) reached1 ??= s;
          }
          final summary = <String, Object?>{
            'summary': true,
            'theme': themeName,
            'policy': policy,
            'seed': seed,
            'reached2': reached2,
            'reached1': reached1,
          };
          print('=== $themeName / $policy / #$seed  '
              '2部へ ${reached2 ?? '-'}季  1部へ ${reached1 ?? '-'}季');
          print('季 部 順位 自11 CPU3部 CPU2部 CPU1部 人件費率 資金');
          for (final r in rows) {
            print('${r['season']} ${r['tier']} ${r['rank']} ${r['user11']} '
                '${r['cpu3']} ${r['cpu2']} ${r['cpu1']} ${r['wageRatio']}% '
                '${r['budget']}${r['sale'] == null ? '' : ' 売却:${r['sale']}'}');
          }
          if (out != null) {
            final f = File(out);
            final buf = StringBuffer();
            for (final r in rows) {
              buf.writeln(jsonEncode(r));
            }
            buf.writeln(jsonEncode(summary));
            f.writeAsStringSync(buf.toString(), mode: FileMode.append);
          }
        }, timeout: const Timeout(Duration(minutes: 60)));
      }
    }
  }
}
