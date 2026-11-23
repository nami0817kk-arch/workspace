import 'package:flutter/foundation.dart';

import 'adult.dart';
import 'ashigaru.dart';
import 'ashigaru_life.dart';
import 'birth.dart';
import 'bonds.dart';
import 'childhood.dart';
import 'childhood_focus.dart';
import 'childhood_more.dart';
import 'data.dart';
import 'echoes.dart';
import 'echoes_more.dart';
import 'echoes_talent.dart';
import 'family.dart';
import 'history.dart';
import 'history_east.dart';
import 'history_life.dart';
import 'history_lines.dart';
import 'history_rumor.dart';
import 'history_west.dart';
import 'life.dart';
import 'lords.dart';
import 'old_age.dart';
import 'pastimes.dart';
import 'regions.dart';
import 'rng.dart';
import 'scene_art.dart';
import 'shadow_life.dart';
import 'talents.dart';
import 'temple.dart';
import 'trade_farm.dart';
import 'village.dart';
import 'ways.dart';
import 'women.dart';
import 'women_life.dart';

/// 選択肢。[f] が返した文字列は見聞録に書かれる。
class Choice {
  Choice(this.label, [this.f, this.cancel = false, this.danger = false])
    : hint = null;

  /// 岐路の選択肢。[hint] は結果を匂わせる一言（数字は出さない）。
  Choice.h(this.label, this.hint, this.f) : cancel = false, danger = false;

  final String label;

  /// 選ぶ前に見せる、結果の匂わせ。
  final String? hint;
  final String? Function()? f;

  /// true なら何も起こさず閉じる（手番も進まない）。
  final bool cancel;
  final bool danger;
}

class Prompt {
  Prompt(this.title, this.text, this.choices, this.after, {this.art});
  final String title, text;

  /// 添える絵の名前（`scene_art.dart` の `kSceneArts`）。場面でない問いは null。
  final String? art;
  final List<Choice> choices;

  /// 選んだあとに呼ぶ（手番を進める・画面を更新する、など）。
  final void Function() after;
}

