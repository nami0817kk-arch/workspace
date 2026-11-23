import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 女性の生き方（2026-11-23、ユーザー「作り込みをストップというまで続けて」）。
///
/// 人生の約2割は女の道に進むのに、女性だけの今年の重点や出来事が薄かったので、
/// 暮らし方の型ごとに重点と岐路を足した。id・旗は `wl_`（`women.dart` の `w_` と紛れないように）。
///
/// - 型（[womanKind]）: 奥で仕える／武家の妻／商家の女／村の女／尼。女武者（`onna`）は型に重ねて重点が一つ増える。
/// - 重点 8（[womanLifeFocusOptions]）: いつもの重点と暮らしと嗜みの重点のうしろに、1年に [kWomenLifePerYear] まで足す。
///   はじめて選んだ年は「始めの一回」の岐路（一生に一度）、2回目からは選んだ年の半分ほどで小さな岐路
///   （`<id>_again`、`repeat`）。どちらも `onlyForced`。
/// - 岐路 14（型ごと。一生に一度、重み2〜2.5）。
///
/// 女性の位を上げるのは「奥の出世」の岐路だけで、下女・女中頭から一つ上げる（奥女中まで）。
/// 後見（位8）・女大名（位9）の届きやすさは変えない。

/// 1年に「今年の重点」に足す、女性の暮らしの重点の数の上限。
/// 暮らしと嗜みの重点（`kPastimesPerYear`）とは別に数える。いつもの重点と合わせて選ぶのが重くならないよう、一つだけ。
const kWomenLifePerYear = 1;

/// 女性の暮らし方の型。
enum WomanKind { oku, wife, merchant, village, nun }

const _bukeCls = ['ashigaru', 'lowsamurai', 'samurai', 'kokujin', 'ronin'];

/// いまの暮らし方の型（女性でない・隠居・当主や女大名・野の道は null）。
WomanKind? womanKind(Game g) {
  final l = g.l;
  if (!l.female || g.hasFlag('retired')) return null;
  if (g.hasFlag('priesthood')) return WomanKind.nun;
  if (l.rank >= 8) return null;
  if (l.rank == 0 && g.hasFlag('way_outlaw')) return null;
  if (l.rank == 0 && (g.hasFlag('way_merchant') || l.cls.id == 'merchant')) {
    return WomanKind.merchant;
  }
  if (l.rank >= 1 && l.lord != null && !l.married) return WomanKind.oku;
  if (l.married && (l.rank >= 1 || _bukeCls.contains(l.cls.id))) {
    return WomanKind.wife;
  }
  if (l.rank == 0 && (l.cls.id == 'farmer' || l.cls.id == 'fisher')) {
    return WomanKind.village;
  }
  return null;
}

/// 女武者として、薙刀を教えられる身か（尼・当主・野の道を除く）。
bool _onnaTeacher(Game g) =>
    g.l.female &&
    g.has('onna') &&
    g.active &&
    !g.hasFlag('priesthood') &&
    g.l.rank < 8 &&
    !(g.l.rank == 0 && g.hasFlag('way_outlaw'));

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
int _n(Game g, String tag) => g.l.focus[tag] ?? 0;
String _girl(Game g) => g.rng.pick(kGivenF);
String _man(Game g) => g.rng.pick(kGivenM);

String _season(Game g) => g.l.t % 2 == 0
    ? g.rng.pick(['田植えの終わった頃', '若葉の頃', '梅雨の晴れ間'])
    : g.rng.pick(['稲刈りの済んだ頃', '木枯らしの吹く頃', '雪の便りの届く頃']);

/// 回を重ねた年の書き出し（2回目は [second]、以降は [more] から一つ。{季} は時節）。
String _intro(Game g, String tag, String second, List<String> more) =>
    (_n(g, tag) <= 2 ? second : g.rng.pick(more)).replaceAll('{季}', _season(g));

/// 始めの一回がまだなら始めの岐路。済んでいれば、半分ほどの年に小さな岐路。
String? _forcedFor(Game g, String id) {
  if (!g.hasFlag('scene:$id')) return id;
  return g.rng.chance(.5) ? '${id}_again' : null;
}

String _lordHouse(Game g) => g.l.lord == null ? '主' : houseName(g, g.l.lord);

/// 連れ合い（いなければ「夫」）。
String _husband(Game g) => g.l.people['伴侶']?.name ?? '夫';

void _spouseBond(Game g, int n) {
  final sp = g.l.people['伴侶'];
  if (sp != null && g.l.married) sp.bond = _c100(sp.bond + n);
}

// ======================================================================
// 重点
// ======================================================================

class _WFocus {
  const _WFocus(this.tag, this.ok, this.make);
  final String tag;
  final bool Function(Game g) ok;
  final FocusDef Function(Game g) make;
}

final _focuses = <_WFocus>[
  // ---- 奥: 奥方の文の取り次ぎ（知・魅・信頼）----
  _WFocus(
    'wl_letters',
    (g) => womanKind(g) == WomanKind.oku,
    (g) => FocusDef(
      'wl_letters',
      '奥方さまの文の取り次ぎを務める',
      '奥の内情に通じ、覚えもめでたくなる。知りすぎるのは危うい',
      (g) {
        if (g.rng.chance(.5)) g.l.chi = _c(g.l.chi + 1);
        if (g.rng.chance(.3)) g.l.mi = _c(g.l.mi + 1);
        g.l.fav = _c100(g.l.fav + g.rng.range(2, 4));
        g.l.merit += g.rng.range(1, 3);
      },
      forced: _forcedFor(g, 'wl_letters'),
    ),
  ),

  // ---- 奥: 若い侍女を仕込む（人脈・名声）----
  _WFocus(
    'wl_maids',
    (g) => womanKind(g) == WomanKind.oku && g.l.rank >= 2,
    (g) => FocusDef('wl_maids', '若い侍女たちを仕込む', '慕われ、奥での名も上がる。手のかかる子もいる', (g) {
      g.l.net += g.rng.range(1, 2);
      if (g.rng.chance(.4)) g.l.fame += 1;
      g.l.merit += g.rng.range(1, 2);
      g.j(2);
    }, forced: _forcedFor(g, 'wl_maids')),
  ),

  // ---- 武家の妻: 屋敷の内を切り盛りする（政・銭・人脈）----
  _WFocus(
    'wl_house',
    (g) => womanKind(g) == WomanKind.wife,
    (g) => FocusDef('wl_house', '屋敷の内を切り盛りする', '蔵が締まり、郎党も落ち着く。気の抜ける暇はない', (g) {
      if (g.rng.chance(.5)) g.l.sei = _c(g.l.sei + 1);
      g.l.gold += g.rng.range(2, 5);
      g.l.net += 1;
      g.l.hp -= 2;
    }, forced: _forcedFor(g, 'wl_house')),
  ),

  // ---- 商家の女: 店を切り盛りする（政・銭）----
  _WFocus(
    'wl_shop',
    (g) => womanKind(g) == WomanKind.merchant,
    (g) => FocusDef('wl_shop', '店を切り盛りする', '帳場が引き締まり、銭も回る。客あしらいに気が張る', (g) {
      g.l.gold += g.rng.range(3, 9) + g.l.sei ~/ 12;
      if (g.rng.chance(.4)) g.l.sei = _c(g.l.sei + 1);
      g.l.hp -= 2;
    }, forced: _forcedFor(g, 'wl_shop')),
  ),

  // ---- 村の女: 機を織って市へ出す（銭）----
  _WFocus(
    'wl_loom',
    (g) => womanKind(g) == WomanKind.village,
    (g) => FocusDef('wl_loom', '機を織って市へ出す', '銭になる。夜なべで目と肩を痛める', (g) {
      g.l.gold += g.rng.range(2, 6);
      g.l.hp -= 3;
    }, forced: _forcedFor(g, 'wl_loom')),
  ),

  // ---- 村の女: 田植え唄を合わせる（幸福・人脈）----
  _WFocus(
    'wl_song',
    (g) => womanKind(g) == WomanKind.village,
    (g) =>
        FocusDef('wl_song', '村の女たちと田植え唄を合わせる', '心が晴れ、女たちとの縁も深まる。稼ぎにはならない', (g) {
          g.j(6);
          g.l.net += g.rng.range(1, 2);
        }, forced: _forcedFor(g, 'wl_song')),
  ),

  // ---- 尼: 女人の参る寺を守る（人脈・名声）----
  _WFocus(
    'wl_refuge',
    (g) => womanKind(g) == WomanKind.nun,
    (g) =>
        FocusDef('wl_refuge', '女人の参る寺を守る', '行き場のない女たちの拠り所になる。厄介ごとも持ち込まれる', (g) {
          g.l.net += 1;
          if (g.rng.chance(.4)) g.l.fame += 1;
          g.j(3);
        }, forced: _forcedFor(g, 'wl_refuge')),
  ),

  // ---- 女武者: 薙刀を若い女に教える（武・人脈）----
  _WFocus(
    'wl_naginata',
    _onnaTeacher,
    (g) => FocusDef('wl_naginata', '薙刀を若い女たちに教える', '腕も、慕う者も育つ。稽古は体にこたえる', (g) {
      if (g.rng.chance(.4)) g.l.bu = _c(g.l.bu + 1);
      g.l.net += 1;
      if (g.rng.chance(.3)) g.l.fame += 1;
      g.l.hp -= 3;
    }, forced: _forcedFor(g, 'wl_naginata')),
  ),
];

