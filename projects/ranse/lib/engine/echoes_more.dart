import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 伏線の回収 その2（2026-11-23）。能力で起きる岐路（`tal_`）・大人の暮らしと嗜み（`ps_`）・
/// 子どもの重点（寺の手習い `tera_*`）で生まれた旗や縁のある人が、何年もあとに返ってくる岐路。
/// どれも一生に一度。旗を持つ人にだけ出るので、重みは `echoes.dart` と同じくらい高めにしてある。
/// id・新しい旗は `e2_` で始める。

int _c(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _down(Game g, int n) => g.l.net = g.l.net >= n ? g.l.net - n : 0;

bool _monk(Game g) => g.hasFlag('priesthood');
bool _outlaw(Game g) => g.hasFlag('way_outlaw');
bool _merchant(Game g) =>
    g.l.rank == 0 &&
    !_monk(g) &&
    (g.hasFlag('way_merchant') || g.l.cls.id == 'merchant');

/// 主家に仕える身（大名その人は除く）。
bool _retainer(Game g) =>
    g.l.rank >= 1 &&
    g.l.rank <= 7 &&
    g.active &&
    !_monk(g) &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 身分のない暮らし（仏門・野の道を除く）。
bool _commoner(Game g) => g.l.rank == 0 && g.active && !_monk(g) && !_outlaw(g);

bool _farmer(Game g) =>
    _commoner(g) &&
    !_merchant(g) &&
    const ['farmer', 'beggar', 'ashigaru'].contains(g.l.cls.id);

String _house(Game g) => houseName(g, g.l.lord);

/// いちばん勢いのある家（なければ null）。
String? _strongest(Game g) {
  final a = g.alive;
  if (a.isEmpty) return null;
  a.sort((x, y) => y.power.compareTo(x.power));
  return a.first.name;
}

/// 自分の国から近い、主家でない家（なければ null）。
String? _nearOther(Game g) {
  final others = g.alive.where((f) => f.name != g.l.lord).toList();
  if (others.isEmpty) return null;
  final near = g.l.lord != null
      ? nearest(others, (f) => f.name, faction: g.l.lord, n: 3)
      : nearest(others, (f) => f.name, region: g.l.region, n: 3);
  return g.rng.pick(near).name;
}

/// [lord] に仕える（身分のない人が足軽から始める）。
void _join(Game g, String lord) {
  final l = g.l;
  l.lord = lord;
  if (l.rank < 1) l.rank = 1;
  if (l.rank > l.maxRank) l.maxRank = l.rank;
  l.fav = 25;
  l.ronin = false;
}

String _newName(Game g, {bool? female}) =>
    '${g.rng.pick(kSurnames)}${g.rng.pick((female ?? g.l.female) ? kGivenF : kGivenM)}';

List<SceneDef> buildEchoMoreScenes() => [
  // ------------------------------------------------------------------
  // 寺の手習いで机を並べた仲間（tera_friends）→ 大人になって口を持ってくる。
  SceneDef(
    'e2_tera_friend',
    20,
    50,
    (g) => 6,
    (g) => g.hasFlag('tera_friends') && g.active && !_monk(g),
    (g, next) {
      final known = g.l.people['手習いの仲間'];
      final name = known?.name ?? _newName(g);
      final hello = '「覚えているか。寺で机を並べた$nameだ」。日に焼けた顔に、手習いの頃の面影があった。';
      final other = _nearOther(g);
      // 身分のない戦える男 → 仕官の口。
      if (g.l.rank == 0 &&
          g.canFight &&
          !g.l.female &&
          !_outlaw(g) &&
          !_merchant(g) &&
          other != null) {
        final h = houseName(g, other);
        g.ask('手習いの仲間', '$hello「いまは$h家に仕えている。足軽の口がひとつ空いた。お前なら推せる」', [
          Choice.h('口添えを頼んで仕える', '身を立てる道が開く。戦に出ることになる', () {
            _join(g, other);
            g.meet('手習いの仲間', name, 60);
            g.setFlag('e2_tera_friend_help');
            g.mark('寺で机を並べた$nameの口添えで、$h家に仕えた');
            return '$nameに連れられて、$h家の門をくぐった。';
          }),
          Choice.h('礼を言って断る', '今の暮らしは変わらない。友は少し寂しがる', () {
            g.meet('手習いの仲間', name, 45);
            g.j(2);
            return '二人で手習いの頃の話をして、夜が更けた。';
          }),
        ], after: next);
        return;
      }
      // 商いの身・身分のない人 → 一緒に商いを。
      if (g.l.rank == 0 && !_outlaw(g)) {
        g.ask('手習いの仲間', '$hello「町で小さな店を出したい。字と算盤の分かる相棒がほしい。お前とならやれる」', [
          Choice.h('銭を出し合って店を開く', '儲かれば暮らしが変わる。しくじれば蓄えを失う', () {
            if (g.l.gold < 10) {
              g.meet('手習いの仲間', name, 50);
              return '出せる銭がなかった。$nameは「また来る」と笑って帰った。';
            }
            g.l.gold -= 10;
            g.meet('手習いの仲間', name, 65);
            if (g.rng.chance(.55 + g.l.sei / 400)) {
              g.l.gold += 30;
              g.l.net += 3;
              g.setFlag('e2_tera_friend_help');
              g.mark('寺で机を並べた$nameと、銭を出し合って店を開いた');
              return '店は当たった。帳面をつけるのは、いつもあなたの役だった。';
            }
            g.j(-4);
            return '一年ともたずに店をたたんだ。$nameは何度も頭を下げた。';
          }),
          Choice.h('帳面の付け方だけ教える', '銭は出さない。友の役には立つ', () {
            g.meet('手習いの仲間', name, 55);
            g.l.net += 2;
            return '夜ごと、$nameに帳面の付け方を教えた。';
          }),
        ], after: next);
        return;
      }
      // 主家に仕える身など → 落ちぶれた友が銭を借りに来る。
      g.ask('手習いの仲間', '$hello「恥を忍んで頼む。仕えた家が潰れて、妻子を食わせられない。少し銭を貸してくれぬか」', [
        Choice.h('黙って銭を渡す', '銭は返ってこないかもしれない。友は恩を忘れない', () {
          _pay(g, 8);
          g.meet('手習いの仲間', name, 75);
          g.l.net += 2;
          g.j(3);
          g.setFlag('e2_tera_friend_help');
          return '$nameは銭を押しいただき、何度も振り返りながら帰っていった。';
        }),
        Choice.h(
          g.l.rank >= 8
              ? '家中に召し抱えてやる'
              : (g.l.rank >= 1 ? '主家に口を利いてやる' : '働き口を探してやる'),
          '銭はかからない。口を利いた者の不始末は、自分にはね返る',
          () {
            g.meet('手習いの仲間', name, 65);
            if (g.rng.chance(.75)) {
              g.l.net += 3;
              return '$nameは新しい務めに就いた。手習いの頃のように、律儀に働いているという。';
            }
            if (g.l.rank >= 1) g.l.fav = _c(g.l.fav - 4);
            g.j(-2);
            return '$nameは務めになじめず、ひと月で姿を消した。口を利いた手前、肩身が狭い。';
          },
        ),
        Choice.h('断る', '銭は守れる。友とはそれきりになる', () {
          g.j(-3);
          return '$nameは「そうか」とだけ言って、背を向けた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 手習いの和尚（tera_diligent・師）→ 老いて、臨終の床から呼ぶ。寺の跡を頼まれる。
  SceneDef(
    'e2_tera_master',
    25,
    60,
    (g) => 6,
    (g) =>
        g.hasFlag('tera_diligent') &&
        g.l.people['師']?.name == '手習いの和尚',
    (g, next) {
      final canSucceed =
          !g.l.female && !_monk(g) && g.l.rank < 8 && g.active;
      g.ask('和尚の床', '手習いの和尚が、重い病の床にあるという知らせが届いた。「筋がよい」と言ってくれた、あの和尚だ。${canSucceed ? '寺には、跡を継ぐ者がいない。' : ''}', [
        Choice.h('枕元へ駆けつける', '最期に会える。務めは何日か滞る', () {
          if (g.l.rank >= 1 && g.active) g.l.fav = _c(g.l.fav - 2);
          g.l.chi = clampInt(g.l.chi + 2, 0, 99);
          g.j(4);
          g.l.people.remove('師');
          g.setFlag('e2_master_farewell');
          g.mark('手習いの和尚の臨終に駆けつけ、形見の硯を受け取った');
          return '和尚は細い手で、使い込んだ硯を差し出した。「字は、人を助ける」。それが最後の言葉だった。';
        }),
        if (canSucceed)
          Choice.h('寺の跡を継ぐと約束する', '和尚は安らかに逝ける。俗世の暮らしとはここで別れる', () {
            final l = g.l;
            g.setFlag('priesthood');
            g.setFlag('temple');
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.flags.remove('way_outlaw');
            l.flags.remove('way_merchant');
            l.people.remove('師');
            g.j(6);
            g.setFlag('e2_master_temple');
            g.mark('手習いの和尚の跡を継ぎ、村の寺に入った');
            return '和尚は微笑んで目を閉じた。翌朝、髪を下ろした。';
          }),
        Choice.h('経をあげてもらうよう寺に寄進する', '会いには行けない。せめてもの供養になる', () {
          _pay(g, 5);
          g.j(-2);
          g.l.people.remove('師');
          return '寄進を届けさせた。和尚が亡くなったと聞いたのは、ひと月後だった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 連歌の友（ps_renga_praised）→ ある家の重臣の座に出入りしていて、取り次ぐ。
  SceneDef(
    'e2_renga_friend',
    25,
    80,
    (g) => 6,
    (g) =>
        g.hasFlag('ps_renga_praised') &&
        g.l.people.containsKey('連歌の友') &&
        g.active,
    (g, next) {
      final other = _nearOther(g);
      final h = other == null ? 'さる' : '${houseName(g, other)}家の';
      final intro = '昔、句を褒めてくれた旅の連歌師が訪ねてきた。いまは$h重臣の連歌の座に、たびたび招かれているという。';
      // 一国の主 → 連歌の会を和の場に。
      if (g.l.rank >= 8 && other != null) {
        g.ask('連歌師の取り持ち', '$intro「向こうの殿も、連歌がお好きです。一座を設けて、膝を交えてみては」', [
          Choice.h('一座を設け、和を結ぶ', '境は静かになる。弱腰と見る家臣もいる', () {
            g.l.net += 4;
            g.l.fame += 4;
            g.j(4);
            g.setFlag('e2_renga_peace');
            g.mark('連歌の会の席で、$h殿と和を結んだ');
            return '付け合いが進むうちに、互いの肩の力が抜けた。帰り際、向こうの殿が「また一座を」と言った。';
          }),
          Choice.h('会に乗じて相手の家中を探らせる', '内情が知れる。気づかれれば、連歌師が危うい', () {
            if (g.rng.chance(.6)) {
              g.l.chi = clampInt(g.l.chi + 2, 0, 99);
              g.l.merit += 5;
              return '座の雑談から、向こうの家中の不和が知れた。';
            }
            g.l.people.remove('連歌の友');
            g.j(-5);
            return '連歌師は、向こうの城下で捕らえられたという。それきり便りはない。';
          }),
          Choice.h('連歌は連歌として楽しむ', '政は持ち込まない。友は喜ぶ', () {
            g.j(5);
            return '連歌師と二人、夜更けまで句を付け合った。';
          }),
        ], after: next);
        return;
      }
      // 主家に仕える身 → 向こうの重臣の内意を取り次ぐ（調略）。
      if (_retainer(g) && other != null) {
        g.ask('連歌師の取り次ぎ', '$intro声をひそめて、「あの重臣どの、近ごろ主に不満がおありのようで。${_house(g)}家に通じたいと、内々に」', [
          Choice.h('殿に取り次ぐ', '大きな手柄になりうる。罠かもしれない', () {
            if (g.rng.chance(.65)) {
              g.l.merit += 20;
              g.l.fav = _c(g.l.fav + 8);
              g.l.fame += 4;
              g.setFlag('e2_renga_chorayaku');
              g.mark('連歌の友の取り次ぎで、$h重臣を味方に引き入れた');
              return '密書が行き交い、向こうの重臣は戦の前に寝返った。殿は「連歌も役に立つものよ」と笑った。';
            }
            g.l.fav = _c(g.l.fav - 6);
            g.l.hp -= 8;
            return '密会の場に、向こうの兵が待ち構えていた。辛うじて逃げ帰った。';
          }),
          Choice.h('聞かなかったことにする', '危うい話には乗らない。友の顔は立たない', () {
            g.j(-1);
            return '連歌師は残念そうに、話を引っ込めた。';
          }),
        ], after: next);
        return;
      }
      // それ以外（商い・仏門・身分のない人・浪人）。
      final merchant = _merchant(g);
      g.ask('連歌師の取り次ぎ', '$intro「重臣どのに、あなたのことを話しておきました。一度、お目通りを」', [
        Choice.h(
          'お目通りに上がる',
          merchant ? '大きな商いの口になる。武家の気まぐれに振り回されもする' : '道が開けるかもしれない。窮屈な思いもする',
          () {
            g.l.net += 3;
            if (merchant) {
              g.l.gold += 20;
              g.setFlag('e2_renga_goyo');
              g.mark('連歌の友の取り次ぎで、$h重臣の屋敷に出入りする商人になった');
              return '重臣の屋敷に、品を納めるようになった。';
            }
            if (_monk(g)) {
              g.l.fame += 4;
              return '重臣は寺に田を寄進してくれた。';
            }
            g.l.fame += 3;
            g.l.gold += 5;
            return '重臣は句の話を喜び、土産を持たせてくれた。';
          },
        ),
        Choice.h('身の丈に合わぬと辞退する', '気楽なままでいられる', () {
          g.j(2);
          return '連歌師は「あなたらしい」と笑った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 連歌の座の者を殿に告げた（ps_renga_report）→ 遠ざけられた者の恨み。
  SceneDef(
    'e2_renga_grudge',
    25,
    70,
    (g) => 5,
    (g) => g.hasFlag('ps_renga_report') && _retainer(g),
    (g, next) {
      g.ask('連歌の座の恨み', 'あなたが殿に告げて遠ざけられた連歌の座の者が、許されて家中に戻ってきた。近ごろ、あなたの悪い噂が殿の耳に入っているという。', [
        Choice.h('殿の前で身の潔白を述べる', '筋は通る。殿の機嫌しだいでは、かえって疑われる', () {
          if (g.rng.chance(.4 + g.l.fav / 200)) {
            g.l.fav = _c(g.l.fav + 4);
            return '殿は黙って聞き、「その方を疑ってはおらぬ」と言った。噂は止んだ。';
          }
          g.l.fav = _c(g.l.fav - 8);
          return '言い訳と取られた。殿の目が冷たい。';
        }),
        Choice.h('相手を訪ね、頭を下げる', '恨みは解けるかもしれない。家中に弱みを見せる', () {
          if (g.rng.chance(.55)) {
            g.l.net += 3;
            g.j(3);
            g.setFlag('e2_renga_reconciled');
            g.mark('連歌の座で告げ口をした相手に、頭を下げて和解した');
            return '相手は長いこと黙っていたが、やがて盃を出した。';
          }
          _down(g, 2);
          return '門前で追い返された。笑い話として家中に広まった。';
        }),
        Choice.h('放っておく', '何もしない。噂は勝手に育つ', () {
          g.l.fav = _c(g.l.fav - 5);
          return '噂は消えなかった。殿から声のかかることが減った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 湯治場の縁（ps_onsen_friend）→ 隠居が亡くなり、遺言で何かを託される。
  SceneDef(
    'e2_onsen_will',
    40,
    84,
    (g) => 6,
    (g) =>
        g.hasFlag('ps_onsen_friend') && g.l.people.containsKey('湯治場の縁'),
    (g, next) {
      final girl = g.rng.pick(kGivenF);
      g.ask('隠居の遺言', '遠国から使いが来た。湯治場で縁を結んだあの隠居が、亡くなったという。「遺言で、あなたさまにお託しすることがございます」', [
        Choice.h('形見の品を受け取る', '名のある品だという。持てば人の目が変わる', () {
          g.l.people.remove('湯治場の縁');
          g.l.gold += 20;
          g.l.fame += 3;
          g.setFlag('e2_onsen_keepsake');
          g.mark('湯治場で縁を結んだ隠居から、遺言で形見の品を託された');
          return '包みを解くと、古いが見事な脇差が出てきた。添えられた文に「湯の中の友へ」とあった。';
        }),
        Choice.h('身寄りのない孫娘を引き取る', '暮らしは苦しくなる。家ににぎわいが増える', () {
          g.l.people.remove('湯治場の縁');
          _pay(g, 5);
          g.j(6);
          g.l.net += 2;
          g.meet('預かった子', girl, 55);
          g.setFlag('e2_onsen_ward');
          g.mark('湯治場で縁を結んだ隠居の遺言で、孫娘の$girlを引き取った');
          return '$girlは、祖父の話をよく聞かされていたと言って、はにかんだ。';
        }),
        Choice.h('辞退して、墓に参るだけにする', '何も背負わない。隠居の家の者は戸惑う', () {
          g.l.people.remove('湯治場の縁');
          g.j(2);
          g.l.hp -= 3;
          return '遠い道を歩いて墓に参り、湯治場の話を墓前で語った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 名物の茶碗（ps_meibutsu）→ 大名が所望してくる。
  SceneDef(
    'e2_meibutsu',
    25,
    84,
    (g) => 6,
    (g) =>
        g.hasFlag('ps_meibutsu') &&
        g.l.rank < 8 &&
        !_monk(g) &&
        (_retainer(g) || _strongest(g) != null),
    (g, next) {
      final mine = _retainer(g);
      final lord = mine ? _house(g) : houseName(g, _strongest(g));
      g.ask('名物所望', '$lord家の${mine ? '殿' : '使い'}が、あなたの持つ名物の茶碗を所望している。${mine ? '「その方の茶碗、一度手に取ってみたいものよ」と、殿は何度も口にした。' : '「殿が、ぜひにと仰せです」'}', [
        Choice.h('差し出す', '出世の糸口になる。茶碗は二度と戻らない', () {
          if (mine) {
            g.l.fav = _c(g.l.fav + 15);
            g.l.merit += 15;
            if (g.l.rank >= 1 && g.l.rank <= 6) {
              g.l.rank += 1;
              if (g.l.rank > g.l.maxRank) g.l.maxRank = g.l.rank;
            }
          } else {
            g.l.gold += 40;
            g.l.net += 3;
          }
          g.l.fame += 4;
          g.setFlag('e2_gave_meibutsu');
          g.mark('名物の茶碗を、$lord家に差し出した');
          return mine
              ? '殿は茶碗を掌で回し、長いこと眺めていた。ほどなくして、取り立ての沙汰があった。'
              : '過分な礼の品が届いた。茶碗の噂は、$lord家の名とともに広まった。';
        }),
        Choice.h('家宝ゆえと断る', '茶碗は手元に残る。所望を退ければ、ただでは済まないこともある', () {
          if (mine) {
            if (g.rng.chance(.04)) {
              g.die('名物の茶碗を差し出すのを拒み、主君の怒りを買って腹を切らされた', 'seppuku');
              return '数日後、上使が屋敷に来た。';
            }
            g.l.fav = _c(g.l.fav - 15);
            g.j(-3);
            return '殿はそれきり、茶碗の話をしなくなった。あなたへの言葉も減った。';
          }
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          _down(g, 2);
          return '使いは顔色を変えて帰っていった。それから、$lord家の侍があなたの家の前をよく通る。';
        }),
        Choice.h('茶会を開いて、殿を客に招く', '茶碗は手放さずに済むかもしれない。座の運びしだい', () {
          if (g.rng.chance(.3 + g.l.mi / 250)) {
            g.l.fame += 3;
            if (mine) g.l.fav = _c(g.l.fav + 5);
            g.l.net += 2;
            return '一服の茶に、客はたいそう満足した。茶碗の話は、それきり出なかった。';
          }
          if (mine) g.l.fav = _c(g.l.fav - 6);
          g.j(-2);
          return '座はぎこちなく終わった。所望を言い出せなかった客の機嫌は、かえって悪くなった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 写した医書（ps_book_med）→ 疫病の村を救う。
  SceneDef(
    'e2_book_med',
    25,
    84,
    (g) => 6,
    (g) => g.hasFlag('ps_book_med'),
    (g, next) {
      g.ask('疫病の村', '隣の村で疫病が流行り、薬師も逃げ出したという。昔写した医書に、似た病の煎じ方があったのを思い出した。', [
        Choice.h('村に入って薬を煎じる', '多くを救えるかもしれない。病をもらうおそれがある', () {
          if (g.rng.chance(.04)) {
            g.die('写した医書を頼りに疫病の村で薬を煎じるうち、病をもらって亡くなった', 'byo');
            return '十日目の朝、自分の額が熱いことに気づいた。';
          }
          if (g.rng.chance(.25)) g.l.hp -= 12;
          g.l.fame += 6;
          g.l.net += 5;
          g.j(5);
          g.setFlag('e2_saved_village');
          g.mark('写した医書を頼りに、疫病の村で薬を煎じた');
          return '一人、また一人と熱が下がった。村の者は、あなたを拝むようにして見送った。';
        }),
        Choice.h('煎じ方を書き写して届ける', '自分の身は安全だ。字の読める者がいれば役に立つ', () {
          g.l.net += 2;
          g.j(2);
          return '煎じ方を書いた紙を、村の入口の柱に結んできた。';
        }),
        Choice.h('戸を閉ざして関わらない', '病は家に入らない。胸は痛む', () {
          g.j(-4);
          return '風向きが変わるたびに、隣村の方角から煙が上がった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 写した兵法書（ps_book_war）→ 戦の陣で、写した陣立てを思い出す。
  SceneDef(
    'e2_book_war',
    20,
    65,
    (g) => 5,
    (g) => g.hasFlag('ps_book_war') && _retainer(g) && g.canFight,
    (g, next) {
      g.ask('写した陣立て', '${_house(g)}家の陣で、敵が谷あいに兵を伏せているらしいと聞いた。昔、灯の下で写した兵法書の陣立ての図が、目の前の地形とそっくりだ。', [
        Choice.h('書にあった手立てを上役に献じる', '当たれば手柄になる。書物の受け売りと笑われるかもしれない', () {
          if (g.rng.chance(.45 + g.l.chi / 250)) {
            g.l.merit += 15;
            g.l.fav = _c(g.l.fav + 6);
            g.setFlag('e2_book_war_win');
            g.mark('写した兵法書の陣立てを献じ、伏兵を見破った');
            return '谷の両側を先に押さえさせた。伏兵は戦わずに退いた。';
          }
          g.l.fav = _c(g.l.fav - 3);
          return '「戦は書物ではない」と退けられた。';
        }),
        Choice.h('自ら少ない兵で谷の上を押さえに行く', '手柄は大きい。読みが外れれば、囲まれる', () {
          if (g.rng.chance(.05)) {
            g.die('兵法書の陣立てを頼みに谷の上を押さえに出て、敵に囲まれ討たれた', 'senshi');
            return '谷の上にいたのは、伏兵の本隊だった。';
          }
          g.l.merit += 25;
          g.l.fame += 6;
          g.l.hp -= 8;
          g.mark('写した兵法書を頼みに、少ない兵で伏兵の背後を突いた');
          return '伏兵の背後に回り込み、谷から追い落とした。';
        }),
        Choice.h('黙って下知に従う', '何も起きない。書物は書物のままだ', () {
          return '口をつぐんで、持ち場についた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 拓いた新田（ps_field_*）→ 領主の検地。
  SceneDef(
    'e2_field_survey',
    25,
    84,
    (g) => 6,
    (g) =>
        (g.hasFlag('ps_field_river') ||
            g.hasFlag('ps_field_hill') ||
            g.hasFlag('ps_field_border')) &&
        _farmer(g),
    (g, next) {
      g.ask('検地', '領主の役人が、竿を担いで村の田を測りに来た。あなたの拓いた田は、まだ帳面に載っていない。', [
        Choice.h('拓いた田を正直に申し出る', '年貢は重くなる。田は晴れてあなたのものになる', () {
          _pay(g, 4);
          g.j(2);
          g.setFlag('e2_field_declared');
          g.mark('自分で拓いた田を、検地の役人に正直に申し出た');
          return '田は帳面に載った。名請けの欄に、あなたの名が書かれた。';
        }),
        Choice.h('藪で隠して隠し田にする', '年貢は軽いまま。露見すれば、ただでは済まない', () {
          if (g.rng.chance(.25)) {
            if (g.rng.chance(.1)) {
              g.die('拓いた田を隠し田にしたことが露見し、見せしめに処された', 'seppuku');
              return '役人は、藪の向こうの田を見逃さなかった。';
            }
            _pay(g, 10);
            g.l.hp -= 10;
            return '隠し田は見つかった。打ち据えられ、田は取り上げられた。';
          }
          g.l.gold += 6;
          g.setFlag('e2_field_hidden');
          return '役人は藪の前を素通りした。夜、胸をなでおろした。';
        }),
        Choice.h('庄屋に頼んで、帳面に載せる田を小さくしてもらう', '礼の銭がいる。村の者に借りができる', () {
          _pay(g, 3);
          _down(g, 1);
          return '庄屋は渋い顔をしながらも、竿を短めに入れさせた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 境の野・川沿いを拓いた（ps_field_border / ps_field_river）→ 隣村との水争い。
  SceneDef(
    'e2_field_water',
    25,
    84,
    (g) => 5,
    (g) =>
        (g.hasFlag('ps_field_border') || g.hasFlag('ps_field_river')) &&
        _farmer(g),
    (g, next) {
      final border = g.hasFlag('ps_field_border');
      g.ask('水争い', border ? '日照りの夏。あなたが拓いた境の田に引く水を、隣村が堰で止めた。「もともと、こちらの野だ」と言う。' : '日照りの夏。あなたが拓いた川沿いの田に水を引くと、川下の隣村の田が干上がると、隣村の者が怒鳴り込んできた。', [
        if (g.canFight)
          Choice.h('村の若い者を連れて堰を切りに行く', '水は戻るかもしれない。隣村も鍬を持って待っている', () {
            if (g.rng.chance(.03)) {
              g.die('水争いで隣村の者ともみ合い、打ちどころが悪く亡くなった', 'sai');
              return '夜の堰で、誰かの鍬が振り下ろされた。';
            }
            if (g.rng.chance(.5)) {
              g.l.gold += 4;
              g.l.net += 1;
              return '堰は切られ、水が田に戻った。隣村とは、口もきかなくなった。';
            }
            g.l.hp -= 12;
            return '隣村の者に追い返され、頭に傷を負った。';
          }, via: g.fightVia),
        Choice.h('寄合で、水を日ごとに分ける取り決めをする', '実りは減る。争いは収まる', () {
          g.l.net += 3;
          g.j(2);
          g.setFlag('e2_water_shared');
          g.mark('拓いた田の水をめぐる争いを、隣村と分け合う取り決めで収めた');
          return '一日おきに堰を開ける取り決めができた。双方の年寄りが、盃を交わした。';
        }),
        Choice.h('代官に裁きを願い出る', '筋は通る。裁きがどちらに転ぶかは分からない', () {
          if (g.rng.chance(.5)) {
            g.l.gold += 3;
            return '代官は、拓いた者の言い分を認めた。';
          }
          _pay(g, 3);
          g.j(-4);
          return '代官は隣村の言い分を取り、礼の銭まで取られた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 子に手習いをさせた（ps_kid_*）→ 成長した子が家を助ける。
  SceneDef(
    'e2_kid_grown',
    36,
    84,
    (g) => 6,
    (g) =>
        (g.hasFlag('ps_kid_tera') ||
            g.hasFlag('ps_kid_home') ||
            g.hasFlag('ps_kid_work')) &&
        g.l.kids > 0 &&
        g.l.hasKidAged(g.year, 15),
    (g, next) {
      final n =
          g.l.people['子']?.name ??
          g.l.people['娘']?.name ??
          g.l.kidAged(g.year, 15)?.name ??
          '子';
      void bond(int v) {
        final k = g.l.people['子'] ?? g.l.people['娘'];
        if (k != null) k.bond = _c(k.bond + v);
      }

      final String text;
      if (g.hasFlag('ps_kid_tera')) {
        text = '寺の手習いで字を覚えた$nが、すっかり大人になった。家の帳面を見せると、「ここの勘定が合いませぬ」と、長年の誤りを見つけた。';
      } else if (g.hasFlag('ps_kid_home')) {
        text = '灯の下で字を教えた$nが、すっかり大人になった。あなたが寝込むと、昔の手習いの反故を取り出して、「今度はこちらが」と枕元で書を読んでくれた。';
      } else {
        text = '幼いうちから家業を仕込んだ$nが、すっかり大人になった。「そろそろ、仕事を任せてくださいませ」と言う。';
      }
      g.ask('子の成長', text, [
        Choice.h('家のことを任せていく', '肩の荷が下りる。子のやり方に口を出したくなる', () {
          bond(8);
          g.l.gold += 8;
          g.j(6);
          _heal(g, 10);
          g.setFlag('e2_kid_trusted');
          g.mark('手塩にかけた$nに、家のことを任せていった');
          return '$nの采配で、家はかえって回るようになった。';
        }),
        Choice.h('まだ早いと、自分で切り盛りする', '家は変わらない。子は少し不満そうだ', () {
          bond(-4);
          return '$nは黙ってうなずいた。';
        }),
        Choice.h('家を出て、広い世間で身を立てよと送り出す', '子の道が開ける。家は寂しくなる', () {
          bond(4);
          g.j(-2);
          g.l.net += 2;
          return '$nは何度も振り返りながら、旅立っていった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 軍師の招きで主家を捨てた（tal_left_lord）→ 元の主家が刺客を送る。
  SceneDef(
    'e2_left_lord',
    27,
    75,
    (g) => 6,
    (g) => g.hasFlag('tal_left_lord') && g.active && !_monk(g),
    (g, next) {
      g.ask('元の主家の恨み', '軍師の招きに応じて捨てた元の主家が、あなたを「恩知らず」と恨み、刺客を放ったという噂が届いた。', [
        if (g.canFight)
          Choice.h('寝所を替え、刺客を待ち受ける', '返り討ちにできれば、もう狙われない。相手は手練れだ', () {
            if (g.rng.chance(.06)) {
              g.die('捨てた元の主家の放った刺客に、寝所で討たれた', 'ansatsu');
              return '刺客は、替えた寝所の天井裏にいた。';
            }
            g.l.hp -= 8;
            g.l.fame += 4;
            g.setFlag('e2_killed_assassin');
            g.mark('捨てた元の主家の放った刺客を、返り討ちにした');
            return '夜半、障子の影が動いた。斬り結んで、刺客を倒した。';
          }, via: g.fightVia),
        Choice.h('今の主君に守りを頼む', '身は守られる。頼り切りと見られる', () {
          if (g.l.lord != null) g.l.fav = _c(g.l.fav - 3);
          g.j(-2);
          return '屋敷の周りに、夜ごと番の兵が立つようになった。';
        }),
        Choice.h('元の主家に詫びの書状を送る', '恨みが解けるかもしれない。今の主家には面白くない', () {
          if (g.rng.chance(.5)) {
            g.j(4);
            g.setFlag('e2_old_lord_forgave');
            return '元の主君から、短い返書が届いた。「達者で励め」とだけあった。';
          }
          if (g.l.lord != null) g.l.fav = _c(g.l.fav - 5);
          g.l.hp -= 10;
          return '書状は破り捨てられたという。帰り道で、何者かに斬りつけられた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 天下一の評判（tal_tenka_ichi）→ 弟子入り志願。
  SceneDef(
    'e2_disciple',
    22,
    75,
    (g) => 6,
    (g) => g.hasFlag('tal_tenka_ichi') && g.canFight && g.active,
    (g, next) {
      final boy = g.rng.pick(kGivenM);
      g.ask('弟子入り志願', '門の前に、痩せた若者が三日も座り込んでいる。「天下一のお方と聞いて、遠国から来ました。$boyと申します。弟子にしてくだされ」', [
        Choice.h('弟子にとる', '教える喜びがある。若者の行く末を背負う', () {
          g.meet('武芸の弟子', boy, 55);
          g.l.net += 3;
          g.j(5);
          g.setFlag('e2_took_disciple');
          g.mark('天下一の評判を聞いて来た若者$boyを、弟子にとった');
          return '$boyは誰よりも早く起き、誰よりも遅くまで木刀を振った。';
        }),
        Choice.h('木刀で打ち据えて、それでも残るか試す', '本物かどうかが分かる。やりすぎれば、若者は去る', () {
          if (g.rng.chance(.5)) {
            g.meet('武芸の弟子', boy, 65);
            g.l.net += 2;
            g.setFlag('e2_took_disciple');
            return '何度打ち倒されても、$boyは立ち上がった。翌朝から、稽古をつけることにした。';
          }
          g.j(-2);
          return '$boyは泣きながら去っていった。少し、打ちすぎたかもしれない。';
        }),
        Choice.h('弟子はとらぬと追い返す', '身軽なままでいられる。評判に陰がさすかもしれない', () {
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          return '握り飯を持たせて、帰らせた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 一揆の頭に担がれた（tal_ikki_head）→ ふたたび村の者が来る。
  SceneDef(
    'e2_ikki_again',
    25,
    70,
    (g) => 6,
    (g) => g.hasFlag('tal_ikki_head') && g.active && !_monk(g),
    (g, next) {
      final samurai = g.l.rank >= 1 && g.l.lord != null;
      if (samurai) {
        g.ask('村の者の頼み', '一揆の頭だった頃の村の者たちが、夜更けにそっと訪ねてきた。「また年貢が重くなった。いまは${_house(g)}家にお仕えのあなたさまから、どうか」', [
          Choice.h('殿に年貢を軽くするよう申し上げる', '村は救われるかもしれない。殿の覚えは悪くなる', () {
            if (g.rng.chance(.4 + g.l.fav / 250)) {
              g.l.net += 4;
              g.l.fame += 3;
              g.setFlag('e2_ikki_eased');
              g.mark('一揆の頭だった村の頼みを受け、主君に年貢を軽くさせた');
              return '殿は渋い顔をしたが、その年の年貢はわずかに下げられた。';
            }
            g.l.fav = _c(g.l.fav - 8);
            return '「百姓の肩を持つか」と、殿は不機嫌に席を立った。';
          }),
          Choice.h('いまの身では力になれぬと断る', '主家への務めは守れる。村の者は去っていく', () {
            _down(g, 3);
            g.j(-3);
            return '村の者たちは、黙って頭を下げて帰っていった。';
          }),
          Choice.h('ひそかに、また一揆の段取りを授ける', '村の力になれる。主家に知れれば命はない', () {
            if (g.rng.chance(.1)) {
              g.die('主家に仕えながら一揆の段取りを授けたことが露見し、腹を切らされた', 'seppuku');
              return '村の者の一人が、捕らえられて口を割った。';
            }
            g.l.net += 5;
            g.j(2);
            return '一揆は起き、年貢は下がった。誰が段取りを授けたのか、家中に知る者はない。';
          }),
        ], after: next);
        return;
      }
      g.ask('ふたたびの一揆', '凶作の年。かつて一揆の頭に立ったあなたのもとへ、村々の者がまた集まってきた。「もう一度、頭に立ってくだされ」', [
        Choice.h('もう一度、頭に立つ', '年貢が下がるかもしれない。二度目は見逃されない', () {
          if (g.rng.chance(.2)) {
            g.die('二度目の一揆の頭として捕らえられ、処刑された', 'seppuku');
            return '代官は、前の一揆の頭の名を忘れていなかった。';
          }
          g.l.fame += 6;
          g.l.net += 5;
          g.setFlag('e2_ikki_twice');
          g.mark('ふたたび一揆の頭に立ち、凶作の年の年貢を下げさせた');
          return '村々の旗が、ふたたび城下に揃った。年貢は下げられた。';
        }),
        Choice.h('若い者を頭に立て、後ろで知恵を貸す', '自分の身は守れる。若い者が危うい', () {
          g.l.net += 2;
          if (g.rng.chance(.4)) {
            g.j(-6);
            return '頭に立った若い者が、捕らえられた。あなたの名は、最後まで出さなかったという。';
          }
          return '若い者は、あなたの教えどおりに代官と渡り合った。';
        }),
        Choice.h('もう年だと断る', '身は守れる。村での顔は少しつぶれる', () {
          _down(g, 2);
          return '村の者たちは、肩を落として帰っていった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 村の若い衆に武芸を教えた（tal_taught_youth）→ 野盗が村を襲う年に、若い衆が集まる。
  SceneDef(
    'e2_taught_youth',
    22,
    75,
    (g) => 6,
    (g) => g.hasFlag('tal_taught_youth') && _commoner(g),
    (g, next) {
      g.ask('棒を持つ若い衆', '野盗の一団が、村を襲うつもりだという知らせが入った。かつてあなたが棒を教えた若い衆が、得物を手に集まってきた。「師匠、下知を」', [
        if (g.canFight)
          Choice.h('先頭に立って野盗を迎え撃つ', '村は守れるかもしれない。斬り合いになる', () {
            if (g.rng.chance(.04)) {
              g.die('村を襲った野盗を、教えた若い衆とともに迎え撃って討たれた', 'senshi');
              return '野盗の頭の刃が、こちらの棒より長かった。';
            }
            g.l.fame += 6;
            g.l.net += 4;
            g.l.hp -= 8;
            g.setFlag('e2_village_defended');
            g.mark('昔武芸を教えた若い衆を率い、村を襲った野盗を追い払った');
            return '若い衆は教えたとおりに棒を揃え、野盗を村の外へ押し返した。';
          }, via: g.fightVia),
        Choice.h('若い衆に柵と見張りを任せ、女子供を山へ逃がす', '人は守れる。家と蔵は野盗しだい', () {
          if (g.rng.chance(.5)) {
            g.l.net += 3;
            return '柵と篝火を見た野盗は、村を素通りしていった。';
          }
          _pay(g, 6);
          return '人は無事だったが、蔵の米を持っていかれた。';
        }),
        Choice.h('米を差し出して引き取ってもらう', '血は流れない。若い衆は悔しがる', () {
          _pay(g, 5);
          _down(g, 1);
          return '若い衆は、握った棒を下ろして唇を噛んだ。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 鷹狩りで降りた麦畑の主に詫びの銭を置いた（ps_hawk_kind）→ その百姓が危うい企てを知らせに来る。
  SceneDef(
    'e2_hawk_farmer',
    25,
    84,
    (g) => 6,
    (g) =>
        g.hasFlag('ps_hawk_kind') &&
        g.active &&
        (g.l.rank >= 8 || _retainer(g)),
    (g, next) {
      final lord = g.l.rank >= 8;
      g.ask('麦畑の百姓', '夜更けに、見覚えのある百姓が屋敷の裏口を叩いた。鷹狩りの日、詫びの銭を置いていった麦畑の主だ。「お恩返しに。${lord ? '隣の郷の者たちが、ご領内へ押し入る相談をしておりました' : '敵の兵が、殿の陣の裏手の山に潜んでおります'}」', [
        Choice.h('百姓の言葉を信じて備える', '外れれば笑われる。当たれば大きい', () {
          if (lord) {
            g.l.sei = clampInt(g.l.sei + 2, 0, 99);
            g.l.fame += 4;
          } else {
            g.l.merit += 15;
            g.l.fav = _c(g.l.fav + 6);
          }
          g.l.net += 2;
          g.setFlag('e2_hawk_repaid');
          g.mark('鷹狩りの日に詫びた麦畑の百姓の知らせで、不意打ちを防いだ');
          return '百姓の言ったとおりだった。備えを見た相手は、手を出さずに退いた。';
        }),
        Choice.h('礼の銭だけ渡して帰す', '百姓の顔は立つ。知らせは聞き流す', () {
          _pay(g, 2);
          if (g.rng.chance(.3)) {
            g.l.hp -= 15;
            if (!lord) g.l.fav = _c(g.l.fav - 4);
            return '数日後、本当に不意を突かれた。手傷を負い、あの夜のことを悔やんだ。';
          }
          return '何も起きなかった。百姓の思い過ごしだったのかもしれない。';
        }),
      ], after: next);
    },
  ),
];
