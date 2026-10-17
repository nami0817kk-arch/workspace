import 'dart:math';

import 'calendar.dart';
import 'career.dart';
import 'characters.dart';
import 'exp.dart';
import 'life.dart';
import 'path.dart';
import 'player.dart';
import 'season.dart';
import 'traits.dart';

/// いま何を待っているか。画面はこれを見て出すものを決める。
enum Phase {
  term, // 季節の過ごし方を選ぶ
  event, // 出来事の選択肢を選ぶ
  pathChoice, // ドラフトに外れた。大学/社会人を選ぶか、諦めるか
  retired, // 終わり
}

/// 引退時のまとめ。
class Ending {
  const Ending({
    required this.title,
    required this.madePro,
    required this.proYears,
    required this.peakOverall,
    required this.championships,
    required this.wasTwoWay,
    this.rivalWins = 0,
    this.rivalLosses = 0,
    this.partnerName,
  });

  final String title;
  final bool madePro;
  final int proYears;
  final int peakOverall;
  final int championships;
  final bool wasTwoWay;
  final int rivalWins;
  final int rivalLosses;

  /// 絆が深かった恋人の名前(いれば結婚した)。
  final String? partnerName;
  bool get married => partnerName != null;
}

/// 6歳から引退までの一代記を進める本体。画面には依存しない。
/// 乱数は注入する(テストで再現できる)。
class Game {
  Game._(this.rng, this.player, this.cast);

  /// 新しい選手で始める。`potential` を省くと乱数で決まる。
  factory Game.newGame({
    required String name,
    required Role role,
    required Random rng,
    int? potential,
  }) {
    final p = Player(
      name: name,
      role: role,
      age: startAge,
      potential: potential ?? 30 + rng.nextInt(61),
      abilities: {for (final a in abilitiesOf(role)) a: 15},
      traits: rollInnateTraits(rng),
    );
    return Game._(rng, p, Cast.initial(rng, role, p.traits))
      .._wasTwoWay = role == Role.twoWay;
  }

  final Random rng;
  Player player;
  Condition condition = const Condition();
  int slot = 0; // 今年の何ターン目か(0始まり)。月単位か季節かは段階で決まる
  Cast cast; // 家族・ライバル・仲間・コーチ・恋人
  ExpPool exp = const ExpPool(); // 貯めた経験点。`spend` で能力に振り分ける
  Phase phase = Phase.term;
  GameEvent? pendingEvent;
  Ability _eventFocus = Ability.contact;

  Course? route; // 大学/社会人を選んだか
  bool turnedPro = false;
  int lowYears = 0;
  int proYears = 0;
  int peakOverall = 0;
  int championships = 0;
  bool _wasTwoWay = false;
  final List<double> achievements = []; // 夏の大会ごとの実績
  final List<String> log = []; // 画面に出す出来事の記録
  Map<Category, int> lastGain = const {}; // 直前のターンで貯まった経験点(保存しない・画面の表示用)
  Ending? ending;

  /// 引退後、殿堂(過去の選手の記録)に書き込み済みか。
  bool archived = false;

  Stage get stage =>
      phase == Phase.retired ? Stage.retired : stageOf(player.age, turnedPro: turnedPro);

  /// ドラフトにかかるときの実績: 直近3回の大会の平均。
  double get recentAchievement {
    if (achievements.isEmpty) return 0;
    final r = achievements.length > 3
        ? achievements.sublist(achievements.length - 3)
        : achievements;
    return r.reduce((a, b) => a + b) / r.length;
  }

  // ── ターンの選択 ──

  /// 今のターンの表示名。月単位なら「7月」、季節なら「夏」。
  String get slotName => slotLabel(stage, slot);

  /// 今の年のターン数(12 または 4)。
  int get slotsInYear => slotsPerYear(stage);

  Motivation get motivation => motivationOf(condition.morale);

