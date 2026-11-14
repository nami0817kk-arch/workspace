import 'dart:math' as math;

import 'difficulty.dart';
import 'draft.dart';
import 'gm_people.dart';
import 'inbox.dart';
import 'league.dart';
import 'names.dart';
import 'personality.dart';
import 'player.dart';
import 'rating.dart';
import 'records.dart';
import 'skills.dart';
import 'rng.dart';
import 'trade.dart';

/// 自動で遊ぶGM・点検が1回に進める年数。ゲームの任期に上限は無い(解任か、自分で終えるまで続く)。
const careerSeasons = 10;

/// 任されたときのチームの状態(強さの順位から決まる。0始まり)。
enum Outlook {
  contender('優勝候補', '主力がそろい、すぐに優勝を狙える。オーナーの期待も高い。'),
  playoff('プレーオフ圏', 'プレーオフには届く力。あと一押しで上を狙える。'),
  bubble('瀬戸際', 'プレーオフに届くかどうか。補強しだいで上にも下にも行く。'),
  rebuild('立て直し', '下位のチーム。若手を育て、指名権を集めて先を見る。オーナーは気長に待ってくれる。');

  const Outlook(this.label, this.text);
  final String label;
  final String text;

  static Outlook of(int rank) => rank < 6
      ? Outlook.contender
      : rank < 14
          ? Outlook.playoff
          : rank < 22
              ? Outlook.bubble
              : Outlook.rebuild;
}

/// 入場料の段階(ドル)。
const ticketPrices = [70, 100, 140, 180];
const ticketLabels = ['安い', 'ふつう', '高い', 'とても高い'];

/// 会場の席の数。
const arenaSeats = 19000;

/// 1シーズンの放映料など、勝ち負けによらない収入(10万ドル)。
final baseIncome = capScaled(900);

/// 売店の値段の段階(ドル)。
const concessionPrices = [12, 18, 26];
const concessionLabels = ['安い', 'ふつう', '高い'];

/// 収入の種類。
enum Income {
  tv('放映料'),
  gate('入場料'),
  concession('売店'),
  merch('グッズ'),
  sponsor('スポンサー'),
  playoffs('プレーオフ'),
  cup('カップ戦');

  const Income(this.label);
  final String label;
}

/// オーナーの性格。続けて気に入られると、信頼に上乗せが付く(嫌われて減ることはない)。
enum OwnerType {
  winNow('勝利一筋', '勝つことだけを見る。優勝を争える年は信頼が大きく上がる。お金にはおおらか'),
  steady('堅実', '収支とぜいたく税を見る。黒字で税を払わない年は信頼が上がる'),
  youth('育成好き', '若手を育てるのを好む。毎年「25歳以下を先発に2人」を目標にし、果たすと信頼が大きく上がる'),
  popular('人気重視', '人気の上がり下がりを見る。人気が上がった年は信頼が上がる');

  const OwnerType(this.label, this.text);
  final String label;
  final String text;
}

/// 予算の段階(年俸の合計の目安)。低く約束して守るほど、オーナーに気に入られる。
const budgetLabels = ['上限まで', 'ぜいたく税の手前まで', '第2の壁まで'];

/// オーナーの目標の種類。
enum GoalKind {
  wins('勝ち数'),
  profit('収支を黒字にする'),
  playoffs('プレーオフに出る'),
  youth('25歳以下を先発に2人'),
  noTax('ぜいたく税を払わない');

  const GoalKind(this.label);
  final String label;
}

/// オーナーの目標1つ。[met] はシーズンの終わりに決まる。
class OwnerGoal {
  OwnerGoal(this.kind, {this.met});
  final GoalKind kind;
  bool? met;

  Map<String, dynamic> toJson() => {'k': kind.index, if (met != null) 'm': met};
  static OwnerGoal fromJson(Map<String, dynamic> j) =>
      OwnerGoal(GoalKind.values[(j['k'] as int).clamp(0, GoalKind.values.length - 1)], met: j['m'] as bool?);
}

/// 目標を1つ果たすと増え、外すと減る信頼。
const goalTrust = 6;

/// はじめのオーナーの信頼。
const startTrust = 50;

/// 進み具合。
enum Phase {
  /// シーズン前。トレードと補強ができる。
  preseason,

  /// シーズン中(20〜21試合ずつ4区切り)。
  season,

  /// レギュラーシーズンを終えた。次はプレーオフ。
  playoffs,

  /// シーズンを終えた(結果とオーナーの評価)。
  seasonEnd,

  /// オフ: 成長と引退の知らせを見たあと、ドラフト。
  draft,

  /// オフ: 契約切れの選手との再契約と、自由契約の選手との契約。
  contracts,

  /// 任期が終わった(10年を終えた・解任された)。
  over,
}

/// 1シーズンの記録。
class SeasonRecord {
  SeasonRecord({required this.season, required this.wins, required this.losses, required this.rank, required this.result, required this.trustAfter, required this.target});

  final int season;
  final int wins;
  final int losses;
  final int rank;

  /// 0: プレーオフに出られず、1: 1回戦で敗退、2: 2回戦で敗退、3: 地区決勝で敗退、4: ファイナルで敗退、5: 優勝。
  final int result;
  final int trustAfter;
  final int target;

  bool get champion => result == 5;

  String get resultLabel => resultLabels[result.clamp(0, 5)];

  Map<String, dynamic> toJson() => {'s': season, 'w': wins, 'l': losses, 'r': rank, 'x': result, 't': trustAfter, 'g': target};

  static SeasonRecord fromJson(Map<String, dynamic> j) => SeasonRecord(
        season: j['s'] as int,
        wins: j['w'] as int,
        losses: j['l'] as int,
        rank: j['r'] as int,
        result: j['x'] as int,
        trustAfter: j['t'] as int,
        target: (j['g'] as int?) ?? 0,
      );
}

const resultLabels = ['プレーオフ届かず', '1回戦で敗退', '2回戦で敗退', '地区決勝で敗退', 'ファイナルで敗退', '優勝'];

/// プレーオフの結果ごとに増えるオーナーの信頼。
const resultTrust = [0, 4, 8, 13, 19, 28];

/// シーズンの表彰。
enum AwardKind {
  mvp('MVP'),
  roy('新人王'),
  dpoy('最優秀守備選手'),
  // ここから下は後から足した(保存は番号なので、足すときは後ろに)
  sixth('シックスマン賞'),
  mip('躍進賞'),
  finalsMvp('ファイナルMVP'),
  allLeague1('オールリーグ1st'),
  allLeague2('オールリーグ2nd'),
  allLeague3('オールリーグ3rd'),
  month('月間MVP');

  const AwardKind(this.label);
  final String label;

  bool get allLeague => this == allLeague1 || this == allLeague2 || this == allLeague3;
}

/// 殿堂に入った選手。
class HallEntry {
  const HallEntry({required this.name, required this.pos, required this.season, required this.team, required this.seasons, required this.line, required this.honors});
  final String name;
  final Pos pos;

  /// 殿堂に入った年(引退した年)。
  final int season;

  /// 最後にいたチーム(-1 は自由契約のまま引退)。
  final int team;

  /// このリーグで出たシーズンの数。
  final int seasons;

  /// 通算の成績(「21.3点 7.0リ 4.1ア」)。
  final String line;

  /// 主な実績(「MVP 2回・オールスター 5回」)。
  final String honors;

  Map<String, dynamic> toJson() => {'n': name, 'p': pos.index, 's': season, 't': team, 'y': seasons, 'l': line, 'h': honors};
  static HallEntry fromJson(Map<String, dynamic> j) => HallEntry(
        name: j['n'] as String,
        pos: Pos.values[((j['p'] as int?) ?? 0).clamp(0, Pos.values.length - 1)],
        season: j['s'] as int,
        team: ((j['t'] as int?) ?? -1).clamp(-1, teamDefs.length - 1),
        seasons: (j['y'] as int?) ?? 0,
        line: (j['l'] as String?) ?? '',
        honors: (j['h'] as String?) ?? '',
      );
}

/// 練習の強さ(軽め・ふつう・きつい)と、その効き目。
const trainingLabels = ['軽め', 'ふつう', 'きつい'];
const trainingNotes = [
  'けがが少なく、気持ちが少し上がる。30歳を過ぎた選手が落ちにくい',
  '',
  '25歳以下が伸びやすい。けがが増え、気持ちが少し下がる',
];

/// オフの成長の記録(自分のチームの1人分)。
class GrowthLine {
  const GrowthLine({required this.name, required this.age, required this.before, required this.after, this.focus, this.parts = const []});
  final String name;

  /// 伸びの内訳(年齢・育成・練習・出場時間・性格。力のもとの数字で)。
  final List<(String, int)> parts;

  /// 1つ年を取ったあとの年齢。
  final int age;
  final int before;
  final int after;
  final Attr? focus;

  int get delta => after - before;

  Map<String, dynamic> toJson() => {
        'n': name,
        'a': age,
        'b': before,
        'f': after,
        if (focus != null) 'fo': focus!.index,
        if (parts.isNotEmpty) 'pt': [for (final (l, v) in parts) [l, v]],
      };
  static GrowthLine fromJson(Map<String, dynamic> j) => GrowthLine(
        name: j['n'] as String,
        age: j['a'] as int,
        before: j['b'] as int,
        after: j['f'] as int,
        focus: j['fo'] is int && (j['fo'] as int) >= 0 && (j['fo'] as int) < Attr.values.length ? Attr.values[j['fo'] as int] : null,
        parts: [
          if (j['pt'] is List)
            for (final x in j['pt'] as List)
              if (x is List && x.length == 2 && x[0] is String && x[1] is int) (x[0] as String, x[1] as int),
        ],
      );
}

/// 殿堂に入る点の基準([Career.hallScore] がこれ以上)。
const hallThreshold = 10;

class Award {
  const Award({required this.season, required this.kind, required this.player, required this.name, required this.team, required this.line, this.block = 0});
  final int season;
  final AwardKind kind;
  final int player;
  final String name;
  final int team;

  /// 受けたときの成績(「27.1点 8.0リ 6.2ア」)。
  final String line;

  /// 月間MVP の、何区切り目か(1〜4。ほかの表彰は0)。
  final int block;

  Map<String, dynamic> toJson() => {'s': season, 'k': kind.index, 'p': player, 'n': name, 't': team, 'l': line, if (block != 0) 'b': block};
  static Award fromJson(Map<String, dynamic> j) => Award(
        season: j['s'] as int,
        kind: AwardKind.values[(j['k'] as int).clamp(0, AwardKind.values.length - 1)],
        player: j['p'] as int,
        name: j['n'] as String,
        team: j['t'] as int,
        line: (j['l'] as String?) ?? '',
        block: (j['b'] as int?) ?? 0,
      );
}

/// オフの自由契約の日数。大物(最低年俸より高く求める選手)は、この日数のあいだに申し込みを比べて決める。
const faDays = 10;

/// 日ごとの、大物が決める見込み(最後の日は必ず決める)。
const faDecideChance = [0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.65, 0.8, 1.0];

/// 自由契約の選手への申し込み。
/// 選手を放すときの年俸の残し方。
enum ReleaseMode {
  full('全額を払う', '残りの年俸を全部、契約どおりの年に払う'),
  stretch('ストレッチ', '残りの年俸を、残り年数の2倍＋1年に均して払う。今季の負担は軽いが、長く残る'),
  buyout('バイアウト', '選手が残りの年俸の3割を諦める。払いは契約どおりの年に、3割少ない');

  const ReleaseMode(this.label, this.text);
  final String label;
  final String text;
}

/// バード権の段階。
enum Bird {
  none('バード権なし'),
  early('アーリーバード権'),
  full('フルバード権');

  const Bird(this.label);
  final String label;
}

/// 上限を超えて自由契約の選手を取るのに使う例外枠。
enum CapException {
  mle('中くらいの例外枠', mleSalary, 3),
  taxMle('課税者の中くらいの例外枠', taxMleSalary, 2),
  biennial('2年ごとの例外枠', biennialSalary, 2);

  const CapException(this.label, this.limit, this.maxYears);
  final String label;
  final int limit;
  final int maxYears;
}

/// オフの自由契約で決まった1件([day] は何日目か。[faDays] ならオフの終わりにまとめて決まった分)。
class FaMove {
  const FaMove(this.id, this.name, this.ovr, this.team, this.salary, this.years, this.day);
  final int id;
  final String name;
  final int ovr, team, salary, years, day;

  List<Object> toJson() => [id, name, ovr, team, salary, years, day];
  static FaMove fromJson(List<dynamic> j) =>
      FaMove(j[0] as int, j[1] as String, j[2] as int, j[3] as int, j[4] as int, j[5] as int, j[6] as int);
}

class FaBid {
  const FaBid(this.team, this.salary, this.years);
  final int team;
  final int salary;
  final int years;

  List<int> toJson() => [team, salary, years];
}

/// 契約切れの選手が求める条件。
class Ask {
  const Ask(this.salary, this.maxYears);
  final int salary;
  final int maxYears;
}

/// GMの任期1回分。仕組みはすべてここにあり、画面はこれを呼ぶだけ。
class Career {
  Career._({required this.seed, required this.mine, required this.rng, required this.teams});

  /// 新しく任される。リーグは [seed] だけで決まる(どのチームを選んでも同じリーグになる)。[team] が自分のチーム。
  factory Career.start({required int seed, int team = 0, Difficulty difficulty = Difficulty.normal}) {
    final rng = Rng(seed);
    final c = Career._(seed: seed, mine: team.clamp(0, teamDefs.length - 1), rng: rng, teams: [])..difficulty = difficulty;
    c._build();
    c.ownerType = OwnerType.values[(seed * 7 + c.mine) % OwnerType.values.length];
    // はじめのコーチ陣はみな「良い」。ヘッドコーチは70ちょうど(強さを変えないので、どのチームを選んでも同じリーグ)
    c.me.coaches = [
      for (final x in c._makeCoaches(-1, start: true)) x.role == Staff.coach ? Coach(name: x.name, role: x.role, rating: 70) : x,
    ];
    c.coachPool = c._makeCoaches(0, start: false);
    c.startRank = c.strengthRank(c.mine);
    return c;
  }

  final int seed;
  final Rng rng;
  final List<Team> teams;

  /// 難しさ(始めるときに選び、途中では変えない)。
  Difficulty difficulty = Difficulty.normal;

  /// 自分のチーム。
  final int mine;
  Team get me => teams[mine];

  /// 任されたときの強さの順位(0始まり)と、そこから決まるチームの状態。
  int startRank = 0;
  Outlook get outlook => Outlook.of(startRank);

  int season = 1;
  Phase phase = Phase.preseason;

  /// 今のシーズンで終えた区切り(0〜4)。
  int block = 0;

  /// 今のシーズンで終えた節(試合の数。0〜82)。
  int roundAt = 0;

  /// 直前の区切りの、自分のチームの試合。
  List<GameResult> lastGames = [];

  /// 直近の自分の試合の点差(勝ちはプラス。新しいものが後ろ、[formLength] 試合まで)。シーズンが始まると空にする。
  List<int> form = [];
  static const formLength = 10;

  /// 試合の見どころ(大勝・接戦・逆転・40点)。新しい順。
  List<String> highlightsOf(List<GameResult> games) {
    final out = <String>[];
    for (final g in games.reversed) {
      final opp = teams[g.opponentOf(mine)].def.short;
      final diff = g.ptsOf(mine) - g.ptsAgainst(mine);
      final score = '${g.ptsOf(mine)}-${g.ptsAgainst(mine)}';
      if (g.quarters.length == 8) {
        // 3クォーターまでの点差(自分から見て)
        final h3 = g.quarters[0] + g.quarters[1] + g.quarters[2];
        final a3 = g.quarters[4] + g.quarters[5] + g.quarters[6];
        final lead3 = g.home == mine ? h3 - a3 : a3 - h3;
        if (diff > 0 && lead3 <= -8) {
          out.add('逆転勝ち: $opp戦、3Qまで${-lead3}点負けていたが $score');
          continue;
        }
        if (diff < 0 && lead3 >= 8) {
          out.add('逆転負け: $opp戦、3Qまで$lead3点勝っていたが $score');
          continue;
        }
      }
      if (diff >= 20) {
        out.add('大勝: $opp戦 $score');
      } else if (diff <= -20) {
        out.add('大敗: $opp戦 $score');
      } else if (diff.abs() <= 2) {
        out.add('${diff > 0 ? '接戦を制した' : '接戦を落とした'}: $opp戦 $score');
      }
      for (final b in g.box) {
        if (b.pts >= 40) out.add('${b.name}が${b.pts}点($opp戦)');
      }
    }
    return out;
  }

  /// プレーオフ(プレーイン・1回戦・2回戦・地区決勝・ファイナルの順)。
  List<Series> playoffs = [];

  /// 自由契約の選手。
  List<Player> freeAgents = [];

  /// 指名権(今年と来年の分)。
  List<DraftPick> picks = [];

  /// ドラフトの候補・順番・何番目まで進んだか。
  List<Prospect> prospects = [];
  List<int> order = [];
  int draftAt = 0;

  /// 指名された順の候補(prospects の番号)。
  List<int> draftLog = [];

  /// 今年のくじの前の並び(くじに入ったチーム、成績の悪い順)。くじの結果を見せるのに使う。
  List<int> lotteryPre = [];

  /// オフに入ったときの自分の選手(id)と強さの順位(0が1位)。オフのまとめで、入った・出た選手と順位の変化を出す。
  List<int> offStartIds = [];
  int offStartRank = -1;
  int scoutsLeft = 0;
  bool scoutAdUsed = false;

  /// 契約の話し合いを待っている自分の選手(id)。
  List<int> expiring = [];

  /// オーナーの信頼(0で解任)と、今シーズンの勝ち数の目標。
  int trust = 50;

  /// オーナーの性格(始めるときに決まる)。
  OwnerType ownerType = OwnerType.steady;

  /// 面談で決めた予算の段階([budgetLabels] の番号)。0 は上限、1 はぜいたく税、2 は第2の壁(既定。どちらも縛らない)。
  int budgetLevel = 2;

  /// 最後に面談したシーズン。
  int meetingSeason = -1;

  /// 予算の年俸の合計の目安。
  int get budgetCap => const [salaryCap, taxLine, secondApron][budgetLevel];

  /// 今季の面談ができるか(シーズン前に1回)。
  bool get meetingOpen => phase == Phase.preseason && meetingSeason != season;

  /// オーナーと面談して予算を決める。
  void ownerMeeting(int level) {
    if (!meetingOpen) return;
    budgetLevel = level.clamp(0, 2);
    meetingSeason = season;
    _mail(Sender.owner, '予算の面談', '今季の予算は「${budgetLabels[budgetLevel]}」で合意した。${budgetLevel == 2 ? '' : '守れば信頼が上がる。超える補強やトレードは、オーナーが許さない。'}');
  }

  /// 予算を超える補強・トレードを止める理由(止めないなら null)。年俸の合計が増えるときだけ。
  String? budgetProblem(int after) {
    if (budgetLevel >= 2 || after <= budgetCap || after <= me.payroll) return null;
    return 'オーナーとの約束(${budgetLabels[budgetLevel]}=${money(budgetCap)})を超える';
  }
  int target = 0;

  /// 解任を1度だけ取り消せる(動画)。
  bool rescueUsed = false;
  bool fired = false;

  List<SeasonRecord> history = [];

  /// オフの知らせ(成長・引退など)。
  List<String> news = [];

  /// 相手から届いているトレードの申し込み。
  TradeOffer? incoming;

  int tradesDone = 0;

  /// 受信箱(新しい順、[inboxLimit] 件まで)。
  List<Message> inbox = [];
  static const inboxLimit = 40;
  int _msgId = 1;

  /// 返事を待っている知らせ・読んでいない知らせの数。
  int get unread => inbox.where((m) => !m.read || m.needsAnswer).length;

