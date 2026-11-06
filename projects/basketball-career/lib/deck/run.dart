/// 1シーズン(1回の挑戦)。地区予選→県大会→全国大会。
///
/// 各大会は7つの行き先を順に選び、最後に決勝。行き先は 試合・強豪・練習・部室・出来事。
/// 普通の試合・強豪に負けると「気持ち」が1つ減り、0で終わり。決勝に負けたら敗退。
library;

import 'battle.dart';
import 'cards.dart';
import 'mates.dart';
import 'opponents.dart';
import 'rng.dart';

enum NodeType {
  game('試合', '勝つとカードと部費'),
  elite('強豪', '手ごわい。勝つと仲間が加わる'),
  practice('練習', 'カードを1枚強くする'),
  shop('部室', 'カードと仲間を部費で'),
  event('出来事', '何かが起きる'),
  boss('決勝', '負けたら敗退');

  const NodeType(this.label, this.text);
  final String label;
  final String text;
}

/// いま何をしているところか。
enum Phase {
  /// 行き先を選ぶ。
  map,

  /// 試合中。
  battle,

  /// 勝った後のカード選び。
  reward,

  /// 強豪に勝った後の仲間選び。
  mateReward,

  /// 練習(強くするカードを選ぶ)。
  practice,

  /// 部室。
  shop,

  /// 出来事。
  event,

  /// 優勝・敗退。
  finished,
}

class ShopItem {
  ShopItem.card(CardInstance this.card, this.price) : mate = null;
  ShopItem.mate(MateDef this.mate, this.price) : card = null;
  final CardInstance? card;
  final MateDef? mate;
  final int price;
  bool sold = false;

  Map<String, dynamic> toJson() => {
        if (card != null) 'card': card!.toJson(),
        if (mate != null) 'mate': mate!.id,
        'price': price,
        if (sold) 'sold': true,
      };

  static ShopItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final price = (j['price'] as num?)?.toInt() ?? 50;
    ShopItem? it;
    if (j['card'] != null) {
      final c = CardInstance.fromJson(j['card']);
      if (c != null) it = ShopItem.card(c, price);
    } else if (mateById[j['mate']] != null) {
      it = ShopItem.mate(mateById[j['mate']]!, price);
    }
    if (it != null && j['sold'] == true) it.sold = true;
    return it;
  }
}

/// 出来事の選択肢。
class EventChoice {
  const EventChoice(this.label, this.result);
  final String label;

  /// 選んだあとに出す一言。
  final String result;
}

class GameEvent {
  const GameEvent(this.id, this.title, this.text, this.choices);
  final String id;
  final String title;
  final String text;
  final List<EventChoice> choices;
}

const allEvents = <GameEvent>[
  GameEvent('ob', 'OBの差し入れ', '卒業した先輩が、体育館に顔を出してくれた。', [
    EventChoice('差し入れをもらう(部費+35)', '部費が35増えた。'),
    EventChoice('練習を見てもらう(1枚強くする)', '先輩の一言で、プレーがひとつ良くなった。'),
  ]),
  GameEvent('press', '雑誌の取材', '地元の雑誌が、チームを取材したいと言ってきた。', [
    EventChoice('取材を受ける(部費+50・気持ち-1)', '記事になった。部費は増えたが、少し浮き足立った。'),
    EventChoice('断って練習する(1枚強くする)', '取材は断り、いつもどおり練習した。'),
  ]),
  GameEvent('rain', '雨で練習が中止', '体育館が使えない。どう過ごす?', [
    EventChoice('みんなで休む(気持ち+1)', 'よく休んで、気持ちが戻った。'),
    EventChoice('ミーティング(カードを1枚外す)', '作戦を見直して、要らないプレーをひとつやめた。'),
  ]),
  GameEvent('joint', '合同練習の誘い', '強い学校から、合同練習に誘われた。', [
    EventChoice('参加する(「いい」カード1枚)', '新しいプレーを覚えた。'),
    EventChoice('遠征費を出して本気で(部費-40・「すごい」カード1枚)', '本気の相手から、とっておきのプレーを盗んだ。'),
  ]),
  GameEvent('senpai', '先輩の特訓', '先輩が、厳しい特訓をつけてくれるという。', [
    EventChoice('受ける(気持ち-1・2枚強くする)', 'くたくたになったが、ふたつのプレーが良くなった。'),
    EventChoice('今日は遠慮する', '体を休めた。'),
  ]),
  GameEvent('transfer', '転校生', 'バスケ経験のある転校生が、入部したいと言ってきた。', [
    EventChoice('仲間に迎える', '新しい仲間が加わった。'),
    EventChoice('今は断る(部費+20)', '紹介してくれた先生から、部費の足しをもらった。'),
  ]),
];

