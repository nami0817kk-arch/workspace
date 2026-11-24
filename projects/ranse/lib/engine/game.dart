import 'package:flutter/foundation.dart';

import 'adult.dart';
import 'aims.dart';
import 'ashigaru.dart';
import 'ashigaru_life.dart';
import 'birth.dart';
import 'bonds.dart';
import 'castle_life.dart';
import 'childhood.dart';
import 'childhood_focus.dart';
import 'childhood_more.dart';
import 'craft_life.dart';
import 'daimyo_life.dart';
import 'data.dart';
import 'echoes.dart';
import 'echoes_more.dart';
import 'echoes_talent.dart';
import 'family.dart';
import 'history.dart';
import 'illness.dart';
import 'history_east.dart';
import 'history_life.dart';
import 'history_lines.dart';
import 'history_rumor.dart';
import 'history_shift.dart';
import 'history_west.dart';
import 'life.dart';
import 'lords.dart';
import 'major_scenes.dart';
import 'off_ladder.dart';
import 'oku_life.dart';
import 'old_age.dart';
import 'pastimes.dart';
import 'peace.dart';
import 'peace_life.dart';
import 'regions.dart';
import 'retainer_life.dart';
import 'rng.dart';
import 'scene_art.dart';
import 'seasons.dart';
import 'shadow_life.dart';
import 'spending.dart';
import 'talents.dart';
import 'temple.dart';
import 'trade_farm.dart';
import 'trait_scenes.dart';
import 'village.dart';
import 'ways.dart';
import 'women.dart';
import 'women_life.dart';

/// 選択肢。[f] が返した文字列は見聞録に書かれる。
class Choice {
  Choice(this.label, [this.f, this.cancel = false, this.danger = false])
    : hint = null,
      via = null;

  /// 岐路の選択肢。[hint] は結果を匂わせる一言（数字は出さない）。
  /// [via] は、能力・特性・持ち物の条件つきで出る手に付ける印（下の [via]）。
  Choice.h(this.label, this.hint, this.f, {this.via})
    : cancel = false,
      danger = false;

  final String label;

  /// 選ぶ前に見せる、結果の匂わせ。
  final String? hint;
  final String? Function()? f;

  /// true なら何も起こさず閉じる（手番も進まない）。
  final bool cancel;
  final bool danger;

  /// その手が出た理由（能力・特性・持ち物のおかげで出た手だけ。ほかは null）。
  /// 能力は一字（武・知・政・魅・運。二つの能力なら「知魅」のように二字）、
  /// 特性は名（`kTraits` の name）、持ち物は名（「鉄砲」など）。画面の札に出るだけで、
  /// 乱数にも結果にも効かない。
  final String? via;
}

/// [Choice.via] に書ける能力の字。
const kViaAbilities = ['武', '知', '政', '魅', '運'];

/// [Choice.via] に書ける持ち物の名。
const kViaItems = ['鉄砲'];

/// 能力の字だけでできた印か（一字、または「知魅」のような二字）。
bool viaIsAbility(String via) =>
    via.isNotEmpty &&
    via.length <= 2 &&
    via.split('').every(kViaAbilities.contains);

/// [Choice.via] に書いてよい語か（能力の字・特性の名・持ち物の名）。
bool viaKnown(String via) =>
    viaIsAbility(via) ||
    kViaItems.contains(via) ||
    kTraits.any((t) => t.name == via);

class Prompt {
  Prompt(
    this.title,
    this.text,
    this.choices,
    this.after, {
    this.art,
    this.cause,
    this.major = false,
  });
  final String title, text;

  /// 世を変えうる・一生の向きを変える「大きな分かれ道」か（`major_scenes.dart` の表）。画面の印に出るだけ。
  final bool major;

  /// その場面が起きた訳（能力で起きる岐路 `tal_` は能力の字、特性の場面 `tr_` は特性の名。ほかは null）。
  /// 画面の題の横の札に出るだけ（`sceneCauseFor`）。
  final String? cause;

  /// 添える絵の名前（`scene_art.dart` の `kSceneArts`）。場面でない問いは null。
  final String? art;
  final List<Choice> choices;

  /// 選んだあとに呼ぶ（手番を進める・画面を更新する、など）。
  final void Function() after;
}

/// 縁の役割（嫡男・子・娘 など）の指す子が、家にいて歳が [lo]〜[hi]（[female] があれば性別も）ならその子。
/// 年の分からない子は歳が合うとみなす。
Kid? roleKid(Game g, String role, int lo, [int hi = 999, bool? female]) {
  final k = g.l.kidOfRole(role);
  if (k == null || !k.home) return null;
  if (female != null && k.female != female) return null;
  final a = k.ageAt(g.year);
  return a == null || (a >= lo && a <= hi) ? k : null;
}

/// 縁談の年頃（十三から二十五）の家にいる娘。名のある娘（裳着・祝い）がその歳ならその娘。
Kid? marriageableDaughter(Game g) =>
    roleKid(g, '娘', 13, 25, true) ?? g.l.daughterAged(g.year, 13, 25);

class Game extends ChangeNotifier {
  Game({Rng? rng, this.onCheckpoint, this.onChoice}) : rng = rng ?? Rng() {
    childScenes = [
      ...buildChildScenes(),
      ...buildMoreChildScenes(),
      ...buildChildHistoryScenes(),
      ...buildChildRumorScenes(),
      ...buildTalentChildScenes(),
      ...buildRegionChildScenes(),
      ...buildChildFocusScenes(),
      ...buildSeasonChildScenes(),
    ];
    adultScenes = [
      ...buildAdultScenes(),
      ...buildWayScenes(),
      ...buildLordScenes(),
      ...buildEchoScenes(),
      ...buildEchoMoreScenes(),
      ...buildEchoTalentScenes(),
      ...buildChildFocusEchoScenes(),
      ...buildFamilyScenes(),
      ...buildBondScenes(),
      ...buildWomenScenes(),
      ...buildWomanLifeScenes(),
      ...buildAshigaruScenes(),
      ...buildAshigaruLifeScenes(),
      ...buildRetainerLifeScenes(),
      ...buildOkuLifeScenes(),
      ...buildCastleLifeScenes(),
      ...buildCraftLifeScenes(),
      ...buildDaimyoLifeScenes(),
      ...buildSeasonScenes(),
      ...buildTraitScenes(),
      ...buildSpendingScenes(),
      ...buildAimScenes(),
      ...buildVillageScenes(),
      ...buildTradeFarmScenes(),
      ...buildShadowLifeScenes(),
      ...buildOffLadderScenes(),
      ...buildTalentScenes(),
      ...buildPastimeScenes(),
      ...buildOldAgeScenes(),
      ...buildPeaceScenes(),
      ...buildPeaceLifeScenes(),
      ...buildTempleScenes(),
      ...buildRegionScenes(),
      ...buildHistoryScenes(),
      ...buildHistoryEastScenes(),
      ...buildHistoryWestScenes(),
      ...buildLifeHistoryScenes(),
      ...buildAltScenes(),
    ];
  }

