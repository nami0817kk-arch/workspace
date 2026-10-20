import 'dart:math';

import 'package:flutter/material.dart';

import '../game/at_bat.dart';
import '../game/player.dart';
import '../game/traits.dart';

/// 対戦テスト(管理者モード): 能力と特性を決めて、打者と投手を何千回も対戦させ、
/// 結果の割合を見る。育成中の選手には何も影響しない(ゲームのバランス確認用)。
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key});

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

/// 対戦の集計。
class VersusResult {
  VersusResult(this.n);
  final int n;
  int walk = 0, strikeout = 0, out = 0;
  int single = 0, doubles = 0, triples = 0, homeRun = 0;

  int get hits => single + doubles + triples + homeRun;
  int get atBats => n - walk;
  int get totalBases => single + 2 * doubles + 3 * triples + 4 * homeRun;
  double get battingAverage => atBats == 0 ? 0 : hits / atBats;
  double get onBase => n == 0 ? 0 : (hits + walk) / n;
  double get slugging => atBats == 0 ? 0 : totalBases / atBats;
}

/// 打者 `bat` と投手 `pit` を `n` 回対戦させる。特性の上乗せは試合用の能力として足す。
VersusResult runVersus({
  required Map<Ability, int> bat,
  required Set<Trait> batTraits,
  required Map<Ability, int> pit,
  required Set<Trait> pitTraits,
  required int n,
  required Random rng,
}) {
  int adj(Map<Ability, int> m, Set<Trait> t, Ability a) =>
      ((m[a] ?? 0) + (traitAbilityDelta(t)[a] ?? 0)).clamp(0, gameAbilityCap);
  final b = Batter(
    contact: adj(bat, batTraits, Ability.contact),
    power: adj(bat, batTraits, Ability.power),
    eye: adj(bat, batTraits, Ability.eye),
  );
  final p = Pitcher(
    control: adj(pit, pitTraits, Ability.control),
    stuff: adj(pit, pitTraits, Ability.stuff),
  );
  final r = VersusResult(n);
  for (var i = 0; i < n; i++) {
    switch (simulateAtBat(p, b, rng)) {
      case AtBatResult.walk:
        r.walk++;
      case AtBatResult.strikeout:
        r.strikeout++;
      case AtBatResult.out:
        r.out++;
      case AtBatResult.single:
        r.single++;
      case AtBatResult.double:
        r.doubles++;
      case AtBatResult.triple:
        r.triples++;
      case AtBatResult.homeRun:
        r.homeRun++;
    }
  }
  return r;
}

/// チーム同士の1試合の勝つ確率(試合の中の個人の出来を除いた、チーム力の差だけの計算)。
double teamWinChance(int mine, int theirs) =>
    (0.5 + (mine - theirs) / 100).clamp(0.0, 1.0);

class _VersusScreenState extends State<VersusScreen> {
  final Map<Ability, double> _bat = {
    Ability.contact: 99,
    Ability.power: 99,
    Ability.eye: 99,
  };
  final Map<Ability, double> _pit = {
    Ability.stuff: 10,
    Ability.control: 10,
  };
  final Set<Trait> _batTraits = {};
  final Set<Trait> _pitTraits = {};
  double _teamA = 99, _teamB = 10;
  int _count = 5000;
  VersusResult? _result;
  double? _teamResult;
  int _seed = 1;

  static const _batTraitList = [
    Trait.slugger,
    Trait.contactHitter,
    Trait.patient,
    Trait.speedster,
    Trait.prodigyBat,
  ];
  static const _pitTraitList = [
    Trait.fireballer,
    Trait.finesse,
    Trait.workhorse,
    Trait.prodigyArm,
  ];

  static String _abilityName(Ability a) => switch (a) {
        Ability.contact => 'ミート',
        Ability.power => 'パワー',
        Ability.eye => '選球眼',
        Ability.stuff => '球威',
        Ability.control => '制球',
        _ => a.name,
      };

  void _preset(int bat, int pit) => setState(() {
        for (final a in _bat.keys) {
          _bat[a] = bat.toDouble();
        }
        for (final a in _pit.keys) {
          _pit[a] = pit.toDouble();
        }
        _result = null;
      });

  void _run() {
    setState(() {
      _result = runVersus(
        bat: {for (final e in _bat.entries) e.key: e.value.round()},
        batTraits: _batTraits,
        pit: {for (final e in _pit.entries) e.key: e.value.round()},
        pitTraits: _pitTraits,
        n: _count,
        rng: Random(_seed++),
      );
    });
  }

  void _runTeam() {
    final rng = Random(_seed++);
    final p = teamWinChance(_teamA.round(), _teamB.round());
    var win = 0;
    for (var i = 0; i < _count; i++) {
      if (rng.nextDouble() < p) win++;
    }
    setState(() => _teamResult = win / _count);
  }