  /// 今のターンの過ごし方を決める。`focus` は練習・特訓・研究で伸ばす能力。
  /// 能力は直接は上がらず、経験点が貯まる。`spend` / `autoSpend` で振り分ける。
  void choose(Plan action, [Ability? focus]) {
    _require(Phase.term);
    final f = focus ?? abilitiesOf(player.role).first;
    if (!abilitiesOf(player.role).contains(f)) {
      throw ArgumentError('${player.role.name} にその能力は無い: ${f.name}');
    }
    final share = slotShare(stage);
    final wasInjured = condition.injured;
    final r = playTerm(player, condition, action, f, rng, share: share);
    player = r.player;
    condition = r.condition;
    // _afterCast が経験点(コーチのボーナス)を直接足すことがあるので、先に評価する。
    final gained = wasInjured ? r.exp : _afterCast(action, f, r.exp);
    exp = exp.add(gained);
    lastGain = gained;
    if (r.gotInjured) log.add('怪我をしてしまった。');
    if (isTournamentSlot(stage, slot)) _playSummer();

    final e = drawEvent(rng, share: share, stage: stage, cast: cast);
    if (e == null) {
      _nextSlot();
    } else {
      pendingEvent = e;
      _eventFocus = f;
      phase = Phase.event;
    }
  }

  void resolveEvent(int index) {
    _require(Phase.event);
    final ch = pendingEvent!.choices[index];
    final r = ch.apply(player, condition, _eventFocus);
    player = r.player;
    condition = r.condition;
    ch.onCast?.call(cast, rng);
    _checkCoach();
    pendingEvent = null;
    phase = Phase.term;
    _nextSlot();
  }

  // ── 経験点の振り分け ──

  /// 能力を1つ上げる。足りなければ false。
  bool spend(Ability a) {
    final r = buy(player, exp, a);
    if (r == null) return false;
    player = r.player;
    exp = r.pool;
    return true;
  }

  /// 買えるだけ上げる。上がった数を返す。
  int spendAll(Ability a) {
    final r = buyAll(player, exp, a);
    player = r.player;
    exp = r.pool;
    return r.bought;
  }

  /// おまかせ: 種類ごとに低い能力から順に振り分ける。
  void autoSpend() {
    final r = autoSpendExp(player, exp);
    player = r.player;
    exp = r.pool;
  }

  /// プロの間はいつでも役割を変えられる(二刀流にする/戻す)。
  void changeRole(Role to) {
    _require(Phase.term);
    player = switchRole(player, to, stage);
    if (to == Role.twoWay) _wasTwoWay = true;
    log.add('${to.name} に転向した。');
  }

  /// プロの間は自分で引退を決められる。
  void retire() {
    _require(Phase.term);
    if (!canChooseRetire(stage)) throw StateError('引退を選べるのはプロの間だけ');
    _retire();
  }

  // ── ドラフトに外れたとき ──

  void chooseRoute(Course r) {
    _require(Phase.pathChoice);
    route = r;
    phase = Phase.term;
    log.add('${r.name} で再挑戦する。');
  }

  void giveUp() {
    _require(Phase.pathChoice);
    _retire();
  }

  // ── 内部 ──

  /// 友情タッグ・コーチ・恋人/家族への影響。経験点の量を返す。
  Map<Category, int> _afterCast(Plan action, Ability focus, Map<Category, int> gained) {
    final out = Map<Category, int>.of(gained);
    final trains = action == Plan.train ||
        action == Plan.special ||
        action == Plan.match ||
        action == Plan.lesson;
    if (trains && gained.isNotEmpty) {
      final mate = cast.pickTagMate(focus, rng);
      if (mate != null) {
        for (final k in out.keys.toList()) {
          out[k] = (out[k]! * tagMultiplier).round();
        }
        mate.addBond(8);
        log.add('${mate.name}と友情タッグ練習!');
      }
    }
    if (action == Plan.lesson) {
      final coach = cast.coach;
      if (coach != null) {
        coach.tips++;
        _checkCoach();
      }
    }
    if (action == Plan.social) {
      (cast.lover ?? cast.family)?.addBond(10);
    }
    return out;
  }