  final Rng rng;

  /// 区切り（選択肢が出ていない状態）ごとに呼ばれる。保存用。
  final void Function(Game g)? onCheckpoint;

  /// 手を一つ選ぶたびに呼ばれる（年の途中の選びを残す。2026-11-24、アプリを閉じるとその年の選択が消えていた）。
  final void Function(Game g)? onChoice;

  /// 年の初めから選んだ手（何番目か・手の名）。続きから再開するとき、この順に選び直す。
  final List<(int, String)> choiceLog = [];

  /// 年の初めに乱数を引き直すか（アプリだけ真。テストの人生の流れは変えない）。
  bool reseedAtCheckpoint = false;

  /// 年の初めに引き直した種（保存に入れる。同じ種から同じ年を流し直す）。
  int? checkpointSeed;
  bool _restoring = false;

  /// 年の初めの区切り。選んだ手の記録を空にし、乱数を引き直してから保存を呼ぶ。
  void _yearCheckpoint() {
    choiceLog.clear();
    if (reseedAtCheckpoint && !_restoring) checkpointSeed = rng.reseed();
    onCheckpoint?.call(this);
  }

  late final List<SceneDef> childScenes, adultScenes;

  Life? life;
  Map<String, Faction> fa = {};
  Prompt? prompt;

  Life get l => life!;
  List<Faction> get alive => fa.values.where((f) => f.alive).toList();

  // ---------- 時間 ----------
  int get year => l.startYear + l.t ~/ 2;
  int get age => l.t ~/ 2;
  bool get isChild => age < 15;
  String get season => l.t % 2 == 0 ? '春夏' : '秋冬';
  List<String> get rk => l.female ? kRanksF : kRanksM;
  bool has(String id) => l.has(id);
  bool get canFight => !l.female || has('onna') || l.rank == 8;

  /// 戦える人だけに出る手の印（[Choice.via]）。女武者の特性のおかげで戦える女性にだけ付く。
  String? get fightVia => l.female && has('onna') ? kTraitOnna.name : null;

  /// 運で当たり外れを引く（運の条件つきの手 `via: '運'` の結果）。運が高いほど当たりやすいが、必ずではない。
  bool luck([double base = .35]) => rng.chance(clampD(base + l.un / 200, .1, .9));

  /// 腕で片が付くかを引く（武の条件つきの手 `via: '武'` の結果）。武が高いほど通りやすい。
  bool might([double base = .4]) => rng.chance(clampD(base + l.bu / 200, .1, .92));

  /// 隠居していない（家中の務めや合戦に関わる）。
  bool get active => !hasFlag('retired');

  double get share {
    final a = alive;
    final tot = a.fold<double>(0, (s, f) => s + f.power);
    final lord = l.lord;
    if (lord == null || fa[lord] == null || tot == 0) return 0;
    return fa[lord]!.power / tot;
  }

  // ---------- 状態の更新 ----------
  void j(int n) => l.joy = clampInt(l.joy + n, 0, 100);

  /// 前の選択肢が出てから、いまの選択肢が出るまでに起きたこと（画面で「前の選択の結果」として見せる）。
  List<LogEntry> lastResults = [];
  final List<LogEntry> _pending = [];

  void log(String txt, [String kind = '', String? cause]) {
    final e = LogEntry('$year$season', txt, kind, cause: cause);
    _pending.add(e);
    l.log.insert(0, e);
    if (l.log.length > 140) l.log.removeLast();
  }

  void rec() {
    l.hist.add(
      HistPoint(
        l.t / 2,
        l.hp / l.maxhp * 100,
        l.joy.toDouble(),
        l.chi.toDouble(),
        l.net > 100 ? 100 : l.net.toDouble(),
      ),
    );
  }

  /// 亡くなる。[kind] は死に方の種類（`kDeathKinds` のキー）。最初の一度だけ効く。
  void die(String cause, [String kind = 'byo']) {
    if (l.dead != null) return;
    l.dead = cause;
    l.deathKind = kind;
  }

  /// 歩んだ道に一行足す（結果カードに載る）。
  void mark(String text) => l.path.add('$age歳　$text');

  void setFlag(String f) => l.flags.add(f);
  bool hasFlag(String f) => l.flags.contains(f);

  /// 縁のある人と出会う。同じ役割なら置き換わる。
  /// 子を指す役割（嫡男・娘・子 など、`kKidRoles`）は、同じ名の子の記録と結ぶ。
  void meet(String role, String name, int bond) {
    l.people[role] = Person(role, name, bond);
    if (kKidRoles.contains(role)) l.bindKidRole(role, year);
  }

  /// 画面を更新する。選択肢が出ていない区切りでは保存も呼ぶ。
  void changed() {
    if (prompt == null && life != null) onCheckpoint?.call(this);
    notifyListeners();
  }

  /// いま進めている場面の id（絵を選ぶため。選んだら消す）。
  String? _sceneId;

  void ask(
    String title,
    String text,
    List<Choice> choices, {
    void Function()? after,
  }) {
    lastResults = [..._pending];
    _pending.clear();
    prompt = Prompt(
      title,
      text,
      choices,
      after ?? changed,
      art: sceneArtFor(this, _sceneId, title),
      cause: sceneCauseFor(_sceneId),
      major: isMajorScene(_sceneId),
    );
    notifyListeners();
  }

  /// 直近の手で変わった歴史（`history_shift.dart`）。画面が一度だけ「歴史が動いた」と知らせる。
  /// 次の手を選ぶか、[dismissHistoryShift] で消える。続きから選び直すあいだは立てない。
  HistoryShift? historyShift;
  bool _replaying = false;

