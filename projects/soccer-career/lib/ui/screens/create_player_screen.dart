import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import 'guide_screen.dart';
import 'hall_screen.dart';
import '../../game/career_engine.dart';
import '../../game/world.dart';
import '../../models/look.dart';
import '../../models/agent.dart';
import '../../models/challenge.dart';
import '../../game/formulas.dart';
import '../../models/legend.dart';
import '../../models/attributes.dart';
import '../../models/physique.dart';
import '../../models/traits.dart';
import '../trait_row.dart';
import '../../state/career_controller.dart';
import '../player_portrait.dart';
import '../readable_width.dart';

/// キャリアの最初の画面。名前・ポジション・年齢・代理人を決める。
///
/// ポテンシャルと特性はここでは見せない。始めてから分かるのがキャリアもの。
class CreatePlayerScreen extends StatefulWidget {
  const CreatePlayerScreen({super.key, required this.controller});

  final CareerController controller;

  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> {
  final _name = TextEditingController();
  Position _position = Position.st;
  Side _side = Side.right;
  int _age = 17;
  Foot _foot = Foot.right;
  int _height = Physique.baseHeight;
  int _weight = Physique.baseWeight;
  final Map<AttributeKey, int> _tweaks = {};
  PlayerLook _look = const PlayerLook();
  int _number = 10;
  String? _countryId;
  late final List<Agent> _agents = Agent.candidates(Random());
  Agent? _agent;
  bool _busy = false;

  /// 引いた特性。始めるときにそのまま渡す。
  ///
  /// 特性は**始めてから分かるもの**にしていたが、2つの長所で選手の性格が
  /// ほとんど決まるのに、それが見えないまま20年ぶんの選択をすることになる。
  /// 見せて引き直せるようにする（引き直しは、作り直せば同じことができた）。
  late List<Trait> _traits = Trait.roll(_traitRandom, position: _position);
  final Random _traitRandom = Random();

  /// 引き直した回数。稀な特性が出るまで押せることは隠さない。
  int _rerolls = 0;

  void _rerollTraits() {
    setState(() {
      _traits = Trait.roll(_traitRandom, position: _position);
      _rerolls++;
    });
  }

  /// 1カテゴリを動かせる幅。
  static const int tweakLimit = 6;

  /// 割り振りの合計。0 でないと始められない（増やしたぶんは削る）。
  int get _tweakSum => _tweaks.values.fold(0, (a, b) => a + b);

  /// そのポジションで意味のあるカテゴリ。GK 能力は GK だけ。
  List<AttributeKey> get _keys => [
    for (final key in AttributeKey.values)
      if (key != AttributeKey.goalkeeping || _position == Position.gk) key,
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      _agent != null &&
      _tweakSum == 0 &&
      !_busy;

  /// まだ始められない理由。ボタンが灰色なだけでは、2画面ぶん
  /// スクロールした先で「何が足りないのか」が分からなかった。
  List<String> get _missing => [
    if (_name.text.trim().isEmpty) tr('選手名を入れる', 'enter a name'),
    if (_tweakSum != 0)
      tr('能力の割り振りを合計0にする（今 ${_tweakSum > 0 ? '+' : ''}$_tweakSum）', 'balance the attribute points to zero (now ${_tweakSum > 0 ? '+' : ''}$_tweakSum)'),
    if (_agent == null) tr('代理人を選ぶ', 'pick an agent'),
  ];

  /// ポジションを変えると、基準値も割り振れる項目も変わる。
  void _selectPosition(Position position) {
    setState(() {
      _position = position;
      _tweaks.clear();
      if (!position.hasSide) _side = Side.center;
      if (position.hasSide && _side == Side.center) {
        _side = _foot == Foot.left ? Side.left : Side.right;
      }
      _height = _defaultHeightFor(position);
      _weight = _weightFor(_height);
      // 特性はポジションで引ける集合が変わる。
      // ストライカーに「反応の鬼」が付いたままになるのを防ぐ。
      _traits = Trait.roll(_traitRandom, position: position);
    });
  }

  static int _defaultHeightFor(Position position) => switch (position) {
    Position.gk => 189,
    Position.cb => 187,
    Position.st => 182,
    Position.dm => 180,
    Position.cm => 177,
    Position.sb => 176,
    Position.am => 174,
    Position.wg => 173,
  };

  /// 身長なりの体重。スライダーの初期値に使う。
  static int _weightFor(int height) => ((height - 100) * 0.86).round();

  Future<void> _start() async {
    if (!_ready) return;
    setState(() => _busy = true);
    await widget.controller.startCareer(
      name: _name.text.trim(),
      position: _position,
      age: _age,
      agent: _agent!,
      side: _side,
      look: _look,
      squadNumber: _number,
      countryId: _countryId,
      physique: Physique(
        heightCm: _height,
        weightKg: _weight,
        foot: _foot,
        // 逆足の精度は自分では選べない。始めてから分かるもののひとつ。
        weakFoot: 1 + Random().nextInt(3),
      ),
      tweaks: _tweaks,
      traits: _traits,
      declaredChallenge: _declared?.name,
    );
  }

  /// **今回狙う挑戦。** 選ばなくてもいい。
  ///
  /// 挑戦そのものは宣言しなくても達成できる（引退した記録から静かに判定する）。
  /// ここで宣言するのは、**今回の run に形を与える**ため。達成すれば
  /// 引退時の殿堂ポイントが重くなる。
  Challenge? _declared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      // **始めるボタンは画面の下に固定する。**
      // 決めることが11あって全体は3画面ぶんあるが、始めるのに要るのは
      // 名前と代理人だけ（残りは既定で埋まっている）。下まで送ると、
      // こだわらない人まで3画面スクロールしてからでないと始められない。
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_busy && _missing.isNotEmpty) ...[
                Text(
                  tr('あと: ${_missing.join(' ・ ')}', 'Still to do: ${_missing.join(' - ')}'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _ready ? _start : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(tr('キャリアを始める', 'Start the career')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ReadableWidth.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('選手キャリア', 'Player Career'), style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    tr('2部の下位クラブから始まる。38試合すべてに出て、'
                    '評価点を積み上げて上を目指す。'
                    'ポテンシャルは始めてから分かる。', 'You start at a struggling second-tier club. Play all 38 games, build up your ratings and climb. How far you can go is something you learn as you play.'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GuideScreen()),
                      ),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: Text(tr('遊び方ガイドを読む', 'Read how to play')),
                    ),
                  ),
                  // 前の選手をここから見に行ける。始める前に眺めるのが
                  // 一番自然な場所（引退画面は一度閉じたら戻れない）。
                  if (widget.controller.hall.legends.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                HallScreen(controller: widget.controller),
                          ),
                        ),
                        icon: const Icon(
                          Icons.workspace_premium_outlined,
                          size: 18,
                        ),
                        // **次の選手を作る場所に、追うものを出す。**
                        // 挑戦は殿堂の中にあるので、開かないと存在に気付かない。
                        label: Text(
                          tr('これまでの選手'
                          '（${widget.controller.hall.legends.length}人）'
                          ' ・ 挑戦 '
                          '${Challenge.values.where(widget.controller.hall.isCleared).length}'
                          '/${Challenge.values.length}', 'Players so far (${widget.controller.hall.legends.length}) - challenges ${Challenge.values.where(widget.controller.hall.isCleared).length}/${Challenge.values.length}'),
                        ),
                      ),
                    ),
                  // **前の選手たちが残したもの。** 貯まった点が、そのまま
                  // 今回の伸びしろになる。
                  if (widget.controller.hall.legacyPoints > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('受け継ぐもの '
                              '${widget.controller.hall.legacyPoints}pt', 'Inherited ${widget.controller.hall.legacyPoints}pt'),
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.controller.hall.potentialBonus > 0
                                  ? tr('これまでの選手が残した記録で、この選手の'
                                        '伸びしろが'
                                        '+${widget.controller.hall.potentialBonus}'
                                        'される'
                                        '（${Formulas.legacyPerPotential}ptごとに+1、'
                                        '上限+${Formulas.legacyPotentialCap}）。', 'What your earlier players left behind raises this one ceiling by +${widget.controller.hall.potentialBonus} (+1 for every ${Formulas.legacyPerPotential}pt, up to +${Formulas.legacyPotentialCap}).')
                                  : tr('あと'
                                        '${Formulas.legacyPerPotential - widget.controller.hall.legacyPoints}'
                                        'ptで、次の選手の伸びしろが+1される。', '${Formulas.legacyPerPotential - widget.controller.hall.legacyPoints}pt more and the next player ceiling goes up by 1.'),
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: tr('選手名', 'Name'),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PlayerPortrait(
                        look: _look,
                        squadNumber: _number,
                        size: 88,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tr('顔は描かない。髪と肌と、着ているもので「自分の選手」にする。'
                          'クラブに入ると、そのクラブの色を着る。', 'No facial features are drawn. Hair, skin and kit are what make this your player. Once you join a club, you wear its colours.'),
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(tr('ポジション', 'Position'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in Position.values)
                        ChoiceChip(
                          label: Text(p.label),
                          selected: _position == p,
                          onSelected: (_) => _selectPosition(p),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_position.fullName, style: muted),
                  if (_position.hasSide) ...[
                    const SizedBox(height: 12),
                    Text(tr('立つ側', 'Side'), style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      tr('利き足と同じ側なら、逆足で対応する局面が減る。'
                      '逆サイドは逆足の局面が増える代わりに、'
                      '内へ切り込んで利き足で打てる。', 'On your strong foot side, fewer moments force your weaker foot. On the other side there are more of them, but you can cut inside and shoot with your good foot.'),
                      style: muted,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final side in [Side.left, Side.right])
                          ChoiceChip(
                            label: Text(side.label),
                            selected: _side == side,
                            onSelected: (_) => setState(() => _side = side),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _side.matches(_foot)
                          ? tr('${_side.label}サイドの${_foot.label}。'
                                '外を向いたまま蹴れる。', '${_foot.label} on the ${_side.label}. You can play facing out.')
                          : tr('${_side.label}サイドの${_foot.label}。'
                                '内へ切り込む形になる。', '${_foot.label} on the ${_side.label}. You will be cutting inside.'),
                      style: muted,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(tr('代理人', 'Agent'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(tr('契約交渉と移籍先の開拓を任せる。交渉力・人脈・手数料が違う。', 'They handle your contracts and find you clubs. They differ in bargaining, contacts and fee.'), style: muted),
                  const SizedBox(height: 8),
                  for (final agent in _agents) ...[
                    _AgentCard(
                      agent: agent,
                      selected: _agent == agent,
                      onTap: () => setState(() => _agent = agent),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 24),
                  Text(tr('年齢  $_age', 'Age  $_age'), style: theme.textTheme.labelLarge),
                  Slider(
                    value: _age.toDouble(),
                    min: 16,
                    max: 21,
                    divisions: 5,
                    label: '$_age',
                    onChanged: (v) => setState(() => _age = v.round()),
                  ),
                  Text(
                    _age <= 17
                        ? tr('育成年代からの出発。一番下の部で、無名のまま始まる。'
                              '伸びしろは長い。', 'Starting from the youth ranks. Bottom tier, no name yet, and a long way to grow.')
                        : tr('若く始めるほど伸びしろは長いが、初期能力は低い。', 'The younger you start, the longer you have to grow, and the weaker you begin.'),
                    style: muted,
                  ),
                  const SizedBox(height: 24),
                  Text(tr('出身国', 'Country'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    tr('始めるリーグと、代表と、外国人としての扱いが決まる。'
                    '格の高い国は水準も高いぶん、上がるのは難しい。', 'This sets the league you start in, the national team you can play for, and how you are treated as a foreigner. A higher-standing country is a higher standard, and harder to climb.'),
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(tr('おまかせ', 'Any')),
                        selected: _countryId == null,
                        onSelected: (_) => setState(() => _countryId = null),
                      ),
                      for (final country in World.countries)
                        ChoiceChip(
                          label: Text(
                            '${country.name} '
                            '${'★' * country.prestige}',
                          ),
                          selected: _countryId == country.id,
                          onSelected: (_) =>
                              setState(() => _countryId = country.id),
                        ),
                    ],
                  ),
                  if (_countryId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      tr('${World.byId(_countryId!).confederation.label}  ・  '
                      '${World.byId(_countryId!).tiers}部制  ・  '
                      '外国人ルール ${World.byId(_countryId!).foreignRule.summary}', '${World.byId(_countryId!).confederation.label}  -  ${plural(World.byId(_countryId!).tiers, 'tier')}  -  foreigner rule ${World.byId(_countryId!).foreignRule.summary}'),
                      style: muted,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(tr('身体', 'Body'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    tr('練習では動かない。高さは競り合いに、体重は当たりの強さと'
                    'キレの入れ替えに効く。', 'Training does not change these. Height tells in the air; weight trades sharpness for strength in a duel.'),
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final foot in [Foot.right, Foot.left])
                        ChoiceChip(
                          label: Text(foot.label),
                          selected: _foot == foot,
                          onSelected: (_) => setState(() {
                            _foot = foot;
                            if (_position.hasSide) {
                              _side = foot == Foot.left
                                  ? Side.left
                                  : Side.right;
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(tr('身長  $_height cm', 'Height  $_height cm'), style: theme.textTheme.bodyMedium),
                  Slider(
                    value: _height.toDouble(),
                    min: 165,
                    max: 200,
                    divisions: 35,
                    label: '$_height',
                    onChanged: (v) => setState(() => _height = v.round()),
                  ),
                  Text(tr('体重  $_weight kg', 'Weight  $_weight kg'), style: theme.textTheme.bodyMedium),
                  Slider(
                    value: _weight.toDouble(),
                    min: 58,
                    max: 98,
                    divisions: 40,
                    label: '$_weight',
                    onChanged: (v) => setState(() => _weight = v.round()),
                  ),
                  Text(
                    Physique(
                      heightCm: _height,
                      weightKg: _weight,
                      foot: _foot,
                    ).buildLabel,
                    style: muted,
                  ),
                  const SizedBox(height: 16),
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(tr('見た目と背番号', 'Look and shirt number'), style: theme.textTheme.labelLarge),
                      subtitle: Text(
                        tr('${_look.hair.label}  ・  '
                        '${PlayerLook.hairColorLabels[_look.hairColor]}  ・  '
                        '背番号 $_number', '${_look.hair.label}  -  ${PlayerLook.hairColorLabels[_look.hairColor]}  -  no. $_number'),
                        style: muted,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(tr('試合の判定には効かない。', 'None of this affects anything on the pitch.'), style: muted),
                        ),
                        const SizedBox(height: 10),
                        _LookRow(
                          label: tr('肌', 'Skin'),
                          children: [
                            for (
                              var i = 0;
                              i < PlayerLook.skinTones.length;
                              i++
                            )
                              _Swatch(
                                color: Color(PlayerLook.skinTones[i]),
                                selected: _look.skin == i,
                                onTap: () => setState(
                                  () => _look = _look.copyWith(skin: i),
                                ),
                              ),
                          ],
                        ),
                        _LookRow(
                          label: tr('髪の色', 'Hair colour'),
                          children: [
                            for (
                              var i = 0;
                              i < PlayerLook.hairColors.length;
                              i++
                            )
                              _Swatch(
                                color: Color(PlayerLook.hairColors[i]),
                                selected: _look.hairColor == i,
                                onTap: () => setState(
                                  () => _look = _look.copyWith(hairColor: i),
                                ),
                              ),
                          ],
                        ),
                        _LookRow(
                          label: tr('髪型', 'Hair'),
                          children: [
                            for (final style in HairStyle.values)
                              ChoiceChip(
                                label: Text(style.label),
                                selected: _look.hair == style,
                                onSelected: (_) => setState(
                                  () => _look = _look.copyWith(hair: style),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr('背番号  $_number', 'Shirt number  $_number'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Slider(
                          value: _number.toDouble(),
                          min: 1,
                          max: 99,
                          divisions: 98,
                          label: '$_number',
                          onChanged: (v) => setState(() => _number = v.round()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('能力の割り振り', 'Attribute points'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    tr('ポジションの基準値から、$tweakLimit まで動かせる。'
                    '増やしたぶんはどこかを削る（合計を0にすると始められる）。'
                    'ポテンシャルは始めてから分かる。', 'You can move each attribute up to $tweakLimit from the baseline for your position. Whatever you add has to come off somewhere else — balance it to zero and you can start. How far you can grow is something you learn as you play.'),
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  for (final key in _keys)
                    _TweakRow(
                      label: key.label,
                      base: CareerEngine.startingBaseFor(_position)[key] ?? 0,
                      value: _tweaks[key] ?? 0,
                      limit: tweakLimit,
                      onChanged: (v) => setState(() => _tweaks[key] = v),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _tweakSum == 0
                        ? tr('割り振りは釣り合っている。', 'The points are balanced.')
                        : tr('合計 ${_tweakSum > 0 ? '+' : ''}$_tweakSum。'
                              '0にすると始められる。', 'Total ${_tweakSum > 0 ? '+' : ''}$_tweakSum. Balance it to zero and you can start.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _tweakSum == 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(tr('生まれ持った特性', 'Traits you were born with'), style: theme.textTheme.labelLarge),
                      ),
                      TextButton.icon(
                        onPressed: _rerollTraits,
                        icon: const Icon(Icons.casino_outlined, size: 18),
                        label: Text(tr('引き直す', 'Draw again')),
                      ),
                    ],
                  ),
                  Text(
                    tr('長所が2つ、3割で欠点が1つ。まれに特別なものが混じる。'
                    '伸ばせないが、効く場面は決まっている。'
                    '${_rerolls > 0 ? '（$_rerolls回 引き直した）' : ''}', 'Two strengths, and a flaw three times in ten. Something rare turns up now and then. You cannot train them, but each one has its moments. ${_rerolls > 0 ? '(drawn again ${plural(_rerolls, 'time')})' : ''}'),
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _traits.length; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            TraitRow(trait: _traits[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DeclareCard(
                    hall: widget.controller.hall,
                    declared: _declared,
                    onPick: (c) => setState(() => _declared = c),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 見た目の1行。ラベルと、選ぶものを並べる。
/// **今回狙う挑戦を1つ宣言する。**
///
/// 挑戦は宣言しなくても達成できる（引退した記録から静かに判定する）。
/// ここで選ぶのは、**今回の run に形を与える**ため。達成すれば
/// 引退時の殿堂ポイントが重くなる。選ばなくてもいい。
class _DeclareCard extends StatelessWidget {
  const _DeclareCard({
    required this.hall,
    required this.declared,
    required this.onPick,
  });

  final Hall hall;
  final Challenge? declared;
  final ValueChanged<Challenge?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // まだ達成していないものから出す。済んだものを狙わせても薄い。
    final open = [
      for (final c in Challenge.values)
        if (!hall.isCleared(c)) c,
    ];
    if (open.isEmpty) return const SizedBox.shrink();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey('declare-challenge'),
          title: Text(tr('今回狙うもの', 'What you are going for'), style: theme.textTheme.titleSmall),
          subtitle: Text(
            declared == null
                ? tr('選ばなくてもいい（達成は宣言しなくても記録される）', 'You do not have to pick one — anything you clear is recorded either way')
                : tr('${declared!.label} ・ 達成で +${declared!.declaredBonus}pt', '${declared!.label} - +${declared!.declaredBonus}pt if you do it'),
            style: muted,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in open)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  declared == c
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: declared == c
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
                title: Text('${c.label}　+${c.declaredBonus}pt'),
                subtitle: Text(c.requirement, style: muted),
                onTap: () => onPick(c),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                declared == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: declared == null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
              title: Text(tr('宣言しない', 'Call nothing')),
              onTap: () => onPick(null),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookRow extends StatelessWidget {
  const _LookRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
          ),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: children)),
        ],
      ),
    );
  }
}

/// 色を選ぶ丸。
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// 能力を1つ、基準値から動かす行。
class _TweakRow extends StatelessWidget {
  const _TweakRow({
    required this.label,
    required this.base,
    required this.value,
    required this.limit,
    required this.onChanged,
  });

  final String label;

  /// ポジションの基準値。動かした結果がいくつになるかを見せる。
  final int base;

  final int value;
  final int limit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            // 日本語は「シュート」の4文字、英語は Goalkeeping の11文字が
            // 一番長い。84 のままだと途中で割れる。
            width: pick(84.0, 102.0),
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > -limit ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${base + value}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < limit ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
          SizedBox(
            width: 34,
            child: Text(
              value == 0 ? '' : '${value > 0 ? '+' : ''}$value',
              style: theme.textTheme.labelMedium?.copyWith(
                color: value > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final Agent agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('${agent.name} ・ ${agent.style}', '${agent.name} - ${agent.style}'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle),
            ],
          ),
        ),
      ),
    );
  }
}