  Widget _slider(String label, double v, ValueChanged<double> on, {Key? key}) =>
      Row(children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: Slider(
            key: key,
            value: v,
            min: 0,
            max: 99,
            divisions: 99,
            label: '${v.round()}',
            onChanged: on,
          ),
        ),
        SizedBox(
            width: 32, child: Text('${v.round()}', textAlign: TextAlign.right)),
      ]);

  Widget _traitChips(List<Trait> list, Set<Trait> have) => Wrap(
        spacing: 6,
        children: [
          for (final t in list)
            FilterChip(
              key: Key('vs-trait-${t.name}'),
              label: Text(t.label),
              selected: have.contains(t),
              onSelected: (on) => setState(() {
                on ? have.add(t) : have.remove(t);
                _result = null;
              }),
            ),
        ],
      );

  String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('対戦テスト')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('育成中の選手には影響しません。能力を決めて、打者と投手を何千回も対戦させます。',
                  style: t.bodySmall),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [
                OutlinedButton(
                    key: const Key('vs-preset-99-10'),
                    onPressed: () => _preset(99, 10),
                    child: const Text('打者99 vs 投手10')),
                OutlinedButton(
                    key: const Key('vs-preset-50-50'),
                    onPressed: () => _preset(50, 50),
                    child: const Text('50 vs 50')),
                OutlinedButton(
                    key: const Key('vs-preset-10-99'),
                    onPressed: () => _preset(10, 99),
                    child: const Text('打者10 vs 投手99')),
                OutlinedButton(
                    key: const Key('vs-preset-99-99'),
                    onPressed: () => _preset(99, 99),
                    child: const Text('99 vs 99')),
              ]),
              const SizedBox(height: 12),
              Text('打者', style: t.titleSmall),
              for (final a in _bat.keys)
                _slider(_abilityName(a), _bat[a]!, (v) {
                  setState(() {
                    _bat[a] = v;
                    _result = null;
                  });
                }, key: Key('vs-bat-${a.name}')),
              _traitChips(_batTraitList, _batTraits),
              const SizedBox(height: 12),
              Text('投手', style: t.titleSmall),
              for (final a in _pit.keys)
                _slider(_abilityName(a), _pit[a]!, (v) {
                  setState(() {
                    _pit[a] = v;
                    _result = null;
                  });
                }, key: Key('vs-pit-${a.name}')),
              _traitChips(_pitTraitList, _pitTraits),
              const SizedBox(height: 12),
              Row(children: [
                const Text('対戦回数'),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1000, label: Text('1000')),
                    ButtonSegment(value: 5000, label: Text('5000')),
                    ButtonSegment(value: 20000, label: Text('2万')),
                  ],
                  selected: {_count},
                  onSelectionChanged: (s) => setState(() {
                    _count = s.first;
                    _result = null;
                    _teamResult = null;
                  }),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('vs-run'),
                onPressed: _run,
                child: const Text('対戦させる'),
              ),
              if (r != null) ...[
                const SizedBox(height: 12),
                Card(
                  key: const Key('vs-result'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.n}打席の結果', style: t.titleSmall),
                          const SizedBox(height: 6),
                          _row('出塁(四球+ヒット)', _pct(r.onBase),
                              key: const Key('vs-onbase')),
                          _row('打率', r.battingAverage.toStringAsFixed(3),
                              key: const Key('vs-avg')),
                          _row('長打率', r.slugging.toStringAsFixed(3)),
                          _row('三振', _pct(r.strikeout / r.n)),
                          _row('四球', _pct(r.walk / r.n)),
                          _row('凡退', _pct(r.out / r.n)),
                          _row('本塁打', _pct(r.homeRun / r.n)),
                          _row('二塁打・三塁打', _pct((r.doubles + r.triples) / r.n)),
                        ]),
                  ),
                ),
              ],
              const Divider(height: 32),
              Text('チーム同士の試合(チーム力の差だけで決まる勝つ確率)', style: t.titleSmall),
              _slider(
                  '自チーム',
                  _teamA,
                  (v) => setState(() {
                        _teamA = v;
                        _teamResult = null;
                      }),
                  key: const Key('vs-team-a')),
              _slider(
                  '相手',
                  _teamB,
                  (v) => setState(() {
                        _teamB = v;
                        _teamResult = null;
                      }),
                  key: const Key('vs-team-b')),
              FilledButton.tonal(
                key: const Key('vs-team-run'),
                onPressed: _runTeam,
                child: const Text('試合をさせる'),
              ),
              if (_teamResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('$_count試合で自チームの勝ち: ${_pct(_teamResult!)}',
                      key: const Key('vs-team-result'), style: t.titleMedium),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, {Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k)),
          Text(v,
              key: key, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}