  void dismissHistoryShift() {
    if (historyShift == null) return;
    historyShift = null;
    notifyListeners();
  }

  void choose(int i) {
    final p = prompt!;
    prompt = null;
    _sceneId = null;
    historyShift = null;
    final c = p.choices[i];
    choiceLog.add((i, c.label));
    if (c.cancel) {
      changed();
      onChoice?.call(this);
      return;
    }
    final before = _replaying ? null : historyKeys(this);
    final res = c.f?.call();
    if (before != null) historyShift = newHistoryShift(this, before);
    // 岐路の結果には場面の名前を付ける（「この年の心がけ」は文の中に「今年は…」とあるので付けない）。
    if (res != null) log(p.title == 'この年の心がけ' ? res : '【${p.title}】$res');
    p.after();
    onChoice?.call(this);
  }

  // ---------- 人生の開始 ----------
  void newWorld() {
    fa = {
      for (final e in kFactionBase.entries)
        e.key: Faction(e.key, e.value * (0.75 + rng.next() * 0.5)),
    };
  }

  static const _infant = [.12, .05, .03, .02, .02];

  void start(Birth b) {
    newWorld();
    prompt = null;
    historyShift = null;
    final s = b.stats;
    life = Life(
      name: b.name,
      cls: b.cls,
      clsName: b.label,
      female: b.female,
      order: b.order,
      region: b.region.n,
      home: b.faction,
      startYear: b.startYear,
      bu: s.bu,
      chi: s.chi,
      sei: s.sei,
      mi: s.mi,
      un: s.un,
      maxhp: s.maxhp,
      joy: 50 + (b.cls.id == 'beggar' ? -10 : (b.cls.rank >= 3 ? 5 : 0)),
      gold: b.cls.gold,
      birthRank: b.birthRank,
      traits: b.traits.map((t) => t.id).toList(),
      rarity: b.rarity,
      sameClass: b.sameClass,
    );
    log(
      '$year年（${gengo(year)}）、${b.region.n}国の${b.cls.name}の家に'
          '${ordLabel(b.female, b.order)}として生まれた。',
      'big',
    );
    // 乳幼児期（0〜4歳）は自動で進む。
    for (var a = 0; a < 5 && l.dead == null; a++) {
      final m =
          _infant[a] *
          l.cls.m *
          (has('sickly') ? 1.5 : 1) *
          (has('hardy') ? .7 : 1);
      l.t = a * 2;
      rec();
      if (rng.chance(m)) {
        l.t = a * 2 + 1;
        die(a == 0 ? '生まれて間もなく亡くなった' : '幼くして病に倒れた');
        log(
          a == 0
              ? '産声を上げて間もなく、息絶えた。この時代、生まれた子の五人に一人は五つまで生きられない。'
              : '$a歳の冬、熱病で世を去った。',
          'bad',
        );
      }
    }
    if (l.dead == null) {
      l.t = 10;
      log('五つの春を迎えた。幼い命は、どうにか生き延びた。');
      _beginYear();
      return;
    }
    changed();
  }

  /// 保存から復元する。
  ///
  /// 年の始まりで保存している。その年を最初から流し、種（`seed`）があれば同じ乱数で流し直して、
  /// 年の初めから選んでいた手（`replay`）を順に選び直す。手の名が食い違ったら、そこで止める。
  void restore(
    Life saved,
    Map<String, Faction> world, {
    int? seed,
    List<(int, String)> replay = const [],
  }) {
    life = saved;
    fa = world;
    prompt = null;
    historyShift = null;
    if (saved.dead == null && saved.end == null) {
      _recap();
      final recap = [..._pending];
      if (seed != null) {
        rng.setSeed(seed);
        checkpointSeed = seed;
      }
      _restoring = true;
      isChild ? _beginYear() : _beginAdultYear();
      _restoring = false;
      var n = 0;
      if (seed != null) {
        _replaying = true;
        for (final (i, label) in replay) {
          final p = prompt;
          if (p == null || finished || i >= p.choices.length) break;
          if (p.choices[i].label != label) break;
          choose(i);
          n++;
        }
        _replaying = false;
      }
      // 選び直した場合も、再開した最初の画面に「前回までのあらすじ」を出す。
      if (n > 0 && !finished) {
        lastResults = [...recap, ...lastResults];
        notifyListeners();
      }
      return;
    }
    notifyListeners();
  }

  /// 画面にだけ出す一行（見聞録には残さない）。
  void _note(String txt, [String kind = '']) =>
      _pending.add(LogEntry('$year$season', txt, kind));

  /// 再開したときの「前回までのあらすじ」。
  void _recap() {
    _note('―― 前回までのあらすじ ――', 'big');
    _note(
      '${l.name}、$age歳。${rankName()}${l.lord != null ? '（${houseName(this, l.lord)}家）' : ''}。',
    );
    for (final p in l.path.reversed.take(3).toList().reversed) {
      _note(p);
    }
  }

  static const _chapters = {
    30: '【壮年の章】三十の坂を越えた。',
    45: '【熟年の章】四十五。人生の秋が見えてきた。',
    60: '【晩年の章】還暦を迎えた。',
  };

  /// 章の区切り（30・45・60歳）。ここまでを短く振り返る。
  void _chapter() {
    final head = _chapters[age];
    if (head == null || hasFlag('chapter:$age')) return;
    setFlag('chapter:$age');
    final sp = l.married ? l.people['伴侶'] : null;
    log(
      '$headいまは${rankName()}${l.lord != null ? '（${houseName(this, l.lord)}家）' : ''}。'
          '${sp != null ? '連れ合いは${sp.name}。' : ''}${l.kids > 0 ? '子は${l.kids}人。' : ''}',
      'big',
    );
  }

