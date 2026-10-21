import 'career.dart';
import 'difficulty.dart';
import 'marks.dart';
import 'player.dart';
import 'records.dart';
import 'snapshot.dart';
import 'talent.dart';
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
  Achievement('rookie', '新人王', '新人王に選ばれる。',
      (s) => s.records.any((r) => r.awards.contains('新人王'))),
  Achievement('best-nine', 'ベストナイン', 'ベストナインに選ばれる。',
      (s) => s.records.any((r) => r.awards.contains('ベストナイン'))),
  Achievement('golden-glove', '守備の名手', 'ゴールデングラブ賞を受ける。',
      (s) => s.records.any((r) => r.awards.contains('ゴールデングラブ'))),
  Achievement('comeback-award', '不死鳥', '大怪我のあと、カムバック賞を受ける。',
      (s) => s.records.any((r) => r.awards.contains('カムバック賞'))),
  Achievement('free-agent', 'FA宣言', 'FA権を使って、別のチームに移籍する。',
      (s) => s.events.any((e) => e.text.contains('FAで'))),
  Achievement('japan-series', '日本一', '日本シリーズを制して、日本一になる。',
      (s) => s.records.any((r) => r.awards.contains('日本一'))),
  Achievement(
      'hall-of-fame',
      '殿堂入り',
      '引退後の殿堂入り投票で、75%以上の票を集める。',
      (s) => inHallOfFame(hallOfFameVote(
          records: s.records,
          title: s.endingTitle ?? '',
          madePro: s.proStartAge != null))),
  Achievement('month-mvp-3', '月の主役', '月間MVPに3回選ばれる。',
      (s) => s.events.where((e) => e.text.contains('の月間MVP')).length >= 3),
  Achievement('all-star-5', '夢の球宴', 'オールスターに5回選ばれる。',
      (s) => s.events.where((e) => e.text.contains('オールスターに選出')).length >= 5),
  Achievement(
      'triple-awards',
      '栄誉の三冠',
      '新人王・ベストナイン・ゴールデングラブをすべて受ける。',
      (s) => const {'新人王', 'ベストナイン', 'ゴールデングラブ'}
          .every((a) => s.records.any((r) => r.awards.contains(a)))),
  Achievement('japan-series-3', '常勝軍団', '日本一を3回経験する。',
      (s) => s.records.where((r) => r.awards.contains('日本一')).length >= 3),
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
  Achievement('rare-trait', '選ばれし者', 'レア特性を持って引退する(生まれつき、または覚醒)。',
      (s) => s.traits.any((t) => t.rare)),
  Achievement('awakening', '眠れる才能', '節目の「覚醒」で、特性に目覚める。', (s) => s.awakened),
  Achievement('gifted', '才能の塊', '使う能力の天賦の平均が+0.8以上(才能に恵まれて生まれる)。',
      (s) => giftAverage(s.role, s.gifts) >= 0.8),
  Achievement('triple-crown', '三冠王', '打率・本塁打・打点の三冠王に輝く。',
      (s) => s.records.any((r) => r.awards.contains('三冠王'))),
  Achievement('pitch-triple-crown', '投手三冠', '防御率・勝利・奪三振の投手三冠に輝く。',
      (s) => s.records.any((r) => r.awards.contains('投手三冠'))),
  Achievement('ace-award', 'エース賞', '先発投手の最高の栄誉「エース賞」を受ける。',
      (s) => s.records.any((r) => r.awards.contains('エース賞'))),
  Achievement('triple-three', 'トリプルスリー', '打率.300・30本塁打・30盗塁を同じ年に達成する。',
      (s) => s.records.any((r) => r.awards.contains('トリプルスリー'))),
  Achievement('series-mvp', 'シリーズの顔', '日本一の年に、シリーズMVPに選ばれる。',
      (s) => s.records.any((r) => r.awards.contains('シリーズMVP'))),
  Achievement('amateur-mvp', '大会の主役', 'アマの大会で「大会最優秀選手」に選ばれる。',
      (s) => s.records.any((r) => r.awards.contains('大会最優秀選手'))),
  Achievement(
      'tryout-comeback',
      'もう一度、舞台へ',
      'トライアウトで契約を勝ち取り、現役を続ける。',
      (s) => s.events
          .any((e) => e.text.contains('トライアウトで') && e.text.contains('契約'))),
  Achievement('title-streak', '連続王者', 'プロで5年連続でタイトルを獲得する。',
      (s) => longestTitleStreak(s.records) >= 5),
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
  Achievement('overseas', '海を渡る', 'アメリカのリーグでプレーする。',
      (s) => s.records.any((r) => r.overseas)),
  Achievement('overseas-champion', 'アメリカの頂点', 'アメリカのリーグで優勝する。',
      (s) => s.records.any((r) => r.overseas && r.rank == 1)),
  Achievement(
      'heir', '二世の誕生', '殿堂の選手の子(二世)として、一生を送る。', (s) => s.parentName != null),
  Achievement('heir-legend', '親を超える', '二世で、レジェンドになる。',
      (s) => s.parentName != null && s.endingTitle == 'レジェンド'),
  Achievement('rich', '資産家', '資産が10億円を超えて引退する。', (s) => s.money >= 100000),
  Achievement('full-support', '万全の体制', '3つの投資をすべて最大(Lv3)にする。',
      (s) => s.investTotal >= 9),
  Achievement('superstar', '国民的スター', '人気が90以上(Sランク)になる。',
      (s) => popularityOf(s.records, s.worldRecords) >= 90),
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
