import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../engine/birth.dart';
import '../engine/data.dart';
import '../engine/game.dart';
import '../engine/history_lines.dart';
import '../engine/kid_raising.dart';
import '../engine/life.dart';
import '../engine/peace.dart';
import '../engine/retainers.dart';
import '../engine/rng.dart';
import '../engine/spending.dart';
import 'end_screen.dart';
import 'rank_guide.dart';
import 'standing_card.dart';
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

  /// タイトルへ戻る前に確かめる（2026-11-24、ユーザー「タイトルに戻るがない」）。
  /// 保存は年の初めにしているので、戻ると、その年に選んだことはやり直しになる。
  Future<void> _confirmTitle() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Pal.bg,
        title: const Text('タイトルに戻りますか？'),
        content: const Text(
          'この年の初めまでの歩みは残してあります。タイトルの「続きから」で、この年の初めから再開できます。',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('タイトルへ', style: TextStyle(color: Pal.accent)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) widget.c.toTitle();
  }

  PreferredSizeWidget _header() => AppBar(
    backgroundColor: Pal.panel,
    toolbarHeight: 52,
    titleSpacing: 16,
    actions: [
      IconButton(
        icon: const Icon(Icons.home_outlined, color: Pal.muted),
        tooltip: 'タイトルへ',
        onPressed: _confirmTitle,
      ),
    ],
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
    // 選択肢をスクロールせずに押せるよう、岐路があるときは立ち位置を一行に縮めて上に、
    // くわしいカードは岐路の下に回す（2026-11-23 ユーザー「選択肢はスクロールしないでも可能にして」）。
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        if (p != null) ...[
          _RankTap(g, child: StandingStrip(g)),
          const SizedBox(height: 6),
          _PromptCard(g, p),
          const SizedBox(height: 12),
        ],
        _RankTap(g, child: StandingCard(g)),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gauge('健康', l.hp / l.maxhp * 100, color: Pal.good),
              Gauge('幸福', l.joy.toDouble(), color: Pal.gold),
              Gauge('縁', l.net.toDouble(), color: Pal.purple),
              if (!g.isChild) ...[
                const SizedBox(height: 6),
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

/// 選択肢がこの数以上なら二列に並べる（毎年の重点は多いと十ほどになる）。
const kTwoColumnChoices = 5;

/// 岐路（いまの選択）。行動タブの先頭に出す。選んでいる間も他のタブは見られる。
/// 一画面に収まるよう詰めてある: 前の結果は二行まで、絵は題を重ねた帯、選択肢が多ければ二列。
class _PromptCard extends StatelessWidget {
  const _PromptCard(this.g, this.p);
  final Game g;
  final Prompt p;

  @override
  Widget build(BuildContext context) {
    final results = g.lastResults;
    final n = p.choices.length;
    final twoCol = n >= kTwoColumnChoices;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Pal.panel,
        border: Border.all(color: Pal.gold),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (results.isNotEmpty) ...[
            for (final e in results.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                // 能力の段を越えた【才】の一行には、どの能力かの札を添える（`LogEntry.cause`）。
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        e.txt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: e.kind == 'bad'
                              ? Pal.bad
                              : (e.kind == 'good' || e.kind == 'big'
                                    ? Pal.gold
                                    : Pal.muted),
                        ),
                      ),
                    ),
                    if (e.cause case final cause?)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 1),
                        child: _ViaTag(cause, compact: true),
                      ),
                  ],
                ),
              ),
            if (results.length > 2)
              Text(
                'ほか${results.length - 2}件は見聞録に',
                style: const TextStyle(fontSize: 11, color: Pal.muted),
              ),
            const Divider(color: Pal.line, height: 12),
          ],
          // 場面の絵（Gemini で作ったドット絵）に題を重ねる。「この年の心がけ」には絵を添えない。
          if (p.art case final art?)
            _ArtBanner(art: art, title: p.title, cause: p.cause)
          else
            // 能力・特性のおかげで起きた場面には、題の横に札を添える（`Prompt.cause`）。
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    p.title,
                    style: const TextStyle(
                      color: Pal.gold,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                if (p.cause case final cause?)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _ViaTag(cause),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Text(p.text, style: const TextStyle(fontSize: 14.5, height: 1.6)),
          const SizedBox(height: 10),
          if (twoCol)
            for (var r = 0; r < n; r += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                // IntrinsicHeight は字の折り返しを読み違えて字が枠からはみ出したので、
                // 高さの下限をそろえるだけにする（長い字の釦は伸びる）。
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 66),
                        child: _ChoiceButton(g, p, r, compact: true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: r + 1 < n
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 66),
                              child: _ChoiceButton(g, p, r + 1, compact: true),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              )
          else
            for (var i = 0; i < n; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: _ChoiceButton(g, p, i),
                ),
              ),
        ],
      ),
    );
  }
}

/// 場面の絵の帯。下に暗いぼかしを敷き、題を白で重ねる。
class _ArtBanner extends StatelessWidget {
  const _ArtBanner({required this.art, required this.title, this.cause});
  final String art, title;