  // ---------- 合戦 ----------
  /// 合戦に加わる。[role] は持ち場（van 先陣・main 本陣・ほかは後詰め）。
  /// 合戦の状況（`battles.dart`）は、選んだ手で [risk]（討死の危うさの倍率）・[gain]（手柄の倍率）・
  /// [edge]（味方の勝ちやすさに足す）を変える。既定の値なら従来どおり。
  String battle(
    String role, {
    String? enemy,
    double risk = 1,
    double gain = 1,
    double edge = 0,
  }) {
    final lf = fa[l.lord]!;
    final named = enemy == null ? null : fa[enemy];
    final e = (named != null && named.alive && named != lf)
        ? named
        : rng.pick(alive.where((f) => f != lf).toList());
    var w = clampD(lf.power / (lf.power + e.power), .15, .85);
    if (edge != 0) w = clampD(w + edge, .08, .92);
    final win = rng.chance(w);
    final (d: danger, m: mult) = switch (role) {
      'van' => (d: .2, m: 2.0),
      'main' => (d: .09, m: 1.2),
      _ => (d: .03, m: .6),
    };
    final skill =
        l.bu * .6 +
        l.chi * .15 +
        l.un * .25 +
        (l.gun ? 10 : 0) +
        (l.troops * .3 > 30 ? 30 : l.troops * .3);
    var dp = danger * (win ? .7 : 1.4) * (1 - clampD(skill / 150, 0, .7));
    if (l.hp < 40) dp *= 1.5;
    dp *= risk * spendingRisk(this); // 具足・馬・郎党（`spending.dart`）
    // 死因と結果の文に出す家の名は、いまの呼び名で（一五六七年からは徳川、一五八六年からは豊臣）。
    final en = houseName(this, e.name);
    if (rng.chance(dp)) {
      die('$enとの合戦で討死', 'senshi');
      return '$enとの合戦で、${role == 'van' ? '先陣にて' : ''}討死した。';
    }
    final merit =
        (mult *
                gain *
                spendingGain(this) *
                (skill / 12 + rng.range(0, 6)) *
                (win ? 1.3 : .6) *
                (1 + l.troops / 150))
            .round();
    l.merit += merit;
    l.fame += merit ~/ 3;
    l.fav = clampInt(l.fav + (win ? 3 : -1), 0, 100);
    j(win ? 2 : -4);
    var txt = '$en家との合戦。${win ? '我が方の勝利！' : '我が方は敗れた。'}功$merit。';
    if (win) {
      final g = rng.range(1, 4) * mult.ceil();
      l.gold += g;
      txt += '恩賞と戦利で銭$g貫。';
      lf.power += 1.5;
      e.power = e.power - 1.5 < 3 ? 3 : e.power - 1.5;
    } else {
      final lost = (l.troops * .15).floor();
      l.troops -= lost;
      if (lost > 0) txt += '兵$lostを失う。';
      lf.power = lf.power - 1.5 < 3 ? 3 : lf.power - 1.5;
    }
    if (rng.chance(danger * .8)) {
      final dmg = rng.range(10, 30);
      l.hp -= dmg;
      j(-3);
      txt += '深手を負った（体力-$dmg）。';
    }
    if (l.hp <= 0) {
      die('戦傷が元で死去', 'senshi');
      txt += '傷は癒えなかった。';
    }
    return txt;
  }

  double betrayChance() {
    final lf = fa[l.lord]!;
    return clampD(
      .1 +
          (l.troops / (l.troops + lf.power * 3)) * .6 +
          (has('amb') ? .1 : 0) -
          l.fav / 400 +
          (l.chi + l.un) / 600 +
          (has('loyal') ? -.1 : 0) +
          gkPrepBonus(this), // 謀反の支度（`aims.dart`。2026-11-25）
      .05,
      .8,
    );
  }

  String doBetray(double p) {
    final lf = fa[l.lord]!;
    if (rng.chance(p)) {
      l.rank = 8;
      l.maxRank = l.maxRank > 8 ? l.maxRank : 8;
      l.fame += 30;
      lf.power = lf.power * .85 + l.troops * .3;
      l.gold += 40;
      l.troops = 0;
      j(10);
      return '下剋上成功！${houseName(this, l.lord)}家を乗っ取り、ついに大名の座に就いた！';
    }
    if (rng.chance(.35)) {
      die('謀反に失敗し、処刑された', 'seppuku');
      return '謀反は露見し、捕らえられて処刑された…';
    }
    l.rank = 0;
    l.lord = null;
    l.troops = 0;
    l.fame -= 20;
    l.fav = 0;
    l.ronin = true;
    l.gold = (l.gold * .3).floor();
    j(-20);
    return '謀反に敗れたが、命からがら国を逃れた。浪人となる。';
  }

  double invadeP(Faction me, Faction t, double sk) =>
      clampD(me.power * sk / (me.power * sk + t.power), .05, .95);

  String doInvade(Faction t, double sk) {
    final me = fa[l.lord]!;
    if (rng.chance(invadeP(me, t, sk))) {
      final gain = t.power * .6;
      me.power += gain;
      l.fame += 10;
      j(3);
      if (t.power * .4 < 8 || rng.chance(.5)) {
        t.alive = false;
        t.power = 0;
        l.conq++;
        log('${t.name}家は滅んだ。', 'big');
      } else {
        t.power *= .4;
      }
      return '${t.name}家との戦に勝利！勢力が${gain.toStringAsFixed(1)}増した。';
    }
    me.power *= .8;
    l.fame -= 3;
    j(-5);
    if (rng.chance(.08 * (1 - l.un / 200))) {
      die('${houseName(this, t.name)}家との戦で討死', 'senshi');
      return '${houseName(this, t.name)}家との戦に敗れ、討死した。';
    }
    return '${t.name}家との戦に敗れた。勢力が削られた。';
  }

  // ---------- ターン進行 ----------
  /// 年ごとの病死・老衰の割合（大人）。2026-11-23 に、若いうちの病死を4割ほど下げた
  /// （選択と関係のない「病に倒れた」が成人の死の3分の1を占め、平均31歳で人生が切れていたため）。
  /// 寿命の上限の歳。この歳に届いた年に、必ず天寿が来る（一五六八年生まれでも一六五三年まで）。
  static const kMaxAge = 85;

  static double annualMort(int a) => a < 25
      ? .007
      : a < 35
      ? .010
      : a < 45
      ? .015
      : a < 55
      ? .03
      : a < 65
      ? .08
      : a < 75
      ? .16
      : .3;