final eventById = {for (final e in allEvents) e.id: e};

class RunState {
  RunState({required int seed, this.difficulty = 0, Set<String> lockedCards = const {}, Set<String> lockedMates = const {}})
      : rng = Rng(seed),
        lockedCards = {...lockedCards},
        lockedMates = {...lockedMates} {
    deck.addAll(starterDeck());
    _makeStage();
  }

  RunState._empty({required this.rng, required this.difficulty, required this.lockedCards, required this.lockedMates});

  final Rng rng;
  final int difficulty;
  final Set<String> lockedCards;
  final Set<String> lockedMates;

  final deck = <CardInstance>[];
  final mates = <MateDef>[];
  int money = 60;
  int hearts = 3;
  static const maxHearts = 3;
  int stage = 0;

  /// いまの大会の何番目の行き先か(0〜7。7が決勝)。
  int floor = 0;
  static const floorsPerStage = 8;

  /// 大会ごとの行き先の候補(floor ごとに2〜3つ)。
  List<List<NodeType>> map = [];
  Phase phase = Phase.map;
  int removals = 0;
  int wins = 0;
  int losses = 0;
  bool champion = false;

  /// 動画で決勝をやり直せるのは1シーズンに1回。
  bool retryUsed = false;

  // ── いまの行き先の中身
  NodeType? current;
  Opponent? opponent;

  /// 試合を始めたときの乱数の状態(途中で閉じても同じ試合を始め直せる)。
  int? battleSeed;
  Battle? battle;
  List<CardInstance> rewardCards = [];
  List<MateDef> rewardMates = [];
  List<ShopItem> shopItems = [];
  GameEvent? event;
  String? lastMessage;

  /// 直前の試合の部費。
  int lastPrize = 0;

  String get stageName => stageNames[stage];
  bool get atBoss => floor == floorsPerStage - 1;
  int get removalPrice => 50 + removals * 25;
  bool get over => phase == Phase.finished;

  void _makeStage() {
    map = [];
    for (var f = 0; f < floorsPerStage; f++) {
      if (f == floorsPerStage - 1) {
        map.add([NodeType.boss]);
      } else if (f == 0) {
        map.add([NodeType.game]);
      } else if (f == floorsPerStage - 2) {
        map.add([NodeType.practice, NodeType.shop]);
      } else {
        final n = 2 + rng.nextInt(2);
        final set = <NodeType>{};
        var guard = 0;
        while (set.length < n && guard++ < 30) {
          set.add(rng.weighted({
            NodeType.game: 40,
            if (f >= 2) NodeType.elite: 16,
            NodeType.event: 20,
            NodeType.shop: 10,
            NodeType.practice: 14,
          }));
        }
        // 試合の無い階をなくす(勝ち上がる感じを保つ)
        if (!set.contains(NodeType.game) && !set.contains(NodeType.elite)) {
          set.remove(set.first);
          set.add(NodeType.game);
        }
        map.add(set.toList());
      }
    }
    floor = 0;
  }

  List<NodeType> get choices => map[floor];

  /// 行き先を選ぶ。
  void choose(NodeType t) {
    if (phase != Phase.map || !choices.contains(t)) return;
    current = t;
    lastMessage = null;
    switch (t) {
      case NodeType.game:
      case NodeType.elite:
      case NodeType.boss:
        opponent = makeOpponent(rng,
            stage: stage, elite: t == NodeType.elite, boss: t == NodeType.boss, difficulty: difficulty);
        battleSeed = rng.next();
        startBattle();
      case NodeType.practice:
        phase = Phase.practice;
      case NodeType.shop:
        _makeShop();
        phase = Phase.shop;
      case NodeType.event:
        event = rng.pick(allEvents);
        phase = Phase.event;
    }
  }