  void _mail(Sender from, String title, String body, {MsgKind kind = MsgKind.info, List<String> choices = const [], int? player}) {
    inbox.insert(0, Message(id: _msgId++, season: season, from: from, title: title, body: body, kind: kind, choices: choices, player: player));
    if (inbox.length > inboxLimit) inbox.removeRange(inboxLimit, inbox.length);
  }

  /// 知らせを読んだ。
  void readMessage(int id) {
    for (final m in inbox) {
      if (m.id == id) m.read = true;
    }
  }

  /// 返事が要らない知らせを、全部読んだことにする(受信箱を閉じるとき)。
  void readAllMessages() {
    for (final m in inbox) {
      if (!m.needsAnswer) m.read = true;
    }
  }

  /// 読んだ知らせを消す(返事を待っている知らせは残す)。消した数を返す。
  int clearReadMessages() {
    final before = inbox.length;
    inbox.removeWhere((m) => m.read && !m.needsAnswer);
    return before - inbox.length;
  }

  /// 知らせに返事をする。返事ごとの効き目(選手の気持ち・先発の順)をここで起こす。
  void answer(int id, int choice) {
    final m = inbox.where((x) => x.id == id).firstOrNull;
    if (m == null || !m.needsAnswer || choice < 0 || choice >= m.choices.length) return;
    m
      ..answer = choice
      ..read = true;
    if (m.kind == MsgKind.press) {
      // 強気は人気を呼ぶが、勝てていないと信頼を失う。慎重は信頼が少し上がる。はぐらかすと人気が少し下がる
      switch (choice) {
        case 0:
          hype = (hype + 3).clamp(0, 100);
          trust = (trust + (me.winPct >= 0.5 ? 1 : -2)).clamp(0, 100);
        case 1:
          trust = (trust + 1).clamp(0, 100);
        default:
          hype = (hype - 1).clamp(0, 100);
      }
      return;
    }
    final p = m.player == null ? null : me.roster.where((x) => x.id == m.player).firstOrNull;
    if (p == null) return;
    switch (m.kind) {
      case MsgKind.minutes:
        if (choice == 0) {
          // 先発に入れる: いまの順の5番目に入れる
          final order = [for (final x in me.order) x.id]..remove(p.id);
          order.insert(4.clamp(0, order.length), p.id);
          me.rotation = order;
          p.morale = (p.morale + 15).clamp(0, 100);
        } else {
          p.morale = (p.morale - 8).clamp(0, 100);
        }
      case MsgKind.tradeRequest:
        p.morale = (p.morale + (choice == 0 ? 8 : -6)).clamp(0, 100);
      case MsgKind.info:
      case MsgKind.press:
        break;
    }
  }

  /// MVP争い(いまの成績での順位)。試合の半分以上に出た選手だけ。
  List<(Player, int)> mvpRace({int count = 5}) {
    final min = math.max(1, (roundAt * 0.5).round());
    final all = [
      for (final t in teams)
        for (final p in t.roster)
          if (p.stats.gp >= min) (p, t.index),
    ];
    double score((Player, int) x) => x.$1.stats.ppg + 0.6 * x.$1.stats.rpg + 0.9 * x.$1.stats.apg + teams[x.$2].winPct * 12;
    all.sort((a, b) => score(b).compareTo(score(a)));
    return all.take(count).toList();
  }

  /// 今シーズンのオールスター(選手の id)。
  List<int> allStarIds = [];

  /// オールスターを選ぶ(シーズンの半分、41試合のあと)。地区ごとに12人。
  // ---------------------------------------------------------------- 入れ替え権

  /// 入れ替え権([その年, 権利を持つチーム, 入れ替えの相手のチーム])。ドラフトの順が決まったときに使う。
  List<List<int>> swaps = [];

  /// その年の1巡目の指名権の番号(無ければ -1)。
  int _firstRound(int s, int from) => picks.indexWhere((p) => p.season == s && p.round == 1 && p.from == from);

  /// ドラフトの順が決まったあと、入れ替え権を使う。権利を持つチームが自分の1巡目を持ったままで、相手の1巡目のほうが上位なら入れ替える。
  void _applySwaps() {
    for (final s in swaps.where((x) => x[0] == season)) {
      final h = _firstRound(season, s[1]), t = _firstRound(season, s[2]);
      if (h < 0 || t < 0 || picks[h].owner != s[1]) continue;
      final ph = order.indexOf(h), pt = order.indexOf(t);
      if (ph < 0 || pt < 0 || pt >= ph) continue;
      final tOwner = picks[t].owner;
      picks[t].owner = s[1];
      picks[h].owner = tOwner;
      _log('入れ替え権: ${teams[s[1]].def.short}が${teams[s[2]].def.short}の1巡目(${pt + 1}番目)と自分の1巡目(${ph + 1}番目)を入れ替えた');
    }
    swaps.removeWhere((x) => x[0] <= season);
  }

  // ---------------------------------------------------------------- 締め切り日

  /// 締め切り日のまとめ(朝・昼・夕・直前の4つに分けて、今季のトレードを時間順に見せる)。乱数は使わない。
  void _deadlineDay() {
    final prefix = '$season年目 トレード';
    // ニュースは新しい順。今季のトレードを時間順(古い順)に並べる
    final trades = [for (final l in log.reversed) if (l.startsWith(prefix)) l.substring('$season年目 '.length)];
    const slots = ['朝', '昼', '夕', '直前'];
    final buf = StringBuffer('トレードの締め切り日。動きを時間順に。\n');
    for (var i = 0; i < slots.length; i++) {
      final from = trades.length * i ~/ slots.length, to = trades.length * (i + 1) ~/ slots.length;
      final part = trades.sublist(from, to);
      buf.writeln('\n【${slots[i]}】${part.isEmpty ? '目立った動きはなかった' : ''}');
      for (final t in part.take(3)) {
        buf.writeln('・$t');
      }
      if (part.length > 3) buf.writeln('・ほか${part.length - 3}件');
    }
    _mail(Sender.league, '締め切り日のまとめ', buf.toString().trim());
    _log('トレードの締め切りを迎えた(今季のトレード${trades.length}件)');
  }

  /// 締め切り前の最後の区切りの前に、知らせを出す。
  void _deadlineWarning() {
    _mail(Sender.league, 'トレードの締め切りが近い', 'このあとの区切りでトレードの締め切りを迎える。補強やトレードを動かすなら、いまのうち。');
  }

  // ---------------------------------------------------------------- カップ戦

  /// 歴代のカップ戦の結果(シーズン・優勝・準優勝のチーム)。
  List<List<int>> cupHistory = [];

  /// 今季のカップ戦の8チーム(41試合のあと、地区の上位4チームずつ)。
  List<int> cupField = [];

  /// 今季のカップ戦の経過(例: 準々決勝の勝ち上がり。チームの番号を勝者の順に)。
  List<int> cupRounds = [];

  /// 41試合のあと、地区の上位4チームずつ(8チーム)で1試合勝負のトーナメントを行う。82試合には数えない。
  /// 勝敗は専用の乱数で決める(リーグの続きを変えない)。優勝は賞金と人気が入る。
  void _runCup() {
    final r = Rng(seed * 131 + season * 977 + 5);
    final east = [for (final t in standings(teams, east: true).take(4)) t.index];
    final west = [for (final t in standings(teams, east: false).take(4)) t.index];
    cupField = [...east, ...west];
    int play(int a, int b) => r.chance(winChance(teams[a].strength, teams[b].strength)) ? a : b;
    final rounds = <int>[];
    int bracket(List<int> g) {
      final a = play(g[0], g[3]), b = play(g[1], g[2]);
      rounds.addAll([a, b]);
      final w = play(a, b);
      rounds.add(w);
      return w;
    }

    final e = bracket(east), w = bracket(west);
    final champ = play(e, w);
    final runnerUp = champ == e ? w : e;
    rounds.add(champ);
    cupRounds = rounds;
    cupHistory.add([season, champ, runnerUp]);
    if (cupField.contains(mine)) {
      final prize = champ == mine ? capScaled(40) : runnerUp == mine ? capScaled(20) : capScaled(8);
      _earn(Income.cup, prize);
      hype = (hype + (champ == mine ? 4 : runnerUp == mine ? 2 : 1)).clamp(0, 100);
    }
    _log('カップ戦: ${teams[champ].def.short}が優勝(決勝の相手は${teams[runnerUp].def.short})${champ == mine ? '。賞金${money(capScaled(40))}' : ''}');
    if (champ == mine) _mail(Sender.owner, 'カップ戦の優勝', 'カップ戦で優勝した。賞金と人気が入った。');
  }

  void _pickAllStars() {
    allStarIds = [];
    final race = mvpRace(count: 300);
    for (final east in [true, false]) {
      final picks = race.where((x) => teams[x.$2].east == east).take(12);
      for (final (p, _) in picks) {
        allStarIds.add(p.id);
        p.allStars++;
      }
    }
    final mine = [for (final p in me.roster) if (allStarIds.contains(p.id)) p];
    for (final p in mine) {
      p.morale = (p.morale + 10).clamp(0, 100);
    }
    _log('オールスター: 東西24人が決まった${mine.isEmpty ? '' : '(${me.def.short}から${mine.map((p) => p.name).join('・')})'}');
    _mail(Sender.league, 'オールスターの選手が決まった',
        mine.isEmpty ? '今年は${me.def.short}から選ばれた選手はいなかった。' : '${mine.map((p) => p.name).join('・')}が選ばれた。本人たちの気持ちも上がっている。');
  }

  /// 区切りのあとに届く知らせ(出番の不満・トレードの希望・MVP争い・オーナーの声)。
  // ---------------------------------------------------------------- 報道

  /// 自分のチームの見出し(新しいものが先頭。最大12)。
  List<String> headlines = [];

  /// 区切りのあとに、自分のチームの見出しを作る(乱数を使わない)。
  void _makeHeadlines() {
    final out = <String>[];
    final st = standings(teams, east: me.east);
    final rank = st.indexWhere((t) => t.index == mine) + 1;
    if (me.streak >= 5) out.add('${me.def.short}が${me.streak}連勝、勢いが止まらない');
    if (me.streak <= -4) out.add('${me.def.short}が${-me.streak}連敗、チームに重い空気');
    if (rank == 1 && roundAt >= 20) out.add('${me.def.short}が${me.east ? '東' : '西'}地区の首位に立つ');
    if (rank > playInSeeds && roundAt >= 40) out.add('${me.def.short}、プレーオフ圏外で苦しい戦い');
    final star = me.roster.where((p) => p.injured > 0 && p.ovr >= 70).toList()..sort((a, b) => b.ovr.compareTo(a.ovr));
    if (star.isNotEmpty) out.add('主力の${star.first.name}が${star.first.injuryText.isEmpty ? 'けが' : star.first.injuryText}');
    if (hype >= 75) out.add('人気が沸騰、チケットは売り切れ続出');
    if (hype <= 25) out.add('客席に空席目立つ、人気の低迷が続く');
    final unhappy = me.roster.where((p) => p.morale < 25 && p.ovr >= 62).toList();
    if (unhappy.isNotEmpty) out.add('${unhappy.first.name}に不満の声、移籍の観測も');
    if (out.isEmpty) out.add('${me.def.short}は${me.wins}勝${me.losses}敗(地区$rank位)、静かな区切り');
    headlines = [...out.map((h) => '$season年目・$roundAt試合: $h'), ...headlines].take(12).toList();
  }

  /// ファンの声(人気と勝率から、その場で決まる)。
  String get fanVoice {
    final pct = me.winPct;
    final voices = hype >= 70 && pct >= 0.55
        ? ['今年は本当にいける気がする!', '毎試合チケットを取るのが大変だよ', 'GMは神様か?']
        : pct < 0.4
            ? ['そろそろ立て直しを見せてほしい', 'いつまで待てばいいんだ…', 'GM、何か手を打ってくれ']
            : hype <= 30
                ? ['最近、試合を見に行かなくなった', 'もっとワクワクさせてほしい', '若手に期待してるよ']
                : ['まあまあ楽しませてもらってる', '次の補強に期待', '勝ち越しならファンは満足'];
    return voices[(seed + season * 7 + roundAt) % voices.length];
  }

  /// 区切りのあとの記者の質問(3区切りに1回ほど。乱数を使わない)。
  void _pressQuestion() {
    if ((seed + season * 3 + block) % 3 != 0) return;
    final pct = me.winPct;
    final q = pct >= 0.6
        ? '好調が続いていますが、今季の目標は優勝ですか?'
        : pct < 0.4
            ? '苦しい戦いが続きます。立て直しの手はありますか?'
            : 'ここまでのチームをどう評価しますか?';
    _mail(Sender.press, '記者の質問', q, kind: MsgKind.press, choices: const ['強気に答える(「優勝を狙う」)', '慎重に答える(「一試合ずつ」)', 'はぐらかす']);
  }