  void comeOfAge() {
    // 幼いうちに起きた史実を、見聞録に書かずに進めておく。
    applyHistory(this, year - 1, quietBefore: 9999);
    l.rank = l.birthRank;
    l.maxRank = l.rank;
    final home = (fa[l.home]?.alive ?? false)
        ? l.home
        : (alive..sort((a, b) => b.power.compareTo(a.power))).first.name;
    if (l.rank >= 1) {
      l.lord = home;
      l.fav = l.rank >= 3 ? 35 : 25;
    }
    if (l.rank >= 5) {
      l.troops = 30;
    } else if (l.rank == 3) {
      l.troops = 5;
    }
    var txt = '十五になり、${l.female ? '裳着' : '元服'}を迎えた。ここから先は、自らの選択で生きる。';
    if (l.female && l.cls.id == 'daimyo' && rng.chance(.12)) {
      l.rank = 8;
      l.maxRank = 8;
      l.troops = 0;
      fa[home]!.power *= .9;
      txt += '\n父に男子がなく、あなたが家督を継ぐことになった！';
    } else if (l.rank == 8) {
      fa[home]!.power *= .9;
      txt += '\n父が没し、あなたは家督を継いだ。若き当主の船出である。';
    } else if (l.rank >= 1) {
      txt += '\n$home家での身分は「${rk[l.rank]}」。';
    } else {
      txt += '\n身分はなく、己の力だけが頼りだ。';
    }
    log(txt.replaceFirst('\n', ' '), 'big');
    ask(l.female ? '裳着' : '元服', txt, [
      Choice('乱世へ歩み出す'),
    ], after: _beginAdultYear);
  }

  // ---------- 幼少期（5〜14歳） ----------
  // 1年ごとに「この年の心がけ」を選ぶ。選んだ年の途中で、岐路が起きることがある。

  /// 年の始まり。保存はここで行い、「この年の心がけ」を聞く。
  void _beginYear() {
    prompt = null;
    final a = age;
    l.t = a * 2;
    _yearCheckpoint();
    final opts = childFocusOptions(this);
    // いつもの4つ（手伝い・読み書き・武芸ごっこ、遊ぶか友と過ごすのどちらか）に、
    // 家柄・年頃で増える重点（寺の手習い・道場・算盤・行儀見習い）を足す。
    final shown = [
      ...opts.sublist(0, 3),
      rng.chance(.5) ? opts[3] : opts[4],
      ...opts.sublist(5),
    ];
    ask('この年の心がけ', childYearText(this), [
      for (final o in shown)
        Choice.h(o.label, o.hint, () {
          final before = (l.bu, l.chi, l.net, l.gold);
          o.perYear(this);
          l.focus[o.tag] = (l.focus[o.tag] ?? 0) + 1;
          _forced = o.forced;
          final d = <String>[];
          if (l.bu > before.$1) d.add('武+${l.bu - before.$1}');
          if (l.chi > before.$2) d.add('知+${l.chi - before.$2}');
          if (l.net > before.$3) d.add('縁+${l.net - before.$3}');
          if (l.gold > before.$4) d.add('銭+${l.gold - before.$4}');
          return '今年は${o.label}。${d.isEmpty ? '' : d.join('・')}';
        }),
    ], after: _yearScene);
  }

  /// 年の途中。この年齢で起こりうる岐路があれば、確率で一つ出す。
  void _yearScene() {
    final a = age;
    // 重点で選んだ岐路（寺の手習いの初日など）は、まだ出ていなければその年に出す。
    final forcedId = _forced;
    _forced = null;
    // 続けた年の岐路（`childhood_focus.dart`）は、その年に史実の岐路があれば次に選んだ年へ回す
    // （史実の岐路はその年かぎりで、1年に出す岐路は1つまでのため）。
    final deferred =
        forcedId != null &&
        isChildFocusStage(forcedId) &&
        childScenes.any((s) => isHistoryScene(s.id) && _childSceneOk(s, a));
    if (forcedId != null && !deferred) {
      for (final s in childScenes) {
        if (s.id == forcedId && !hasFlag('scene:${s.id}') && s.cond(this)) {
          l.t = a * 2 + 1;
          setFlag('scene:${s.id}');
          _sceneId = s.id;
          s.run(this, _endYear);
          return;
        }
      }
    }
    // 季節の行事（`seasons.dart`）はふつうの候補に入れず、岐路の起きなかった年にだけ出す。
    final cand = [
      for (final s in childScenes)
        if (!isSeasonScene(s.id) && _childSceneOk(s, a)) s,
    ];
    // その年の史実の岐路は、数の上限や確率に関係なく必ず出す。
    final hist = cand.where((s) => isHistoryScene(s.id)).toList();
    if (hist.isNotEmpty) {
      final s = hist.first;
      l.t = a * 2 + 1;
      setFlag('scene:${s.id}');
      _sceneId = s.id;
      s.run(this, _endYear);
      return;
    }
    final done = l.flags
        .where(
          (f) =>
              f.startsWith('scene:') &&
              !isHistoryScene(f.substring(6)) &&
              !isSeasonScene(f.substring(6)),
        )
        .length;
    // 幼少期の岐路は6つほどに収める。少なすぎれば出やすく、多すぎれば出にくくする。
    var p = .5;
    if (a >= 11 && done < 4) p = .9;
    if (done >= 7) p = .1;
    if (cand.isEmpty || !rng.chance(p)) {
      // 岐路の起きなかった年にも、季節の行事が巡ってくることがある（`seasons.dart`）。
      final seasons = [
        for (final s in childScenes)
          if (isSeasonScene(s.id) && _childSceneOk(s, a)) s,
      ];
      if (seasons.isNotEmpty && rng.chance(kSeasonChildQuietChance)) {
        final s = rng.wpick(seasons, (e) => e.weight(this));
        l.t = a * 2 + 1;
        setFlag('scene:${s.id}');
        _sceneId = s.id;
        s.run(this, _endYear);
        return;
      }
      _endYear();
      return;
    }
    final s = rng.wpick(cand, (e) => e.weight(this));
    l.t = a * 2 + 1;
    setFlag('scene:${s.id}');
    _sceneId = s.id;
    s.run(this, _endYear);
  }

  bool _childSceneOk(SceneDef s, int a) =>
      !s.onlyForced &&
      !hasFlag('scene:${s.id}') &&
      !_twinDone(s.id) &&
      !sceneSkippedInLine(this, s.id) &&
      a >= s.minAge &&
      a <= s.maxAge &&
      (s.ageOk == null || s.ageOk!(this, a)) &&
      s.cond(this);