  /// コツが貯まったら、コーチの教える特性を習得する。
  void _checkCoach() {
    final coach = cast.coach;
    if (coach == null || coach.tips < tipsNeeded) return;
    coach.tips = 0;
    final t = coach.teaches;
    if (t != null && canGain(player.traits, t)) {
      player = player.copyWith(traits: gain(player.traits, t));
      log.add('${coach.name}のコツをつかんだ! 特性「${t.label}」を習得。');
    } else {
      exp = exp.add({
        for (final c in Category.values) c: 40,
      });
      log.add('${coach.name}から多くを学んだ。(経験点を獲得)');
    }
  }

  void _require(Phase p) {
    if (phase != p) throw StateError('いまは ${phase.name} の段階: ${p.name} は選べない');
  }

  ({int team, List<int> opponents}) get _league => switch (stage) {
        Stage.youth => (team: 35, opponents: const [25, 30, 35, 40]),
        Stage.juniorHigh => (team: 42, opponents: const [32, 38, 44, 50]),
        Stage.highSchool => (team: 50, opponents: const [40, 46, 52, 58, 64]),
        Stage.pathChoice => (team: 58, opponents: const [48, 54, 60, 66]),
        _ => (team: 65, opponents: const [55, 60, 66, 72, 78]),
      };

  void _playSummer() {
    final l = _league;
    final t = playTournament(
      player,
      teamLevel: l.team,
      opponents: l.opponents,
      rng: rng,
      condition: condition.value,
    );
    var ach = t.achievement;
    final rival = cast.rival;
    if (rival != null) {
      final mine = overall(player) + (rng.nextDouble() * 2 - 1) * 8;
      if (mine >= rivalLevel(rival, player.age)) {
        cast.rivalWins++;
        ach = min(100, ach + 5);
        condition = condition.copyWith(morale: condition.morale + 10);
        log.add('${rival.name}に勝った!');
      } else {
        cast.rivalLosses++;
        condition = condition.copyWith(morale: condition.morale - 8);
        log.add('${rival.name}に負けた…');
      }
      rival.addBond(5);
    }
    achievements.add(ach);
    if (t.champion) {
      championships++;
      log.add('夏の大会で優勝した!');
    } else {
      log.add('夏の大会は${t.roundsWon}回戦突破。');
    }
  }

  void _nextSlot() {
    if (slot + 1 >= slotsPerYear(stage)) {
      _endYear();
    } else {
      slot++;
    }
  }

  void _endYear() {
    final before = stage;
    slot = 0;
    player = endOfYear(player);
    condition = endOfYearCondition(condition);
    final partner = cast.lover ?? cast.family;
    if (partner != null && partner.bond >= 50) {
      condition = condition.copyWith(fatigue: condition.fatigue - 5); // 支えてくれる
    }
    peakOverall = max(peakOverall, overall(player).round());

    if (turnedPro) {
      proYears++;
      lowYears = nextLowYears(player, lowYears);
      if (mustRetire(player, lowYears)) {
        log.add(isReleased(lowYears) ? '戦力外になった。' : '年齢により引退した。');
        _retire();
      }
    } else if (route == null && player.age == proEntryAge + 1) {
      _draft();
    } else if (route != null && player.age == graduationAge(route!)) {
      _draft();
    }
    _rotateCast(before);
  }

  /// 段階が変わったら、仲間とコーチが替わる(高校で恋人が現れる)。
  void _rotateCast(Stage before) {
    if (phase == Phase.retired) return;
    final after = stage;
    if (after != before) cast.rotate(after, rng, player.role, player.traits);
  }

  void _draft() {
    if (isDrafted(player, recentAchievement, rng)) {
      turnedPro = true;
      log.add('ドラフトで指名された!');
    } else if (route == null) {
      log.add('ドラフトで指名されなかった。');
      phase = Phase.pathChoice;
    } else {
      log.add('再挑戦も実らなかった。');
      _retire();
    }
  }