  void _mailAfterBlock() {
    _makeHeadlines();
    _pressQuestion();
    final race = mvpRace(count: 5);
    if (race.isNotEmpty) {
      _mail(Sender.league, 'MVP争い($roundAt試合のあと)',
          [for (var i = 0; i < race.length; i++) '${i + 1}. ${race[i].$1.name}(${teams[race[i].$2].def.short}) ${race[i].$1.stats.line}'].join('\n'));
    }
    // 出番の不満: 力の順位より2つ以上下で、気持ちが下がってきた選手から1人
    final order = me.order;
    final byOvr = [...me.roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final waiting = inbox.where((m) => m.needsAnswer).map((m) => m.player).toSet();
    for (var i = 0; i < order.length; i++) {
      final p = order[i];
      final expected = byOvr.indexOf(p);
      if (waiting.contains(p.id) || p.injured > 0) continue;
      if (p.morale < 20) {
        _mail(Sender.player, '${p.name}がトレードを希望', '${p.name}(OVR${shown(p.ovr)})「このチームでは先が見えない。よそでプレーしたい」',
            kind: MsgKind.tradeRequest, choices: const ['相手を探すと約束する', '残ってほしいと伝える'], player: p.id);
        break;
      }
      if (i >= 5 && expected < 5 && p.morale < 50) {
        _mail(Sender.player, '${p.name}が出番を求めている', '${p.name}(OVR${shown(p.ovr)})「自分は先発で出られるはずだ。もっと出番がほしい」',
            kind: MsgKind.minutes, choices: const ['先発に入れると約束する', '今の役割を続けてもらう'], player: p.id);
        break;
      }
    }
    // オーナー: 目標の勝ち数に遠いとき
    final pace = roundAt == 0 ? 0.0 : me.wins / roundAt * gamesPerSeason;
    if (roundAt >= blockStart(2) && pace < target - 6) {
      _mail(Sender.owner, 'オーナーから', 'このままでは目標の$target勝に届かない(いまの勢いだと${pace.round()}勝)。何か手を打ってほしい。');
    }
  }

  /// 人気(0〜100)。勝つ・プレーオフに出ると上がる。観客の入りに効く。
  int hype = 50;

  /// メディア好きの主力(上から9人)がいると、シーズンの終わりに人気が上がる(1人+2、2人まで)。
  int get mediaHype => 2 * me.order.take(9).where((p) => hasTrait(p, Trait.media)).length.clamp(0, 2);

  /// 入場料の段階([ticketPrices] の番号)。
  int priceLevel = 1;

  /// 売店の値段の段階([concessionPrices] の番号)。
  int concessionLevel = 1;

  /// 自分のチームの市場の大きさ(スポンサーとグッズに掛かる)。
  double get market => marketSizes[mine];

  /// 今シーズンの収入の内訳([Income] の順)。合計は [revenue]。
  List<int> incomeBy = List.filled(Income.values.length, 0);

  void _earn(Income i, int v) {
    incomeBy[i.index] += v;
    revenue += v;
  }

  /// 勝ち負けによらない1シーズンの収入(放映料・スポンサー・グッズ)。人気と市場の大きさで変わる。
  Map<Income, int> get baseIncomeParts => {
        Income.tv: (baseIncome * 0.45).round(),
        Income.sponsor: (baseIncome * 0.25 * market).round(),
        Income.merch: (baseIncome * 0.20 * market * (0.6 + hype * 0.008)).round(),
      };

  /// 1試合のホームの売店の収入(10万ドル)。
  int get concessionPerGame => (arenaSeats * attendance * concessionPrices[concessionLevel] * capScale / 100000).round();

  /// 今シーズンの収入と支出(10万ドル)。区切りごとに足していく。
  int revenue = 0;
  int costs = 0;
  int get profit => revenue - costs;

  /// 前のシーズンの収支。
  int lastProfit = 0;

  /// 今シーズンのオーナーの目標(勝ち数・収支・もう1つ)。
  List<OwnerGoal> goals = [];

  /// 観客の入り(0.3〜1.0)。人気が高いほど、値段が安いほど入る。
  double get attendance => (0.55 + hype * 0.0045 - (ticketPrices[priceLevel] - 100) * 0.003 - (concessionPrices[concessionLevel] - 18) * 0.002).clamp(0.3, 1.0);

  /// 1試合のホームの入場収入(10万ドル)。
  int get gatePerGame => (arenaSeats * attendance * ticketPrices[priceLevel] * capScale / 100000).round();

  void setConcession(int level) {
    if (phase == Phase.over) return;
    concessionLevel = level.clamp(0, concessionPrices.length - 1);
  }

  void setPrice(int level) {
    if (phase == Phase.over) return;
    priceLevel = level.clamp(0, ticketPrices.length - 1);
  }

  /// 目標が果たせているか(シーズン中は見込み)。
  bool goalOk(OwnerGoal g) => switch (g.kind) {
        GoalKind.wins => me.wins >= target,
        GoalKind.profit => _projectedProfit >= 0,
        GoalKind.playoffs => confRank <= playInSeeds && (finals == null || myResult >= 1),
        GoalKind.youth => me.order.take(5).where((p) => p.age <= 25).length >= 2,
        GoalKind.noTax => me.payroll <= taxLine,
      };

  /// シーズンの終わりの収支の見込み(残りの試合を今の入りで数える)。
  int get _projectedProfit {
    // シーズンを閉じたあと(税もプレーオフの収入も入ったあと)は、そのままの収支
    if (finals != null) return profit;
    final left = gamesPerSeason - roundAt;
    final perGameCost = me.payroll / gamesPerSeason;
    final tax = me.payroll > taxLine ? ((me.payroll - taxLine) * 1.5).round() : 0;
    final base = baseIncomeParts.values.fold(0, (a, b) => a + b);
    final rest = (left / 2 * (gatePerGame + concessionPerGame) + base * left / gamesPerSeason - perGameCost * left).round();
    return profit + rest - tax;
  }

  /// シーズンの終わりの収支の見込み(画面用)。
  int get projectedProfit => _projectedProfit;

  /// これまでの表彰(古い順)。
  List<Award> awards = [];

  /// [season] の表彰。
  List<Award> awardsOf(int season) => [for (final a in awards) if (a.season == season) a];

  /// 個人成績の上位([key] で並べる。試合の半分以上に出た選手だけ)。
  List<(Player, int)> leaders(double Function(Stats) key, {int count = 5}) {
    final all = [
      for (final t in teams)
        for (final p in t.roster)
          if (p.stats.gp >= math.max(1, (roundAt * 0.5).round())) (p, t.index),
    ]..sort((a, b) => key(b.$1.stats).compareTo(key(a.$1.stats)));
    return all.take(count).toList();
  }

  /// 歴代の優勝([シーズン, 優勝, ファイナルの相手]、古い順)。
  List<List<int>> champs = [];

  /// 殿堂(古い順)。
  List<HallEntry> hall = [];

  /// 殿堂に入る点。表彰・オールスター・優勝・通算得点から。
  int hallScore(Player p) {
    var n = p.allStars + p.careerTotals.pts ~/ 4000;
    for (final a in awards.where((a) => a.player == p.id)) {
      n += switch (a.kind) {
        AwardKind.mvp => 6,
        AwardKind.finalsMvp => 3,
        AwardKind.allLeague1 => 3,
        AwardKind.dpoy || AwardKind.allLeague2 => 2,
        AwardKind.allLeague3 || AwardKind.roy || AwardKind.sixth || AwardKind.mip => 1,
        AwardKind.month => 0,
      };
    }
    return n;
  }

  /// 永久欠番(背番号・引退した年・自分のチームでのシーズン数)。名前は [retiredNames] の同じ順。
  List<List<int>> retiredNumbers = [];
  List<String> retiredNames = [];

  /// 今オフに引退した、力のある選手(名前・力)。コーチ候補に加わる(最大4人)。
  List<List<Object>> retirees = [];

  void _noteRetiree(Player p) {
    if (p.ovr >= 62 && retirees.length < 4) retirees.add([p.name, p.ovr]);
  }

  /// テスト用: 引退した選手の殿堂入りと永久欠番の判定をそのまま行う。
  void toHallForTest(Player p, int team) => _toHall(p, team);

  /// 引退した選手が殿堂に入るか確かめる。
  void _toHall(Player p, int team) {
    if (hallScore(p) < hallThreshold) return;
    final mine = awards.where((a) => a.player == p.id).toList();
    String count(bool Function(Award) f, String label) {
      final n = mine.where(f).length;
      return n == 0 ? '' : '$label $n回';
    }

    final honors = [
      count((a) => a.kind == AwardKind.mvp, 'MVP'),
      count((a) => a.kind == AwardKind.finalsMvp, 'ファイナルMVP'),
      count((a) => a.kind == AwardKind.dpoy, '最優秀守備'),
      count((a) => a.kind.allLeague, 'オールリーグ'),
      if (p.allStars > 0) 'オールスター ${p.allStars}回',
    ].where((s) => s.isNotEmpty).join('・');
    hall.add(HallEntry(name: p.name, pos: p.pos, season: season, team: team, seasons: p.career.length, line: p.careerTotals.line, honors: honors));
    // 自分のチームで4シーズン以上プレーした殿堂入りの選手は、背番号が永久欠番になる
    final withMe = p.career.where((r) => r[1] == this.mine).length;
    if (withMe >= 4) {
      retiredNumbers.add([jerseyOf(p), season, withMe]);
      retiredNames.add(p.name);
      _log('永久欠番: ${p.name}の背番号${jerseyOf(p)}(自分のチームで$withMeシーズン)');
      _mail(Sender.owner, '${p.name}の背番号を永久欠番に', '${p.name}は$withMeシーズン、チームでプレーした。背番号${jerseyOf(p)}を永久欠番にする。');
    }
    _log('殿堂入り: ${p.name}($honors)');
    _mail(Sender.league, '${p.name}が殿堂入り', '${p.name}が引退し、殿堂に入った。通算 ${p.careerTotals.line}。$honors');
  }

  /// 現役の選手の通算成績の上位([key] で並べる)。
  List<(Player, int)> careerLeaders(int Function(Stats) key, {int count = 5}) {
    final all = [
      for (final t in teams)
        for (final p in t.roster)
          if (p.career.isNotEmpty) (p, t.index),
    ]..sort((a, b) => key(b.$1.careerTotals).compareTo(key(a.$1.careerTotals)));
    return all.take(count).toList();
  }

  /// シーズンの終わりに表彰を決める(MVP・新人王・最優秀守備選手・シックスマン賞・躍進賞・ファイナルMVP・オールリーグ)。
  void _giveAwards() {
    final pool = [
      for (final t in teams)
        for (final p in t.roster)
          if (p.stats.gp >= 50) (p, t),
    ];
    if (pool.isEmpty) return;
    double mvp((Player, Team) x) => x.$1.stats.ppg + 0.6 * x.$1.stats.rpg + 0.9 * x.$1.stats.apg + x.$2.winPct * 12;
    double dpoy((Player, Team) x) => x.$1.attr(Attr.defense) + x.$1.stats.rpg * 0.8 + x.$2.winPct * 4;
    void give(AwardKind k, Iterable<(Player, Team)> cands, double Function((Player, Team)) score) {
      final list = cands.toList();
      if (list.isEmpty) return;
      final best = list.reduce((a, b) => score(a) >= score(b) ? a : b);
      awards.add(Award(season: season, kind: k, player: best.$1.id, name: best.$1.name, team: best.$2.index, line: best.$1.stats.line));
      _log('${k.label}: ${best.$1.name}(${best.$2.def.short}・${best.$1.stats.line})');
      _mail(Sender.league, '${k.label}の発表', '${best.$1.name}(${best.$2.def.short})が選ばれた。${best.$1.stats.line}');
    }

    give(AwardKind.mvp, pool, mvp);
    // 新人王は、出場して点を取った新人がいるときだけ(控えの奥で出ていない新人には出さない)
    give(AwardKind.roy, pool.where((x) => x.$1.exp == 0 && x.$1.stats.ppg >= 5), mvp);
    give(AwardKind.dpoy, pool, dpoy);
    // シックスマン賞は、シーズンの終わりに先発の5人に入っていない選手から
    final starters = {for (final t in teams) ...t.order.take(5).map((p) => p.id)};
    give(AwardKind.sixth, pool.where((x) => !starters.contains(x.$1.id)), (x) => x.$1.stats.ppg + 0.4 * x.$1.stats.rpg + 0.6 * x.$1.stats.apg);
    // 躍進賞は、前のシーズンにも出ていた選手の伸び
    double rise((Player, Team) x) => x.$1.stats.ppg - x.$1.prev.ppg + 0.5 * (x.$1.stats.rpg - x.$1.prev.rpg + x.$1.stats.apg - x.$1.prev.apg);
    give(AwardKind.mip, pool.where((x) => x.$1.prev.gp >= 30 && rise(x) > 0), rise);
    // ファイナルMVPは、優勝したチームでいちばんの選手
    if (champion >= 0) {
      give(AwardKind.finalsMvp, pool.where((x) => x.$2.index == champion), (x) => x.$1.stats.ppg + 0.6 * x.$1.stats.rpg + 0.9 * x.$1.stats.apg);
    }
    // オールリーグは3チーム。各チームにガード2人・フォワード2人・センター1人
    final left = [...pool]..sort((a, b) => mvp(b).compareTo(mvp(a)));
    final teamsOf = <List<(Player, Team)>>[];
    for (var k = 0; k < 3; k++) {
      final five = <(Player, Team)>[];
      for (final (want, n) in [((Pos p) => p.guard, 2), ((Pos p) => p == Pos.sf || p == Pos.pf, 2), ((Pos p) => p == Pos.c, 1)]) {
        five.addAll(left.where((x) => want(x.$1.pos)).take(n));
        left.removeWhere(five.contains);
      }
      teamsOf.add(five);
      for (final x in five) {
        awards.add(Award(season: season, kind: AwardKind.values[AwardKind.allLeague1.index + k], player: x.$1.id, name: x.$1.name, team: x.$2.index, line: x.$1.stats.line));
      }
    }
    if (teamsOf.first.isNotEmpty) {
      _mail(Sender.league, 'オールリーグの発表', [
        for (var k = 0; k < teamsOf.length; k++) '${AwardKind.values[AwardKind.allLeague1.index + k].label}: ${teamsOf[k].map((x) => '${x.$1.name}(${x.$2.def.short})').join('・')}',
      ].join('\n'));
    }
  }

  /// リーグのニュース(新しい順、[logLimit] 件まで)。トレード・大物の移籍・ドラフト1位・優勝・引退。
  List<String> log = [];
  static const logLimit = 60;

  void _log(String text) {
    log.insert(0, '$season年目 $text');
    if (log.length > logLimit) log.removeRange(logLimit, log.length);
  }

  String _names(List<Player> ps) => ps.map((p) => p.name).join('・');

  /// トレードの中身を1行にする。
  String _tradeText(int a, int b, TradeOffer o, List<Player> give, List<Player> get) {
    String side(List<Player> ps, List<int> ix) => [
          if (ps.isNotEmpty) _names(ps),
          for (final i in ix) '指名権(${picks[i].label(teams, season)})',
        ].join('・');
    return 'トレード: ${teams[a].def.short}が${side(give, o.givePicks)}を出し、${teams[b].def.short}から${side(get, o.getPicks)}を獲得';
  }

  /// 前のシーズンのぜいたく税で下がった信頼。
  int lastTax = 0;

  /// 指名して入団した選手の id(生え抜き)。
  List<int> draftedIds = [];

  /// リーグの中で使っている名前(同じ名前の選手が2人いないように)。
  Set<String> get _usedNames => {
        for (final t in teams)
          for (final p in t.roster) p.name,
        for (final p in freeAgents) p.name,
        for (final p in prospects) p.player.name,
      };

  /// まだ使われていない名前を作る(20回試して、だめなら重なってもよい)。
  String _uniqueName([List<Player> building = const []]) {
    final used = {..._usedNames, for (final p in building) p.name};
    var n = randomName(rng);
    for (var i = 0; i < 20 && used.contains(n); i++) {
      n = randomName(rng);
    }
    return n;
  }

  int _nextId = 1;
  int nextId() => _nextId++;

  // ---------------------------------------------------------------- はじめ

  void _build() {
    trust = startTrust;
    final qualities = [for (var i = 0; i < teamDefs.length; i++) -5.5 + 10 * i / (teamDefs.length - 1)];
    rng.shuffle(qualities);
    for (var i = 0; i < teamDefs.length; i++) {
      final q = qualities[i];
      // 弱いチームは若く、強いチームの一部は主力が年寄りで年俸が高い(チームごとに違う状態にする)
      final style = q <= -3 && rng.chance(0.7)
          ? 1
          : q >= 3 && rng.chance(0.5)
              ? 2
              : 0;
      teams.add(Team(index: i, roster: _makeRoster(q, style)));
    }
    // はじめの選手は、リーグでの年数だけ今のチームにいたことにする(新人は0)
    for (final t in teams) {
      for (final p in t.roster) {
        p.tenure = math.min(p.exp, 4);
      }
    }
    // 指名権は今年から6年先まで(7回のドラフト)
    for (final s in [for (var i = 0; i < pickYears; i++) season + i]) {
      for (final r in [1, 2]) {
        for (var t = 0; t < teams.length; t++) {
          picks.add(DraftPick(season: s, round: r, from: t, owner: t));
        }
      }
    }
    freeAgents = [for (var i = 0; i < 12; i++) _filler()];
    _setModes();
  }

  /// 14人の選手を作る。[q] はチームの強さのずれ、[style] は 1: 若い、2: 年寄りで年俸が高い。
  List<Player> _makeRoster(double q, int style) {
    const tmpl = [80, 75, 72, 70, 68, 66, 64, 62, 60, 57, 55, 53, 50, 48];
    // ポジションはチームごとに並べ替える(エースがどのチームも同じポジションにならないように)。
    // 先発の5人は5つのポジションに1人ずつ、控えも2・3人ずつ
    final posCycle = <Pos>[];
    for (final n in [5, 5, 4]) {
      final ps = [...Pos.values];
      rng.shuffle(ps);
      posCycle.addAll(ps.take(n));
    }
    final roster = <Player>[];
    for (var k = 0; k < tmpl.length; k++) {
      final ovr = (tmpl[k] + q + rng.nextInt(5) - 2).round().clamp(42, 92);
      int age;
      if (style == 1) {
        age = 20 + rng.nextInt(6);
      } else if (style == 2 && k < 5) {
        age = 30 + rng.nextInt(4);
      } else {
        age = 21 + rng.nextInt(12);
      }
      final room = age <= 22 ? 10 + rng.nextInt(14) : age <= 25 ? 4 + rng.nextInt(10) : age <= 27 ? rng.nextInt(5) : 0;
      final pot = (ovr + room + (style == 1 ? 4 : 0)).clamp(ovr, 96);
      var sal = (fairSalary(ovr, age) * (0.8 + rng.nextInt(45) / 100)).round();
      if (style == 2 && k < 5) sal = (sal * 1.2).round();
      roster.add(Player(
        id: nextId(),
        name: _uniqueName(roster),
        pos: posCycle[k],
        age: age,
        ovr: ovr,
        pot: pot,
        salary: sal.clamp(minSalary, maxSalaryFor(math.max(1, age - 20))),
        years: 1 + rng.nextInt(4),
        exp: math.max(1, age - 20),
      ));
    }
    // 年俸の合計が上限の外へ大きく出ないように整える。チームごとに空きの大きさを散らす
    final limit = style == 2 ? secondApron - capScaled(80) - rng.nextInt(capScaled(120)) : salaryCap - capScaled(style == 1 ? 260 : 20) - rng.nextInt(capScaled(220)) + capScaled(80);
    var total = roster.fold(0, (s, p) => s + p.salary);
    if (total > limit) {
      final f = limit / total;
      for (final p in roster) {
        p.salary = (p.salary * f).round().clamp(minSalary, maxSalaryFor(p.exp));
      }
    } else if (total < capScaled(950)) {
      // 若いチームでも、年俸の合計が少なすぎないようにする(上限の3分の2ほどまでは払っている)
      final f = capScaled(950) / total;
      for (final p in roster) {
        p.salary = (p.salary * f).round().clamp(minSalary, maxSalaryFor(p.exp));
      }
    }
    if (style == 2) {
      total = roster.fold(0, (s, p) => s + p.salary);
      if (total < salaryCap + capScaled(120)) {
        final f = (salaryCap + capScaled(120)) / total;
        for (final p in roster.take(5)) {
          p.salary = (p.salary * f).round().clamp(minSalary, maxSalaryFor(p.exp));
        }
      }
    }
    return roster;
  }

  /// 最低年俸で来てくれる控えの選手。
  Player _filler({Pos? pos}) {
    final age = 23 + rng.nextInt(10);
    final ovr = 50 + rng.nextInt(9);
    final r = Pos.values[rng.nextInt(5)];
    return Player(id: nextId(), name: _uniqueName(), pos: pos ?? r, age: age, ovr: ovr, pot: ovr + (age < 26 ? rng.nextInt(5) : 0), salary: minSalary, years: 1, exp: age - 21);
  }

  /// 各チームの考え方を、強さの順と年俸から決める。
  void _setModes() {
    final st = {for (final t in teams) t.index: t.strength};
    final order = [...teams]..sort((a, b) => st[b.index]!.compareTo(st[a.index]!));
    for (var r = 0; r < order.length; r++) {
      final t = order[r];
      if (t.payroll > salaryCap + capScaled(150) && r >= 6) {
        t.mode = TeamMode.cutCost;
      } else if (r < 6) {
        t.mode = TeamMode.contend;
      } else if (r >= order.length - 10) {
        t.mode = TeamMode.rebuild;
      } else {
        t.mode = TeamMode.balanced;
      }
    }
  }

  /// 強さの順位(0が1位)。
  int strengthRank(int team) {
    final mine = teams[team].strength;
    return teams.where((t) => t.index != team && t.strength > mine).length;
  }

  // ---------------------------------------------------------------- シーズン

  /// シーズンを始められない理由(始められるなら null)。
  String? get startProblem {
    if (me.roster.length < minRoster) return '選手が$minRoster人そろっていない(いま${me.roster.length}人)';
    if (me.roster.length > maxRoster) return '選手が$maxRoster人を超えている(いま${me.roster.length}人)';
    return null;
  }

  /// 今のシーズンの試合が始まっているか(シーズン中・プレーオフ前・シーズン終了)。
  bool get seasonStarted => phase == Phase.season || phase == Phase.playoffs || phase == Phase.seasonEnd;

  bool get canTrade => phase == Phase.preseason || phase == Phase.contracts || phase == Phase.draft || (phase == Phase.season && block < tradeDeadlineBlock);

  /// 自由契約の選手と契約できるか(シーズン中も最低年俸の選手なら取れる)。
  bool get canSign => phase == Phase.preseason || phase == Phase.contracts || phase == Phase.season;

  void startSeason() {
    if (phase != Phase.preseason || startProblem != null) return;
    for (final t in teams) {
      t.wins = 0;
      t.losses = 0;
      t.streak = 0;
      for (final p in t.roster) {
        p.prev = p.stats;
        p.stats = Stats();
      }
      if (t.index != mine) _aiTrim(t);
    }
    _setModes();
    final r = strengthRank(mine);
    target = (gamesPerSeason * (0.72 - r * 0.016)).round();
    revenue = 0;
    cupField = [];
    cupRounds = [];
    incomeBy = List.filled(Income.values.length, 0);
    costs = 0;
    final third = [GoalKind.playoffs, GoalKind.youth, GoalKind.noTax];
    // 強いチームにはプレーオフ、立て直しには若手、上限を大きく超えたチームには税を
    final kind = r < 12 ? GoalKind.playoffs : r >= 22 ? GoalKind.youth : me.payroll > taxLine - capScaled(50) ? GoalKind.noTax : third[rng.nextInt(third.length)];
    goals = [OwnerGoal(GoalKind.wins), OwnerGoal(GoalKind.profit), OwnerGoal(ownerType == OwnerType.youth ? GoalKind.youth : kind)];
    allStarIds = [];
    extAsked = [];
    for (final p in me.roster.where((p) => p.years == 1 && p.ovr >= 70 && p.nextSalary == null)) {
      _mail(Sender.agent, '${p.name}の代理人から', '${p.name}の契約は今季で切れる。延長の話をしたい(チームの画面で選手を押すと申し出られる)。'
          '求める年俸は${money(extensionAsk(p).salary)}ほど。', player: p.id);
    }
    _mail(Sender.owner, '$season年目の目標', [
      'オーナーからの今シーズンの目標:',
      for (final g in goals) '・${g.kind == GoalKind.wins ? '$target勝する' : g.kind.label}',
    ].join('\n'));
    block = 0;
    roundAt = 0;
    lastGames = [];
    form = [];
    playoffs = [];
    incoming = null;
    phase = Phase.season;
  }

  /// 次の区切り(20〜21試合)を進める。
  void playBlock() => _playRounds(blockStart(block + 1) - roundAt);

  /// 1週間(3節)進める。区切りの終わりは越えない。区切りの終わりに着いたら true。
  bool playWeek() {
    final before = block;
    _playRounds(math.min(daysPerWeek, blockStart(block + 1) - roundAt));
    return block != before;
  }

  /// 1週間に進める節の数。
  static const daysPerWeek = 3;

  /// [n] 節進める。区切りの終わりに着いたら、区切りのあとの出来事(気持ち・相手同士のトレード・申し込み)を起こす。
  void _playRounds(int n) {
    if (phase != Phase.season || block >= blocksPerSeason || n <= 0) return;
    injuries.clear();
    incoming = null;
    // 区切りの初めから進めるときは、結果の一覧を空にする(区切りの途中なら足していく)
    if (roundAt == blockStart(block)) {
      lastGames = [];
      _snapshotBlock();
    }
    final games = <GameResult>[];
    for (final round in seasonSchedule(teams.length).sublist(roundAt, roundAt + n)) {
      for (final (h, a) in round) {
        final g = playGame(teams[h], teams[a], rng, mine: mine, injuryScale: difficulty.injury);
        if (g.involves(mine)) games.add(g);
      }
    }
    roundAt += n;
    _tickTenDay(n);
    lastGames = [...lastGames, ...games];
    form = [...form, for (final g in games) g.ptsOf(mine) - g.ptsAgainst(mine)];
    if (form.length > formLength) form = form.sublist(form.length - formLength);
    _checkGameRecords(games);
    final homeGames = games.where((g) => g.home == mine).length;
    _earn(Income.gate, homeGames * gatePerGame);
    _earn(Income.concession, homeGames * concessionPerGame);
    for (final e in baseIncomeParts.entries) {
      _earn(e.key, (e.value * games.length / gamesPerSeason).round());
    }
    costs += ((me.payroll + me.staffCost + me.twoWay.length * twoWaySalary) * games.length / gamesPerSeason).round();
    for (final (t, p) in injuries) {
      if (t == mine || p.ovr >= 76) _log('けが: ${p.name}(${teams[t].def.short})が${p.injured}試合欠場');
    }
    injuries.clear();
    if (roundAt < blockStart(block + 1)) return;
    block++;
    _updateMorale();
    _updateChem();
    _giveMonthly();
    if (block == tradeDeadlineBlock) {
      _deadlineDay();
      _runCup();
      _pickAllStars();
    }
    if (block == tradeDeadlineBlock - 1) _deadlineWarning();
    if (block < blocksPerSeason) _mailAfterBlock();
    if (block <= tradeDeadlineBlock && rng.chance(0.5)) _aiTrades(1);
    if (block >= blocksPerSeason) {
      phase = Phase.playoffs;
    } else if (rng.chance(0.6)) {
      _makeIncoming();
    }
  }

  /// このオフの自分のチームの成長(年を取る前と後の力)。
  List<GrowthLine> growth = [];

  void setTraining(int level) => me.training = level.clamp(0, 2);

  /// チームの方針の [axis] 番目の軸を [choice](0・1・2)にする。
  void setPolicy(int axis, int choice) {
    if (axis < 0 || axis >= me.policy.length || phase == Phase.over) return;
    me.policy[axis] = choice.clamp(0, 2);
  }

  void setFocus(int id, Attr? a) {
    final p = _mineById(id);
    if (p != null) p.focus = a;
  }

  /// オフの練習の効き目。力の変わった分を返す(重点は能力のずれだけを動かす)。
  int _train(Player p, int d) {
    var b = 0;
    if (me.training == 2 && p.age <= 25 && d >= 0 && p.ovr < p.pot && rng.chance(0.35)) b = 1;
    if (me.training == 0 && p.age >= 30 && d < 0 && rng.chance(0.5)) b = 1;
    if (b != 0) {
      p.ovr = (p.ovr + b).clamp(35, 99);
      if (p.pot < p.ovr) p.pot = p.ovr;
      p.lastDelta += b;
    }
    final f = p.focus;
    if (f != null) {
      p.attrs[f.index] = math.min(p.attrs[f.index] + (me.staffLevel(Staff.development) == 3 ? 3 : 2), 15);
      final others = [for (final a in Attr.values) if (a != f) a];
      final o = others[rng.nextInt(others.length)];
      p.attrs[o.index] = math.max(p.attrs[o.index] - 1, -20);
    }
    return b;
  }

  /// 自分のチームの選手の気持ちを、区切りごとに動かす。
  /// 力の順位より出場の順が2つ以上下なら下がり、上なら上がる。チームの勝率でも動く。
  /// 相性が決まる要素(先発から9人目まで)。続けて一緒にいる選手の割合・不満の人数・好調の人数・勝ち。
  ({double continuity, int unhappy, int happy}) get chemFactors {
    final top = me.order.take(9).toList();
    if (top.isEmpty) return (continuity: 0.5, unhappy: 0, happy: 0);
    return (
      continuity: top.where((p) => p.tenure >= 1).length / top.length,
      unhappy: top.where((p) => p.morale < 35).length,
      happy: top.where((p) => p.morale >= 70).length,
    );
  }

  /// 区切りごとに、相性を目標へ寄せる(新しい選手が多い・不満がある・負けが続くと下がる)。
  void _updateChem() {
    final f = chemFactors;
    final top = me.order.take(9).toList();
    final leaders = top.where((p) => hasTrait(p, Trait.leader)).length.clamp(0, 2);
    final troublemakers = top.where((p) => hasTrait(p, Trait.troublemaker)).length;
    final target = 50 + (f.continuity - 0.5) * 20 + (me.winPct - 0.5) * 16 + (f.happy - 4) * 1.5 - f.unhappy * 6 + leaders * 3 - troublemakers * 3 + (skillOf(Skill.charisma) >= 2 ? skillOf(Skill.charisma) * 2 : 0);
    me.chem = (me.chem + ((target - me.chem) * 0.4).round()).clamp(0, 100);
  }

  void _updateMorale() {
    final order = me.order;
    final mins = me.playMinutes();
    final byOvr = [...me.roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final pct = me.winPct;
    for (var i = 0; i < order.length; i++) {
      final p = order[i];
      final expected = byOvr.indexOf(p);
      var d = 0;
      if (me.minutes.isEmpty) {
        if (i >= expected + 2 && expected < 9) d -= 3 + (i - expected);
        if (i < expected) d += 2;
      } else {
        // 出場時間を決めたときは、期待より何分少ないか・多いかで
        final diff = mins[i] - expectedMinutes(p);
        if (diff <= -6 && expectedMinutes(p) >= 8) d -= 3 + (-diff) ~/ 4;
        if (diff >= 4) d += 2;
      }
      if (pct >= 0.6) d += 3;
      if (pct < 0.4) d -= 3;
      // 勝ちたい選手は、勝ち負けに敏感
      if (personalityOf(p).value == Value.win) d += pct >= 0.55 ? 1 : pct < 0.4 ? -2 : 0;
      if (skillOf(Skill.charisma) > 0) d += 1;
      d += me.training == 2 && hasTrait(p, Trait.grinder) ? 0 : const [1, 0, -1][me.training.clamp(0, 2)];
      final before = p.morale;
      p.morale = (p.morale + d).clamp(0, 100);
      if (before >= 20 && p.morale < 20) _log('${p.name}(${me.def.short})がトレードを希望');
    }
  }

  void _makeIncoming() {
    if (block >= tradeDeadlineBlock) return;
    final others = [for (var i = 0; i < teams.length; i++) if (i != mine) i];
    rng.shuffle(others);
    // トレードブロックに選手がいれば、まずその選手への申し込みを探す
    final onBlock = tradeBlock.where((id) => me.roster.any((p) => p.id == id)).toList();
    if (onBlock.isNotEmpty) {
      final id = onBlock[rng.nextInt(onBlock.length)];
      for (final t in others.take(8)) {
        final o = blockOfferFrom(teams, picks, mine, t, id, season, hardness: _hard(t));
        if (o != null) {
          incoming = o;
          final name = me.roster.firstWhere((p) => p.id == id).name;
          _mail(Sender.league, '${teams[t].def.short}が$nameに申し込み', 'トレードブロックの$nameが欲しいという。進行の画面で中身を見て返事できる。');
          return;
        }
      }
    }
    for (final t in others.take(4)) {
      final o = makeIncomingOffer(teams, picks, mine, t, season, hardness: _hard(t));
      if (o != null) {
        incoming = o;
        _mail(Sender.league, '${teams[t].def.short}からトレードの申し込み', '進行の画面で、出す選手と受け取る選手を見て返事できる。');
        return;
      }
    }
  }

  /// 届いた申し込みを受ける。
  bool acceptIncoming() {
    final o = incoming;
    if (o == null || !canTrade) return false;
    incoming = null;
    if (!judgeTrade(teams, picks, mine, o, season, hardness: _hard(o.partner)).ok) return false;
    _logTrade(mine, o);
    applyTrade(teams, picks, mine, o);
    tradesDone++;
    return true;
  }

  void declineIncoming() => incoming = null;

  // ------------------------------------------------------------ トレードブロック

  /// トレードブロック(出してもよいと周りに知らせた自分の選手の id)。区切りのあと、この選手への申し込みが届きやすい。
  List<int> tradeBlock = [];

  /// トレードブロックに載せる・外す。載せると、本人の気持ちが少し下がる。
  void toggleTradeBlock(int id) {
    final p = _mineById(id);
    if (p == null) return;
    if (tradeBlock.remove(id)) return;
    tradeBlock.add(id);
    p.morale = (p.morale - 5).clamp(0, 100);
  }

  /// サイン＆トレードができない理由(できるなら null)。契約が切れる自分の選手を、再契約したうえでトレードに出す。
  String? signAndTradeProblem(Player p) {
    if (phase != Phase.contracts) return 'オフの契約の画面だけ';
    if (!expiring.contains(p.id)) return '契約が切れる選手だけ';
    if (!canTrade) return '今はトレードできない';
    return resignProblem(p);
  }

  /// サイン＆トレード: 求める条件(最長4年)で再契約して、そのままトレードブロックに載せる。
  /// 載せたあと、トレードの画面で申し込みを集められる(再契約した選手を出す形なので、受けるチームの年俸の決まりも通る)。
  bool signAndTrade(int id) {
    final p = _mineById(id);
    if (p == null || signAndTradeProblem(p) != null) return false;
    final years = math.min(4, askOf(p, me).maxYears);
    resign(id, years);
    if (!tradeBlock.contains(id)) tradeBlock.add(id);
    _log('サイン＆トレード: ${p.name}と再契約し、トレードブロックに載せた');
    return true;
  }

  /// トレードブロックの選手への、いま届く申し込み(チームごとに1つ。こちらに値打ちの高い順)。
  List<TradeOffer> blockOffers(int id) {
    if (!canTrade) return const [];
    final out = [
      for (var t = 0; t < teams.length; t++)
        if (t != mine) blockOfferFrom(teams, picks, mine, t, id, season, hardness: _hard(t)),
    ].whereType<TradeOffer>().toList();
    double value(TradeOffer o) =>
        o.get.fold(0.0, (n, pid) => n + playerValue(teams[o.partner].roster.firstWhere((p) => p.id == pid), me.mode)) +
        o.getPicks.fold(0.0, (n, i) => n + pickValue(picks[i], me.mode, 15, season));
    out.sort((a, b) => value(b).compareTo(value(a)));
    return out;
  }

  /// 申し込みを受けて成立させる(トレードブロックから選んだもの)。
  bool acceptBlockOffer(TradeOffer o) {
    final ok = propose(o);
    if (ok) tradeBlock.removeWhere((id) => o.give.contains(id));
    return ok;
  }

  // ------------------------------------------------------------ 月間MVP

  /// 区切りの初めの、選手ごとの成績(id → [試合, 点, リバウンド, アシスト])。区切りの成績はここからの差。
  Map<int, List<int>> blockBase = {};

  /// 月間MVP(区切りごとに東西1人ずつ。古い順)。
  List<Award> monthly = [];

  void _snapshotBlock() {
    blockBase = {
      for (final t in teams)
        for (final p in t.roster) p.id: [p.stats.gp, p.stats.pts, p.stats.reb, p.stats.ast],
    };
  }

  /// 区切りを終えたら、東西で区切りのあいだいちばん良かった選手を選ぶ。
  void _giveMonthly() {
    for (final east in [true, false]) {
      (Player, Team, double, String)? best;
      for (final t in teams.where((t) => t.east == east)) {
        for (final p in t.roster) {
          final b = blockBase[p.id] ?? const [0, 0, 0, 0];
          final gp = p.stats.gp - b[0];
          if (gp < 10) continue;
          final ppg = (p.stats.pts - b[1]) / gp, rpg = (p.stats.reb - b[2]) / gp, apg = (p.stats.ast - b[3]) / gp;
          final score = ppg + 0.6 * rpg + 0.9 * apg + t.winPct * 10;
          if (best == null || score > best.$3) {
            best = (p, t, score, '${ppg.toStringAsFixed(1)}点 ${rpg.toStringAsFixed(1)}リ ${apg.toStringAsFixed(1)}ア');
          }
        }
      }
      if (best == null) continue;
      monthly.add(Award(season: season, kind: AwardKind.month, player: best.$1.id, name: best.$1.name, team: best.$2.index, line: best.$4, block: block));
      if (best.$2.index == mine) {
        _mail(Sender.league, '${best.$1.name}が月間MVP', '${east ? '東' : '西'}地区の月間MVPに選ばれた。${best.$4}');
        best.$1.morale = (best.$1.morale + 5).clamp(0, 100);
      }
    }
  }

  /// 試合をまとめて進める先。
  bool get canSimToDeadline => phase == Phase.season && block < tradeDeadlineBlock;

  /// プレーオフ。地区ごとに1〜6位はそのまま、7〜10位はプレーインで2枠を争う。どの回戦も4勝で勝ち抜け。
  void playPlayoffs() {
    if (phase != Phase.playoffs) return;
    playoffs = [];
    final champs = <int>[];
    for (final east in [true, false]) {
      final st = standings(teams, east: east).map((t) => t.index).toList();
      // プレーイン: 7位と8位の勝者が7番目。敗者と、9位と10位の勝者が8番目を争う
      final a = _series(st[6], st[7], 1, 0);
      final b = _series(st[8], st[9], 1, 0);
      final c = _series(a.loser, b.winner, 1, 0);
      final seeds = [...st.take(directSeeds), a.winner, c.winner];
      // 1回戦: 1-8・4-5・2-7・3-6。勝ち上がりは山の形のまま
      var alive = [seeds[0], seeds[7], seeds[3], seeds[4], seeds[1], seeds[6], seeds[2], seeds[5]];
      for (var round = 1; alive.length > 1; round++) {
        final next = <int>[];
        for (var k = 0; k < alive.length; k += 2) {
          final hi = st.indexOf(alive[k]) < st.indexOf(alive[k + 1]) ? alive[k] : alive[k + 1];
          final lo = hi == alive[k] ? alive[k + 1] : alive[k];
          next.add(_series(hi, lo, 4, round).winner);
        }
        alive = next;
      }
      champs.add(alive.single);
    }
    // ファイナルは、シーズンの成績が上のほうがホーム
    final all = standings(teams).map((t) => t.index).toList();
    final hi = all.indexOf(champs[0]) < all.indexOf(champs[1]) ? champs[0] : champs[1];
    _series(hi, hi == champs[0] ? champs[1] : champs[0], 4, 4);
    _giveAwards();
    _closeSeason();
    _log('優勝: ${teams[champion].name}(ファイナルで${teams[finals!.loser].def.short}を${finals!.winner == finals!.high ? finals!.highWins : finals!.lowWins}勝${finals!.winner == finals!.high ? finals!.lowWins : finals!.highWins}敗)');
    phase = Phase.seasonEnd;
  }

  Series _series(int high, int low, int need, int round) {
    final s = Series(high: high, low: low, need: need, round: round)..play(teams, rng, mine);
    playoffs.add(s);
    return s;
  }

  /// ファイナル。
  Series? get finals => playoffs.isNotEmpty && playoffs.last.round == 4 ? playoffs.last : null;

  int get champion => finals?.winner ?? -1;

  /// 自分のチームのプレーオフの結果(0〜5)。
  int get myResult {
    if (finals == null) return 0;
    if (champion == mine) return 5;
    for (final s in playoffs) {
      if (s.round >= 1 && s.loser == mine) return s.round;
    }
    return 0;
  }

  /// 自分の地区での順位(1始まり)。
  int get confRank => standings(teams, east: me.east).indexWhere((t) => t.index == mine) + 1;

  // ---------------------------------------------------------------- 記録帳

  /// 記録帳(種類 → いちばんの記録)。自分のチームの試合とシーズンの成績から。破ると知らせる。
  Map<String, RecordEntry> records = {};

  void _setRecord(String key, double v, String name) {
    final old = records[key];
    if (old != null && v <= old.value) return;
    records[key] = RecordEntry(v, name, season);
    if (old != null) _log('記録更新: ${recordLabels[key]} ${recordText(key, v)}($name・前は${recordText(key, old.value)})');
  }

  // ---------------------------------------------------------------- ライバル

  /// 相手ごとの通算の対戦(チームの番号 → [勝ち, 負け, プレーオフで当たった回数, プレーオフの勝ち越し(勝ち−負け)])。
  Map<int, List<int>> h2h = {};

  List<int> _h2h(int opp) => h2h.putIfAbsent(opp, () => [0, 0, 0, 0]);

  /// 宿敵(対戦が多く、プレーオフで当たった相手ほど上)。まだ決まらなければ null。
  int? get rival {
    int? best;
    var bestScore = 5;
    for (final e in h2h.entries) {
      final r = e.value;
      final score = r[0] + r[1] + r[2] * 6;
      if (score > bestScore) {
        bestScore = score;
        best = e.key;
      }
    }
    return best;
  }

  /// 宿敵との対戦の説明。
  String rivalLine(int opp) {
    final r = h2h[opp] ?? [0, 0, 0, 0];
    return '通算 ${r[0]}勝${r[1]}敗・プレーオフで${r[2]}回対戦';
  }

  /// 自分のチームの試合の、選手の数字から1試合の記録を見る。
  void _checkGameRecords(List<GameResult> games) {
    for (final g in games) {
      if (g.involves(mine)) {
        final opp = g.home == mine ? g.away : g.home;
        _h2h(opp)[g.winner == mine ? 0 : 1]++;
      }
      for (final l in [...g.box, ...g.oppBox]) {
        _setRecord('g_pts', l.pts.toDouble(), l.name);
        _setRecord('g_reb', l.reb.toDouble(), l.name);
        _setRecord('g_ast', l.ast.toDouble(), l.name);
        _setRecord('g_stl', l.stl.toDouble(), l.name);
        _setRecord('g_blk', l.blk.toDouble(), l.name);
      }
    }
    if (me.streak > 0) _setRecord('s_streak', me.streak.toDouble(), me.def.short);
  }

  /// シーズンの終わりに、シーズンの記録を見る(40試合以上出た選手の平均)。
  void _checkSeasonRecords() {
    _setRecord('s_wins', me.wins.toDouble(), me.def.short);
    for (final t in teams) {
      for (final p in t.roster) {
        final s = p.stats;
        if (s.gp < 40) continue;
        _setRecord('s_ppg', s.pts / s.gp, p.name);
        _setRecord('s_rpg', s.reb / s.gp, p.name);
        _setRecord('s_apg', s.ast / s.gp, p.name);
      }
    }
  }

  void _closeSeason() {
    _checkSeasonRecords();
    for (final s in playoffs) {
      if (s.round >= 1 && (s.high == mine || s.low == mine)) {
        final opp = s.high == mine ? s.low : s.high;
        final r = _h2h(opp);
        r[2]++;
        r[3] += s.winner == mine ? 1 : -1;
      }
    }
    final res = myResult;
    lastTax = luxuryTaxTrust(me.payroll);
    // ぜいたく税は、超えた分の1.5倍を払う。プレーオフのホームの試合も入場収入になる
    if (me.payroll > taxLine) costs += ((me.payroll - taxLine) * 1.5).round();
    final poHome = playoffs.where((s) => s.round >= 1 && (s.high == mine || s.low == mine)).fold(0, (n, s) => n + (s.games.where((g) => g.home == mine).length));
    _earn(Income.playoffs, poHome * ((gatePerGame + concessionPerGame) * 1.5).round());
    lastProfit = profit;
    for (final g in goals) {
      g.met = goalOk(g);
    }
    final goalDelta = goals.where((g) => g.kind != GoalKind.wins).fold(0, (n, g) => n + (g.met! ? goalTrust : -goalTrust));
    // 人気: 勝率とプレーオフで動く
    hype = (hype + ((me.winPct - 0.5) * 40).round() + const [-4, 3, 6, 9, 12, 16][res] + mediaHype).clamp(0, 100);
    // オーナーの性格に合う年は、信頼に上乗せが付く(嫌われて減ることはない)
    final liked = switch (ownerType) {
      OwnerType.winNow => res >= 3 ? 5 : 0,
      OwnerType.steady => profit >= 0 && lastTax == 0 ? 3 : 0,
      OwnerType.youth => goals.any((g) => g.kind == GoalKind.youth && g.met == true) ? 5 : 0,
      OwnerType.popular => me.winPct > 0.5 ? 3 : 0,
    };
    // 予算を守った年(上限か税の手前を約束していたとき)
    final kept = budgetLevel < 2 && me.payroll <= budgetCap ? (budgetLevel == 0 ? 6 : 3) : 0;
    final raw = ((me.wins - target) * 1.5).round() + resultTrust[res] - lastTax + goalDelta + liked + kept;
    // オーナーの厳しさ: 信頼が減るときだけ、難しさの倍率をかける
    final delta = raw < 0 ? (raw * difficulty.ownerStrict).round() : raw;
    trust = (trust + delta).clamp(0, 100);
    history.add(SeasonRecord(season: season, wins: me.wins, losses: me.losses, rank: confRank, result: res, trustAfter: trust, target: target));
    if (trust <= 0) fired = true;
    _awardRating(res);
    if (finals != null) champs.add([season, champion, finals!.loser]);
    // 選手の年ごとの成績を残す(シーズンの終わりにいたチームで)
    for (final t in teams) {
      for (final p in t.roster) {
        final s = p.stats;
        if (s.gp > 0) p.career.add([season, t.index, s.gp, s.pts, s.reb, s.ast]);
      }
    }
  }

  /// 前のシーズンの、オーナーの信頼の変わり方。
  int get lastTrustDelta {
    if (history.isEmpty) return 0;
    final prev = history.length >= 2 ? history[history.length - 2].trustAfter : startTrust;
    return history.last.trustAfter - prev;
  }

  /// 解任を取り消す(動画を見たとき。1度だけ)。信頼は少し戻る。
  bool get canRescue => fired && !rescueUsed && phase == Phase.seasonEnd;

  void rescue() {
    if (!canRescue) return;
    rescueUsed = true;
    fired = false;
    trust = 15;
    history.last = SeasonRecord(
      season: history.last.season,
      wins: history.last.wins,
      losses: history.last.losses,
      rank: history.last.rank,
      result: history.last.result,
      trustAfter: trust,
      target: history.last.target,
    );
  }

  /// 任期を自分で終える(シーズンの結果を見たあと)。任期に上限は無いので、やめたいときはここで。
  void endCareer() {
    if (phase == Phase.seasonEnd) phase = Phase.over;
  }

  // ---------------------------------------------------------------- GM の格

  /// GM の格の通算の点と、最初の10シーズンで取った点(ランキングはこちらで比べる)。
  int gmPoints = 0;
  int gmPointsFirst10 = 0;

  /// 直前のシーズンの点の内訳(難しさの倍率をかけたあと)。
  List<RatingPart> lastRating = [];

  int get gmLevel => ratingLevelOf(gmPoints);

  // ---------------------------------------------------------------- 技能

  /// 技能の段階([Skill] の順に 0〜3)。
  List<int> skills = List.filled(Skill.values.length, 0);

  int skillOf(Skill s) => skills[s.index];

  /// 使える技能の点(格が1つ上がるごとに1点)。
  int get skillPoints => gmLevel - 1 - skills.fold(0, (a, b) => a + b);

  String? skillProblem(Skill s) {
    if (skillOf(s) >= skillMax) return 'もう最高の段階';
    if (skillPoints <= 0) return '技能の点が無い(格が上がると1点)';
    return null;
  }

  void learnSkill(Skill s) {
    if (skillProblem(s) != null) return;
    skills[s.index]++;
  }

  /// 代理人との値切りの最大の往復(交渉の技能で1回増える)。
  int get haggleLimit => maxHaggle + (skillOf(Skill.negotiation) >= 3 ? 1 : 0);

  /// 直前のシーズンで格が上がったか(上がる前の段階。上がっていなければ null)。
  int? levelBefore;

  /// シーズンの結果から点をつける。賞のあと、信頼を動かしたあとに呼ぶ。
  void _awardRating(int res) {
    final scale = difficulty.ratingScale;
    final parts = <RatingPart>[];
    void add(String label, int raw) {
      final pts = (raw * scale).round();
      if (pts > 0) parts.add(RatingPart(label, pts));
    }

    if (res > 0) add(res == 5 ? '優勝' : res == 4 ? 'ファイナルまで進んだ' : res == 3 ? '地区決勝まで進んだ' : res == 2 ? '2回戦まで進んだ' : 'プレーオフに出た', playoffPoints[res]);
    if (me.wins > me.losses) add('勝ち越し', 5);
    for (final a in awardsOf(season)) {
      if (a.team != mine || !draftedIds.contains(a.player)) continue;
      final raw = switch (a.kind) {
        AwardKind.mvp || AwardKind.finalsMvp => 20,
        AwardKind.month => 0,
        AwardKind.allLeague1 || AwardKind.allLeague2 || AwardKind.allLeague3 => 5,
        _ => 10,
      };
      if (raw > 0) add('自分で指名した${a.name}が${a.kind.label}', raw);
    }
    for (final g in goals) {
      if (g.met == true) add('オーナーの目標「${g.kind.label}」', 5);
    }
    if (lastProfit > 0 && !goals.any((g) => g.kind == GoalKind.profit && g.met == true)) add('黒字', 5);
    final before = gmLevel;
    final total = parts.fold(0, (n, x) => n + x.points);
    gmPoints += total;
    if (history.length <= 10) gmPointsFirst10 += total;
    lastRating = parts;
    levelBefore = gmLevel > before ? before : null;
  }

  // ---------------------------------------------------------------- オフ

  /// シーズンを閉じてオフへ(成長・引退・契約の年数を進め、ドラフトの準備をする)。
  void toOffseason() {
    if (phase != Phase.seasonEnd) return;
    if (fired) {
      phase = Phase.over;
      return;
    }
    news = [];
    growth = [];
    optionPending = [];
    for (final p in [...freeAgents, ...me.roster]) {
      p
        ..tenDay = 0
        ..tenDayCount = 0;
    }
    for (final t in teams) {
      t.deadCap = t.deadLater.isEmpty ? 0 : t.deadLater.removeAt(0);
      final retired = <Player>[];
      for (final p in t.roster) {
        final start = p.ovr;
        var d = ageOneYear(p, rng);
        final byAge = d;
        var byCoach = 0, byTraining = 0;
        p.injured = 0;
        // コーチの段階で若手の伸びが変わる(力が上がる年だけ)
        final coach = t.staffLevel(Staff.development);
        if (p.age <= 26 && d >= 0) {
          var b = coach == 3 && rng.chance(0.55) ? 1 : coach == 1 && rng.chance(0.4) ? -1 : 0;
          // 育成の技能(自分のチームだけ。段階が0なら乱数を使わない)
          if (t.index == mine && skillOf(Skill.development) > 0 && rng.chance(0.12 * skillOf(Skill.development))) b += 1;
          if (b != 0) {
            p.ovr = (p.ovr + b).clamp(35, 99);
            if (p.pot < p.ovr) p.pot = p.ovr;
            p.lastDelta += b;
            d += b;
            byCoach = b;
          }
        }
        if (t.index == mine) {
          byTraining = _train(p, d);
          d += byTraining;
        }
        // 出場時間と性格(どのチームも。乱数は使わない)
        final extra = extraGrowth(p, d);
        for (final (label, v) in extra) {
          p.ovr = (p.ovr + v).clamp(35, 99);
          if (label == Trait.lateBloomer.label && v > 0 && p.pot < p.ovr + 1) p.pot = math.min(99, p.ovr + 1);
          if (p.pot < p.ovr) p.pot = p.ovr;
          p.lastDelta += v;
          d += v;
        }
        if (t.index == mine) {
          growth.add(GrowthLine(name: p.name, age: p.age, before: start, after: p.ovr, focus: p.focus, parts: [
            if (byAge != 0) (p.age <= 25 ? '年齢(若さ)' : '年齢', byAge),
            if (byCoach != 0) ('育成コーチ', byCoach),
            if (byTraining != 0) ('練習の強さ', byTraining),
            ...extra,
          ]));
        }
        p.years--;
        p.tenure++;
        if (p.nextSalary != null) {
          p.salary = p.nextSalary!;
          p.nextSalary = null;
        } else if (p.raise > 0 && p.years > 0) {
          p.salary = (p.salary * (1 + p.raise / 100)).round().clamp(minSalary, maxSalaryFor(p.exp));
        }
        if (p.years <= 0) p.raise = 0;
        // 選択権の年が来た選手: 次の年を使うか決める(自分のチームは契約の画面で。相手はここで決める)
        if (p.optionYears > 0 && p.years == p.optionYears) {
          if (t.index == mine) {
            optionPending.add(p.id);
          } else if (p.ovr >= 55 || playerValue(p, t.mode) > 8) {
            _exerciseOption(p);
          } else {
            p
              ..years = 0
              ..optionYears = 0;
          }
        }
        if (t.index == mine) {
          if (d >= 4) news.add('${p.name}が大きく伸びた(OVR ${shown(p.ovr)})');
          if (d <= -4) news.add('${p.name}の力が落ちた(OVR ${shown(p.ovr)})');
        }
        if (retires(p, rng)) retired.add(p);
      }
      for (final p in retired) {
        t.roster.remove(p);
        _toHall(p, t.index);
        _noteRetiree(p);
        if (t.index == mine) news.add('${p.name}(${p.age}歳)が引退した');
        if (p.ovr >= 72 || t.index == mine) _log('引退: ${p.name}(${t.def.short}・${p.age}歳)');
      }
    }
    for (final p in freeAgents) {
      ageOneYear(p, rng);
    }
    freeAgents.removeWhere((p) {
      final gone = retires(p, rng);
      if (gone) {
        _toHall(p, p.career.isEmpty ? -1 : p.career.last[1]);
        _noteRetiree(p);
      }
      return gone || p.ovr < 45;
    });
    // 2ウェイの選手も年を取る。契約が切れたら自由契約に出る(戻したければ自由契約から取り直す)
    for (final p in [...me.twoWay]) {
      final start = p.ovr;
      ageOneYear(p, rng);
      p.years--;
      if (retires(p, rng)) {
        me.twoWay.remove(p);
        news.add('${p.name}(${p.age}歳・2ウェイ)が引退した');
      } else if (p.years <= 0) {
        me.twoWay.remove(p);
        p.salary = askOf(p, teams[(mine + 1) % teams.length]).salary;
        freeAgents.add(p);
        news.add('${p.name}の2ウェイ契約が切れた(自由契約へ)');
      } else if (p.ovr - start >= 4) {
        news.add('${p.name}(2ウェイ)が大きく伸びた(OVR ${shown(p.ovr)})');
      }
    }
    offStartIds = [for (final p in me.roster) p.id];
    offStartRank = strengthRank(mine);
    // ドラフト
    // 1回戦に出たチーム(プレーインを勝ち抜いたチームを含む)は、くじに入らない
    final inPlayoffs = {for (final s in playoffs.where((s) => s.round == 1)) ...[s.high, s.low]}.toList();
    lotteryPre = standings(teams).reversed.map((t) => t.index).where((i) => !inPlayoffs.contains(i)).toList();
    order = draftOrder(teams, picks, season, inPlayoffs, rng);
    _applySwaps();
    for (final i in conveyedBack) {
      _log('保護: ${teams[picks[i].from].def.short}の1巡目は上位${picks[i].protect}位に入ったので、${teams[picks[i].from].def.short}に戻った');
    }
    final main = makeProspects(rng, nextId, order.length + 8, name: _uniqueName);
    // 層を厚くする(2巡目の後半にも選ぶ余地を残す)。リーグの続きをずらさないよう、別の乱数で作る
    final deepRng = Rng(seed * 104723 + season * 613 + 29);
    final used = {..._usedNames, for (final p in main) p.player.name};
    String deepName() {
      var n = randomName(deepRng);
      for (var i = 0; i < 200 && used.contains(n); i++) {
        n = randomName(deepRng);
      }
      used.add(n);
      return n;
    }

    prospects = [...main, ...makeProspects(deepRng, nextId, deepProspects, name: deepName, deep: true)];
    board = [];
    draftAt = 0;
    draftLog = [];
    scoutsLeft = 1 + me.staffLevel(Staff.scout) + skillOf(Skill.eye);
    scoutAdUsed = false;
    phase = Phase.draft;
    _advanceDraft();
  }

  /// 今の指名権(ドラフト中)。
  DraftPick? get currentPick => phase == Phase.draft && draftAt < order.length ? picks[order[draftAt]] : null;

  bool get myTurn => currentPick?.owner == mine;

  /// ドラフトで数える人数(契約が切れる選手は数えない)。
  int get signedCount => me.roster.where((p) => p.years > 0).length;

  /// 指名できない理由(できるなら null)。
  String? get draftProblem {
    if (signedCount >= offseasonRoster) return '契約中の選手が$offseasonRoster人いて、これ以上は指名できない。チームの画面で放すか、見送る';
    return null;
  }

  bool get canDraftPick => myTurn && draftProblem == null;

  /// チームのポジションごとの人数。
  Map<Pos, int> posCounts(Team t) => {for (final p in Pos.values) p: t.roster.where((x) => x.pos == p).length};

  /// いちばん人数の少ないポジション(同じなら PG から)。
  Pos _neededPos(Team t) {
    final c = posCounts(t);
    return Pos.values.reduce((a, b) => c[b]! < c[a]! ? b : a);
  }

  /// 自分の番まで、相手のチームの指名を進める。
  void _advanceDraft() {
    while (phase == Phase.draft && draftAt < order.length && picks[order[draftAt]].owner != mine) {
      final pick = picks[order[draftAt]];
      final t = teams[pick.owner];
      final p = aiDraftChoice(prospects, t.mode, rng, counts: posCounts(t));
      _sign(t, p, draftAt);
      draftAt++;
    }
    if (draftAt >= order.length) _endDraft();
  }

  void _sign(Team t, Prospect p, int overall) {
    p.pickedBy = t.index;
    p.pickNo = overall + 1;
    draftLog.add(prospects.indexOf(p));
    if (overall == 0) _log('ドラフト全体1位: ${p.player.name}(${t.def.short})');
    final (sal, yrs) = rookieContract(overall);
    p.player
      ..salary = sal
      ..years = yrs
      ..optionYears = rookieOptionYears(overall)
      ..drafted = t.name;
    t.roster.add(p.player);
    if (t.index == mine) draftedIds.add(p.player.id);
  }

  /// 自分の番で、候補を指名する。
  void pickProspect(Prospect p) {
    if (!canDraftPick || p.pickedBy != null) return;
    _sign(me, p, draftAt);
    draftAt++;
    _advanceDraft();
  }

  /// 自分の番を飛ばす(指名しない)。
  void passPick() {
    if (!myTurn) return;
    draftAt++;
    _advanceDraft();
  }

  /// 自分のボード(注目の候補の選手 id。印を付けた順)。
  List<int> board = [];

  void toggleBoard(Prospect p) {
    if (!board.remove(p.player.id)) board.add(p.player.id);
  }

  /// 次の自分の指名までに、ほかのチームが何人取るか(自分の番なら0、指名権が無ければ null)。
  int? picksBeforeMine() {
    for (var k = draftAt; k < order.length; k++) {
      if (picks[order[k]].owner == mine) return k - draftAt;
    }
    return null;
  }

  void scoutProspect(Prospect p) {
    if (phase != Phase.draft || scoutsLeft <= 0 || p.scouted || p.pickedBy != null) return;
    scoutsLeft--;
    scout(p, rng, level: me.staffLevel(Staff.scout));
  }

  /// 動画を見てスカウトを2回増やす(ドラフトごとに1度)。
  bool get canAddScouts => phase == Phase.draft && !scoutAdUsed && draftAt < order.length;

  void addScouts() {
    if (!canAddScouts) return;
    scoutAdUsed = true;
    scoutsLeft += 2;
  }

  void _endDraft() {
    // 指名されなかった候補の一部は、最低年俸の自由契約に
    for (final p in prospects.where((p) => p.pickedBy == null).take(4)) {
      p.player
        ..salary = minSalary
        ..years = 1;
      freeAgents.add(p.player);
    }
    // 指名権を1年進める
    picks.removeWhere((p) => p.season <= season);
    _fillPicks(season + 1);
    _startContracts();
  }

  void _startContracts() {
    haggled = [];
    rfa = [];
    sheet = null;
    capYear++;
    mleUsed = false;
    phase = Phase.contracts;
    expiring = [for (final p in me.roster) if (p.years <= 0) p.id];
    // 相手のチームの契約切れ
    for (final t in teams) {
      if (t.index == mine) continue;
      for (final p in [...t.roster.where((p) => p.years <= 0)]) {
        final ask = askOf(p, t);
        final keep = (p.ovr >= 62 || playerValue(p, t.mode) > 10) && t.payroll - p.salary + ask.salary <= secondApron - capScaled(40) && rng.chance(0.95);
        if (keep) {
          p
            ..salary = ask.salary
            ..years = 1 + rng.nextInt(ask.maxYears);
        } else {
          t.roster.remove(p);
          freeAgents.add(p);
        }
      }
    }
    while (freeAgents.where((p) => p.salary <= minSalary).length < 6) {
      freeAgents.add(_filler());
    }
    for (final p in freeAgents) {
      p.salary = askOf(p, me).salary;
    }
    freeAgents.sort((a, b) => b.ovr.compareTo(a.ovr));
    faDay = 0;
    bids = {};
    faLog = [];
    faMoves = [];
    coachPool = _makeCoaches(season, start: false);
    // 引退した力のある選手が、コーチやスカウトの候補に加わる
    for (final r in retirees) {
      final role = Staff.values[(r[0] as String).length % Staff.values.length];
      coachPool.add(Coach(name: '${r[0]}(元選手)', role: role, rating: ((r[1] as int) * 0.9).round().clamp(55, 92)));
    }
    retirees = [];
  }

  /// 選手が求める年俸。弱いチームには高く、強いチームには少し安く言う。
  Ask askOf(Player p, Team t) {
    final last = history.isEmpty ? null : history.last;
    var f = 1.0;
    if (t.index == mine && last != null) {
      if (last.champion) {
        f = 0.92;
      } else if (last.wins < gamesPerSeason * 0.4) {
        f = 1.12;
      }
    }
    // 気持ちが低い選手は、残るなら高く求める
    if (t.index == mine) f *= 1 + (60 - p.morale).clamp(0, 60) / 250;
    if (t.index == mine && t.roster.contains(p) && p.tenure >= 1 && hasTrait(p, Trait.hometown)) f *= 0.9;
    final sal = p.ovr < 58 ? minSalary : (fairSalary(p.ovr, p.age) * f).round().clamp(minSalary, maxSalaryFor(p.exp));
    final own = t.index == mine && t.roster.contains(p);
    final maxYears = p.age >= 33 ? 1 : p.age >= 30 ? 2 : own ? ownMaxYears : 4;
    return Ask(sal, maxYears);
  }

  Player? _mineById(int id) {
    for (final p in me.roster) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 契約切れの選手と再契約できない理由(できるなら null)。再契約は年俸の上限を超えてもよい(固い上限は無い。ぜいたく税と信頼で重くなる)。
  String? resignProblem(Player p, {int? salary}) {
    if (p.morale < 20) return '${p.name}は移籍を希望していて、残らない';
    final sal = salary ?? askOf(p, me).salary;
    final cap = birdLimit(p);
    if (cap != null && me.payroll - p.salary + sal > salaryCap && sal > cap) {
      return '${birdOf(p).label}では、上限を超えて再契約できるのは${money(cap)}まで(求める額は${money(sal)})';
    }
    return null;
  }

  // ---------------------------------------------------------------- バード権と例外枠

  /// 選手のバード権(在籍年数で決まる。上限を超えて再契約できる範囲が変わる)。
  Bird birdOf(Player p) => p.tenure >= 3 ? Bird.full : p.tenure == 2 ? Bird.early : Bird.none;

  /// 上限を超える再契約で出せる年俸の上限(フルバード権は無制限なので null)。
  /// アーリーは前の年俸の175%、バード権なしは120%＋100万ドル。上限に空きがあれば、この制限は無い。
  int? birdLimit(Player p) => switch (birdOf(p)) {
        Bird.full => null,
        Bird.early => math.max(minSalary, (p.salary * 1.75).round()),
        Bird.none => math.max(minSalary, (p.salary * 1.2).round() + 10),
      };

  /// 今の例外枠の年(オフの契約が始まるたびに1つ進む)。
  int capYear = 0;

  /// 中くらいの例外枠(2種類のうち1つ)を、今の年に使ったか。
  bool mleUsed = false;

  /// 2年ごとの例外枠を最後に使った年([capYear])。
  int biennialYear = -9;

  bool get biennialReady => capYear - biennialYear >= 2;

  /// 年俸 [salary] で自由契約の選手を取るのに使える例外枠(上限を超えるときだけ要る。使えなければ null)。
  /// [base] は今の年俸の合計(申し込み中の分を足して数えるとき用)。第2の壁を超えると、どの例外枠も使えない。
  CapException? exceptionFor(int salary, {int? base}) {
    final after = (base ?? me.payroll) + salary;
    if (after > secondApron) return null;
    if (after <= firstApron) {
      if (biennialReady && salary <= biennialSalary) return CapException.biennial;
      if (!mleUsed && salary <= mleSalary) return CapException.mle;
      return null;
    }
    if (!mleUsed && salary <= taxMleSalary) return CapException.taxMle;
    return null;
  }

  /// いま自由契約の選手に出せる年俸の上限と、その元(上限の空き・例外枠・最低年俸)。申し込み中の分は差し引く。
  (int, String) get maxOfferNow {
    if (phase == Phase.season) return (minSalary, 'シーズン中は最低年俸だけ');
    final base = me.payroll + _bidTotal(mine);
    final room = salaryCap - base;
    var best = (minSalary, '最低年俸');
    if (room > best.$1) best = (room, '上限の空き');
    for (final (amt, label) in [(mleSalary, '中くらいの例外枠'), (taxMleSalary, '課税者の例外枠'), (biennialSalary, '2年ごとの例外枠')]) {
      if (amt > best.$1 && exceptionFor(amt, base: base) != null) best = (amt, label);
    }
    return best;
  }

  void _useException(CapException e) {
    if (e == CapException.biennial) {
      biennialYear = capYear;
    } else {
      mleUsed = true;
    }
  }

  void resign(int id, int years) {
    final p = _mineById(id);
    if (phase != Phase.contracts || p == null || !expiring.contains(id) || resignProblem(p) != null) return;
    final ask = askOf(p, me);
    p
      ..salary = ask.salary
      ..years = years.clamp(1, ask.maxYears);
    p.raise = p.years >= 2 ? ownRaisePct : 0;
    expiring.remove(id);
  }

  // ---------------------------------------------------------------- チームの選択権

  /// チームの選択権の年が来て、使うか決める自分の選手(id)。決めないまま契約を終えると、使ったことになる。
  List<int> optionPending = [];

  /// 選択権を使ったときの年俸(新人の契約表で毎年少しずつ上がる)。
  int optionSalary(Player p) => (p.salary * 1.08).round().clamp(minSalary, maxSalaryFor(p.exp));

  void _exerciseOption(Player p) {
    p
      ..salary = optionSalary(p)
      ..optionYears -= 1;
  }

  /// 選択権を使って、次の年も契約を続ける。
  void exerciseOption(int id) {
    final p = _mineById(id);
    if (phase != Phase.contracts || p == null || !optionPending.contains(id)) return;
    optionPending.remove(id);
    _exerciseOption(p);
  }

  /// 選択権を使わない。契約は切れた扱いになり、再契約か、放すかを話し合う。
  void declineOption(int id) {
    final p = _mineById(id);
    if (phase != Phase.contracts || p == null || !optionPending.contains(id)) return;
    optionPending.remove(id);
    p
      ..years = 0
      ..optionYears = 0;
    expiring.add(id);
  }

  void letGo(int id) {
    final p = _mineById(id);
    if (phase != Phase.contracts || p == null || !expiring.contains(id)) return;
    expiring.remove(id);
    me.roster.remove(p);
    // 自分で指名した新人の契約が終わって手放すと、制限付きの自由契約になる(ほかのチームの条件に同じで残せる)
    if (draftedIds.contains(id) && p.exp <= 5 && !rfa.contains(id)) rfa.add(id);
    p.salary = askOf(p, teams[(mine + 1) % teams.length]).salary;
    freeAgents
      ..add(p)
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
  }

  // ---------------------------------------------------------------- 制限付き自由契約(オファーシート)

  /// 制限付きの自由契約の自分の選手(このオフのあいだ、ほかのチームの申し込みに同じ条件で残せる)。
  List<int> rfa = [];

  /// ほかのチームから届いたオファーシート(選手の id・チーム・年俸・年数)。自分が答えるまで保留。
  List<int>? sheet;

  /// オファーシートの選手。
  Player? get sheetPlayer => sheet == null ? null : freeAgents.where((p) => p.id == sheet![0]).firstOrNull;

  /// 同じ条件で残せない理由(残せるなら null)。上限は超えてよいが、登録の人数は守る。
  String? matchProblem() {
    if (sheet == null || sheetPlayer == null) return 'オファーシートが無い';
    if (me.roster.length - expiring.length >= offseasonRoster) return '登録がいっぱいで、残せない(先に空ける)';
    return null;
  }

  /// オファーシートと同じ条件で残す。
  bool matchSheet() {
    final p = sheetPlayer;
    if (p == null || matchProblem() != null) return false;
    final s = sheet!;
    sheet = null;
    rfa.remove(p.id);
    _signBid(p, FaBid(mine, s[2], s[3]));
    p.morale = 70;
    return true;
  }

  /// オファーシートを見送る(選手はそのチームに行く)。
  void declineSheet() {
    final p = sheetPlayer;
    final s = sheet;
    sheet = null;
    if (p == null || s == null) return;
    rfa.remove(p.id);
    _signBid(p, FaBid(s[1], s[2], s[3]));
  }

  // ---------------------------------------------------------------- 10日契約

  /// 10日契約で取れない理由(取れるなら null)。シーズン中の、最低年俸の選手だけ。同じ選手とは今季2回まで。
  String? tenDayProblem(Player p) {
    if (phase != Phase.season) return '10日契約はシーズン中だけ';
    if (me.roster.length - expiring.length >= maxRoster) return '登録が15人いっぱい';
    if (askOf(p, me).salary > minSalary) return '10日契約は最低年俸の選手だけ';
    if (p.tenDayCount >= 2) return '10日契約は2回まで。あとは今季の契約だけ';
    return null;
  }

  /// 10日契約を結ぶ(5試合。年俸は日割りで合計に数える。切れたら自由契約に戻る)。
  void signTenDay(int id) {
    final i = freeAgents.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = freeAgents[i];
    if (tenDayProblem(p) != null) return;
    p
      ..salary = tenDaySalary
      ..years = 1
      ..tenDay = tenDayRounds
      ..tenDayCount += 1
      ..tenure = 0
      ..morale = 65;
    freeAgents.removeAt(i);
    me.roster.add(p);
  }

  /// 10日契約の選手の残りの節を進める。切れたら自由契約に戻す。
  void _tickTenDay(int n) {
    for (final p in [...me.roster]) {
      if (p.tenDay <= 0) continue;
      p.tenDay -= n;
      if (p.tenDay > 0) continue;
      p.tenDay = 0;
      me.roster.remove(p);
      p
        ..salary = askOf(p, me).salary
        ..years = 1;
      freeAgents
        ..add(p)
        ..sort((a, b) => b.ovr.compareTo(a.ovr));
      _log('10日契約: ${p.name}の契約が切れた(あと${2 - p.tenDayCount}回まで10日契約を結べる)');
    }
  }

  /// 自由契約の選手と契約できない理由。
  String? signProblem(Player p, {int? salary}) {
    if (!canSign) return '今は契約できない';
    if (me.roster.length - expiring.length >= maxRoster) return '登録が15人いっぱい';
    final ask = askOf(p, me);
    final sal = salary ?? ask.salary;
    if (phase == Phase.season && ask.salary > minSalary) return 'シーズン中は最低年俸の選手だけ';
    if (phase == Phase.contracts && ask.salary > minSalary) return '申し込んで、返事を待つ(ほかのチームと競り合う)';
    if (sal > minSalary && me.payroll + sal > salaryCap && exceptionFor(sal) == null) {
      return '年俸の上限まで${money(math.max(0, me.capRoom))}しか空きがなく、使える例外枠も無い';
    }
    if (sal > minSalary) return budgetProblem(me.payroll + sal);
    return null;
  }

  void signFreeAgent(int id, int years, {int? salary}) {
    final i = freeAgents.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = freeAgents[i];
    if (signProblem(p, salary: salary) != null) return;
    final ask = askOf(p, me);
    final sal = salary ?? ask.salary;
    final ex = sal > minSalary && me.payroll + sal > salaryCap ? exceptionFor(sal) : null;
    p
      ..salary = sal
      ..years = years.clamp(1, math.min(ask.maxYears, ex?.maxYears ?? 9))
      ..tenDay = 0
      ..tenure = 0;
    freeAgents.removeAt(i);
    p.morale = 65;
    me.roster.add(p);
    if (phase == Phase.contracts) faMoves.add(FaMove(p.id, p.name, p.ovr, mine, p.salary, p.years, faDay));
    if (ex != null) _useException(ex);
  }

  // ------------------------------------------------------------ 自由契約の競り合い

  /// オフの自由契約の何日目か(0始まり。[faDays] で終わり)。
  int faDay = 0;

  /// 大物への申し込み(選手の id → 申し込んだチームごと)。
  Map<int, List<FaBid>> bids = {};

  /// このオフの自由契約の動き(新しい順)。
  List<String> faLog = [];

  /// このオフの自由契約の契約(日ごとの発表とオフのまとめ用)。
  List<FaMove> faMoves = [];

  /// 大物として競り合いになる選手か(オフの契約のあいだ、最低年俸より高く求める選手)。
  bool isBigFa(Player p) => phase == Phase.contracts && freeAgents.contains(p) && askOf(p, me).salary > minSalary;

  /// 自分の申し込み。
  FaBid? myBid(int id) => bids[id]?.where((b) => b.team == mine).firstOrNull;

  /// ほかのチームの申し込みの数。
  int rivalBids(int id) => bids[id]?.where((b) => b.team != mine).length ?? 0;

  List<(int, FaBid)> _bidsOf(int team) => [
        for (final e in bids.entries)
          for (final b in e.value)
            if (b.team == team) (e.key, b),
      ];

  /// 申し込み中の年俸の合計(ほかの選手への分。[except] は数えない)。
  int _bidTotal(int team, {int? except}) => _bidsOf(team).where((x) => x.$1 != except).fold(0, (n, x) => n + x.$2.salary);

  /// 選手がチームに向ける関心(0〜100)。昨季の勝率・優勝を狙うか・出番(先発になれるか)・人気で決まる。
  int interest(Player p, int team) {
    final t = teams[team];
    var v = 45.0 + (t.winPct - 0.5) * 80;
    if (team != mine && t.mode == TeamMode.contend) v += 8;
    final better = t.roster.where((x) => x.ovr > p.ovr && !(team == mine && expiring.contains(x.id))).length;
    v += better < 3 ? 18 : better < 5 ? 10 : better < 8 ? 0 : -12;
    if (team == mine) v += (hype - 50) / 5 + (me.chem - 50) / 10;
    // 価値観: 勝ちたい選手は勝率をさらに重く見る。忠誠と地元っ子は前のチームに残りたがる
    final pers = personalityOf(p);
    if (pers.value == Value.win) v += (t.winPct - 0.5) * 50;
    if (lastTeamOf(p) == team) {
      if (pers.value == Value.loyal) v += 10;
      if (pers.traits.contains(Trait.hometown)) v += 12;
    }
    return v.round().clamp(0, 100);
  }

  /// 選手が最後にシーズンを終えたチーム(無ければ -1)。
  int lastTeamOf(Player p) => p.career.isEmpty ? -1 : p.career.last[1];

  /// 自由契約で選手が重く見ること(価値観から。代理人から聞ける)。
  String faPriority(Player p) => switch (personalityOf(p).value) {
        Value.win => '勝てるチーム',
        Value.money => '年俸の額',
        Value.loyal => '前のチーム',
      };

  /// 申し込みの額の重み(お金の選手は額を重く、忠誠の選手は軽く見る)。
  double _moneyWeight(Player p) => switch (personalityOf(p).value) {
        Value.money => 300.0,
        Value.loyal => 170.0,
        Value.win => 220.0,
      };

  /// 申し込みの値打ち(選手の目から)。関心に、求める額との差を足す。
  double _bidScore(Player p, FaBid b) {
    final ask = askOf(p, teams[b.team]).salary;
    return interest(p, b.team) + (b.salary / ask - 1) * _moneyWeight(p) + math.min(b.years, askOf(p, me).maxYears) * 1.5;
  }

  /// 今の申し込みで、自分のチームを選ぶ見込み(0〜1)。画面用の目安で、乱数は使わない。
  double winChanceOf(Player p) {
    final mineBid = myBid(p.id);
    if (mineBid == null) return 0;
    final others = bids[p.id]!.where((b) => b.team != mine).map((b) => _bidScore(p, b));
    final best = others.isEmpty ? 0.0 : others.reduce(math.max);
    final d = _bidScore(p, mineBid) - best;
    return others.isEmpty ? 1 : (0.5 + d / 40).clamp(0.05, 0.95);
  }

  /// 大物に申し込めない理由(できるなら null)。
  String? bidProblem(Player p, {double factor = 1}) {
    if (phase != Phase.contracts || faDay >= faDays) return '今は申し込めない';
    if (!isBigFa(p)) return '最低年俸の選手は、そのまま契約できる';
    final others = _bidsOf(mine).where((x) => x.$1 != p.id).length;
    if (me.roster.length - expiring.length + others >= maxRoster) return '登録が15人いっぱい(申し込み中も数える)';
    final salary = _offerSalary(p, factor);
    final room = salaryCap - me.payroll - _bidTotal(mine, except: p.id);
    if (salary > room && exceptionFor(salary, base: me.payroll + _bidTotal(mine, except: p.id)) == null) {
      return '年俸の上限まで${money(math.max(0, room))}しか空きがなく、使える例外枠も無い(申し込み中も数える)';
    }
    return budgetProblem(me.payroll + _bidTotal(mine, except: p.id) + salary);
  }

  /// 大物に申し込む(前の申し込みは置きかえる)。[factor] は求める額に掛ける数。返事は日が進むと来る。
  bool bid(int id, int years, double factor) {
    final p = freeAgents.where((x) => x.id == id).firstOrNull;
    if (p == null || bidProblem(p, factor: factor) != null) return false;
    final list = bids.putIfAbsent(id, () => [])..removeWhere((b) => b.team == mine);
    list.add(FaBid(mine, _offerSalary(p, factor), years.clamp(1, askOf(p, me).maxYears)));
    return true;
  }

  void withdrawBid(int id) {
    bids[id]?.removeWhere((b) => b.team == mine);
    if (bids[id]?.isEmpty ?? false) bids.remove(id);
  }

  /// 自由契約を1日進める。ほかのチームが申し込み、大物の一部が行き先を決める。
  void nextFaDay() {
    if (phase != Phase.contracts || faDay >= faDays) return;
    if (sheet != null) declineSheet(); // 答えないまま日が進めば、見送り
    _aiBids();
    final chance = faDecideChance[faDay.clamp(0, faDecideChance.length - 1)];
    for (final id in bids.keys.toList()) {
      final p = freeAgents.where((x) => x.id == id).firstOrNull;
      if (p == null) {
        bids.remove(id);
        continue;
      }
      // 決めるときに、まだ取れるチームの申し込みだけ
      final list = bids[id]!.where((b) {
        final t = teams[b.team];
        final count = b.team == mine ? t.roster.length - expiring.length : t.roster.length;
        if (count >= maxRoster) return false;
        if (t.payroll + b.salary <= salaryCap) return true;
        return b.team == mine && exceptionFor(b.salary) != null;
      }).toList();
      if (list.isEmpty) {
        bids.remove(id);
        continue;
      }
      if (!rng.chance(chance)) continue;
      final best = list.reduce((a, b) => _bidScore(p, a) >= _bidScore(p, b) ? a : b);
      bids.remove(id);
      if (best.team != mine && rfa.contains(p.id) && sheet == null) {
        sheet = [p.id, best.team, best.salary, best.years];
        _mail(Sender.agent, '${p.name}にオファーシート', '${teams[best.team].name}が${best.years}年 ${money(best.salary)}を出した。同じ条件で残すか、見送るか。答えないまま日が進むと、見送りになる。');
        continue;
      }
      _signBid(p, best);
      if (best.team != mine && list.any((b) => b.team == mine)) {
        _mail(Sender.agent, '${p.name}は${teams[best.team].def.short}を選んだ',
            '申し込みに感謝しつつ、${teams[best.team].name}と${best.years}年 ${money(best.salary)}で契約した。');
      }
    }
    faDay++;
  }

  void _signBid(Player p, FaBid b) {
    freeAgents.remove(p);
    p
      ..salary = b.salary
      ..years = b.years;
    final t = teams[b.team];
    p.tenure = 0;
    if (b.team == mine && t.payroll + b.salary > salaryCap) {
      final ex = exceptionFor(b.salary);
      if (ex != null) _useException(ex);
    }
    t.roster.add(p);
    faMoves.add(FaMove(p.id, p.name, p.ovr, b.team, b.salary, b.years, faDay));
    final text = '${p.name}(OVR${shown(p.ovr)})が${t.def.short}と${b.years}年 ${money(b.salary)}';
    faLog.insert(0, '${faDay + 1}日目 $text');
    if (b.team == mine) {
      p.morale = 65;
      _mail(Sender.agent, '${p.name}が契約に合意', '${p.name}が申し込みを受けた。${b.years}年 ${money(b.salary)}。');
      _log('移籍: $text');
    } else if (p.ovr >= 70) {
      _log('移籍: $text');
    }
  }

  /// ほかのチームが大物に申し込む(1人に1日2チームまで)。
  void _aiBids() {
    final big = freeAgents.where((p) => askOf(p, me).salary > minSalary).toList()..sort((a, b) => b.ovr.compareTo(a.ovr));
    final others = [for (final t in teams) if (t.index != mine) t];
    for (final p in big.take(14)) {
      rng.shuffle(others);
      var added = 0;
      for (final t in others) {
        if (added >= 2) break;
        if (bids[p.id]?.any((b) => b.team == t.index) ?? false) continue;
        final ask = askOf(p, t);
        if (t.roster.length + _bidsOf(t.index).length >= maxRoster) continue;
        if (t.payroll + _bidTotal(t.index) + ask.salary > salaryCap) continue;
        if (!rng.chance(t.mode == TeamMode.contend ? 0.45 : 0.3)) continue;
        final salary = (ask.salary * (0.95 + rng.nextInt(4) * 0.05)).round().clamp(minSalary, maxSalaryFor(p.exp));
        bids.putIfAbsent(p.id, () => []).add(FaBid(t.index, salary, 1 + rng.nextInt(ask.maxYears)));
        added++;
      }
    }
  }

  /// 放した選手の年俸の残り方。[now] は今季の合計に残る分、[later] は来季以降に残る分(先頭が来季)。
  ({int now, List<int> later}) releaseCost(Player p, ReleaseMode mode) {
    final r = math.max(1, p.years);
    // 一部保証の契約は、2年目以降の年俸が保証の割合だけ残る
    final gf = p.guarantee / 100;
    switch (mode) {
      case ReleaseMode.full:
        return (now: p.salary, later: List.filled(r - 1, (p.salary * gf).round()));
      case ReleaseMode.stretch:
        // 残りの年俸の全部を、残り年数の2倍＋1年に均して払う(今季の負担は軽く、長く残る)
        final n = 2 * r + 1;
        final per = (p.salary * (1 + (r - 1) * gf) / n).ceil();
        return (now: per, later: List.filled(n - 1, per));
      case ReleaseMode.buyout:
        // 選手が残りの年俸の3割を諦める。払いは全額のときと同じ形で、3割少ない
        return (now: (p.salary * 0.7).round(), later: List.filled(r - 1, (p.salary * 0.7 * gf).round()));
    }
  }

  /// 選手を放せない理由(放せるなら null)。
  String? releaseProblem(Player p, [ReleaseMode mode = ReleaseMode.full]) {
    if (!me.roster.contains(p)) return '自分の登録選手だけ';
    if (expiring.contains(p.id)) return '契約が切れる選手は放す必要がない';
    if (!(phase == Phase.preseason || phase == Phase.season || phase == Phase.contracts)) return '今は放せない';
    if (mode == ReleaseMode.stretch && p.years < 2) return '残りが1年の契約はストレッチできない(2年以上の契約だけ)';
    if (mode == ReleaseMode.buyout) {
      if (p.years < 2) return 'バイアウトは残りが2年以上の契約だけ';
      if (p.morale < 45) return '${p.name}は今、年俸を諦める話に乗らない(気持ちが低い)';
    }
    return null;
  }

  /// ウェーバーで、ほかのチームが拾う確率(全額で放す選手だけ。力が高く年俸が安いほど拾われる)。
  double waiverChance(Player p) {
    if (p.salary > 100 || p.ovr < 58) return 0;
    return (0.3 + (p.ovr - 58) * 0.03 - p.salary / 400).clamp(0.0, 0.85);
  }

  /// 選手を放す。年俸は [mode] の形で合計に残る(全額・ストレッチ・バイアウト)。
  /// 全額で放すと、まずウェーバーに出る。ほかのチームが拾えば、年俸の負担は残らない。拾われたら true。
  bool release(int id, {ReleaseMode mode = ReleaseMode.full}) {
    final p = _mineById(id);
    if (p == null || releaseProblem(p, mode) != null) return false;
    // 拾われるかは乱数の列を使わず、選手と年から決める(同じ局面なら同じ結果で、ほかの出来事の乱数をずらさない)
    final waived = phase != Phase.contracts && ((p.id * 7919 + season * 104729) % 100) / 100 < waiverChance(p);
    if (mode == ReleaseMode.full && waived) {
      final open = [for (final t in teams) if (t.index != mine && t.roster.length < maxRoster) t]..sort((a, b) => a.wins.compareTo(b.wins));
      if (open.isNotEmpty) {
        final t = open.first;
        me.roster.remove(p);
        p.tenure = 0;
        t.roster.add(p);
        _log('ウェーバー: ${p.name}を${t.def.short}が拾った(年俸の負担は残らない)');
        return true;
      }
    }
    me.roster.remove(p);
    final cost = releaseCost(p, mode);
    me.deadCap += cost.now;
    for (var i = 0; i < cost.later.length; i++) {
      if (i < me.deadLater.length) {
        me.deadLater[i] += cost.later[i];
      } else {
        me.deadLater.add(cost.later[i]);
      }
    }
    p.raise = 0;
    p
      ..salary = askOf(p, teams[(mine + 1) % teams.length]).salary
      ..years = 1;
    freeAgents
      ..add(p)
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
    return false;
  }

  // ---------------------------------------------------------------- 2ウェイ契約

  Player? _twoWayById(int id) {
    for (final p in me.twoWay) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 2ウェイ契約にできない理由(できるなら null)。若手(リーグでの年数が [twoWayMaxExp] 以下)だけ。
  String? twoWayProblem(Player p) {
    if (!canSign) return '今は契約できない';
    if (me.twoWay.length >= twoWayMax) return '2ウェイは$twoWayMax人まで';
    if (p.exp > twoWayMaxExp) return '2ウェイはリーグ$twoWayMaxExp年目までの若手だけ';
    return null;
  }

  /// 自由契約の若手を2ウェイ契約で取る(登録の15人にも上限にも数えない。年俸は ${twoWaySalary * 10}万ドル。競り合いにならない)。
  void signTwoWay(int id, {int years = 2}) {
    final i = freeAgents.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = freeAgents[i];
    if (twoWayProblem(p) != null || bids[id]?.any((b) => b.team == mine) == true) return;
    freeAgents.removeAt(i);
    p
      ..salary = twoWaySalary
      ..years = years.clamp(1, 2)
      ..optionYears = 0
      ..morale = 65;
    me.twoWay.add(p);
  }

  /// 登録の選手を2ウェイに変えられない理由(できるなら null)。契約を結んだままの年俸は払い終えた扱いで、デッドキャップは残らない。
  String? toTwoWayProblem(Player p) {
    if (!(phase == Phase.draft || phase == Phase.contracts || phase == Phase.preseason)) return 'オフとシーズン前だけ';
    if (expiring.contains(p.id)) return '契約が切れる選手は、再契約か自由契約で決める';
    return twoWayProblem(p);
  }

  /// 登録の若手を2ウェイに下げる(登録に空きができる)。
  void toTwoWay(int id) {
    final p = _mineById(id);
    if (p == null || toTwoWayProblem(p) != null) return;
    me.roster.remove(p);
    me.rotation.remove(id);
    me.minutes.remove(id);
    p
      ..salary = twoWaySalary
      ..years = 2
      ..optionYears = 0;
    me.twoWay.add(p);
  }

  /// 2ウェイの選手を登録に上げられない理由(できるなら null)。
  String? promoteProblem(Player p) {
    if (!(phase == Phase.preseason || phase == Phase.season || phase == Phase.contracts)) return '今は登録に上げられない';
    if (me.roster.length - expiring.length >= maxRoster) return '登録が$maxRoster人いっぱい';
    return null;
  }

  /// 2ウェイの選手を登録に上げる(最低年俸の2年契約)。
  void promoteTwoWay(int id) {
    final p = _twoWayById(id);
    if (p == null || promoteProblem(p) != null) return;
    me.twoWay.remove(p);
    p
      ..salary = minSalary
      ..years = 2;
    me.roster.add(p);
  }

  /// 2ウェイの選手を自由契約にする(払うお金は残らない)。
  void waiveTwoWay(int id) {
    final p = _twoWayById(id);
    if (p == null) return;
    me.twoWay.remove(p);
    p.salary = askOf(p, teams[(mine + 1) % teams.length]).salary;
    freeAgents
      ..add(p)
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
  }

  /// オフを終えてシーズン前へ。残った契約切れの選手は放し、相手のチームが自由契約の選手を取る。
  void finishContracts() {
    if (phase != Phase.contracts) return;
    for (final id in [...optionPending]) {
      exerciseOption(id);
    }
    for (final id in [...expiring]) {
      letGo(id);
    }
    // 残りの日を進めて、大物の行き先を決める
    while (faDay < faDays) {
      nextFaDay();
    }
    if (sheet != null) declineSheet();
    bids = {};
    _aiFreeAgency();
    for (final t in teams) {
      if (t.index != mine) {
        _aiBalance(t);
        _aiTrim(t);
      }
    }
    // ドラフトの候補は、指名された選手とつながっている。シーズンに入る前に手放す(保存で別の物にならないように)
    prospects = [];
    order = [];
    draftLog = [];
    season++;
    _setModes();
    _aiTrades(1);
    phase = Phase.preseason;
    _setModes();
  }

  void _aiFreeAgency() {
    final others = [for (final t in teams) if (t.index != mine) t];
    for (final p in [...freeAgents]..sort((a, b) => b.ovr.compareTo(a.ovr))) {
      rng.shuffle(others);
      for (final t in others) {
        final ask = askOf(p, t);
        if (t.roster.length >= 15) continue;
        if (ask.salary > minSalary && t.payroll + ask.salary > salaryCap) continue;
        if (p.ovr < 60 && t.roster.length >= 13) continue;
        // 同じポジションが4人以上いれば取らない(よほどの選手でなければ)
        if (p.ovr < 72 && t.roster.where((x) => x.pos == p.pos).length >= 4) continue;
        p
          ..salary = ask.salary
          ..years = 1 + rng.nextInt(ask.maxYears);
        t.roster.add(p);
        freeAgents.remove(p);
        if (p.ovr >= 60) faMoves.add(FaMove(p.id, p.name, p.ovr, t.index, p.salary, p.years, faDays));
        if (p.ovr >= 70) _log('移籍: ${p.name}(OVR${shown(p.ovr)})が${t.def.short}と${p.years}年契約');
        break;
      }
    }
    for (final t in others) {
      while (t.roster.length < 13) {
        t.roster.add(_filler(pos: _neededPos(t)));
      }
    }
    while (freeAgents.where((p) => p.salary <= minSalary).length < 6) {
      freeAgents.add(_filler());
    }
  }

  /// 相手のチームの、2人に満たないポジションを埋める(自由契約のその位置でいちばんの選手を最低年俸か上限の空きで。いなければ補充の選手)。
  /// 15人いっぱいなら、4人以上いるポジションの力の低い選手を先に放す。
  void _aiBalance(Team t) {
    for (final pos in Pos.values) {
      if (t.roster.where((p) => p.pos == pos).length >= 2) continue;
      if (t.roster.length >= maxRoster) {
        final c = posCounts(t);
        final surplus = t.roster.where((p) => c[p.pos]! >= 4).toList();
        if (surplus.isEmpty) continue;
        t.roster.remove(surplus.reduce((a, b) => a.ovr <= b.ovr ? a : b));
      }
      final cands = freeAgents.where((p) => p.pos == pos && (p.salary <= minSalary || t.payroll + p.salary <= salaryCap)).toList()
        ..sort((a, b) => b.ovr.compareTo(a.ovr));
      if (cands.isNotEmpty) {
        final p = cands.first;
        freeAgents.remove(p);
        p.years = 1 + rng.nextInt(2);
        t.roster.add(p);
      } else {
        t.roster.add(_filler(pos: pos));
      }
    }
  }

  /// 相手のチームの人数を15人以内に保つ。3人以上いるポジションの、力の低い選手から放す。
  void _aiTrim(Team t) {
    while (t.roster.length > maxRoster) {
      final c = posCounts(t);
      final pool = t.roster.where((p) => c[p.pos]! >= 3).toList();
      final worst = (pool.isEmpty ? t.roster : pool).reduce((a, b) => a.ovr <= b.ovr ? a : b);
      t.roster.remove(worst);
    }
  }

  // ---------------------------------------------------------------- トレード

  TradeVerdict judge(TradeOffer o) {
    if (!canTrade) return const TradeVerdict(false, '今はトレードできない(締め切りを過ぎた)', 0);
    if (o.give.any((id) => expiring.contains(id) || optionPending.contains(id))) return const TradeVerdict(false, '契約の話し合い中の選手は出せない', 0);
    final gs = [for (final id in o.give) me.roster.where((p) => p.id == id).firstOrNull?.salary ?? 0].fold(0, (a, b) => a + b);
    final ts = [for (final id in o.get) teams[o.partner].roster.where((p) => p.id == id).firstOrNull?.salary ?? 0].fold(0, (a, b) => a + b);
    final bp = budgetProblem(me.payroll - gs + ts);
    if (bp != null) return TradeVerdict(false, bp, 0);
    return judgeTrade(teams, picks, mine, o, season,
        rosterLimit: phase == Phase.season ? maxRoster : offseasonRoster, hardness: _hard(o.partner), needs: true);
  }

  /// トレードで両チームの強さと、82試合での勝ち数の見込みがどう変わるか
  /// ((自分の前, 自分の後, 相手の前, 相手の後)の強さと、(自分の前, 後)の勝ち数)。選手を入れ替えて数え、元に戻す。
  ({double myBefore, double myAfter, double theirBefore, double theirAfter, double winsBefore, double winsAfter}) tradeImpact(TradeOffer o) {
    final them = teams[o.partner];
    final give = [for (final id in o.give) ...me.roster.where((p) => p.id == id)];
    final get = [for (final id in o.get) ...them.roster.where((p) => p.id == id)];
    double wins(Team t, double str) {
      var w = 0.0;
      for (final x in teams) {
        if (x == t) continue;
        final xs = x.strength;
        w += (winChance(str, xs) + 1 - winChance(xs, str)) / 2;
      }
      return w / (teams.length - 1) * gamesPerSeason;
    }

    final myBefore = me.strength, theirBefore = them.strength;
    final winsBefore = wins(me, myBefore);
    me.roster
      ..removeWhere(give.contains)
      ..addAll(get);
    them.roster
      ..removeWhere(get.contains)
      ..addAll(give);
    final myAfter = me.strength, theirAfter = them.strength;
    final winsAfter = wins(me, myAfter);
    me.roster
      ..removeWhere(get.contains)
      ..addAll(give);
    them.roster
      ..removeWhere(give.contains)
      ..addAll(get);
    return (myBefore: myBefore, myAfter: myAfter, theirBefore: theirBefore, theirAfter: theirAfter, winsBefore: winsBefore, winsAfter: winsAfter);
  }

  bool propose(TradeOffer o) {
    final v = judge(o);
    if (!v.ok) return false;
    _logTrade(mine, o);
    applyTrade(teams, picks, mine, o, swaps: swaps);
    tradesDone++;
    incoming = null;
    return true;
  }

  void _logTrade(int from, TradeOffer o) {
    final give = [for (final id in o.give) teams[from].roster.firstWhere((p) => p.id == id)];
    final get = [for (final id in o.get) teams[o.partner].roster.firstWhere((p) => p.id == id)];
    _log(_tradeText(from, o.partner, o, give, get));
  }

  /// スタッフの段階を変えられるか(シーズン前とオフの契約のときだけ)。
  bool get canChangeStaff => phase == Phase.preseason || phase == Phase.contracts;

  /// 雇えるコーチ(オフごとに入れ替わる)。
  List<Coach> coachPool = [];

  /// コーチの候補を作る(試合の乱数とは別の種で。リーグの続きを変えない)。
  List<Coach> _makeCoaches(int salt, {required bool start}) {
    final r = Rng(seed * 7919 + salt);
    return [
      for (final s in Staff.values)
        for (var k = 0; k < (start ? 1 : 3); k++) Coach(name: randomName(r), role: s, rating: start ? 66 + r.nextInt(9) : 50 + r.nextInt(46)),
    ];
  }

  /// コーチを雇う(同じ役の今のコーチは辞め、給料の半年分を払う)。
  bool hireCoach(int poolIndex) {
    if (!canChangeStaff || poolIndex < 0 || poolIndex >= coachPool.length) return false;
    final c = coachPool.removeAt(poolIndex);
    final old = me.coachOf(c.role);
    if (old != null) {
      me.coaches.remove(old);
      costs += old.salary ~/ 2;
      coachPool.add(old);
    }
    me.coaches.add(c);
    return true;
  }

  /// 雇ったときに払う、今のコーチへの違約金。
  int buyoutOf(Staff s) => (me.coachOf(s)?.salary ?? 0) ~/ 2;

  /// 出場時間を決める(空なら自動)。合計は [totalMinutes]、1人 [maxMinutes] まで。
  void setMinutes(Map<int, int> m) {
    if (m.isEmpty) {
      me.minutes = {};
      return;
    }
    final total = m.values.fold(0, (a, b) => a + b);
    if (total != totalMinutes || m.values.any((v) => v < 0 || v > maxMinutes)) return;
    me.minutes = {for (final e in m.entries) if (me.roster.any((p) => p.id == e.key)) e.key: e.value};
  }

  /// 選手が期待する出場時間(力の順位から)。
  int expectedMinutes(Player p) {
    final byOvr = [...me.roster]..sort((a, b) => b.ovr.compareTo(a.ovr));
    final i = byOvr.indexOf(p);
    return i >= 0 && i < minutesByOrder.length ? minutesByOrder[i] : 0;
  }

  /// 値切りを断られた選手(断られるたびに1回足す。代理人との交渉は [maxHaggle] 回まで)。
  List<int> haggled = [];

  /// 代理人との値切りの交渉の最大の往復。
  static const maxHaggle = 3;

  /// この選手の値切りを、いままでに断られた回数。
  int haggleRounds(int id) => haggled.where((x) => x == id).length;

  /// 値切ったときに受けてくれる見込み(0〜1)。気持ちが高い・チームが強いほど受ける。
  double discountChance(Player p, {required bool freeAgent}) {
    var base = freeAgent ? 0.35 + hype / 250 : 0.3 + p.morale / 200;
    if (!freeAgent) base += personalityOf(p).value == Value.loyal ? 0.1 : personalityOf(p).value == Value.money ? -0.1 : 0;
    final win = history.isEmpty ? 0.0 : (history.last.wins / gamesPerSeason - 0.5) * 0.6;
    return (base + win + 0.06 * skillOf(Skill.negotiation)).clamp(0.1, 0.85);
  }

  /// 交渉の結果。
  int _offerSalary(Player p, double factor) => (askOf(p, me).salary * factor).round().clamp(minSalary, maxSalaryFor(p.exp));

  /// 次の契約を一部保証にするか(交渉の画面のスイッチ。申し出たら元に戻る)。
  bool partialNext = false;

  /// 一部保証にできるか(2年以上の契約で、29歳以上の選手)。
  bool partialOk(Player p, int years) => years >= 2 && p.age >= 29;

  /// 契約を申し出る。[factor] は求める額に掛ける数(0.9 で1割安く、1.1 で1割高く)。受けたら true。
  /// 1割安くを断られると気持ちが4下がり、次は受けにくくなる(3回断られたら、このオフはもう値切れない)。1割高くは気持ちが10上がる。
  bool offer(int id, int years, double factor) {
    final partial = partialNext;
    partialNext = false;
    final exp = expiring.contains(id);
    final p = exp ? _mineById(id) : freeAgents.where((x) => x.id == id).firstOrNull;
    if (p == null) return false;
    if (factor < 1) {
      final rounds = haggleRounds(id);
      if (rounds >= haggleLimit) return false;
      // 断られるたびに、次は受けにくくなる(代理人は往復するほど硬くなる)
      if (!rng.chance((discountChance(p, freeAgent: !exp) - 0.1 * rounds).clamp(0.05, 0.85))) {
        haggled.add(id);
        p.morale = (p.morale - 4).clamp(0, 100);
        return false;
      }
    }
    // 一部保証は、選手の保証が減る分、年俸が8%高くなる
    final isPartial = partial && partialOk(p, years);
    final salary = isPartial ? (_offerSalary(p, factor) * 1.08).round().clamp(minSalary, maxSalaryFor(p.exp)) : _offerSalary(p, factor);
    if (exp) {
      if (resignProblem(p, salary: salary) != null || me.payroll - p.salary + salary > secondApron) return false;
      resign(id, years);
    } else {
      if (signProblem(p, salary: salary) != null) return false;
      signFreeAgent(id, years, salary: salary);
    }
    p.salary = salary;
    p.guarantee = isPartial ? 50 : 100;
    if (factor > 1) p.morale = (p.morale + 10).clamp(0, 100);
    return true;
  }

  /// これからの自分のチームの試合(相手・ホームか)。今の節から [count] 試合。
  List<(int, bool)> upcoming({int count = 5}) {
    if (phase != Phase.season) return const [];
    final out = <(int, bool)>[];
    for (final round in seasonSchedule(teams.length).skip(roundAt)) {
      for (final (h, a) in round) {
        if (h == mine) out.add((a, true));
        if (a == mine) out.add((h, false));
      }
      if (out.length >= count) break;
    }
    return out;
  }

  /// このシーズンに延長を申し出て断られた選手(シーズンのあいだ、もう申し出られない)。
  List<int> extAsked = [];

  /// 契約の延長ができない理由(できるなら null)。残り1年の自分の選手だけ、シーズン前とシーズン中に申し出られる。
  String? extendProblem(Player p) {
    if (!(phase == Phase.preseason || phase == Phase.season)) return 'シーズン前かシーズン中だけ';
    if (!me.roster.contains(p)) return '自分のチームの選手だけ';
    if (p.years != 1) return '契約の残りが1年の選手だけ';
    if (p.nextSalary != null) return 'もう延長した';
    if (extAsked.contains(p.id)) return '今季はもう断られた';
    if (p.morale < 35) return '${p.name}は今、延長の話に乗らない(気持ちが低い)';
    return null;
  }

  /// 延長で求める年俸(早く決める分、少し高く求める。新人の延長は伸びしろも見る)。
  Ask extensionAsk(Player p) {
    final base = askOf(p, me);
    final rookie = draftedIds.contains(p.id) && p.exp <= 3;
    final f = rookie ? 1.0 + (p.pot - p.ovr).clamp(0, 20) / 100 : 1.05;
    return Ask((base.salary * f).round().clamp(minSalary, maxSalaryFor(p.exp)), base.maxYears);
  }

  /// 延長を申し出る。受けたら true。[years] は今の契約のあとに足す年数。
  /// 1割安くは断られることがある(断られると今季はもう申し出られず、気持ちが下がる)。
  bool extend(int id, int years, double factor) {
    final p = me.roster.where((x) => x.id == id).firstOrNull;
    if (p == null || extendProblem(p) != null) return false;
    final ask = extensionAsk(p);
    final chance = factor < 1 ? discountChance(p, freeAgent: false) : factor > 1 ? 1.0 : 0.85;
    if (!rng.chance(chance)) {
      extAsked.add(id);
      p.morale = (p.morale - 8).clamp(0, 100);
      return false;
    }
    p
      ..nextSalary = (ask.salary * factor).round().clamp(minSalary, maxSalaryFor(p.exp))
      ..years = 1 + years.clamp(1, ask.maxYears)
      ..raise = ownRaisePct;
    if (factor > 1) p.morale = (p.morale + 10).clamp(0, 100);
    _log('延長: ${p.name}(${me.def.short})が$years年延長(来季から${money(p.nextSalary!)})');
    return true;
  }

  /// 先発と控えの順を決める([ids] は上から。空なら自動に戻す)。
  void setRotation(List<int> ids) {
    if (phase == Phase.over) return;
    me.rotation = [for (final id in ids) if (me.roster.any((p) => p.id == id)) id];
  }

  /// 相手のチームのトレードの受けにくさ(難しさ × 相手の GM の型)。
  double _hard(int partner) => difficulty.tradeHardness * gmOf(seed, partner).style.hardness * (1 - 0.03 * skillOf(Skill.network));

  /// チームの GM(名前と型)。
  GmPerson gmPerson(int team) => gmOf(seed, team);

  /// 「相手に聞く」: [partner] から [get] を受け取るのに、こちらが出せばよい組み合わせ。契約の話し合い中の選手は出さない。
  TradeOffer? askPartner(int partner, {List<int> get = const [], List<int> getPicks = const []}) {
    if (!canTrade || (get.isEmpty && getPicks.isEmpty)) return null;
    return findPackage(teams, picks, mine, partner,
        get: get, getPicks: getPicks, exclude: expiring, nowSeason: season, hardness: _hard(partner));
  }

  /// 今の申し込みに、こちらから1つ(選手か指名権)足せば受けてもらえるもの。相手にとって値打ちの低いものから選ぶ。無ければ null。
  TradeOffer? suggestAddition(TradeOffer o) {
    if (!canTrade || judge(o).ok) return null;
    final mode = teams[o.partner].mode;
    final cands = <(double, TradeOffer)>[];
    TradeOffer withGive(List<int> give, List<int> givePicks) => TradeOffer(
          partner: o.partner,
          give: give,
          get: o.get,
          givePicks: givePicks,
          protections: o.protections,
          getPicks: o.getPicks,
          giveSwaps: o.giveSwaps,
          getSwaps: o.getSwaps,
        );
    for (final p in me.roster) {
      if (o.give.contains(p.id) || expiring.contains(p.id) || optionPending.contains(p.id)) continue;
      cands.add((playerValue(p, mode), withGive([...o.give, p.id], o.givePicks)));
    }
    for (var i = 0; i < picks.length; i++) {
      if (picks[i].owner != mine || o.givePicks.contains(i)) continue;
      cands.add((pickValue(picks[i], mode, slotGuess(teams, picks[i].from), season), withGive(o.give, [...o.givePicks, i])));
    }
    cands.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, x) in cands) {
      if (judge(x).ok) return x;
    }
    return null;
  }

  /// 相手のチーム同士のトレード。優勝を狙うチームが、立て直し中・年俸を減らしたいチームのベテランを、若手や指名権で取る。
  /// どちらの見方でも損にならないときだけ成立する。
  void _aiTrades(int count) {
    final buyers = [for (final t in teams) if (t.index != mine && (t.mode == TeamMode.contend || t.mode == TeamMode.balanced)) t.index];
    final sellers = [for (final t in teams) if (t.index != mine && (t.mode == TeamMode.rebuild || t.mode == TeamMode.cutCost)) t.index];
    rng.shuffle(buyers);
    var done = 0;
    // 探すのは重いので、試す組み合わせの数を絞る(買い手4つ×売り手2つまで)
    for (final a in buyers.take(4)) {
      if (done >= count) break;
      rng.shuffle(sellers);
      for (final b in sellers.take(2)) {
        final vets = teams[b].roster.where((p) => p.age >= 27 && p.ovr >= 68).toList()..sort((x, y) => y.ovr.compareTo(x.ovr));
        if (vets.isEmpty) continue;
        final target = vets.first;
        final o = findPackage(teams, picks, a, b, get: [target.id], nowSeason: season);
        if (o == null) continue;
        // 取る側から見ても得か
        final give = [for (final id in o.give) teams[a].roster.firstWhere((p) => p.id == id)];
        final out = give.fold(0.0, (s, p) => s + playerValue(p, teams[a].mode)) +
            o.givePicks.fold(0.0, (s, i) => s + pickValue(picks[i], teams[a].mode, slotGuess(teams, picks[i].from), season));
        if (playerValue(target, teams[a].mode) < out) continue;
        _log(_tradeText(a, b, o, give, [target]));
        applyTrade(teams, picks, a, o);
        done++;
        break;
      }
    }
  }

  /// [from] から7回分のドラフトの指名権がそろうように足す(前の保存で2年分しか無かったときも)。
  void _fillPicks(int from) {
    for (var s = from; s < from + pickYears; s++) {
      for (final r in [1, 2]) {
        for (var t = 0; t < teams.length; t++) {
          if (!picks.any((p) => p.season == s && p.round == r && p.from == t)) {
            picks.add(DraftPick(season: s, round: r, from: t, owner: t));
          }
        }
      }
    }
  }

  /// [team] が出した(ほかのチームが持っている)自分の指名権。
  List<int> picksOwedBy(int team) => [for (var i = 0; i < picks.length; i++) if (picks[i].from == team && picks[i].owner != team) i];

  /// 自分の持っている指名権(全体の並びでの番号)。
  List<int> picksOf(int team) => [for (var i = 0; i < picks.length; i++) if (picks[i].owner == team) i];

  // ---------------------------------------------------------------- 保存

  Map<String, dynamic> toJson() => {
        'v': 1,
        'seed': seed,
        'mine': mine,
        'sr': startRank,
        'df': difficulty.index,
        'gp': gmPoints,
        'gp10': gmPointsFirst10,
        'rp': [for (final x in lastRating) x.toJson()],
        if (levelBefore != null) 'lvb': levelBefore,
        'rng': rng.state,
        'teams': [for (final t in teams) t.toJson()],
        'season': season,
        'phase': phase.index,
        'block': block,
        'ra': roundAt,
        'lg': [for (final g in lastGames) g.toJson()],
        if (form.isNotEmpty) 'frm': form,
        'po': [for (final s in playoffs) s.toJson()],
        'fa': [for (final p in freeAgents) p.toJson()],
        'picks': [for (final p in picks) p.toJson()],
        'pros': [for (final p in prospects) p.toJson()],
        if (board.isNotEmpty) 'bb': board,
        'order': order,
        'da': draftAt,
        'dl': draftLog,
        if (lotteryPre.isNotEmpty) 'lpre': lotteryPre,
        if (offStartIds.isNotEmpty) 'ofs': offStartIds,
        if (offStartRank != -1) 'ofr': offStartRank,
        if (faMoves.isNotEmpty) 'fm': [for (final m in faMoves) m.toJson()],
        'sl': scoutsLeft,
        'sau': scoutAdUsed,
        'exp': expiring,
        if (optionPending.isNotEmpty) 'opp': optionPending,
        'trust': trust,
        if (swaps.isNotEmpty) 'swp': swaps,
        if (retirees.isNotEmpty) 'rtr': retirees,
        if (retiredNumbers.isNotEmpty) 'rnum': retiredNumbers,
        if (retiredNames.isNotEmpty) 'rnam': retiredNames,
        if (h2h.isNotEmpty) 'h2h': {for (final e in h2h.entries) '${e.key}': e.value},
        if (headlines.isNotEmpty) 'hl': headlines,
        if (skills.any((x) => x != 0)) 'skl': skills,
        if (cupHistory.isNotEmpty) 'cup': cupHistory,
        if (cupField.isNotEmpty) 'cf': cupField,
        if (cupRounds.isNotEmpty) 'cr': cupRounds,
        if (records.isNotEmpty) 'rcd': {for (final e in records.entries) e.key: e.value.toJson()},
        if (ownerType != OwnerType.steady) 'ot': ownerType.index,
        if (budgetLevel != 2) 'bl': budgetLevel,
        if (meetingSeason != -1) 'ms': meetingSeason,
        'target': target,
        'ru': rescueUsed,
        'fired': fired,
        'hist': [for (final h in history) h.toJson()],
        'news': news,
        if (incoming != null) 'inc': incoming!.toJson(),
        'td': tradesDone,
        'ea': extAsked,
        'ib': [for (final m in inbox) m.toJson()],
        'mid': _msgId,
        'asi': allStarIds,
        'hg': haggled,
        if (rfa.isNotEmpty) 'rf': rfa,
        if (sheet != null) 'sh': sheet,
        'hy': hype,
        'pl': priceLevel,
        'rv': revenue,
        'incb': incomeBy,
        if (concessionLevel != 1) 'cl': concessionLevel,
        'cs': costs,
        'lp': lastProfit,
        'gl': [for (final g in goals) g.toJson()],
        'aw': [for (final a in awards) a.toJson()],
        if (tradeBlock.isNotEmpty) 'tbk': tradeBlock,
        'bbs': [for (final e in blockBase.entries) [e.key, ...e.value]],
        'mvm': [for (final a in monthly) a.toJson()],
        'cp': [for (final c in coachPool) c.toJson()],
        'gr': [for (final g in growth) g.toJson()],
        'fd': faDay,
        'bd': {for (final e in bids.entries) '${e.key}': [for (final b in e.value) b.toJson()]},
        'fl': faLog,
        if (capYear != 0) 'cy': capYear,
        if (mleUsed) 'mu': true,
        if (biennialYear != -9) 'by': biennialYear,
        'chp': champs,
        'hof': [for (final h in hall) h.toJson()],
        'log': log,
        'tax': lastTax,
        'dr': draftedIds,
        'nid': _nextId,
      };

  static Career fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> maps(String k) => [for (final x in (j[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final c = Career._(
      seed: j['seed'] as int,
      mine: ((j['mine'] as int?) ?? 0).clamp(0, teamDefs.length - 1),
      rng: Rng(j['seed'] as int)..state = j['rng'] as int,
      teams: [for (final t in maps('teams')) Team.fromJson(t)],
    );
    if (c.teams.length != teamDefs.length) throw const FormatException('teams');
    c
      ..startRank = (j['sr'] as int?) ?? 0
      ..difficulty = Difficulty.fromIndex(j['df'])
      ..gmPoints = (j['gp'] as int?) ?? 0
      ..gmPointsFirst10 = (j['gp10'] as int?) ?? 0
      ..lastRating = [for (final x in (j['rp'] as List? ?? const [])) RatingPart.fromJson(x as List)]
      ..levelBefore = j['lvb'] as int?
      ..season = j['season'] as int
      ..phase = Phase.values[(j['phase'] as int).clamp(0, Phase.values.length - 1)]
      ..block = j['block'] as int
      ..roundAt = (j['ra'] as int?) ?? blockStart((j['block'] as int).clamp(0, blocksPerSeason))
      ..lastGames = [for (final g in maps('lg')) GameResult.fromJson(g)]
      ..form = [for (final x in (j['frm'] as List? ?? const [])) x as int]
      ..playoffs = [for (final s in maps('po')) Series.fromJson(s)]
      ..freeAgents = [for (final p in maps('fa')) Player.fromJson(p)]
      ..picks = [for (final p in maps('picks')) DraftPick.fromJson(p)]
      ..prospects = [for (final p in maps('pros')) Prospect.fromJson(p)]
      ..board = [for (final x in (j['bb'] as List? ?? const [])) x as int]
      ..order = [for (final x in (j['order'] as List? ?? const [])) x as int]
      ..draftAt = (j['da'] as int?) ?? 0
      ..draftLog = [for (final x in (j['dl'] as List? ?? const [])) x as int]
      ..lotteryPre = [for (final x in (j['lpre'] as List? ?? const [])) x as int]
      ..offStartIds = [for (final x in (j['ofs'] as List? ?? const [])) x as int]
      ..offStartRank = (j['ofr'] as int?) ?? -1
      ..faMoves = [
        for (final x in (j['fm'] as List? ?? const []))
          if (x is List && x.length == 7) FaMove.fromJson(x),
      ]
      ..scoutsLeft = (j['sl'] as int?) ?? 0
      ..scoutAdUsed = (j['sau'] as bool?) ?? false
      ..expiring = [for (final x in (j['exp'] as List? ?? const [])) x as int]
      ..optionPending = [for (final x in (j['opp'] as List? ?? const [])) x as int]
      ..trust = (j['trust'] as int?) ?? 50
      ..swaps = [for (final x in (j['swp'] as List? ?? const [])) [for (final y in x as List) y as int]]
      ..retirees = [for (final x in (j['rtr'] as List? ?? const [])) [(x as List)[0] as String, x[1] as int]]
      ..retiredNumbers = [for (final x in (j['rnum'] as List? ?? const [])) [for (final y in x as List) y as int]]
      ..retiredNames = [for (final x in (j['rnam'] as List? ?? const [])) x as String]
      ..h2h = {for (final e in ((j['h2h'] as Map?) ?? const {}).entries) int.parse(e.key as String): [for (final x in e.value as List) x as int]}
      ..headlines = [for (final x in (j['hl'] as List? ?? const [])) x as String]
      ..skills = [for (var i = 0; i < Skill.values.length; i++) i < ((j['skl'] as List?)?.length ?? 0) ? ((j['skl'] as List)[i] as int).clamp(0, skillMax) : 0]
      ..cupHistory = [for (final x in (j['cup'] as List? ?? const [])) [for (final y in x as List) y as int]]
      ..cupField = [for (final x in (j['cf'] as List? ?? const [])) x as int]
      ..cupRounds = [for (final x in (j['cr'] as List? ?? const [])) x as int]
      ..records = {for (final e in ((j['rcd'] as Map?) ?? const {}).entries) e.key as String: RecordEntry.fromJson(e.value as List)}
      ..ownerType = OwnerType.values[((j['ot'] as int?) ?? OwnerType.steady.index).clamp(0, OwnerType.values.length - 1)]
      ..budgetLevel = ((j['bl'] as int?) ?? 2).clamp(0, 2)
      ..meetingSeason = (j['ms'] as int?) ?? -1
      ..target = (j['target'] as int?) ?? 0
      ..rescueUsed = (j['ru'] as bool?) ?? false
      ..fired = (j['fired'] as bool?) ?? false
      ..history = [for (final h in maps('hist')) SeasonRecord.fromJson(h)]
      ..news = [for (final x in (j['news'] as List? ?? const [])) x as String]
      ..incoming = j['inc'] == null ? null : TradeOffer.fromJson(Map<String, dynamic>.from(j['inc'] as Map))
      ..tradesDone = (j['td'] as int?) ?? 0
      ..extAsked = [for (final x in (j['ea'] as List? ?? const [])) x as int]
      ..inbox = [for (final m in maps('ib')) Message.fromJson(m)]
      .._msgId = (j['mid'] as int?) ?? 1
      ..allStarIds = [for (final x in (j['asi'] as List? ?? const [])) x as int]
      ..haggled = [for (final x in (j['hg'] as List? ?? const [])) x as int]
      ..rfa = [for (final x in (j['rf'] as List? ?? const [])) x as int]
      ..sheet = j['sh'] is List ? [for (final x in j['sh'] as List) x as int] : null
      ..hype = ((j['hy'] as int?) ?? 50).clamp(0, 100)
      ..priceLevel = ((j['pl'] as int?) ?? 1).clamp(0, ticketPrices.length - 1)
      ..revenue = (j['rv'] as int?) ?? 0
      ..incomeBy = [for (var i = 0; i < Income.values.length; i++) i < ((j['incb'] as List?)?.length ?? 0) ? (j['incb'] as List)[i] as int : 0]
      ..concessionLevel = ((j['cl'] as int?) ?? 1).clamp(0, concessionPrices.length - 1)
      ..costs = (j['cs'] as int?) ?? 0
      ..lastProfit = (j['lp'] as int?) ?? 0
      ..goals = [for (final g in maps('gl')) OwnerGoal.fromJson(g)]
      ..awards = [for (final a in maps('aw')) Award.fromJson(a)]
      ..tradeBlock = [for (final x in (j['tbk'] as List? ?? const [])) x as int]
      ..blockBase = {
        for (final r in (j['bbs'] as List? ?? const []))
          if (r is List && r.length == 5) r[0] as int: [for (final x in r.skip(1)) x as int],
      }
      ..monthly = [for (final a in maps('mvm')) Award.fromJson(a)]
      ..coachPool = [for (final x in maps('cp')) Coach.fromJson(x)]
      ..growth = [for (final g in maps('gr')) GrowthLine.fromJson(g)]
      ..faDay = ((j['fd'] as int?) ?? 0).clamp(0, faDays)
      ..bids = {
        for (final e in (j['bd'] as Map? ?? const {}).entries)
          int.parse(e.key as String): [
            for (final b in e.value as List)
              if (b is List && b.length == 3) FaBid((b[0] as int).clamp(0, teamDefs.length - 1), b[1] as int, b[2] as int),
          ],
      }
      ..faLog = [for (final x in (j['fl'] as List? ?? const [])) x as String]
      ..capYear = (j['cy'] as int?) ?? 0
      ..mleUsed = (j['mu'] as bool?) ?? false
      ..biennialYear = (j['by'] as int?) ?? -9
      ..champs = [
        for (final r in (j['chp'] as List? ?? const []))
          if (r is List && r.length == 3) [for (final x in r) x as int],
      ]
      ..hall = [for (final h in maps('hof')) HallEntry.fromJson(h)]
      ..log = [for (final x in (j['log'] as List? ?? const [])) x as String]
      ..lastTax = (j['tax'] as int?) ?? 0
      ..draftedIds = [for (final x in (j['dr'] as List? ?? const [])) x as int]
      .._nextId = (j['nid'] as int?) ?? 100000;
    // 前の版の保存(指名権が2年分)でも、4年分そろえる
    c._fillPicks(c.phase == Phase.contracts ? c.season + 1 : c.season);
    return c;
  }

  /// 優勝の回数。
  int get titles => history.where((h) => h.champion).length;
}
