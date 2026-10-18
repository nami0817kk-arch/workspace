import 'career.dart';
import 'difficulty.dart';
import 'player.dart';
import 'records.dart';
import 'snapshot.dart';
import 'traits.dart';

/// 実績。一生が終わったときに調べ、何度遊んでも残る(端末ごと)。
class Achievement {
  const Achievement(this.id, this.title, this.description, this.check);
  final String id;
  final String title;
  final String description;

  /// 一生の記録(引退後の写し)から、達成したかを調べる。
  final bool Function(PlayerSnapshot s) check;
}

bool _proRecords(PlayerSnapshot s, bool Function(dynamic r) f) =>
    s.records.where((r) => r.stage == Stage.pro).any(f);

/// 連続した年で、条件を満たした最長の年数。
int _longestRun(PlayerSnapshot s, bool Function(dynamic r) f) {
  var best = 0, run = 0;
  int? last;
  for (final r in s.records.where((r) => r.stage == Stage.pro)) {
    if (f(r)) {
      run = (last != null && r.age == last + 1) ? run + 1 : 1;
      best = run > best ? run : best;
      last = r.age;
    } else {
      run = 0;
      last = null;
    }
  }
  return best;
}

final List<Achievement> achievements = [
  Achievement(
      'first-pro', 'プロの舞台へ', 'ドラフトで指名されてプロ入りする。', (s) => s.proStartAge != null),
  Achievement('comeback', '遠回りの末に', '大学か社会人を経て、プロ入りする。',
      (s) => s.route != null && s.proStartAge != null),
  Achievement(
      'amateur-champion',
      '大会を制す',
      'アマチュアの大会で優勝する。',
      (s) =>
          s.records.where((r) => r.stage != Stage.pro).any((r) => r.champion)),
  Achievement(
      'last-summer',
      '最後の夏',
      '高校3年の夏の大会で優勝する。',
      (s) => s.records.any(
          (r) => r.stage == Stage.highSchool && r.age == 18 && r.champion)),
  Achievement('league-champion', 'リーグ優勝', 'プロのリーグ優勝を経験する。',
      (s) => _proRecords(s, (r) => r.rank == 1)),
  Achievement('dynasty', '黄金時代', 'リーグ3連覇を成し遂げる。',
      (s) => _longestRun(s, (r) => r.rank == 1) >= 3),
  Achievement('title', 'タイトルホルダー', 'プロでタイトルを1つ獲得する。',
      (s) => s.records.any((r) => r.titles.isNotEmpty)),
  Achievement(
      'double-crown',
      '二冠王',
      '同じ年に、2つ以上のタイトルを獲得する。',
      (s) =>
          s.records.any((r) => r.titles.where((t) => t != 'MVP').length >= 2)),
  Achievement('mvp', 'MVP', 'MVPに選ばれる。',
      (s) => s.records.any((r) => r.titles.contains('MVP'))),
  Achievement('legend', '伝説', '称号「レジェンド」を得る。', (s) => s.endingTitle == 'レジェンド'),
  Achievement('iron-man', '鉄人', 'プロで15年以上プレーする。',
      (s) => s.records.where((r) => r.stage == Stage.pro).length >= 15),
  Achievement('veteran', '生涯現役', '40歳まで現役を続ける。',
      (s) => s.proStartAge != null && s.age >= 40),
  Achievement(
      'two-way-title',
      '二刀流の頂点',
      '二刀流で、タイトルを獲得する。',
      (s) =>
          (s.role == Role.twoWay ||
              s.events
                  .any((e) => e.kind == 'role' && e.text.contains('二刀流'))) &&
          s.records.any((r) => r.titles.isNotEmpty)),
  Achievement('married', '家庭を築く', '引退までに、恋人と結婚する。', (s) => s.married),
  Achievement('rival-winner', 'ライバルに勝ち越す', 'ライバルとの通算で、10勝以上して勝ち越す。',
      (s) => s.rivalWins >= 10 && s.rivalWins > s.rivalLosses),
  Achievement('s-rank', 'Sランク', 'いずれかの能力を90以上にする。',
      (s) => s.abilities.values.any((v) => v >= 90)),
  Achievement('traits-full', 'こだわりの個性', '特性を4つ以上そろえる。',
      (s) => s.traits.length >= maxTraits),
  Achievement('salary-oku', '億の男', '年俸が1億円を超える年を迎える。',
      (s) => s.records.any((r) => salaryOf(r) >= 10000)),
  Achievement('earnings-10', '一代で財を成す', 'プロ通算の収入が10億円を超える。',
      (s) => careerEarnings(s.records) >= 100000),
  Achievement('national-team', '日の丸を背負う', '世界大会の日本代表に選ばれる。',
      (s) => s.worldRecords.isNotEmpty),
  Achievement('world-champion', '世界一', '世界大会で優勝する。',
      (s) => s.worldRecords.any((r) => r.champion)),
  Achievement(
      'all-ages',
      '全世代の日本代表',
      'U-12・U-15・U-18・プロの世界大会すべてに、日本代表で出る。',
      (s) => const {'u12', 'u15', 'u18', 'pro'}
          .every((id) => s.worldRecords.any((r) => r.eventId == id))),
  Achievement('hard-pro', '狭き門', '「むずかしい」で、プロ入りする。',
      (s) => s.difficulty == Difficulty.hard && s.proStartAge != null),
  Achievement('hard-legend', '不屈の伝説', '「むずかしい」で、レジェンドになる。',
      (s) => s.difficulty == Difficulty.hard && s.endingTitle == 'レジェンド'),
];

/// この一生で達成した実績の id。
Set<String> earnedBy(PlayerSnapshot s) => {
      for (final a in achievements)
        if (a.check(s)) a.id,
    };