  /// 年の終わり。体力が戻り、幼い命が病で失われることもある。
  void _endYear() {
    if (l.dead != null) {
      changed();
      return;
    }
    final a = age;
    l.t = a * 2 + 1;
    l.hp = l.hp + 4 > l.maxhp ? l.maxhp : l.hp + 4;
    if (l.hp <= 0) {
      die('幼くして衰弱し、亡くなった');
    } else if (rng.chance(.008 * l.cls.m * (l.hp < 40 ? 2 : 1))) {
      die('幼くして病に倒れた');
      log('熱病に冒され、幼くして世を去った。', 'bad');
    }
    rec();
    if (l.dead != null) {
      changed();
      return;
    }
    // 能力がはじめて段（60・75・90）を越えたら、【才】の一行を書く。
    talentMilestones(this);
    // 子どものうちも世は動く（見聞録に【世】として残る）。
    applyHistory(this, year, quietBefore: year);
    l.t = (a + 1) * 2;
    if (a + 1 >= 15) {
      comeOfAge();
      return;
    }
    _beginYear();
  }

  // ---------- 大人（15歳〜） ----------
  // 幼少期と同じく、1年ごとに「この年の心がけ」を選ぶ。重点によっては、その年に必ず岐路が起きる。

  String? _forced;

  /// 年の始まり。保存はここで行い、「この年の心がけ」を聞く。
  void _beginAdultYear() {
    prompt = null;
    l.t = age * 2;
    _chapter();
    _yearCheckpoint();
    final opts = adultFocusOptions(this);
    ask('この年の心がけ', adultYearText(this), [
      for (final o in opts)
        Choice.h(o.label, o.hint, () {
          final lordF = l.lord == null ? null : fa[l.lord];
          final p0 = lordF?.power ?? 0;
          final b = (l.bu, l.chi, l.net, l.gold, l.merit, l.fav, l.troops);
          o.perYear(this);
          l.focus[o.tag] = (l.focus[o.tag] ?? 0) + 1;
          _forced = o.forced;
          final d = <String>[];
          if (l.bu > b.$1) d.add('武+${l.bu - b.$1}');
          if (l.chi > b.$2) d.add('知+${l.chi - b.$2}');
          if (l.net > b.$3) d.add('縁+${l.net - b.$3}');
          if (l.gold > b.$4) d.add('銭+${l.gold - b.$4}');
          if (l.merit > b.$5) d.add('功+${l.merit - b.$5}');
          if (l.fav > b.$6) d.add('信頼+${l.fav - b.$6}');
          if (l.troops > b.$7) d.add('兵+${l.troops - b.$7}');
          if (lordF != null && l.rank == 8 && lordF.power - p0 >= .5) {
            d.add('勢力+${(lordF.power - p0).toStringAsFixed(1)}');
          }
          return '今年は${o.label}。${d.join('・')}';
        }),
    ], after: _adultYearScene);
    _yearPrompt = prompt;
  }

  /// 大人の年の初めの問い（「この年の心がけ」）。[atYearStart] が見る。
  Prompt? _yearPrompt;

  /// 大人の年の初めの問いが出ているか（まだ心がけを選んでいない）。銭と功の使い道を使えるのはこのときだけ（`spending.dart`）。
  bool get atYearStart =>
      life != null &&
      !finished &&
      !isChild &&
      prompt != null &&
      identical(prompt, _yearPrompt);

  /// 年の初めの問いのまま、保存し直す（2026-11-25、銭と功の使い道を年の初めに使ったとき）。
  ///
  /// 年の初めの種（[checkpointSeed]）に乱数を戻して、続きから再開したとき（[restore]）と同じ手順で問いを作り直し、
  /// 保存（`onCheckpoint`）を呼ぶ。保存には使ったあとの暮らしが入り、再開すると同じ問いが出る。
  /// 選んだ手の記録（[choiceLog]）は空のまま。年の初めでなければ何もしない。
  void resaveYearStart() {
    if (!atYearStart) return;
    final keep = [...lastResults];
    if (checkpointSeed != null) rng.setSeed(checkpointSeed!);
    _restoring = true;
    _beginAdultYear();
    _restoring = false;
    lastResults = [...keep, ...lastResults];
    notifyListeners();
  }

  bool _sceneOk(SceneDef s, int a) =>
      a >= s.minAge &&
      a <= s.maxAge &&
      (s.ageOk == null || s.ageOk!(this, a)) &&
      (s.repeat || !hasFlag('scene:${s.id}')) &&
      !_twinDone(s.id) &&
      !sceneSkippedInLine(this, s.id) &&
      !sceneSkippedInPeace(this, s.id) &&
      s.cond(this);

  bool _twinDone(String id) {
    final t = twinScene(id);
    return t != null && hasFlag('scene:$t');
  }

  /// 年の途中。重点で決まった岐路があればそれを、なければ確率で一つ出す。
  void _adultYearScene() {
    final a = age;
    var forcedId = _forced;
    _forced = null;
    // 初陣を済ませていなければ、出陣は初陣になる。
    if (forcedId == 'battle' && !hasFlag('first_battle')) {
      forcedId = 'first_battle';
    }
    if (forcedId != null) {
      for (final s in adultScenes) {
        if (s.id == forcedId && _sceneOk(s, a)) {
          _runAdultScene(s, _historyScenes);
          return;
        }
      }
    }
    // その年の史実の岐路があれば、それを（いくつでも順に）出す。
    if (_nextHistoryScene() != null) {
      _historyScenes();
      return;
    }
    final cand = [
      for (final s in adultScenes)
        if (!s.onlyForced &&
            !isHistoryScene(s.id) &&
            !isSeasonScene(s.id) &&
            _sceneOk(s, a))
          s,
    ];
    if (cand.isEmpty || !rng.chance(sceneChance)) {
      // 岐路の起きない静かな年にも、始まった縁の筋の続き（二の段から）は出ることがある
      // （ほかの岐路を押しのけずに、筋を結末まで見届けやすくする。`bonds.dart`）。
      final bonds = [
        for (final s in cand)
          if (kBondPrev.containsKey(s.id)) s,
      ];
      if (bonds.isNotEmpty && rng.chance(kBondQuietChance)) {
        _runAdultScene(rng.wpick(bonds, (e) => e.weight(this)), _endAdultYear);
        return;
      }
      // 縁の続きも出なかった静かな年には、季節の行事が巡ってくることがある（`seasons.dart`。
      // ふつうの年の候補には入れないので、ほかの岐路を押しのけない）。
      final seasons = [
        for (final s in adultScenes)
          if (isSeasonScene(s.id) && _sceneOk(s, a)) s,
      ];
      if (seasons.isNotEmpty && rng.chance(kSeasonQuietChance)) {
        _runAdultScene(rng.wpick(seasons, (e) => e.weight(this)), _endAdultYear);
        return;
      }
      _endAdultYear();
      return;
    }
    _runAdultScene(rng.wpick(cand, (e) => e.weight(this)), _endAdultYear);
  }