  /// いまの試合を(始めから)始める。
  void startBattle() {
    battle = Battle(deck: deck, opponent: opponent!, mates: mates, rng: Rng(battleSeed!));
    phase = Phase.battle;
  }

  /// 試合が終わったら呼ぶ。
  void finishBattle() {
    final b = battle;
    if (b == null || !b.over || phase != Phase.battle) return;
    final boss = current == NodeType.boss;
    if (b.won) {
      wins++;
      final margin = b.mine - b.theirs;
      var prize = 18 + stage * 6 + (margin >= 10 ? 8 : 0);
      if (current == NodeType.elite) prize += 15;
      if (boss) prize += 40;
      if (mates.any((m) => m.effect == MateEffect.manager)) prize = (prize * 1.5).round();
      money += prize;
      lastPrize = prize;
      rewardCards = _rollCards(mates.any((m) => m.effect == MateEffect.scout) ? 4 : 3,
          elite: current == NodeType.elite, boss: boss);
      phase = Phase.reward;
      if (boss && stage == stageNames.length - 1) {
        champion = true;
      }
    } else {
      losses++;
      lastPrize = 0;
      if (boss) {
        phase = Phase.finished;
      } else {
        hearts--;
        if (hearts <= 0) {
          phase = Phase.finished;
        } else {
          lastMessage = '負けた。気持ちが1つ減った。';
          _advance();
        }
      }
    }
    battle = null;
  }

  /// 決勝で負けた後、動画を見てやり直す(1シーズンに1回)。
  bool get canRetry => phase == Phase.finished && !champion && current == NodeType.boss && !retryUsed;

  void retryBoss() {
    if (!canRetry) return;
    retryUsed = true;
    losses--;
    startBattle();
  }

  /// 報酬のカードを取る(null なら取らない)。
  void takeReward(CardInstance? c) {
    if (phase != Phase.reward) return;
    if (c != null && rewardCards.contains(c)) deck.add(c);
    rewardCards = [];
    if (current == NodeType.elite && mates.length < maxMates) {
      rewardMates = _rollMates(2);
      if (rewardMates.isNotEmpty) {
        phase = Phase.mateReward;
        return;
      }
    }
    _advance();
  }

  /// 動画を見て、報酬のカードを選び直す。
  void rerollReward() {
    if (phase != Phase.reward) return;
    rewardCards = _rollCards(rewardCards.length, elite: current == NodeType.elite, boss: current == NodeType.boss);
  }

  void takeMate(MateDef? m) {
    if (phase != Phase.mateReward) return;
    if (m != null && rewardMates.contains(m) && mates.length < maxMates) mates.add(m);
    rewardMates = [];
    _advance();
  }

  /// 練習: 1枚強くする。
  void upgrade(CardInstance c) {
    if (phase != Phase.practice || !deck.contains(c) || !c.canUpgrade) return;
    c.upgraded = true;
    lastMessage = '${c.def.name}が良くなった。';
    _advance();
  }

  /// 練習のかわりに休む(気持ち+1)。
  void rest() {
    if (phase != Phase.practice) return;
    hearts = (hearts + 1).clamp(0, maxHearts);
    lastMessage = 'よく休んだ。';
    _advance();
  }

  void buy(ShopItem it) {
    if (phase != Phase.shop || it.sold || money < it.price) return;
    if (it.mate != null) {
      if (mates.length >= maxMates || mates.contains(it.mate)) return;
      mates.add(it.mate!);
    } else {
      deck.add(it.card!);
    }
    money -= it.price;
    it.sold = true;
  }

  /// 部室: カードを1枚外す。
  void removeCard(CardInstance c) {
    if (phase != Phase.shop || money < removalPrice || !deck.contains(c) || deck.length <= 5) return;
    money -= removalPrice;
    removals++;
    deck.remove(c);
  }

  void leaveShop() {
    if (phase != Phase.shop) return;
    shopItems = [];
    _advance();
  }

