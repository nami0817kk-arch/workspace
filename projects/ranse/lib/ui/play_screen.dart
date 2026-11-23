import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/game.dart';
import '../engine/history_lines.dart';
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
        return Scaffold(
          appBar: _header(),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: tab,
              children: [
                _ChoiceTab(g),
                _PersonTab(g),
                _WorldTab(g),
                _LogTab(g),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: g.prompt != null && tab != 0,
                  smallSize: 8,
                  child: const Icon(Icons.alt_route),
                ),
                label: '岐路',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '人物',
              ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: '天下',
              ),
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: '見聞録',
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _header() => AppBar(
    backgroundColor: Pal.panel,
    toolbarHeight: 52,
    titleSpacing: 16,
    title: Row(
      children: [
        Expanded(
          child: Text(
            '${g.year}年（${gengo(g.year)}）${g.isChild ? '' : g.season}',
            style: const TextStyle(color: Pal.gold, fontSize: 15),
          ),
        ),
        Text('${g.age}歳', style: const TextStyle(fontSize: 15)),
        if (g.isChild)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Pal.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '幼少期',
              style: TextStyle(color: Pal.accent, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

const _pad = EdgeInsets.fromLTRB(14, 12, 14, 20);

/// 場面の絵の置き場所（`kSceneArts` の名前から）。
String sceneArtPath(String art) => 'assets/images/scene_$art.jpg';

class _ChoiceTab extends StatelessWidget {
  const _ChoiceTab(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    final p = g.prompt;
    return ListView(
      padding: _pad,
      children: [
        if (p != null) ...[_PromptCard(g, p), const SizedBox(height: 12)],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${g.rankName()}${l.lord != null ? '／${houseName(g, l.lord)}家${l.rank == 8 ? '当主' : ''}' : ''}',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Gauge('健康', l.hp / l.maxhp * 100, color: Pal.good),
              Gauge('幸福', l.joy.toDouble(), color: Pal.gold),
              Gauge('人間関係', l.net.toDouble(), color: Pal.purple),
              if (!g.isChild) ...[
                const SizedBox(height: 4),
                Text(
                  g.nextPromo(),
                  style: const TextStyle(color: Pal.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '銭 ${l.gold}貫　兵 ${l.troops}　功 ${l.merit}　信頼 ${l.fav}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(title: '直近のできごと', child: LogList(l.log.take(4).toList())),
        const SizedBox(height: 12),
        Panel(
          title: '歩んだ道',
          child: l.path.isEmpty
              ? const Text(
                  'ここから、あなたの人生が始まる。',
                  style: TextStyle(color: Pal.muted, height: 1.7),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in l.path.reversed.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 岐路（いまの選択）。行動タブの先頭に出す。選んでいる間も他のタブは見られる。
class _PromptCard extends StatelessWidget {
  const _PromptCard(this.g, this.p);
  final Game g;
  final Prompt p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.panel,
        border: Border.all(color: Pal.gold),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (g.lastResults.isNotEmpty) ...[
            for (final e in g.lastResults.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  e.txt,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: e.kind == 'bad'
                        ? Pal.bad
                        : (e.kind == 'good' || e.kind == 'big'
                              ? Pal.gold
                              : Pal.muted),
                  ),
                ),
              ),
            const Divider(color: Pal.line, height: 18),
          ],
          // 場面の絵（Gemini で作ったドット絵）。「今年の重点」には添えない。
          if (p.art case final art?) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                sceneArtPath(art),
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            p.title,
            style: const TextStyle(
              color: Pal.gold,
              fontSize: 19,
              letterSpacing: 2,
            ),
          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    backgroundColor: Pal.bg,
                    overlayColor: Pal.accent,
                    side: BorderSide(
                      color: p.choices[i].danger
                          ? Pal.bad.withValues(alpha: .55)
                          : Pal.line,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    g.choose(i);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChoiceMark(i, danger: p.choices[i].danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                p.choices[i].label,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: p.choices[i].danger
                                      ? Pal.bad
                                      : Pal.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (p.choices[i].hint != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  p.choices[i].hint!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Pal.muted,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Pal.line,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    return ListView(
      padding: _pad,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${l.female ? '女' : '男'}・${ordLabel(l.female, l.order)}／${g.rankName()}／${l.region}',
                style: const TextStyle(color: Pal.muted, fontSize: 13),
              ),
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in l.traits) Tag(traitName(t)),
                  if (l.gun) const Tag('鉄砲'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          title: '暮らし',
          child: Column(
            children: [
              KV('銭', '${l.gold}貫'),
              KV('兵', '${l.troops}'),
              KV('功', '${l.merit}'),
              KV('名声', '${l.fame}'),
              KV('主君の信頼', '${l.fav}'),
              KV(
                '家族',
                '${l.married ? (l.female ? '嫁いだ身' : '妻帯') : '独り身'}・子${l.kids}人',
              ),
            ],
          ),
        ),
        if (l.people.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            title: '縁のある人',
            child: Column(
              children: [
                for (final p in l.people.values)
                  KV(
                    p.role,
                    personDied(g, p.name)
                        ? '${p.name}（故人）'
                        : (p.role == '伴侶' && !l.married
                              ? '${p.name}（いまは共にいない）'
                              : '${p.name}（絆 ${p.bond}）'),
                  ),
              ],
            ),
          ),
        ],
        if (l.path.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            title: '歩んだ道',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in l.path)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Panel(
          title: '生まれ',
          child: Text(
            '約${fmtN(l.rarity)}分の1の巡り合わせ。\n戦国の日本で同じ身分の者は、約${fmtN(l.sameClass)}人。',
            style: const TextStyle(color: Pal.muted, height: 1.7),
          ),
        ),
      ],
    );
  }
}

class _WorldTab extends StatelessWidget {
  const _WorldTab(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final fs = g.alive..sort((a, b) => b.power.compareTo(a.power));
    final maxP = fs.fold<double>(1, (m, f) => f.power > m ? f.power : m);
    return ListView(
      padding: _pad,
      children: [
        if (changedHistory(g).isNotEmpty) ...[
          Panel(
            title: '今の世',
            child: Text(
              '${changedHistory(g).join('。')}。あなたの選択で、歴史は史実と別の道を歩んでいる。',
              style: const TextStyle(color: Pal.gold, height: 1.6),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Panel(
          title: '天下の勢力',
          child: Column(
            children: [
              for (final f in fs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: Text(
                          houseName(g, f.name),
                          style: TextStyle(
                            fontWeight: f.name == g.l.lord
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: f.name == g.l.lord ? Pal.gold : Pal.ink,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: f.power / maxP,
                            minHeight: 8,
                            backgroundColor: Pal.track,
                            valueColor: AlwaysStoppedAnimation(
                              f.name == g.l.lord ? Pal.gold : Pal.muted,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        child: Text(
                          f.power.round().toString(),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '生き残り ${fs.length}家／1600年で乱世は終わる',
                style: const TextStyle(color: Pal.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
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