  /// 重点で決まった岐路の代わりに、ふつうの年と同じく岐路を引く（`aims.dart` の訪ねる年。ほかの岐路を押しのけない）。
  void usualYearScene() => _adultYearScene();

  /// 大人の年に（重点で決まった岐路・史実の岐路がないとき）岐路が起きる確率。
  /// 2026-11-23 に .55 → .7（岐路が約300に増え、1人生の長さが目標の半分だったため）。
  static const sceneChance = .7;

  SceneDef? _nextHistoryScene() {
    for (final s in adultScenes) {
      if (isHistoryScene(s.id) && !s.onlyForced && _sceneOk(s, age)) return s;
    }
    return null;
  }

  /// その年の史実の岐路を順に出し、終わったら年の終わりへ。
  void _historyScenes() {
    final s = l.dead == null ? _nextHistoryScene() : null;
    if (s == null) {
      _endAdultYear();
      return;
    }
    _runAdultScene(s, _historyScenes);
  }

  void _runAdultScene(SceneDef s, void Function() then) {
    setFlag('scene:${s.id}');
    _sceneId = s.id;
    s.run(this, then);
  }

  /// 年の終わり。半年ぶんの暮らしを2回進め、次の年へ。
  void _endAdultYear() {
    if (l.dead != null) {
      changed();
      return;
    }
    spendingYear(this); // 田・知行・店などの持ち物（`spending.dart`）
    _halfYearUpkeep();
    if (l.dead == null && l.end == null) _halfYearUpkeep();
    rec();
    if (l.dead != null || l.end != null) {
      changed();
      return;
    }
    // 能力がはじめて段（60・75・90）を越えたら、【才】の一行を書く。
    talentMilestones(this);
    _beginAdultYear();
  }

  /// 半年ぶんの暮らし（収支・体・世の動き・昇進・家族・寿命・天下）。1年で2回呼ぶ。
  void _halfYearUpkeep() {
    l.t++;
    // 収支
    if (l.rank == 0) {
      l.gold += ((l.cls.id == 'farmer' || l.cls.id == 'fisher') ? 2 : 0) - 2;
    } else if (l.rank < 8) {
      l.gold += kStipend[l.rank] - (l.troops * .15).ceil();
    } else {
      l.gold += (fa[l.lord]!.power * .4).round();
    }
    if (l.gold < 0) {
      l.gold = 0;
      if (l.rank == 0) {
        l.hp -= 8;
        j(-6);
        log('飢えが身にこたえる…', 'bad');
      } else if (l.troops > 0 && !traitKeepsMen(this)) {
        // 気前がいい（`trait_scenes3.dart`）人の兵は、給金が滞っても逃げない。
        final d = (l.troops * .15).ceil();
        l.troops -= d;
        log('給金が払えず、兵$d人が逃散した。', 'bad');
      }
    }
    // 体の戻りは歳で細り、季節の軽い病で寝込むこともある（`illness.dart`。2026-11-25 健康の棒を動かす）。
    // 飢えている年は前と同じ戻り（飢え死にの出方を変えない）。
    healthUpkeep(this, hungry: l.rank == 0 && l.gold == 0);
    if (l.t % 2 == 1) seasonalAilment(this);
    final starving = l.rank == 0 && l.gold == 0 && !hasFlag('priesthood');
    // 幸福の影響
    j((50 - l.joy).sign);
    if (l.joy < 20) {
      l.hp -= 2;
    } else if (l.joy >= 70) {
      l.hp = l.hp + 1 > l.maxhp ? l.maxhp : l.hp + 1;
    }
    if (l.t % 2 == 0 && age > 45 && rng.chance(.5)) {
      l.bu = l.bu - 1 < 5 ? 5 : l.bu - 1;
    }
    if (l.hp <= 0) starving ? die('飢えて死んだ', 'ue') : die('衰弱して死去');
    applyHistory(this, year, quietBefore: l.startYear + 15);
    _simWorld();
    if (l.dead == null) {
      if (l.female && l.married && l.rank >= 1 && l.rank < 8) l.merit += 1;
      // 昇進
      while (l.rank >= 1 && l.rank < 7) {
        final n = kPromo[l.rank + 1]!;
        if (l.merit >= n.merit &&
            l.fav >= n.fav &&
            (l.troops >= n.troops || !canFight)) {
          l.rank++;
          if (l.rank > l.maxRank) l.maxRank = l.rank;
          final bonus = l.rank * 10;
          l.gold += bonus;
          j(6);
          log('昇進！${rk[l.rank]}に取り立てられた。恩賞として銭$bonus貫。', 'big');
        } else {
          break;
        }
      }
      // 家族
      if (l.married &&
          age >= 16 &&
          age <= (l.female ? 40 : 60) &&
          l.kids < 8 &&
          rng.chance(l.female ? .10 : .06)) {
        final born = l.addKid(year);
        j(8);
        log('${born.female ? '娘' : '息子'}の${born.name}が生まれた（${l.kids}人目）。', 'good');
        final risk = clampD(
          (l.hp < 40 ? .08 : .03) *
              (has('hardy') ? .7 : 1) *
              (hasFlag('good_midwife') ? .4 : 1),
          0,
          .2,
        );
        if (l.female && rng.chance(risk)) {
          die('産褥で亡くなった');
          log('お産が長引き、力尽きた。', 'bad');
        }
      }
      // 幼い子（家にいる十までの子。年の分からない子も数える）がいるときだけ。
      final young = l.kidsAged(year, 0, 10).length;
      if (l.dead == null && young > 0 && rng.chance(.012 * young)) {
        l.loseKid(year, 0, 10);
        j(-25);
        setFlag('fa_lost_child');
        log('幼い我が子を病で失った。', 'bad');
      }
      // 天寿
      // 病に伏した翌年は、持ち直すか亡くなるかが決まる（`illness.dart`）。
      if (l.dead == null) resolveIllness(this);
      if (l.dead == null) {
        final a = age;
        var dp = annualMort(a) / 2 * l.cls.m;
        // 健康が高いほど病にかかりにくい（2026-11-24。前は三十を下回ったときに2倍にするだけだった）。
        dp *= healthMortFactor(l.hp);
        if (has('sickly')) dp *= 1.5;
        if (has('hardy')) dp *= .7;
        dp *= traitOldAge(this); // 長命の血筋（`trait_scenes2.dart`）
        if (l.joy < 20) {
          dp *= 1.3;
        } else if (l.joy >= 70) {
          dp *= .9;
        }
        // 人生は亡くなるまで続く（2026-11-24。一六〇一年で終える決まりは外した）。
        // 老いの坂は annualMort が年ごとに急になり、[kMaxAge] に届いた年には必ず天寿が来る。
        // 五十五より前は、突然亡くならずに、まず病に伏す（翌年に持ち直すか亡くなるかが決まる）。
        if (a >= kMaxAge) {
          die('天寿をまっとうした', 'tenju');
        } else if (a >= 55) {
          if (rng.chance(dp)) die('天寿をまっとうした', 'tenju');
        } else if (!isSick(this) && rng.chance(dp * kIllOnsetScale)) {
          fallIll(this);
        }
      }
      // 天下。人生が終わるのは、死と天下統一だけ（古い保存に残る `end == 'era'` は読めるが、もう立てない）。
      if (l.dead == null) {
        if (l.rank == 8 && share >= .5) {
          l.victory = true;
          l.rank = 9;
          l.maxRank = 9;
          l.end = 'victory';
        }
      }
    }
  }