  /// 出来事の選択肢を選ぶ。[target] は「外す」「強くする」で選ぶカード(無ければ自動)。
  void resolveEvent(int i, {CardInstance? target}) {
    final e = event;
    if (phase != Phase.event || e == null || i < 0 || i >= e.choices.length) return;
    switch ((e.id, i)) {
      case ('ob', 0):
        money += 35;
      case ('ob', 1) || ('press', 1):
        _upgradeSome(1, target);
      case ('press', 0):
        money += 50;
        hearts = (hearts - 1).clamp(1, maxHearts);
      case ('rain', 0):
        hearts = (hearts + 1).clamp(0, maxHearts);
      case ('rain', 1):
        final t = target != null && deck.contains(target) ? target : _worstCard();
        if (t != null && deck.length > 5) deck.remove(t);
      case ('joint', 0):
        deck.add(CardInstance(rng.pick(_pool(Rarity.uncommon))));
      case ('joint', 1):
        if (money >= 40) {
          money -= 40;
          deck.add(CardInstance(rng.pick(_pool(Rarity.rare))));
        }
      case ('senpai', 0):
        hearts = (hearts - 1).clamp(1, maxHearts);
        _upgradeSome(2, null);
      case ('transfer', 0):
        final m = _rollMates(1);
        if (m.isNotEmpty && mates.length < maxMates) mates.add(m.first);
      case ('transfer', 1):
        money += 20;
      default:
    }
    lastMessage = e.choices[i].result;
    event = null;
    _advance();
  }

  void _upgradeSome(int n, CardInstance? target) {
    if (target != null && deck.contains(target) && target.canUpgrade) {
      target.upgraded = true;
      n--;
    }
    final can = deck.where((c) => c.canUpgrade).toList();
    rng.shuffle(can);
    for (final c in can.take(n)) {
      c.upgraded = true;
    }
  }

  /// 外すときの既定(基本のカードの、強くしていないもの)。
  CardInstance? _worstCard() {
    for (final id in ['jumper', 'defense']) {
      for (final c in deck) {
        if (c.def.id == id && !c.upgraded) return c;
      }
    }
    return deck.isEmpty ? null : deck.first;
  }

  void _advance() {
    current = null;
    opponent = null;
    battleSeed = null;
    if (phase == Phase.finished) return;
    if (floor >= floorsPerStage - 1) {
      // 決勝を終えた
      if (stage >= stageNames.length - 1) {
        champion = true;
        phase = Phase.finished;
        return;
      }
      stage++;
      hearts = (hearts + 1).clamp(0, maxHearts);
      _makeStage();
      lastMessage = '$stageNameへ進んだ。気持ちが1つ戻った。';
    } else {
      floor++;
    }
    phase = Phase.map;
  }

  List<CardDef> _pool(Rarity r) {
    final p = rewardPool(locked: lockedCards).where((c) => c.rarity == r).toList();
    return p.isEmpty ? rewardPool(locked: lockedCards) : p;
  }

  List<CardInstance> _rollCards(int n, {bool elite = false, bool boss = false}) {
    final out = <CardInstance>[];
    final used = <String>{};
    for (var i = 0; i < n; i++) {
      final r = (boss && i == 0)
          ? Rarity.rare
          : rng.weighted({
              Rarity.common: elite ? 40 : 58,
              Rarity.uncommon: elite ? 42 : 33,
              Rarity.rare: elite ? 18 : 9,
            });
      final pool = _pool(r).where((c) => !used.contains(c.id)).toList();
      final def = pool.isEmpty ? rng.pick(_pool(r)) : rng.pick(pool);
      used.add(def.id);
      out.add(CardInstance(def));
    }
    return out;
  }

  List<MateDef> _rollMates(int n) {
    final pool = allMates.where((m) => !mates.contains(m) && !lockedMates.contains(m.id)).toList();
    rng.shuffle(pool);
    return pool.take(n).toList();
  }

  void _makeShop() {
    shopItems = [];
    final used = <String>{};
    for (final r in [Rarity.common, Rarity.common, Rarity.uncommon, Rarity.uncommon, Rarity.rare]) {
      final pool = _pool(r).where((c) => !used.contains(c.id)).toList();
      if (pool.isEmpty) continue;
      final def = rng.pick(pool);
      used.add(def.id);
      final base = switch (def.rarity) { Rarity.rare => 110, Rarity.uncommon => 70, _ => 45 };
      shopItems.add(ShopItem.card(CardInstance(def), base + rng.nextInt(11) - 5));
    }
    if (mates.length < maxMates) {
      final m = _rollMates(1);
      if (m.isNotEmpty) shopItems.add(ShopItem.mate(m.first, m.first.rare ? 150 : 120));
    }
  }

