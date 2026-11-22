import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/game.dart';
import '../engine/rng.dart';
import 'end_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen(this.c, {super.key});
  final AppController c;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  int tab = 0;

  Game get g => widget.c.game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        if (g.finished) return EndScreen(widget.c);
        return Stack(children: [
          Scaffold(
            appBar: _header(),
            body: SafeArea(
              top: false,
              child: IndexedStack(index: tab, children: [
                _ActionTab(g),
                _PersonTab(g),
                _WorldTab(g),
                _LogTab(g),
              ]),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.bolt_outlined), label: '行動'),
                NavigationDestination(icon: Icon(Icons.person_outline), label: '人物'),
                NavigationDestination(icon: Icon(Icons.public), label: '天下'),
                NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '見聞録'),
              ],
            ),
          ),
          if (g.prompt != null) _PromptOverlay(g),
        ]);
      },
    );
  }

  PreferredSizeWidget _header() => AppBar(
        backgroundColor: Pal.panel,
        toolbarHeight: 52,
        titleSpacing: 16,
        title: Row(children: [
          Expanded(
            child: Text('${g.year}年（${gengo(g.year)}）${g.isChild ? '' : g.season}',
                style: const TextStyle(color: Pal.gold, fontSize: 15)),
          ),
          Text('${g.age}歳', style: const TextStyle(fontSize: 15)),
          if (g.isChild)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                  border: Border.all(color: Pal.accent), borderRadius: BorderRadius.circular(4)),
              child: const Text('幼少期', style: TextStyle(color: Pal.accent, fontSize: 12)),
            ),
        ]),
      );
}

const _pad = EdgeInsets.fromLTRB(14, 12, 14, 20);

class _ActionTab extends StatelessWidget {
  const _ActionTab(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    final acts = g.availableActions();
    return ListView(padding: _pad, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          Text('${g.rankName()}${l.lord != null ? '／${l.lord}家${l.rank == 8 ? '当主' : ''}' : ''}',
              style: const TextStyle(color: Pal.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Gauge('健康', l.hp / l.maxhp * 100, color: Pal.good),
          Gauge('幸福', l.joy.toDouble(), color: Pal.gold),
          Gauge('人間関係', l.net.toDouble(), color: Pal.purple),
          const SizedBox(height: 4),
          Text(g.nextPromo(), style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('銭 ${l.gold}貫　兵 ${l.troops}　功 ${l.merit}　信頼 ${l.fav}',
              style: const TextStyle(fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        title: g.isChild ? 'この一年の過ごし方' : 'この半年の行い',
        child: LayoutBuilder(builder: (context, box) {
          const gap = 8.0;
          final w = (box.maxWidth - gap) / 2;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final a in acts) SizedBox(width: w, child: _ActionButton(g, a)),
          ]);
        }),
      ),
      const SizedBox(height: 12),
      Panel(
        title: '直近のできごと',
        child: LogList(l.log.take(4).toList()),
      ),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.g, this.a);
  final Game g;
  final ActionDef a;

  @override
  Widget build(BuildContext context) {
    final dis = a.dis?.call();
    final label = (g.l.female && a.labelF != null) ? a.labelF! : a.label;
    return Material(
      color: Pal.panel2,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: Pal.line), borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: dis != null
            ? null
            : () {
                HapticFeedback.selectionClick();
                g.doAct(a.id);
              },
        child: Opacity(
          opacity: dis != null ? .4 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: a.danger ? Pal.bad : Pal.ink)),
              const SizedBox(height: 2),
              Text(dis ?? a.desc,
                  style: const TextStyle(color: Pal.muted, fontSize: 11.5, height: 1.35)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PersonTab extends StatelessWidget {
  const _PersonTab(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    return ListView(padding: _pad, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          Text(
              '${l.female ? '女' : '男'}・${ordLabel(l.female, l.order)}／${g.rankName()}／${l.region}',
              style: const TextStyle(color: Pal.muted, fontSize: 13)),
          const SizedBox(height: 10),
          Gauge('健康', l.hp / l.maxhp * 100, color: Pal.good),
          Gauge('幸福', l.joy.toDouble(), color: Pal.gold),
          Gauge('人間関係', l.net.toDouble(), color: Pal.purple),
          const Divider(color: Pal.line, height: 20),
          Gauge('武', l.bu.toDouble()),
          Gauge('知識', l.chi.toDouble()),
          Gauge('政', l.sei.toDouble()),
          Gauge('魅', l.mi.toDouble()),
          Gauge('運', l.un.toDouble()),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in l.traits) Tag(traitName(t)),
            if (l.gun) const Tag('鉄砲'),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        title: '暮らし',
        child: Column(children: [
          KV('銭', '${l.gold}貫'),
          KV('兵', '${l.troops}'),
          KV('功', '${l.merit}'),
          KV('名声', '${l.fame}'),
          KV('主君の信頼', '${l.fav}'),
          KV('家族', '${l.married ? '妻帯' : '独り身'}・子${l.kids}人'),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        title: '生まれ',
        child: Text(
            '約${fmtN(l.rarity)}分の1の巡り合わせ。\n戦国の日本で同じ身分の者は、約${fmtN(l.sameClass)}人。',
            style: const TextStyle(color: Pal.muted, height: 1.7)),
      ),
    ]);
  }
}

class _WorldTab extends StatelessWidget {
  const _WorldTab(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final fs = g.alive..sort((a, b) => b.power.compareTo(a.power));
    final maxP = fs.fold<double>(1, (m, f) => f.power > m ? f.power : m);
    return ListView(padding: _pad, children: [
      Panel(
        title: '天下の勢力',
        child: Column(children: [
          for (final f in fs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 62,
                    child: Text(f.name,
                        style: TextStyle(
                            fontWeight: f.name == g.l.lord ? FontWeight.w700 : FontWeight.w400,
                            color: f.name == g.l.lord ? Pal.gold : Pal.ink))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: f.power / maxP,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF0E0C0A),
                      valueColor: AlwaysStoppedAnimation(
                          f.name == g.l.lord ? Pal.gold : const Color(0xFF6B5A46)),
                    ),
                  ),
                ),
                SizedBox(
                    width: 38,
                    child: Text(f.power.round().toString(),
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          const SizedBox(height: 8),
          Text('生き残り ${fs.length}家／1600年で乱世は終わる',
              style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
        ]),
      ),
    ]);
  }
}

class _LogTab extends StatelessWidget {
  const _LogTab(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) => ListView(
        padding: _pad,
        children: [Panel(title: '見聞録', child: LogList(g.l.log.take(80).toList()))],
      );
}

class _PromptOverlay extends StatelessWidget {
  const _PromptOverlay(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final p = g.prompt!;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: .72),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Pal.panel,
                  border: Border.all(color: Pal.gold),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title,
                      style: const TextStyle(color: Pal.gold, fontSize: 19, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text(p.text, style: const TextStyle(height: 1.7)),
                  const SizedBox(height: 14),
                  for (var i = 0; i < p.choices.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            backgroundColor: Pal.panel2,
                            side: const BorderSide(color: Pal.line),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            g.choose(i);
                          },
                          child: Text(p.choices[i].label,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: p.choices[i].danger ? Pal.bad : Pal.ink,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