  void _simWorld() {
    final al = alive;
    for (final f in al) {
      f.power = f.power * (1 + rng.range(0, 6) / 1000);
      if (f.power > 120) f.power = 120;
    }
    // 小競り合い。勢力は削り合うが、滅ぶのは史実の年表（history.dart）とプレイヤーの侵攻だけ。
    // 泰平の世（史実どおりの世の大坂の陣のあと）には、家どうしの小競り合いは起きない。
    if (al.length > 2 && !peaceTime(this) && rng.chance(.25)) {
      final a = rng.wpick(al, (f) => f.power);
      // 領地を削り合うのは隣り合う家どうし。
      final d = rng.pick(
        nearest(al.where((f) => f != a), (f) => f.name, faction: a.name),
      );
      if (rng.chance(clampD(a.power / (a.power + d.power), .15, .85))) {
        final take = d.power * .12;
        a.power += take;
        d.power = d.power - take < 3 ? 3 : d.power - take;
        if (rng.chance(.3)) log('【世】${a.name}家が${d.name}家の領地を切り取った。');
      } else {
        a.power *= .95;
      }
    }
  }

  /// 主家 [d] が [a] に滅ぼされたときの、自分の身の振り方。
  void lordLost(Faction d, Faction a) {
    if (l.lord != d.name || l.dead != null) return;
    if (l.rank >= 8) {
      l.rank = 0;
      l.lord = null;
      l.troops = 0;
      l.gold = (l.gold * .3).floor();
      l.fav = 0;
      l.ronin = true;
      j(-25);
      log('国は滅んだ…浪々の身となる。', 'bad');
      if (rng.chance(.4)) die('国と共に滅んだ', 'senshi');
    } else {
      // 足軽・雑兵として降った者には、降った先の暮らしの岐路が出る（`ashigaru_life.dart` の `al_kuragae`）。
      if (l.rank <= 2) setFlag('al_kuragae');
      l.lord = a.name;
      l.rank = l.rank - 1 < 1 ? 1 : l.rank - 1;
      l.fav = 10;
      l.troops = (l.troops * .5).floor();
      j(-8);
      log('主家が滅び、${houseName(this, a.name)}家に降った。位は${rk[l.rank]}に。', 'bad');
    }
  }

  // ---------- 表示用の計算 ----------
  String rankName() {
    if (isChild) return l.clsName.endsWith('の子') ? l.clsName : '${l.clsName}の子';
    final retired = hasFlag('retired');
    if (l.rank == 0) {
      if (hasFlag('priesthood')) {
        return l.female ? '尼' : (hasFlag('abbot') ? '住持' : '僧');
      }
      if (hasFlag('way_merchant')) {
        return '${hasFlag('goyo') ? '御用商人' : '商人'}${retired ? '（隠居）' : ''}';
      }
      if (hasFlag('way_outlaw')) {
        return hasFlag('nukenin')
            ? '抜け忍'
            : (hasFlag('wanderer') ? '流れ者' : '野に生きる者');
      }
      if (retired) return '隠居';
      return l.ronin ? (l.female ? '流浪の身' : '浪人') : '${l.clsName}（無役）';
    }
    return retired ? '隠居（元${rk[l.rank]}）' : rk[l.rank];
  }

  String nextPromo() {
    if (isChild) return '${l.female ? '裳着' : '元服'}まであと${15 - age}年';
    if (hasFlag('retired')) return '静かな余生を送る';
    if (l.rank == 0) {
      if (hasFlag('priesthood')) return '仏の道を歩む';
      if (hasFlag('way_merchant')) return '商いを広げる';
      if (hasFlag('way_outlaw')) return '野に生きる';
      return l.female ? '奉公先を得る' : '仕官して身分を得る';
    }
    if (l.rank == 7) return l.female ? '好機を待つ（後見など）' : '下剋上か主君の死で大名へ';
    if (l.rank >= 8) return '天下まで：勢力占有率 ${(share * 100).round()}% / 50%';
    final n = kPromo[l.rank + 1]!;
    final troops = canFight ? '　兵${l.troops}/${n.troops}' : '';
    return '功${l.merit}/${n.merit}　信頼${l.fav}/${n.fav}$troops';
  }

  double get avgJoy => l.hist.isEmpty
      ? 50
      : l.hist.fold<double>(0, (s, p) => s + p.joy) / l.hist.length;

  int get score {
    final a = age;
    if (a < 15) return a;
    return l.maxRank * 120 +
        l.merit +
        l.fame +
        l.conq * 60 +
        (l.victory ? 1000 : 0) +
        (a - 15) * 2 +
        l.kids * 10 +
        (avgJoy / 2).round();
  }

  bool get finished => life != null && (l.dead != null || l.end != null);
}