/// 型に合う、女性の暮らしの重点の tag（乱数を使わない。テスト用にも出す）。
List<String> womanLifeTags(Game g) => [
  for (final f in _focuses)
    if (f.ok(g)) f.tag,
];

/// その年に出す、女性の暮らしの重点（[kWomenLifePerYear] まで）。
/// 当てはまるものが多いときは無作為に選ぶ（並びの順は保つ）。岐路を決める乱数は選ばれたものにだけ使う。
List<FocusDef> womanLifeFocusOptions(Game g) {
  final cand = [
    for (final f in _focuses)
      if (f.ok(g)) f,
  ];
  if (cand.length > kWomenLifePerYear) {
    final keep = <int>{};
    while (keep.length < kWomenLifePerYear) {
      keep.add(g.rng.range(0, cand.length - 1));
    }
    return [
      for (var i = 0; i < cand.length; i++)
        if (keep.contains(i)) cand[i].make(g),
    ];
  }
  return [for (final f in cand) f.make(g)];
}

// ======================================================================
// 重点で選んだ年の岐路
// ======================================================================

SceneDef _first(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(id, 15, 100, (g) => 1, (g) => true, run, onlyForced: true);

SceneDef _again(String id, void Function(Game g, void Function() next) run) =>
    SceneDef(
      '${id}_again',
      15,
      100,
      (g) => 1,
      (g) => true,
      run,
      onlyForced: true,
      repeat: true,
    );

List<SceneDef> _focusScenes() => [
  // ==================================================================
  // 文の取り次ぎ（奥）
  // ==================================================================
  _first('wl_letters', (g, next) {
    final l = g.l;
    g.ask('文の取り次ぎ', '奥方さまの文を、表の重臣へ届ける役を任された。ある日預かった文の封が、一度切られて、糊で貼り直してある。', [
      Choice.h('奥方さまにそっとお知らせする', '奥方さまの信は厚くなる。誰が封を切ったかの詮索が始まる', () {
        l.fav = _c100(l.fav + 8);
        l.merit += 5;
        g.setFlag('wl_letter_warned');
        g.mark('取り次ぐ文の封が切られていると、奥方にそっと知らせた');
        return '奥方さまは顔色を変えず、「よく知らせてくれた」とだけ言った。';
      }),
      Choice.h('黙って届ける', '波風は立たない。何かが動いているのを見過ごすことになる', () {
        g.j(-1);
        return '何も言わずに届けた。胸のつかえが、しばらく残った。';
      }),
      Choice.h('自分で文の中を確かめる', '何が起きているか分かる。知れれば、ただでは済まない', () {
        if (g.rng.chance(.2)) {
          l.fav = _c100(l.fav - 15);
          g.j(-5);
          return '文を開いたところを、年かさの女中に見咎められた。';
        }
        l.chi = _c(l.chi + 2);
        g.setFlag('wl_letter_read');
        return '文には、表の誰かと奥の誰かのあいだの、ひそかな取り決めが書かれていた。';
      }),
    ], after: next);
  }),
  _again('wl_letters', (g, next) {
    final l = g.l;
    final head = _intro(g, 'wl_letters', 'また文の取り次ぎを務めた。', [
      '{季}、奥と表を行き来する日が続いた。',
      '取り次ぐ文の束が、今年はいつもより厚い。',
      '奥方さまの筆の癖を、もう見ずとも言い当てられる。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('取り次ぎ', '$head家中の侍が、奥方さまへの願い文を、ほかの文に紛れ込ませてくれと包みを差し出した。', [
        Choice.h('包みを受け取り、紛れ込ませる', '懐は温まる。露見すれば、取り次ぎの役を失う', () {
          if (g.rng.chance(.25)) {
            l.fav = _c100(l.fav - 12);
            return '奥方さまは願い文に気づき、あなたを冷ややかに見た。';
          }
          l.gold += 6;
          return '願い文は、何事もなく奥方さまの手に渡った。';
        }),
        Choice.h('筋が違うと突き返す', '役目は汚れない。侍の恨みを買うかもしれない', () {
          l.fav = _c100(l.fav + 3);
          return '包みを押し返した。侍は舌打ちして去った。';
        }),
      ], after: next);
      return;
    }
    g.ask('取り次ぎ', '$head奥方さまが、遠国の縁者へ出す文の代筆を命じた。', [
      Choice.h('心を込めて言葉を選ぶ', '奥方さまの気に入れば、覚えはめでたい。手間はかかる', () {
        if (g.rng.chance(.4 + l.chi / 200)) {
          l.fav = _c100(l.fav + 6);
          l.chi = _c(l.chi + 1);
          return '奥方さまは文を読み返し、「わらわの心そのままじゃ」と言った。';
        }
        return '奥方さまは二、三の言葉を直させて、文を封じた。';
      }),
      Choice.h('型どおりに書く', '無難に済む。目には留まらない', () {
        return '決まった言い回しで、さらりと書き上げた。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 侍女の仕込み（奥）
  // ==================================================================
  _first('wl_maids', (g, next) {
    final l = g.l;
    final maid = _girl(g);
    g.ask('侍女の仕込み', '新しく上がった侍女の$maidが、奥方さまの茶碗を割ってしまった。真っ青になって震えている。', [
      Choice.h('自分の不行き届きと申し出る', '侍女は救われ、慕われる。自分の覚えは下がる', () {
        l.fav = _c100(l.fav - 5);
        l.net += 3;
        g.meet('侍女', maid, 65);
        g.setFlag('wl_maid_covered');
        g.mark('茶碗を割った侍女の$maidをかばい、自分の不行き届きと申し出た');
        return '$maidは、あなたの袖をつかんで泣いた。';
      }),
      Choice.h('ありのまま申し上げる', '筋は通る。侍女は暇を出されるかもしれない', () {
        l.fav = _c100(l.fav + 2);
        g.j(-2);
        return '$maidは、その月のうちに奥を去った。';
      }),
      Choice.h('割れた茶碗を、漆で継がせる', '銭はかかる。うまく継げれば、咎めは軽くなる', () {
        if (l.gold < 5) {
          g.j(-2);
          return '継ぎの職人に払う銭が足りず、結局ありのまま申し上げた。';
        }
        l.gold -= 5;
        l.fav = _c100(l.fav + 3);
        l.net += 1;
        g.meet('侍女', maid, 50);
        return '継ぎ目に金を差した茶碗を、奥方さまは面白がって使い続けた。';
      }),
    ], after: next);
  }),
  _again('wl_maids', (g, next) {
    final l = g.l;
    final maid = l.people['侍女']?.name ?? _girl(g);
    final head = _intro(g, 'wl_maids', 'また若い侍女たちを仕込んだ。', [
      '{季}、新しい侍女が二人、奥に上がってきた。',
      '侍女たちの立ち居振る舞いが、ようやく板についてきた。',
      'あなたに仕込まれた侍女が、今では若い者を仕込んでいる。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('侍女たち', '$head侍女の$maidに縁談が来た。奥を去るか、迷っているという。', [
        Choice.h('背中を押してやる', '侍女は幸せになるかもしれない。奥の手は一つ減る', () {
          g.j(4);
          l.net += 1;
          return '$maidは、深々と頭を下げて奥を去った。';
        }),
        Choice.h('もう少し奥にいるよう説く', '頼りになる手は残る。侍女の縁は遠のく', () {
          l.merit += 3;
          return '$maidは、もう一年だけ奥に残ることにした。';
        }),
      ], after: next);
      return;
    }
    g.ask('侍女たち', '$head侍女の二人が、衣の貸し借りでいがみ合っている。', [
      Choice.h('二人とも叱る', '奥の規律は保たれる。二人とも少し離れていく', () {
        l.merit += 2;
        return '二人とも、しゅんとして持ち場へ戻った。';
      }),
      Choice.h('別々に話を聞く', '根が分かれば収まる。手間はかかる', () {
        if (g.rng.chance(.5 + l.mi / 300)) {
          l.net += 2;
          return '話を聞くうちに、二人とも笑い出した。';
        }
        return '話は平行線のまま、いつの間にか収まった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 屋敷の切り盛り（武家の妻）
  // ==================================================================
  _first('wl_house', (g, next) {
    final l = g.l;
    final who = _husband(g);
    g.ask('屋敷の切り盛り', '$whoの扶持だけでは、郎党の口を養いかねる。蔵の米が、春までもちそうにない。', [
      Choice.h('晴れ着の小袖を売って、米に替える', '郎党は飢えずに済む。晴れの日に着る物がなくなる', () {
        l.gold += 6;
        l.net += 2;
        g.j(-3);
        g.setFlag('wl_sold_kosode');
        g.mark('晴れ着の小袖を売り、郎党の米に替えた');
        return '小袖は、思ったより良い値で売れた。郎党の誰も、そのことを知らない。';
      }),
      Choice.h('郎党の数を減らす', '蔵はもつ。暇を出された者は恨むかもしれない', () {
        l.gold += 4;
        l.net -= 2;
        return '古い郎党の一人が、黙って屋敷を去った。';
      }),
      Choice.h('主家の奉行に掛け合う', '通れば扶持が増える。家の内証をさらすことにもなる', () {
        if (g.rng.chance(.35 + l.mi / 250 + l.sei / 400)) {
          l.gold += 10;
          g.setFlag('wl_house_plea');
          return '奉行は渋い顔をしたが、米を少し回してくれた。';
        }
        g.j(-4);
        return '「武家の内証を、女が口にするものではない」と追い返された。';
      }),
    ], after: next);
  }),
  _again('wl_house', (g, next) {
    final l = g.l;
    final who = _husband(g);
    final head = _intro(g, 'wl_house', 'また屋敷の内を切り盛りした。', [
      '{季}、屋敷の蔵を一つずつ改めた。',
      '郎党の子らが、あなたを「奥さま」と呼んで駆け寄ってくる。',
      '帳面と鍵の束が、手に馴染んできた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('家の内', '$head郎党の女房の一人が、産後の肥立ちが悪く床から起き上がれない。', [
        Choice.h('薬と米を届ける', '女房は持ち直すかもしれない。蔵の銭が減る', () {
          _pay(g, 3);
          l.net += 2;
          g.j(3);
          return '女房は、十日ほどで起き上がれるようになった。';
        }),
        Choice.h('郎党に任せる', '蔵は減らない。郎党の目が少し冷たくなる', () {
          l.net -= 1;
          return '女房のことは、郎党の家に任せた。';
        }),
      ], after: next);
      return;
    }
    g.ask('家の内', '$head$whoが、前触れもなく客を連れて帰ってきた。膳が足りない。', [
      Choice.h('あるもので工夫してもてなす', 'うまくいけば夫の面目が立つ。台所は大騒ぎだ', () {
        if (g.rng.chance(.5 + l.sei / 250)) {
          _spouseBond(g, 6);
          l.net += 1;
          return '干した茸と味噌で、客が唸るほどの膳を整えた。';
        }
        return '膳は整ったが、客の箸はあまり進まなかった。';
      }),
      Choice.h('正直に詫びて、酒だけを出す', '気取らずに済む。夫は少し気まずい', () {
        _spouseBond(g, -2);
        return '客は笑って酒を飲み、夜更けまで話し込んでいった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 店の帳場（商家の女）
  // ==================================================================
  _first('wl_shop', (g, next) {
    final l = g.l;
    g.ask('店の帳場', '帳場に座ってみると、帳面に合わない銭がある。手代の一人の様子がおかしい。', [
      Choice.h('手代を問い詰める', '銭は戻るかもしれない。思い違いなら店の空気が悪くなる', () {
        if (g.rng.chance(.4 + l.chi / 250)) {
          l.gold += 8;
          g.setFlag('wl_caught_clerk');
          return '手代は、博打の借りを店の銭で埋めていたと白状した。';
        }
        l.net -= 1;
        return '手代は泣いて否んだ。銭の穴は、帳面の付け違いだった。';
      }),
      Choice.h('帳面を一から付け直す', '時はかかる。店の銭の流れがすっかり見える', () {
        l.sei = _c(l.sei + 2);
        g.setFlag('wl_books');
        return '夜ごと算盤をはじき、ひと月かけて帳面を付け直した。';
      }),
      Choice.h('見逃して様子を見る', '店の空気は保てる。銭の穴は広がるかもしれない', () {
        _pay(g, 4);
        return '銭の穴は、少しずつ広がっていった。';
      }),
    ], after: next);
  }),
  _again('wl_shop', (g, next) {
    final l = g.l;
    final head = _intro(g, 'wl_shop', 'また店を切り盛りした。', [
      '{季}、店先に客が引きも切らない。',
      '暖簾をくぐる客の顔を、たいてい覚えている。',
      '帳場の算盤の音が、店の者の目覚ましになっている。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('店先', '$head馴染みの客が、溜まった掛けを払えないと頭を下げに来た。', [
        Choice.h('払える時まで待つ', '客は恩に着る。銭はしばらく戻らない', () {
          _pay(g, 3);
          l.net += 2;
          return '客は涙ぐみ、「この恩は忘れぬ」と言った。';
        }),
        Choice.h('品で払ってもらう', '銭の代わりにはなる。客の顔は曇る', () {
          l.gold += 2;
          return '客の家の古い漆器を、掛けの代わりに受け取った。';
        }),
      ], after: next);
      return;
    }
    g.ask('店先', '$head同じ町の店の女あるじが、品を回してくれないかと相談に来た。', [
      Choice.h('手を組む', '商いが広がる。相手が傾けば共倒れになる', () {
        if (g.rng.chance(.6 + l.sei / 300)) {
          l.gold += 8;
          l.net += 2;
          return '二つの店で、町の客を分け合うようになった。';
        }
        _pay(g, 5);
        return '相手の店が傾き、回した品の代金が戻らなかった。';
      }),
      Choice.h('丁重に断る', '店は身軽なままだ。町での縁は広がらない', () {
        return '丁重に断った。相手は残念そうに帰っていった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 市の機織り（村の女）
  // ==================================================================
  _first('wl_loom', (g, next) {
    final l = g.l;
    g.ask('市の機織り', '織り溜めた布を市に出すと、町の商人が「まとめて買う」と言う。一反ずつ売れば高いが、売れ残るかもしれない。', [
      Choice.h('商人にまとめて売る', '確かな銭になる。足元は見られる', () {
        l.gold += 5;
        return '安く叩かれたが、懐は温かくなった。';
      }),
      Choice.h('市で一反ずつ売る', '高く売れるかもしれない。日が暮れるまで市に立つ', () {
        if (g.rng.chance(.45 + l.un / 250 + l.mi / 400)) {
          l.gold += 10;
          return '色の良い一反が評判を呼び、日暮れ前に売り切れた。';
        }
        l.gold += 2;
        return '半分も売れず、残りを背負って帰った。';
      }),
      Choice.h('村の女たちと組んで、値を揃える', '叩かれにくくなる。まとまるには手間がかかる', () {
        l.net += 3;
        l.gold += 4;
        g.setFlag('wl_weavers');
        g.mark('村の女たちと組み、市で布の値を揃えた');
        return '女たちが口を揃えると、商人も値を上げざるを得なかった。';
      }),
    ], after: next);
  }),
  _again('wl_loom', (g, next) {
    final l = g.l;
    final head = _intro(g, 'wl_loom', 'また機を織って市へ出た。', [
      '{季}、夜なべの機の音が村に響く。',
      '市の顔なじみが、あなたの布を待っていた。',
      '娘時代から数えて、もう何反織ったか分からない。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('機の音', '$head今年は、新しい縞の柄を試してみようか。', [
        Choice.h('新しい柄を織る', '当たれば評判になる。外れれば売れ残る', () {
          if (g.rng.chance(.45 + l.chi / 300)) {
            l.gold += 6;
            l.fame += 1;
            return '新しい縞は、市でちょっとした評判になった。';
          }
          return '新しい縞は、思ったほど売れなかった。';
        }),
        Choice.h('いつもの柄を織る', '手堅く売れる。目新しさはない', () {
          l.gold += 3;
          return 'いつもの柄は、いつものように売れた。';
        }),
      ], after: next);
      return;
    }
    g.ask('機の音', '$head糸の値が上がった。今年の布は、儲けが薄い。', [
      Choice.h('麻を自分で績む', '銭は浮く。夜なべがさらに延びる', () {
        l.gold += 3;
        l.hp -= 4;
        return '指先を荒らしながら、麻を績んだ。';
      }),
      Choice.h('織る量を減らす', '体は楽になる。銭は少ない', () {
        g.j(2);
        return '今年は、織る量を半分にした。';
      }),
      if (l.un >= 60)
        Choice.h('気の向くままに、見たことのない柄を織ってみる', '売れるかどうかは分からない。ふと、手が動いた', () {
          if (g.luck()) {
            l.gold += 6;
            l.fame += 1;
            return '織り上がった布を市に出すと、旅の商人が足を止め、あるだけ買っていった。上方で、ちょうどそんな柄が流行り始めているという。';
          }
          l.gold += 1;
          return '風変わりな柄は、市で誰の手にも取られなかった。家の者の着物になった。';
        }, via: '運'),
    ], after: next);
  }),

  // ==================================================================
  // 田植え唄（村の女）
  // ==================================================================
  _first('wl_song', (g, next) {
    final l = g.l;
    g.ask('田植え唄', '田植えの日、早乙女たちの唄の音頭を取ってくれと頼まれた。', [
      Choice.h('声を張って音頭を取る', '田が賑わい、名も上がる。喉は嗄れる', () {
        l.net += 3;
        l.fame += 1;
        g.j(5);
        g.setFlag('wl_ondo');
        g.mark('田植えの日、早乙女たちの唄の音頭を取った');
        return 'あなたの声に合わせて、苗が一列に揃っていった。';
      }),
      Choice.h('後ろで声を合わせる', '気楽に楽しめる。目立たない', () {
        g.j(4);
        return '泥に足を取られながら、皆と一緒に唄った。';
      }),
      Choice.h('古い唄を若い娘たちに教える', '村の唄が残る。教えるには根気がいる', () {
        l.net += 2;
        g.setFlag('wl_old_song');
        return '祖母から聞いた古い唄を、娘たちが覚えて口ずさんだ。';
      }),
    ], after: next);
  }),
  _again('wl_song', (g, next) {
    final l = g.l;
    final head = _intro(g, 'wl_song', 'また田植え唄を合わせた。', [
      '田植えの日、今年も女たちの唄が田に響いた。',
      '唄の文句が、少しずつ村の流儀になってきた。',
      '若い早乙女たちが、あなたの声を真似ている。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('唄の輪', '$head隣の村の女たちが、唄くらべをしようと言ってきた。', [
        Choice.h('受けて立つ', '勝てば村の誇りになる。負ければしばらく笑われる', () {
          if (g.rng.chance(.5 + l.mi / 300)) {
            l.net += 2;
            g.j(6);
            return '隣村の女たちが、最後には手を叩いて笑った。';
          }
          g.j(-1);
          return '隣村の唄のほうが、少しだけ声がよく通った。';
        }),
        Choice.h('一緒に唄おうと誘う', '村どうしの縁が結ばれる。勝ち負けはつかない', () {
          l.net += 3;
          return '二つの村の女たちの声が、畦を越えて重なった。';
        }),
      ], after: next);
      return;
    }
    g.ask('唄の輪', '$head唄の途中で、雨が降り出した。', [
      Choice.h('唄いながら植え続ける', '田植えは済む。体は冷える', () {
        l.hp -= 4;
        g.j(3);
        return '雨音に負けじと声を張り、日暮れ前に植え終えた。';
      }),
      Choice.h('皆を小屋へ入れる', '体は守れる。田植えは一日延びる', () {
        g.j(1);
        return '小屋の中で、女たちのおしゃべりが尽きなかった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 寺へ逃げてきた女（尼）
  // ==================================================================
  _first('wl_refuge', (g, next) {
    final l = g.l;
    g.ask(
      '寺へ逃げてきた女',
      '夜更け、裸足の女が寺の門を叩いた。夫の打擲に耐えかねて逃げてきたという。追ってきた夫が、門の外でわめいている。',
      [
        Choice.h('寺に置いてかくまう', '女は救われる。夫が村の者を連れて押しかけるかもしれない', () {
          if (g.rng.chance(.15)) l.hp -= 10;
          l.net += 2;
          l.fame += 2;
          g.setFlag('wl_sheltered');
          g.mark('寺に逃げ込んできた女を、夫から匿った');
          return '女は寺に残り、朝夕の掃除を手伝うようになった。';
        }),
        Choice.h('夫と女のあいだに立って話を聞く', '収まれば一番よい。収まらなければ、女はまた逃げてくる', () {
          if (g.rng.chance(.4 + l.mi / 250)) {
            l.net += 1;
            g.j(3);
            return '夫は門の前で膝をつき、二度と手を上げぬと誓った。';
          }
          g.j(-3);
          return '夫は女を連れ帰った。ひと月のち、女はまた門を叩いた。';
        }),
        Choice.h('門を開けず、朝を待つ', '寺は荒れずに済む。女の行く末は分からない', () {
          g.j(-4);
          return '朝になると、門の前には誰もいなかった。';
        }),
        if (l.bu >= 60)
          Choice.h('門を開け、薙刀の石突きを地に突いて立つ', '身に覚えた構えひとつで、男は引き下がるかもしれない。逆上するかもしれない', () {
            if (g.might()) {
              l.fame += 3;
              g.j(4);
              return '門の内に女をかばい、薙刀を立てて一言も発しなかった。男はしばらくわめいていたが、やがて声が小さくなり、夜道を帰っていった。女は、寺に身を寄せることになった。';
            }
            l.hp -= 6;
            g.j(1);
            return '男は薙刀の柄をつかんで揉み合いになった。騒ぎを聞いた寺男たちが駆けつけ、男を門の外へ押し出した。腕の痣は、しばらく消えなかった。';
          }, via: '武'),
      ],
      after: next,
    );
  }),
  _again('wl_refuge', (g, next) {
    final l = g.l;
    final head = _intro(g, 'wl_refuge', 'また寺の務めに明け暮れた。', [
      '{季}、女たちが寺の縁先で手を合わせていく。',
      '寺の門は、女の参る者にはいつも開いている。',
      '寺に身を寄せた女たちが、境内の掃除を手伝っている。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('寺の務め', '$head幼い子を連れた後家が、しばらく寺に置いてほしいと言う。', [
        Choice.h('寺に置く', '母子は救われる。寺の米が細る', () {
          _pay(g, 2);
          l.net += 2;
          g.j(3);
          return '子の笑う声が、静かな寺に響くようになった。';
        }),
        Choice.h('縁のある寺へ文を書いて送る', '母子の行き先は決まる。手放す寂しさが残る', () {
          l.net += 1;
          return '母子は、文を携えて山向こうの寺へ向かった。';
        }),
      ], after: next);
      return;
    }
    g.ask('寺の務め', '$head参りに来た女が、字が書けないので願の文を書いてほしいと言う。', [
      Choice.h('願いを聞いて書いてやる', '女は喜ぶ。願いの中身に心が揺れるかもしれない', () {
        l.chi = _c(l.chi + 1);
        g.j(2);
        return '戦に出た息子の無事を願う文を、一字ずつ書いた。';
      }),
      Choice.h('手を取って、字を教える', '女は自分で書けるようになる。時がかかる', () {
        l.net += 2;
        return '女は三日通い、自分の名を書けるようになった。';
      }),
    ], after: next);
  }),

  // ==================================================================
  // 薙刀の弟子（女武者）
  // ==================================================================
  _first('wl_naginata', (g, next) {
    final l = g.l;
    final who = l.rank >= 1 ? '奥の若い女たち' : '村の娘たち';
    final pupil = _girl(g);
    g.ask('薙刀の弟子', '$whoが、薙刀を教えてほしいと集まってきた。親の中には、女に刃物などと渋る者もいる。', [
      Choice.h('親を説き伏せて教える', '弟子が増える。親たちの目は厳しい', () {
        if (g.rng.chance(.45 + l.mi / 250)) {
          l.net += 3;
          l.fame += 2;
          g.meet('薙刀の弟子', pupil, 55);
          g.setFlag('wl_disciples');
          g.mark('若い女たちに薙刀を教えた');
          return '親たちも折れ、十人ほどが稽古に通ってくるようになった。中でも$pupilの筋が良い。';
        }
        l.net -= 1;
        return '親たちは首を縦に振らず、来たのはわずかだった。';
      }),
      Choice.h('望む娘にだけ、こっそり教える', '波風は立たない。教えられる数は少ない', () {
        l.net += 1;
        g.meet('薙刀の弟子', pupil, 60);
        return '夜明け前の河原で、$pupilひとりに型を教えた。';
      }),
      Choice.h('断る', '自分の稽古に打ち込める。娘たちはがっかりする', () {
        l.bu = _c(l.bu + 1);
        return '娘たちは、名残惜しそうに帰っていった。';
      }),
    ], after: next);
  }),
  _again('wl_naginata', (g, next) {
    final l = g.l;
    final pupil = l.people['薙刀の弟子']?.name ?? _girl(g);
    final head = _intro(g, 'wl_naginata', 'また薙刀を教えた。', [
      '{季}、稽古場に薙刀の打ち合う音が響く。',
      '弟子たちの構えが、ようやくさまになってきた。',
      'あなたの弟子が、自分の弟子を連れてきた。',
    ]);
    if (g.rng.chance(.5)) {
      g.ask('薙刀の稽古場', '$head弟子の$pupilが、あなたに立ち合いを願い出た。', [
        Choice.h('本気で立ち合う', '弟子は伸びる。どちらかが怪我をするかもしれない', () {
          l.hp -= 5;
          l.bu = _c(l.bu + 1);
          final p = l.people['薙刀の弟子'];
          if (p != null) p.bond = _c100(p.bond + 5);
          return '打ち合いのあと、$pupilは悔し涙を拭って、もう一本と言った。';
        }),
        Choice.h('型だけを見てやる', '怪我はしない。弟子は物足りない', () {
          return '$pupilの型の癖を、一つだけ直してやった。';
        }),
        if (l.bu >= 60)
          Choice.h('片手で受けて、力の差を見せる', '腕があれば、怪我をさせずに高みを見せられる', () {
            l.fame += 1;
            l.net += 2;
            g.j(2);
            return '$pupilの打ち込みを、片手の薙刀で三度流した。四度目に、$pupilは構えを解いて笑った。「まだまだですね」。その日から、$pupilの稽古は倍になった。';
          }, via: '武'),
      ], after: next);
      return;
    }
    g.ask('薙刀の稽古場', '$head近くの村に野盗が出たと噂が立ち、娘たちが目の色を変えて稽古に来た。', [
      Choice.h('身を守る技だけを教え込む', '娘たちは心強くなる。稽古は厳しくなる', () {
        l.net += 2;
        l.hp -= 3;
        return '刃を受け流し、逃げる隙を作る技を、日暮れまで繰り返した。';
      }),
      Choice.h('逃げる道を皆で決めておく', '戦わずに済む。腕は上がらない', () {
        l.net += 1;
        return '山の抜け道と、落ち合う場所を皆で決めた。';
      }),
    ], after: next);
  }),
];

// ======================================================================
// 型ごとの岐路（一生に一度）
// ======================================================================

bool _is(Game g, WomanKind k) => womanKind(g) == k && g.active;

List<SceneDef> _lifeScenes() => [
  // ---- 奥: 奥での出世の機と妬み ----
  SceneDef(
    'wl_oku_promote',
    17,
    40,
    (g) => 2.5,
    (g) => _is(g, WomanKind.oku) && g.l.rank <= 4,
    (g, next) {
      final l = g.l;
      final elder = _girl(g);
      g.ask('奥の出世', '奥方さまが、あなたを上の役に引き上げたいと言う。だが、その役を長く望んできた年かさの女中、$elderがいる。', [
        Choice.h('ありがたくお受けする', '出世の道が開ける。年かさの女中の恨みを買う', () {
          // 位を上げるのは下女・女中頭から奥女中までにとどめる（後見・女大名の届きやすさを変えない）。
          if (l.rank <= 2) {
            l.rank++;
            if (l.rank > l.maxRank) l.maxRank = l.rank;
          } else {
            l.merit += 12;
          }
          l.fav = _c100(l.fav + 5);
          g.setFlag('wl_envied_by_elder');
          g.mark('奥方に引き立てられ、年かさの女中を越えて役に就いた');
          return '新しい役に就いた。$elderは、廊下ですれ違っても目を合わせない。';
        }),
        Choice.h('年かさの女中に譲る', '奥の和は保たれる。次の機がいつ来るかは分からない', () {
          l.net += 3;
          l.fav = _c100(l.fav + 2);
          g.j(2);
          g.setFlag('wl_yielded');
          return '$elderは役に就き、あなたにだけ小さく頭を下げた。';
        }),
        Choice.h('二人で務めたいと申し出る', '角は立たない。奥方さまが受け入れるかは分からない', () {
          if (g.rng.chance(.4 + l.mi / 250)) {
            l.merit += 8;
            l.net += 2;
            return '奥方さまは笑って、「欲のない者たちよ」と二人に役を分けた。';
          }
          l.fav = _c100(l.fav - 3);
          return '奥方さまは「迷う者に役は任せられぬ」と、話を取り下げた。';
        }),
      ], after: next);
    },
  ),

  // ---- 奥: 奥方の密命 ----
  SceneDef(
    'wl_secret_errand',
    20,
    55,
    (g) => 2,
    (g) => _is(g, WomanKind.oku) && g.l.rank >= 3,
    (g, next) {
      final l = g.l;
      final house = _lordHouse(g);
      g.ask(
        '奥方の密命',
        '奥方さまが、ご実家へ届ける文をあなたに託した。表の者には知らせるな、という。いまは、ご実家と$house家の仲が冷えている。',
        [
          Choice.h('ひそかに届ける', '奥方さまの信は厚くなる。夜道は物騒で、露見すれば内通を疑われる', () {
            if (g.rng.chance(.04)) {
              g.die('奥方の密書を運ぶ夜道で、何者かに襲われて落命した', 'ansatsu');
              return '城下を出た夜道で、背後に足音が迫った。';
            }
            if (g.rng.chance(.2)) {
              l.fav = _c100(l.fav - 15);
              return '文は届いたが、表の者に出入りを怪しまれた。';
            }
            l.fav = _c100(l.fav + 10);
            l.merit += 10;
            g.setFlag('wl_secret_kept');
            g.mark('奥方の密書を、ひそかにご実家へ届けた');
            return '文は無事に届いた。奥方さまは、あなたの手を両手で包んだ。';
          }),
          Choice.h('殿のお耳に入れる', '家への忠は立つ。奥方さまの信は失う', () {
            l.merit += 8;
            g.j(-5);
            g.setFlag('wl_told_lord');
            return '殿は文を改め、何も言わずに奥方さまへ返させた。奥の空気が凍りついた。';
          }),
          Choice.h('文を預かったまま、時を待つ', '誰も裏切らずに済む。奥方さまは苛立つかもしれない', () {
            l.fav = _c100(l.fav - 3);
            return 'ほどなく両家の使者が行き来し始め、文は届けずに済んだ。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 尼: 尼寺に落ち延びた姫 ----
  SceneDef('wl_hime_refuge', 20, 75, (g) => 2.5, (g) => _is(g, WomanKind.nun), (
    g,
    next,
  ) {
    final l = g.l;
    final hime = g.rng.pick(kHimeNames);
    g.ask('落ち延びた姫', '落城した家の姫が、侍女ひとりを連れて寺へ逃げてきた。追手の侍が、夜明けには寺を改めに来るという。', [
      Choice.h('尼の姿にして匿う', '姫は救われるかもしれない。見破られれば、寺もただでは済まない', () {
        if (g.rng.chance(.2)) {
          l.hp -= 10;
          g.j(-10);
          return '追手の侍は姫の手の白さに目を留め、連れ去っていった。';
        }
        l.fame += 5;
        g.meet('匿った姫', hime, 70);
        g.setFlag('wl_hid_hime');
        g.mark('落ち延びた姫を、尼の姿にして寺に匿った');
        return '髪を下ろした$himeは、追手の前で黙って経を読み通した。';
      }),
      Choice.h('裏の山道から、遠くの寺へ逃がす', '寺は改められても困らない。山道は姫の足には険しい', () {
        l.net += 1;
        g.j(-2);
        return '夜のうちに、$himeを山道へ送り出した。その後の便りは、まだない。';
      }),
      Choice.h('追手に引き渡す', '寺は守れる。夜ごと夢に見るかもしれない', () {
        g.j(-12);
        return '$himeは、振り返らずに追手の馬に乗せられていった。';
      }),
    ], after: next);
  }),

  // ---- 尼: 戦場の弔い ----
  SceneDef('wl_nun_mourn', 20, 80, (g) => 2, (g) => _is(g, WomanKind.nun), (
    g,
    next,
  ) {
    final l = g.l;
    g.ask('野の弔い', '近くの野で戦があった。打ち捨てられた骸が、雨にさらされている。村の者は、祟りを恐れて近づかない。', [
      Choice.h('村の女たちを集めて弔う', '骸は土に還る。勝った側に咎められるかもしれない', () {
        if (g.rng.chance(.15)) {
          g.j(-4);
          return '勝った側の侍に、敵の骸に手を出すなと追い払われた。';
        }
        l.net += 3;
        l.fame += 3;
        g.setFlag('wl_mourned_field');
        g.mark('戦のあとの野で、村の女たちと敵味方の別なく骸を弔った');
        return '女たちと穴を掘り、一人ずつ名も知らぬ者を葬った。';
      }),
      Choice.h('ひとり野に立って経を読む', '祟りを恐れる村は落ち着く。骸はそのままだ', () {
        g.j(2);
        return '雨の中で、日が暮れるまで経を読んだ。';
      }),
    ], after: next);
  }),

  // ---- 武家の妻: 討死の報せ（噂）----
  SceneDef(
    'wl_husband_rumor',
    18,
    60,
    (g) => 2,
    (g) => _is(g, WomanKind.wife) && g.l.people.containsKey('伴侶'),
    (g, next) {
      final l = g.l;
      final who = _husband(g);
      g.ask('討死の報せ', '$whoが出陣した先から、討死したという噂が流れてきた。確かな報せは、まだない。', [
        Choice.h('取り乱さず、家の者を落ち着かせる', '家は乱れない。胸の内は張り裂けそうだ', () {
          g.j(-6);
          l.net += 2;
          _spouseBond(g, 4);
          g.setFlag('wl_held_firm');
          return '十日ののち、$whoは傷だらけで帰ってきた。噂は、討たれた別の者の話だった。';
        }),
        Choice.h('陣所まで確かめに行く', '真偽はすぐに分かる。女の足で戦場の近くへ出るのは危うい', () {
          l.hp -= 10;
          _spouseBond(g, 10);
          return '陣所の手前で、足を引きずる$whoと行き会った。$whoは、しばらく言葉が出なかった。';
        }),
        Choice.h('寺に籠もって無事を祈る', '心は少し落ち着く。家のことは手につかない', () {
          g.j(-2);
          _spouseBond(g, 5);
          l.net -= 1;
          return '祈りが通じたのか、$whoは生きて帰ってきた。';
        }),
      ], after: next);
    },
  ),

  // ---- 武家の妻: 郎党の女房たちの諍い ----
  SceneDef(
    'wl_retainer_wives',
    20,
    60,
    (g) => 2,
    (g) => _is(g, WomanKind.wife),
    (g, next) {
      final l = g.l;
      g.ask('郎党の女房たち', '郎党の女房たちが、井戸を使う順番を巡っていがみ合っている。どちらも、あなたに裁いてほしいと言う。', [
        Choice.h('古株の女房の顔を立てる', '屋敷の古い秩序は守られる。新参の者は不満を抱く', () {
          l.net += 1;
          return '古株の女房は満足げに、新参の女房は唇を噛んで下がった。';
        }),
        Choice.h('新参の女房の言い分も聞いて、順番を決め直す', '筋は通る。古株の女房はへそを曲げる', () {
          if (g.rng.chance(.5 + l.sei / 300)) {
            l.net += 2;
            g.setFlag('wl_fair_judge');
            return '日ごとに順番を替える決まりにすると、皆が黙って従った。';
          }
          return '決まりは作ったが、古株の女房はしばらく口をきかなかった。';
        }),
        Choice.h('井戸をもう一つ掘らせる', '争いの種がなくなる。蔵の銭が減る', () {
          if (l.gold < 6) {
            g.j(-2);
            return '井戸を掘るほどの銭はなく、なだめて回るしかなかった。';
          }
          l.gold -= 6;
          l.net += 3;
          return '新しい井戸から水が湧くと、女房たちは揃って手を叩いた。';
        }),
      ], after: next);
    },
  ),

  // ---- 武家の後家: 女の身で家督を守る ----
  SceneDef(
    'wl_keep_house',
    22,
    55,
    (g) => 3,
    (g) {
      final l = g.l;
      return l.female &&
          !l.married &&
          l.people.containsKey('伴侶') &&
          l.kids >= 1 &&
          l.hasKidAged(g.year, 0, 14) &&
          (l.rank >= 1 || _bukeCls.contains(l.cls.id)) &&
          l.rank < 8 &&
          !g.hasFlag('priesthood') &&
          g.active;
    },
    (g, next) {
      final l = g.l;
      final uncle = '亡き夫の弟の${_man(g)}';
      g.ask('家督を守る', '$uncleが、幼い子に代わって家を継ぐと言い出した。一族の多くが、そちらに付きかけている。', [
        Choice.h('主家に訴え出て、子の家督を認めてもらう', '筋が通れば家は子のもの。主家に借りを作る', () {
          if (g.rng.chance(.45 + l.sei / 300 + l.net * .01)) {
            l.fame += 5;
            g.setFlag('wl_kept_house');
            g.mark('女の身で主家に訴え出て、幼い子の家督を守り抜いた');
            return '主家は、子の家督を認める書き付けを下した。';
          }
          g.j(-6);
          g.setFlag('wl_lost_house');
          return '訴えは退けられた。家は$uncleの手に渡った。';
        }),
        Choice.h('一族の長老を一人ずつ説いて回る', '時はかかる。味方が増えれば争わずに済む', () {
          if (g.rng.chance(.4 + l.mi / 250 + l.net * .01)) {
            l.net += 3;
            g.setFlag('wl_kept_house');
            g.mark('一族の長老を説いて回り、幼い子の家督を守り抜いた');
            return '長老たちが首を縦に振り、$uncleは引き下がった。';
          }
          g.j(-5);
          g.setFlag('wl_house_lent');
          return '長老たちは煮え切らず、家は子が育つまで$uncleが預かることになった。';
        }),
        Choice.h('子が育つまで、弟に預ける', '争いは起きない。家が子に戻るかは分からない', () {
          g.j(-4);
          g.setFlag('wl_house_lent');
          return '家の鍵を、$uncleに渡した。';
        }),
      ], after: next);
    },
  ),

  // ---- 村・商家: 娘を奉公に出すか ----
  SceneDef(
    'wl_daughter_service',
    26,
    60,
    (g) => 2,
    (g) =>
        (_is(g, WomanKind.village) || _is(g, WomanKind.merchant)) &&
        g.l.daughterAged(g.year, 10, 16) != null,
    (g, next) {
      final l = g.l;
      // 名のある娘がその歳ならその娘、でなければ家にいる十から十六の娘。
      final girl =
          (roleKid(g, '娘', 10, 16, true) ?? l.daughterAged(g.year, 10, 16)!)
              .name;
      g.ask('娘の奉公', '城下の武家の屋敷から、娘の$girlを下女に上げないかという話が来た。口減らしにもなるが、娘はまだ幼い。', [
        Choice.h('奉公に出す', '娘は行儀を覚え、家の口も減る。会える日は限られる', () {
          l.gold += 3;
          g.j(-3);
          g.meet('奉公に出た娘', girl, 55);
          g.setFlag('wl_daughter_served');
          g.mark('娘の$girlを、武家の屋敷へ奉公に出した');
          return '$girlは、小さな包みを抱えて城下へ向かった。';
        }),
        Choice.h('手元に置く', '娘はそばにいる。暮らしは苦しいままだ', () {
          g.j(3);
          _pay(g, 1);
          return '話は断った。$girlは、何も知らずに妹たちと遊んでいる。';
        }),
        Choice.h('娘に決めさせる', '娘の望みどおりになる。どちらを選ぶかは分からない', () {
          if (g.rng.chance(.5)) {
            l.gold += 3;
            g.meet('奉公に出た娘', girl, 70);
            g.setFlag('wl_daughter_served');
            return '$girlは「行ってみたい」と言った。その目は輝いていた。';
          }
          g.j(4);
          return '$girlは、あなたの袖をつかんで首を振った。';
        }),
      ], after: next);
    },
  ),

  // ---- 商家: 夫が倒れ、店を継ぐ ----
  SceneDef(
    'wl_husband_falls',
    22,
    60,
    (g) => 2.5,
    (g) =>
        _is(g, WomanKind.merchant) &&
        g.l.married &&
        g.l.people.containsKey('伴侶'),
    (g, next) {
      final l = g.l;
      final who = _husband(g);
      g.ask(
        '倒れた夫',
        '$whoが帳場で倒れた。命はとりとめたが、右の手足が利かない。店の者が、これからどうするのかとあなたを見ている。',
        [
          Choice.h('自ら帳場に座る', '店はあなたが背負う。女あるじを侮る取引先もいる', () {
            l.sei = _c(l.sei + 3);
            if (g.rng.chance(.45 + l.sei / 250)) {
              l.gold += 10;
              l.fame += 2;
            } else {
              _pay(g, 6);
            }
            g.setFlag('wl_shop_mistress');
            g.mark('倒れた$whoに代わり、自ら店の帳場に座った');
            return '翌朝から、帳場の算盤はあなたの音になった。';
          }),
          Choice.h('番頭に任せ、夫の看病に専念する', '夫のそばにいられる。店の銭の流れは見えなくなる', () {
            _spouseBond(g, 10);
            _pay(g, 5);
            g.setFlag('wl_nursed_husband');
            return '$whoの手をさすりながら、冬を越した。';
          }),
          Choice.h('店をたたみ、蓄えで暮らす', '肩の荷は下りる。蓄えはいずれ尽きる', () {
            l.gold += 15;
            g.j(2);
            g.setFlag('wl_shop_closed');
            return '暖簾を下ろした。店の者たちは、それぞれの縁を頼って散っていった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 商家: 頼母子の講 ----
  SceneDef(
    'wl_tanomoshi',
    22,
    65,
    (g) => 2,
    (g) => _is(g, WomanKind.merchant),
    (g, next) {
      final l = g.l;
      final who = _girl(g);
      g.ask('頼母子の講', '町の女たちと開いている頼母子の講で、銭を受け取る番だった$whoが、受け取ったまま姿を見せなくなった。', [
        Choice.h('自分の銭で穴を埋める', '講は続く。蔵の銭が減る', () {
          _pay(g, 8);
          l.net += 3;
          l.fame += 2;
          g.setFlag('wl_kou_saved');
          g.mark('頼母子の講の穴を自分の銭で埋め、町の女たちの講を守った');
          return '女たちは、あなたを講の頭に立てた。';
        }),
        Choice.h('女の家を訪ねて事情を聞く', '事情によっては救える。銭は戻らないかもしれない', () {
          if (g.rng.chance(.45 + l.mi / 250)) {
            l.net += 2;
            return '$whoは、病の夫の薬代に困っていた。皆で少しずつ待つことにした。';
          }
          return '$whoの家は、もぬけの殻だった。';
        }),
        Choice.h('講を解く', '損はこれ以上広がらない。女たちの縁は切れる', () {
          l.net -= 3;
          return '講は解かれた。女たちは、互いに目を合わせなくなった。';
        }),
      ], after: next);
    },
  ),

  // ---- 商家・村: 市での揉め事を裁く ----
  SceneDef(
    'wl_market_quarrel',
    20,
    65,
    (g) => 2,
    (g) => _is(g, WomanKind.merchant) || _is(g, WomanKind.village),
    (g, next) {
      final l = g.l;
      g.ask('市の揉め事', '市で、塩売りの女と魚売りの男が、場所を巡って掴み合いになった。顔の知れたあなたに、皆が仲裁を求める。', [
        Choice.h('双方の言い分を聞いて裁く', '収まれば市で頼られる。裁きを誤れば恨まれる', () {
          if (g.rng.chance(.4 + (l.chi + l.mi) / 400)) {
            l.fame += 3;
            l.net += 2;
            g.setFlag('wl_market_judge');
            g.mark('市の揉め事を裁き、市の者たちに頼られた');
            return '朝と昼で場所を分ける裁きに、二人とも渋々うなずいた。';
          }
          l.net -= 1;
          return '男は「女に裁かれる筋合いはない」と吐き捨てて去った。';
        }),
        Choice.h('市の世話役を呼びに行く', '筋は通る。収まるのに時がかかる', () {
          return '世話役が来るころには、二人とも疲れて座り込んでいた。';
        }),
        Choice.h('塩売りの女の肩を持つ', '女たちとの縁は深まる。公平とは言えない', () {
          l.net += 1;
          l.fame -= 1;
          return '市の女たちが加勢し、男は引き下がった。';
        }),
      ], after: next);
    },
  ),

  // ---- 村: 米の値と女たち ----
  SceneDef(
    'wl_rice_women',
    18,
    60,
    (g) => 2,
    (g) => _is(g, WomanKind.village),
    (g, next) {
      final l = g.l;
      g.ask(
        '米の値',
        '凶作の年、米の値が跳ね上がった。村の女たちが、米を蔵に積んだまま売り惜しむ町の商人のもとへ押しかけようと言い出した。',
        [
          Choice.h('先頭に立つ', '米が安く出回るかもしれない。捕らえられれば、ただでは済まない', () {
            if (g.rng.chance(.04)) {
              g.die('米の値を巡って商人の蔵へ押しかけた女たちの先頭に立ち、捕らえられて処刑された', 'seppuku');
              return '代官の手の者が、女たちの中からあなただけを引き立てた。';
            }
            if (g.rng.chance(.5 + l.mi / 300)) {
              l.gold += 4;
              l.fame += 3;
              l.net += 3;
              g.setFlag('wl_led_women');
              g.mark('凶作の年、村の女たちの先頭に立って商人の蔵へ押しかけた');
              return '商人は蔵を開け、米を常の値で村に回すと約束した。';
            }
            l.hp -= 10;
            g.j(-5);
            return '蔵の者に棒で追い払われ、腕に痣が残った。';
          }),
          Choice.h('ついて行き、後ろで声を上げる', '米が手に入るかもしれない。目立たずに済む', () {
            l.gold += 2;
            return '女たちの声に押されて、商人は少しだけ米を出した。';
          }),
          Choice.h('皆を止める', '村は荒立たない。空きっ腹は満たされない', () {
            l.hp -= 3;
            g.j(-3);
            return '女たちは渋々引き下がり、その冬は粥を薄めてしのいだ。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 村・商家: 夫から逃げる女の手助け ----
  SceneDef(
    'wl_flee_help',
    18,
    60,
    (g) => 2,
    (g) => _is(g, WomanKind.village) || _is(g, WomanKind.merchant),
    (g, next) {
      final l = g.l;
      final who = _girl(g);
      g.ask('逃げてきた女', '隣の家の$whoが、夜中にあなたの家の戸を叩いた。夫の打擲に耐えかね、山向こうの尼寺へ逃げたいという。', [
        Choice.h('夜のうちに尼寺まで送る', '女は逃げおおせるかもしれない。夫に知れれば恨まれる', () {
          l.hp -= 4;
          if (g.rng.chance(.3)) {
            l.net -= 2;
            g.j(-2);
            g.setFlag('wl_helped_flee');
            return '$whoは尼寺に入ったが、送ったのがあなただと、隣の夫に知れた。';
          }
          g.j(5);
          g.setFlag('wl_helped_flee');
          g.mark('夫から逃げる女を、夜のうちに山向こうの尼寺まで送った');
          return '夜明け前、$whoは尼寺の門の内へ消えた。';
        }),
        Choice.h('一晩泊めて、朝に間に立つ', '収まるかもしれない。収まらなければ同じことが起きる', () {
          if (g.rng.chance(.4 + l.mi / 250)) {
            l.net += 2;
            return '翌朝、隣の夫は頭を掻いて$whoを迎えに来た。';
          }
          g.j(-3);
          return '$whoは連れ戻された。ひと月のち、隣の家から姿を消した。';
        }),
        Choice.h('関わらない', '揉め事に巻き込まれずに済む。夜の戸を叩く音が耳に残る', () {
          g.j(-4);
          return '戸を開けずにいると、足音は遠ざかっていった。';
        }),
        if (l.bu >= 60)
          Choice.h('追ってきた夫の前に、心張り棒を手に立つ', '腕っぷしに覚えがあれば、男も手は出せない。村の噂にはなる', () {
            if (g.might()) {
              l.fame += 2;
              l.net += 2;
              g.j(4);
              return '戸口に立ちはだかり、心張り棒で土間をどんと突いた。「この人は、今夜はうちの客だよ」。夫は口をぱくぱくさせて帰っていった。$whoは三日泊まり、尼寺へ発った。';
            }
            l.hp -= 5;
            return '夫に突き飛ばされて、土間に尻餅をついた。騒ぎで近所が起きてきて、夫はばつが悪そうに引き揚げた。';
          }, via: '武'),
      ], after: next);
    },
  ),

  // ---- 村: 産婆の留守の取り上げ ----
  SceneDef(
    'wl_midwife',
    28,
    65,
    (g) => 2,
    (g) => _is(g, WomanKind.village) && g.l.kids >= 1,
    (g, next) {
      final l = g.l;
      final who = _girl(g);
      g.ask('取り上げ', '夜中に、村の若い女房の$whoのお産が重いと呼ばれた。産婆は山向こうの村へ出ていて、すぐには戻らない。', [
        Choice.h('自分で赤子を取り上げる', '母子を救えるかもしれない。しくじれば恨みを背負う', () {
          if (g.rng.chance(.55 + l.chi / 300 + l.un / 400)) {
            l.fame += 2;
            l.net += 3;
            g.j(6);
            g.setFlag('wl_midwife');
            g.mark('産婆の留守に、村の女房の赤子を取り上げた');
            return '明け方、か細い産声が上がった。$whoは泣きながら笑った。';
          }
          g.j(-10);
          g.setFlag('wl_midwife_lost');
          return '赤子は、とうとう息をしなかった。$whoは、助かった。';
        }),
        Choice.h('産婆を呼びに、夜の山道を走る', '腕のある者が来れば安心だ。間に合うかは分からない', () {
          l.hp -= 6;
          if (g.rng.chance(.6)) {
            l.net += 2;
            return '産婆を背負うようにして連れ帰り、母子は助かった。';
          }
          g.j(-5);
          return '産婆と戻ったときには、すべてが終わっていた。';
        }),
        Choice.h('村の年寄りの女たちを集める', '知恵は集まる。人が多いと手がもつれる', () {
          l.net += 1;
          return '年寄りたちが口々に指図し、どうにか赤子は生まれた。';
        }),
      ], after: next);
    },
  ),
];

/// 女性の生き方の岐路（重点で選んだ年の岐路 16 と、型ごとの岐路 14）。
List<SceneDef> buildWomanLifeScenes() => [..._focusScenes(), ..._lifeScenes()];

/// 型ごとの岐路の id（テスト用）。
const kWomanLifeSceneIds = [
  'wl_oku_promote',
  'wl_secret_errand',
  'wl_hime_refuge',
  'wl_nun_mourn',
  'wl_husband_rumor',
  'wl_retainer_wives',
  'wl_keep_house',
  'wl_daughter_service',
  'wl_husband_falls',
  'wl_tanomoshi',
  'wl_market_quarrel',
  'wl_rice_women',
  'wl_flee_help',
  'wl_midwife',
];