class Game extends ChangeNotifier {
  Game({Rng? rng, this.onCheckpoint}) : rng = rng ?? Rng() {
    childScenes = [
      ...buildChildScenes(),
      ...buildMoreChildScenes(),
      ...buildChildHistoryScenes(),
      ...buildChildRumorScenes(),
      ...buildTalentChildScenes(),
      ...buildRegionChildScenes(),
      ...buildChildFocusScenes(),
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
      ...buildVillageScenes(),
      ...buildTradeFarmScenes(),
      ...buildShadowLifeScenes(),
      ...buildTalentScenes(),
      ...buildPastimeScenes(),
      ...buildOldAgeScenes(),
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

  void log(String txt, [String kind = '']) {
    final e = LogEntry('$year$season', txt, kind);
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
  void meet(String role, String name, int bond) =>
      l.people[role] = Person(role, name, bond);

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
    );
    notifyListeners();
  }

  void choose(int i) {
    final p = prompt!;
    prompt = null;
    _sceneId = null;
    final c = p.choices[i];
    if (c.cancel) {
      changed();
      return;
    }
    final res = c.f?.call();
    // 岐路の結果には場面の名前を付ける（「今年の重点」は文の中に「今年は…」とあるので付けない）。
    if (res != null) log(p.title == '今年の重点' ? res : '【${p.title}】$res');
    p.after();
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
  void restore(Life saved, Map<String, Faction> world) {
    life = saved;
    fa = world;
    prompt = null;
    // 年の始まりで保存している。その年を最初からやり直す。
    if (saved.dead == null && saved.end == null) {
      _recap();
      isChild ? _beginYear() : _beginAdultYear();
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
    dp *= risk;
    if (rng.chance(dp)) {
      die('${e.name}との合戦で討死', 'senshi');
      return '${e.name}との合戦で、${role == 'van' ? '先陣にて' : ''}討死した。';
    }
    final merit =
        (mult *
                gain *
                (skill / 12 + rng.range(0, 6)) *
                (win ? 1.3 : .6) *
                (1 + l.troops / 150))
            .round();
    l.merit += merit;
    l.fame += merit ~/ 3;
    l.fav = clampInt(l.fav + (win ? 3 : -1), 0, 100);
    j(win ? 2 : -4);
    var txt = '${e.name}家との合戦。${win ? '我が方の勝利！' : '我が方は敗れた。'}功$merit。';
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
          (has('loyal') ? -.1 : 0),
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
    if (rng.chance(.7)) {
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
      die('${t.name}家との戦で討死', 'senshi');
      return '${t.name}家との戦に敗れ、討死した。';
    }
    return '${t.name}家との戦に敗れた。勢力が削られた。';
  }

  // ---------- ターン進行 ----------
  /// 年ごとの病死・老衰の割合（大人）。2026-11-23 に、若いうちの病死を4割ほど下げた
  /// （選択と関係のない「病に倒れた」が成人の死の3分の1を占め、平均31歳で人生が切れていたため）。
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
  // 1年ごとに「今年の重点」を選ぶ。選んだ年の途中で、岐路が起きることがある。

  /// 年の始まり。保存はここで行い、「今年の重点」を聞く。
  void _beginYear() {
    prompt = null;
    final a = age;
    l.t = a * 2;
    onCheckpoint?.call(this);
    final opts = childFocusOptions(this);
    // いつもの4つ（手伝い・読み書き・武芸ごっこ、遊ぶか友と過ごすのどちらか）に、
    // 家柄・年頃で増える重点（寺の手習い・道場・算盤・行儀見習い）を足す。
    final shown = [
      ...opts.sublist(0, 3),
      rng.chance(.5) ? opts[3] : opts[4],
      ...opts.sublist(5),
    ];
    ask('今年の重点', childYearText(this), [
      for (final o in shown)
        Choice.h(o.label, o.hint, () {
          final before = (l.bu, l.chi, l.net, l.gold);
          o.perYear(this);
          l.focus[o.tag] = (l.focus[o.tag] ?? 0) + 1;
          _forced = o.forced;
          final d = <String>[];
          if (l.bu > before.$1) d.add('武+${l.bu - before.$1}');
          if (l.chi > before.$2) d.add('知+${l.chi - before.$2}');
          if (l.net > before.$3) d.add('人間関係+${l.net - before.$3}');
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
    final cand = [
      for (final s in childScenes)
        if (_childSceneOk(s, a)) s,
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
        .where((f) => f.startsWith('scene:') && !isHistoryScene(f.substring(6)))
        .length;
    // 幼少期の岐路は6つほどに収める。少なすぎれば出やすく、多すぎれば出にくくする。
    var p = .5;
    if (a >= 11 && done < 4) p = .9;
    if (done >= 7) p = .1;
    if (cand.isEmpty || !rng.chance(p)) {
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
  // 幼少期と同じく、1年ごとに「今年の重点」を選ぶ。重点によっては、その年に必ず岐路が起きる。

  String? _forced;

  /// 年の始まり。保存はここで行い、「今年の重点」を聞く。
  void _beginAdultYear() {
    prompt = null;
    l.t = age * 2;
    _chapter();
    onCheckpoint?.call(this);
    final opts = adultFocusOptions(this);
    ask('今年の重点', adultYearText(this), [
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
          if (l.net > b.$3) d.add('人間関係+${l.net - b.$3}');
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
  }

  bool _sceneOk(SceneDef s, int a) =>
      a >= s.minAge &&
      a <= s.maxAge &&
      (s.ageOk == null || s.ageOk!(this, a)) &&
      (s.repeat || !hasFlag('scene:${s.id}')) &&
      !_twinDone(s.id) &&
      !sceneSkippedInLine(this, s.id) &&
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
        if (!s.onlyForced && !isHistoryScene(s.id) && _sceneOk(s, a)) s,
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
      _endAdultYear();
      return;
    }
    _runAdultScene(rng.wpick(cand, (e) => e.weight(this)), _endAdultYear);
  }

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
      } else if (l.troops > 0) {
        final d = (l.troops * .15).ceil();
        l.troops -= d;
        log('給金が払えず、兵$d人が逃散した。', 'bad');
      }
    }
    l.hp = l.hp + 4 > l.maxhp ? l.maxhp : l.hp + 4;
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
        l.addKid(year);
        j(8);
        log('子が生まれた（${l.kids}人目）。', 'good');
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
      if (l.dead == null && l.kids > 0 && rng.chance(.012 * l.kids)) {
        l.loseKid(year, 0, 10);
        j(-25);
        setFlag('fa_lost_child');
        log('幼い我が子を病で失った。', 'bad');
      }
      // 天寿
      if (l.dead == null) {
        final a = age;
        var dp = annualMort(a) / 2 * l.cls.m;
        if (l.hp < 30) dp *= 2;
        if (has('sickly')) dp *= 1.5;
        if (has('hardy')) dp *= .7;
        if (l.joy < 20) {
          dp *= 1.3;
        } else if (l.joy >= 70) {
          dp *= .9;
        }
        if (a >= 85 || rng.chance(dp)) {
          a >= 55 ? die('天寿をまっとうした', 'tenju') : die('病に倒れた');
        }
      }
      // 天下・時代の終わり
      if (l.dead == null) {
        if (l.rank == 8 && share >= .5) {
          l.victory = true;
          l.rank = 9;
          l.maxRank = 9;
          l.end = 'victory';
        } else if (year > 1600) {
          l.end = 'era';
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
    if (al.length > 2 && rng.chance(.25)) {
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
      log('主家が滅び、${a.name}家に降った。位は${rk[l.rank]}に。', 'bad');
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
