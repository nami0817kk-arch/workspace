import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import 'theme.dart';
import 'widgets.dart';

/// 試験用の生まれ（2026-11-24、ユーザー「テスト用に、自分で諸々生まれ方を決められるようにして」）。
/// タイトルの題字を長押しした先にだけある。ふつうに遊ぶ人には見せない（「生まれは選べない」がこの作品の芯）。
/// 決めなかった項目は籤に任せる。決めた生まれは稀少度を数えない（1分の1）。
class TestBirthScreen extends StatefulWidget {
  const TestBirthScreen(this.c, {super.key});
  final AppController c;

  @override
  State<TestBirthScreen> createState() => _TestBirthScreenState();
}

class _TestBirthScreenState extends State<TestBirthScreen> {
  String? cls, region, faction;
  bool? female;
  int? order, year;
  bool pickTraits = false;
  final traits = <String>[];
  bool setStats = false;
  final stats = [60, 60, 60, 60, 60];

  static const _statNames = ['武', '知', '政', '魅', '運'];

  ClassDef? get _cls =>
      cls == null ? null : kClasses.firstWhere((c) => c.id == cls);
  Region? get _region =>
      region == null ? null : kRegions.firstWhere((r) => r.n == region);

  void _start() {
    widget.c.drawCustom(
      BirthSpec(
        clsId: cls,
        region: region,
        faction: faction,
        startYear: year,
        female: female,
        order: order,
        traitIds: pickTraits ? [...traits] : null,
        stats: setStats ? [...stats] : null,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reg = _region;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Pal.panel,
        title: const Text('試験用の生まれ', style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const Text(
              '試しに遊ぶための画面。決めなかった項目は籤に任せる。'
              'ここで決めた生まれは、稀少度を数えない。',
              style: TextStyle(color: Pal.muted, fontSize: 12.5, height: 1.6),
            ),
            const SizedBox(height: 12),
            _row(
              '身分',
              _drop<String>(
                value: cls,
                items: {for (final c in kClasses) c.id: c.name},
                onChanged: (v) => setState(() {
                  cls = v;
                  // 身分・性別で付かない特性は外す。
                  _dropUnfit();
                }),
              ),
            ),
            _row(
              '国',
              _drop<String>(
                value: region,
                items: {for (final r in kRegions) r.n: r.n},
                onChanged: (v) => setState(() {
                  region = v;
                  faction = null;
                }),
              ),
            ),
            if (reg != null && reg.f.length > 1)
              _row(
                '家',
                _drop<String>(
                  value: faction,
                  items: {for (final f in reg.f) f: '$f家'},
                  onChanged: (v) => setState(() => faction = v),
                ),
              ),
            _row(
              '性別',
              _drop<bool>(
                value: female,
                items: const {false: '男', true: '女'},
                onChanged: (v) => setState(() {
                  female = v;
                  _dropUnfit();
                }),
              ),
            ),
            _row(
              '生まれ順',
              _drop<int>(
                value: order,
                items: const {1: '長子', 2: '次子', 3: '三子以下'},
                onChanged: (v) => setState(() => order = v),
              ),
            ),
            _row(
              '生まれ年',
              Row(
                children: [
                  Checkbox(
                    value: year != null,
                    onChanged: (v) =>
                        setState(() => year = v == true ? 1550 : null),
                  ),
                  Expanded(
                    child: year == null
                        ? const Text('籤に任せる', style: TextStyle(color: Pal.muted))
                        : Slider(
                            value: year!.toDouble(),
                            min: 1525,
                            max: 1568,
                            divisions: 1568 - 1525,
                            label: '$year',
                            onChanged: (v) => setState(() => year = v.round()),
                          ),
                  ),
                  if (year != null)
                    SizedBox(
                      width: 44,
                      child: Text('$year', textAlign: TextAlign.right),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _switch('能力を決める', setStats, (v) => setState(() => setStats = v)),
            if (setStats)
              for (var i = 0; i < 5; i++)
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        _statNames[i],
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: stats[i].toDouble(),
                        min: 3,
                        max: 99,
                        divisions: 96,
                        label: '${stats[i]}',
                        onChanged: (v) => setState(() => stats[i] = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text('${stats[i]}', textAlign: TextAlign.right),
                    ),
                  ],
                ),
            const SizedBox(height: 6),
            _switch(
              '特性を決める（多くて$kMaxTraits）',
              pickTraits,
              (v) => setState(() => pickTraits = v),
            ),
            if (pickTraits) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final id in traits)
                    InputChip(
                      label: Text(_traitName(id)),
                      onDeleted: () => setState(() => traits.remove(id)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(traits.isEmpty ? '特性なし（足す）' : '足す'),
                    onPressed: traits.length >= kMaxTraits ? null : _addTrait,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            BigButton('この生まれで始める', _start),
          ],
        ),
      ),
    );
  }

  /// 選んだ身分・性別に付かない特性を外す。
  void _dropUnfit() {
    final c = _cls;
    if (c == null || female == null) return;
    traits.removeWhere(
      (id) => !kTraits.firstWhere((t) => t.id == id).fits(c, female!),
    );
  }

  String _traitName(String id) {
    final t = kTraits.firstWhere((t) => t.id == id);
    return '${t.name}（${t.tier.label}）';
  }

  Future<void> _addTrait() async {
    final c = _cls;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pal.bg,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            for (final tier in TraitTier.values.reversed) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  tier.label,
                  style: const TextStyle(
                    color: Pal.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final t in kTraits)
                if (t.tier == tier &&
                    !traits.contains(t.id) &&
                    (c == null || female == null || t.fits(c, female!)))
                  ListTile(
                    dense: true,
                    title: Text(t.name),
                    subtitle: Text(
                      t.desc,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.of(context).pop(t.id),
                  ),
            ],
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => traits.add(picked));
  }

  Widget _row(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: value,
        onChanged: onChanged,
      );

  /// 先頭に「籤に任せる」（null）を置いた選び箱。
  Widget _drop<T>({
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) => DropdownButton<T?>(
    value: value,
    isExpanded: true,
    items: [
      const DropdownMenuItem(
        value: null,
        child: Text('籤に任せる', style: TextStyle(color: Pal.muted)),
      ),
      for (final e in items.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: onChanged,
  );
}