  // ── 保存(試合中は、試合を始めた時点に戻して保存する)
  Map<String, dynamic> toJson() => {
        'v': 1,
        'rng': rng.state,
        'dif': difficulty,
        'lockedCards': lockedCards.toList(),
        'lockedMates': lockedMates.toList(),
        'deck': [for (final c in deck) c.toJson()],
        'mates': [for (final m in mates) m.id],
        'money': money,
        'hearts': hearts,
        'stage': stage,
        'floor': floor,
        'map': [for (final f in map) [for (final t in f) t.name]],
        'phase': phase.name,
        'removals': removals,
        'wins': wins,
        'losses': losses,
        'champion': champion,
        'retryUsed': retryUsed,
        if (current != null) 'current': current!.name,
        if (opponent != null) 'opponent': opponent!.toJson(),
        if (battleSeed != null) 'battleSeed': battleSeed,
        'rewardCards': [for (final c in rewardCards) c.toJson()],
        'rewardMates': [for (final m in rewardMates) m.id],
        'shop': [for (final s in shopItems) s.toJson()],
        if (event != null) 'event': event!.id,
        if (lastMessage != null) 'msg': lastMessage,
        'prize': lastPrize,
      };

  static RunState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    try {
      final r = RunState._empty(
        rng: Rng((j['rng'] as num).toInt()),
        difficulty: (j['dif'] as num?)?.toInt() ?? 0,
        lockedCards: {...((j['lockedCards'] as List?) ?? const []).whereType<String>()},
        lockedMates: {...((j['lockedMates'] as List?) ?? const []).whereType<String>()},
      );
      r.deck.addAll([for (final c in (j['deck'] as List)) CardInstance.fromJson(c)].whereType<CardInstance>());
      r.mates.addAll([for (final m in (j['mates'] as List? ?? const [])) mateById[m]].whereType<MateDef>());
      r.money = (j['money'] as num?)?.toInt() ?? 0;
      r.hearts = (j['hearts'] as num?)?.toInt() ?? 1;
      r.stage = ((j['stage'] as num?)?.toInt() ?? 0).clamp(0, stageNames.length - 1);
      r.floor = ((j['floor'] as num?)?.toInt() ?? 0).clamp(0, floorsPerStage - 1);
      r.map = [
        for (final f in (j['map'] as List))
          [for (final t in (f as List)) NodeType.values.firstWhere((n) => n.name == t)]
      ];
      if (r.map.length != floorsPerStage || r.deck.isEmpty) return null;
      r.phase = Phase.values.firstWhere((p) => p.name == j['phase'], orElse: () => Phase.map);
      r.removals = (j['removals'] as num?)?.toInt() ?? 0;
      r.wins = (j['wins'] as num?)?.toInt() ?? 0;
      r.losses = (j['losses'] as num?)?.toInt() ?? 0;
      r.champion = j['champion'] == true;
      r.retryUsed = j['retryUsed'] == true;
      final cur = j['current'];
      r.current = cur == null ? null : NodeType.values.firstWhere((n) => n.name == cur);
      if (j['opponent'] is Map) r.opponent = Opponent.fromJson((j['opponent'] as Map).cast<String, dynamic>());
      r.battleSeed = (j['battleSeed'] as num?)?.toInt();
      r.rewardCards = [for (final c in (j['rewardCards'] as List? ?? const [])) CardInstance.fromJson(c)]
          .whereType<CardInstance>()
          .toList();
      r.rewardMates =
          [for (final m in (j['rewardMates'] as List? ?? const [])) mateById[m]].whereType<MateDef>().toList();
      r.shopItems =
          [for (final s in (j['shop'] as List? ?? const [])) ShopItem.fromJson(s)].whereType<ShopItem>().toList();
      r.event = eventById[j['event']];
      r.lastMessage = j['msg'] as String?;
      r.lastPrize = (j['prize'] as num?)?.toInt() ?? 0;
      // 試合の途中で閉じていたら、その試合を始めから
      if (r.phase == Phase.battle) {
        if (r.opponent == null || r.battleSeed == null) {
          r.phase = Phase.map;
        } else {
          r.startBattle();
        }
      }
      if (r.phase == Phase.event && r.event == null) r.phase = Phase.map;
      return r;
    } catch (_) {
      return null;
    }
  }
}