  /// 能力・特性のおかげで起きた場面の札（`Prompt.cause`）。札は地を塗ってあるので、絵の上でも読める。
  final String? cause;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 86,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              sceneArtPath(art),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: Pal.panel2),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                  stops: [.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFF4DC),
                        fontSize: 18,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Color(0xCC000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  if (cause case final cause?)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _ViaTag(cause),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton(this.g, this.p, this.i, {this.compact = false});
  final Game g;
  final Prompt p;
  final int i;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = p.choices[i];
    // 能力・特性・持ち物のおかげで出た手の印（`Choice.via`）。能力の一字・二字は手の名の右、
    // 特性や持ち物の名は長いので匂わせの下に置く。二列の詰めた釦は幅が狭く、名の右に置くと
    // 手の名が削られるので、どの印も匂わせの下に置く。
    final via = c.via;
    final viaShort = via != null && viaIsAbility(via) && !compact;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.topLeft,
        padding: compact
            ? const EdgeInsets.fromLTRB(8, 7, 8, 7)
            : const EdgeInsets.fromLTRB(12, 8, 8, 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Pal.bg,
        overlayColor: Pal.accent,
        side: BorderSide(
          color: c.danger ? Pal.bad.withValues(alpha: .55) : Pal.line,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        g.choose(i);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChoiceMark(i, danger: c.danger, size: compact ? 20 : 24),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // 手の名も匂わせも、途中で切らずに全文を出す（2026-11-24。二列で匂わせが「…」で切れ、
                      // 「命を落とす」などの危うさの言葉が見えなくなることがあった）。
                      child: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: compact ? 13.5 : 15,
                          height: 1.35,
                          color: c.danger ? Pal.bad : Pal.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (via != null && viaShort)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 1),
                        child: _ViaTag(via, compact: compact),
                      ),
                  ],
                ),
                if (c.hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.hint!,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: Pal.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (via != null && !viaShort)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ViaTag(via, compact: compact),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 能力・特性・持ち物のおかげで出た手に付ける小さな札（`Choice.via`）。
/// 能力・特性のおかげで起きた場面の題の横（`Prompt.cause`）と、【才】の一行の横（`LogEntry.cause`）にも使う。
/// 能力（武・知・政・魅・運）は朱の縁、特性と持ち物の名は金の縁。
class _ViaTag extends StatelessWidget {
  const _ViaTag(this.via, {this.compact = false});
  final String via;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = viaIsAbility(via) ? Pal.accent : Pal.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Pal.panel,
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        via,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          height: 1.2,
          color: color,
          fontWeight: FontWeight.w700,
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
              Gauge('縁', l.net.toDouble(), color: Pal.purple),
              const Divider(color: Pal.line, height: 20),
              Gauge('武', l.bu.toDouble()),
              Gauge('学び', l.chi.toDouble()),
              Gauge('政', l.sei.toDouble()),
              Gauge('魅', l.mi.toDouble()),
              Gauge('運', l.un.toDouble()),
              const SizedBox(height: 10),
              TraitList(
                [for (final t in l.traits) traitOf(t)],
                extra: [
                  if (l.gun) ('鉄砲', '撃ち方を覚えている。合戦で有利になる'),
                  // 銭と功で手に入れた持ち物（`spending.dart`）。
                  ...spendingBelongings(g),
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
        // 家族（連れ合いと子を一行ずつ。亡くなった子は薄く）。
        if (l.familyRows(g.year).isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            title: '家族',
            child: Column(
              children: [
                for (final r in l.familyRows(g.year))
                  _FamilyRow(r.$1, r.$2, faded: r.$3),
                // 子の育て方（家にいる五〜十四の子。決められるのは年の初めだけ。`kid_raising.dart`）。
                if (raisableKids(g).isNotEmpty) _RaisingBox(g),
              ],
            ),
          ),
        ],
        // 家臣（城主より上の人の顔ぶれ。`retainers.dart`）。
        if (l.retainers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            title: '家臣',
            child: Column(
              children: [
                for (final r in retainerRows(g))
                  _FamilyRow(r.$1, r.$2, faded: r.$3),
              ],
            ),
          ),
        ],
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
                '生き残り ${fs.length}家／${peaceTime(g) ? '戦の絶えた世' : '乱世は続く'}',
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

/// 家族の欄の一行（呼び名を左に、名・歳・行き先を右に。長ければ折り返す）。
class _FamilyRow extends StatelessWidget {
  const _FamilyRow(this.label, this.text, {this.faded = false});
  final String label, text;
  final bool faded;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Pal.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Pal.muted, fontSize: 13.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              color: faded ? Pal.muted.withValues(alpha: .7) : null,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 家族の欄の下の「子の育て方」。家にいる五〜十四の子ごとに、今の方針と、決める釦。
/// 決められるのは年の初め（この年の心がけを選ぶ前）だけで、年の途中は釦を押せず、そのことを出す。
class _RaisingBox extends StatelessWidget {
  const _RaisingBox(this.g);
  final Game g;

  @override
  Widget build(BuildContext context) {
    final can = g.canSetKidRaising;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '子の育て方',
            style: TextStyle(
              color: Pal.gold,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final k in raisableKids(g))
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${k.name}（${g.year - k.born!}歳）',
                    style: const TextStyle(fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: can ? () => _pick(context, k) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Pal.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    k.raising == null
                        ? (can ? '決める' : '決めていない')
                        : KidRaising.short[k.raising]!,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          if (!can)
            const Text(
              '育て方は、年の初め（この年の心がけを選ぶ前）にだけ決められる。',
              style: TextStyle(color: Pal.muted, fontSize: 12, height: 1.5),
            ),
        ],
      ),
    );
  }

  void _pick(BuildContext context, Kid k) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Pal.panel,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '${k.name}の育て方',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final r in KidRaising.all)
              ListTile(
                title: Text(KidRaising.label[r]!),
                subtitle: Text(
                  KidRaising.hint[r]!,
                  style: const TextStyle(color: Pal.muted, fontSize: 12.5),
                ),
                trailing: k.raising == r
                    ? const Icon(Icons.check, color: Pal.accent)
                    : null,
                onTap: () {
                  g.setKidRaising(k, r);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 立ち位置を押すと、位の解説を開く。
class _RankTap extends StatelessWidget {
  const _RankTap(this.g, {required this.child});
  final Game g;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => showRankGuide(context, g),
    child: child,
  );
}