  void _retire() {
    phase = Phase.retired;
    pendingEvent = null;
    ending = _buildEnding();
  }

  Ending _buildEnding() {
    final String title;
    if (!turnedPro && proYears == 0) {
      title = 'プロにはなれなかった';
    } else if (peakOverall >= 80) {
      title = 'レジェンド';
    } else if (peakOverall >= 65) {
      title = '一流選手';
    } else if (peakOverall >= 50) {
      title = 'レギュラー';
    } else {
      title = '無名の選手';
    }
    return Ending(
      title: title,
      madePro: turnedPro,
      proYears: proYears,
      peakOverall: peakOverall,
      championships: championships,
      wasTwoWay: _wasTwoWay,
      rivalWins: cast.rivalWins,
      rivalLosses: cast.rivalLosses,
      partnerName: (cast.lover != null && cast.lover!.bond >= 80) ? cast.lover!.name : null,
    );
  }

  // ── 保存 ──

  Map<String, dynamic> toJson() => {
        'player': player.toJson(),
        'condition': condition.toJson(),
        'slot': slot,
        'exp': exp.toJson(),
        'cast': cast.toJson(),
        'phase': phase.name,
        'pendingEvent': pendingEvent?.id,
        'eventFocus': _eventFocus.name,
        'route': route?.name,
        'turnedPro': turnedPro,
        'lowYears': lowYears,
        'proYears': proYears,
        'peakOverall': peakOverall,
        'championships': championships,
        'wasTwoWay': _wasTwoWay,
        'achievements': achievements,
        'archived': archived,
      };

  /// 項目を足すときは既定値を置く(既存セーブを壊さない)。
  factory Game.fromJson(Map<String, dynamic> j, Random rng) {
    T pick<T extends Enum>(List<T> all, Object? name, T orElse) {
      for (final v in all) {
        if (v.name == name) return v;
      }
      return orElse;
    }

    final player = Player.fromJson((j['player'] as Map?)?.cast<String, dynamic>() ?? {});
    final castJson = (j['cast'] as Map?)?.cast<String, dynamic>();
    final g = Game._(
      rng,
      player,
      castJson != null ? Cast.fromJson(castJson) : Cast.initial(rng, player.role, player.traits),
    );
    g.condition = Condition.fromJson((j['condition'] as Map?)?.cast<String, dynamic>() ?? {});
    g.slot = (j['slot'] as num?)?.toInt() ?? 0;
    g.exp = ExpPool.fromJson((j['exp'] as Map?)?.cast<String, dynamic>() ?? {});
    g.phase = pick(Phase.values, j['phase'], Phase.term);
    g.pendingEvent = events.where((e) => e.id == j['pendingEvent']).firstOrNull;
    if (g.phase == Phase.event && g.pendingEvent == null) g.phase = Phase.term;
    g._eventFocus = pick(Ability.values, j['eventFocus'], Ability.contact);
    g.route = Course.values.where((r) => r.name == j['route']).firstOrNull;
    g.turnedPro = (j['turnedPro'] as bool?) ?? false;
    g.lowYears = (j['lowYears'] as num?)?.toInt() ?? 0;
    g.proYears = (j['proYears'] as num?)?.toInt() ?? 0;
    g.peakOverall = (j['peakOverall'] as num?)?.toInt() ?? 0;
    g.championships = (j['championships'] as num?)?.toInt() ?? 0;
    g.archived = (j['archived'] as bool?) ?? false;
    g._wasTwoWay = (j['wasTwoWay'] as bool?) ?? g.player.role == Role.twoWay;
    g.achievements.addAll(
        ((j['achievements'] as List?) ?? const []).map((e) => (e as num).toDouble()));
    g.slot = g.slot.clamp(0, slotsPerYear(g.stage) - 1);
    if (g.phase == Phase.retired) g.ending = g._buildEnding();
    return g;
  }
}
