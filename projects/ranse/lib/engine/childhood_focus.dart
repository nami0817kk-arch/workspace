import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 子どもの重点を足す その2（2026-11-23、ユーザー「寺子屋に通うなどの選択肢がほしい」の続き）。
///
/// - 重点 7（[moreChildFocusOptions]。`childFocusOptions` のうしろに足す）: 弓と馬の稽古（武家の男子）／
///   野山で薬草を摘む（百姓・漁民・寺・河原者）／歌と書を習う（武家・寺・商家の女の子）／
///   弟妹の子守（長子。百姓・漁民・商家・足軽・浪人・河原者）／川で魚を獲る（百姓・漁民・河原者の男の子）／
///   市で使い走り（商家・河原者）／経を覚える（寺の子・小僧として寺に入った子）。
///   出るかどうかは乱数を使わずに決める（[childFocusTags]。テストも使う）。
/// - 続けた年の岐路 14（[kChildFocusStages]。どれも `onlyForced`）: 二度目に選んだ年に一の段、
///   一の段から二年以上あけて三度目以降に選んだ年に二の段。二の段は一の段の選び方で筋が分かれ、
///   能力が高いと選べる手が増える。その年に史実の岐路があれば、次に選んだ年へ回す（`Game._yearScene`）。
/// - 大人になってから返ってくる岐路 7（[buildChildFocusEchoScenes]、id・旗は `e4_`）。
///
/// id・旗は `cf_`（子どもの重点）と `c_f*_`（場面）。数字は label・hint に出さない。
/// 既存の `mark()`・`die()`・最期の文には触れていない。

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
int _n(Game g, String tag) => g.l.focus[tag] ?? 0;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _hurt(Game g, int n) => g.l.hp -= n;

const _bukeKids = ['lowsamurai', 'samurai', 'kokujin', 'daimyo'];
const _herbKids = ['farmer', 'fisher', 'priest', 'beggar'];
const _utaKids = [
  'lowsamurai',
  'samurai',
  'kokujin',
  'daimyo',
  'priest',
  'merchant',
];
const _komoriKids = [
  'farmer',
  'fisher',
  'merchant',
  'ashigaru',
  'ronin',
  'beggar',
];
const _riverKids = ['farmer', 'fisher', 'beggar'];
const _errandKids = ['merchant', 'beggar'];

/// 重点 → [一の段, 二の段] の場面の id。
const kChildFocusStages = <String, List<String>>{
  'yumiba': ['c_fy_tori', 'c_fy_kasagake'],
  'yakuso': ['c_fh_doku', 'c_fh_iyasu'],
  'uta': ['c_fp_utakai', 'c_fp_daihitsu'],
  'komori': ['c_fb_miushinau', 'c_fb_yakusoku'],
  'kawa': ['c_fr_koi', 'c_fr_mizu'],
  'tsukai': ['c_fe_saifu', 'c_fe_ootana'],
  'kyo': ['c_fs_tomurai', 'c_fs_rinju'],
};

/// 大人になってから返ってくる岐路の id。
const kChildFocusEchoIds = [
  'e4_yumi',
  'e4_herb',
  'e4_uta',
  'e4_sib',
  'e4_river',
  'e4_ootana',
  'e4_sutra',
];

/// いまの子に出る、足した重点の tag（乱数を使わない）。
List<String> childFocusTags(Game g) {
  final l = g.l;
  final c = l.cls.id;
  final a = g.age;
  final monkKid = c == 'priest' || g.hasFlag('monk');
  return [
    if (!l.female && _bukeKids.contains(c) && a >= 9) 'yumiba',
    if ((_herbKids.contains(c) || g.hasFlag('monk')) && a >= 7) 'yakuso',
    if (l.female && _utaKids.contains(c) && a >= 7) 'uta',
    if (l.order == 1 &&
        _komoriKids.contains(c) &&
        a >= 6 &&
        a <= 11 &&
        !g.hasFlag('monk'))
      'komori',
    if (!l.female && _riverKids.contains(c) && a >= 7 && !g.hasFlag('monk'))
      'kawa',
    if (_errandKids.contains(c) && a >= 8 && !g.hasFlag('monk')) 'tsukai',
    if (monkKid && a >= 6) 'kyo',
  ];
}

/// 続けた年の岐路（一の段・二の段）の id か。
bool isChildFocusStage(String id) =>
    kChildFocusStages.values.any((st) => st.contains(id));

/// 一の段から何年たったか（一の段がまだなら -1）。
int childFocusSince(Game g, String tag) {
  final pre = 'cf_at:$tag:';
  for (final f in g.l.flags) {
    if (f.startsWith(pre)) return g.age - int.parse(f.substring(pre.length));
  }
  return -1;
}

/// 二度目に選んだ年に一の段、一の段から二年以上あけて三度目以降に選んだ年に二の段。
String? _stageFor(Game g, String tag) {
  final st = kChildFocusStages[tag]!;
  final n = _n(g, tag); // この年の分は、まだ数えていない
  if (!g.hasFlag('scene:${st[0]}')) return n >= 1 ? st[0] : null;
  if (!g.hasFlag('scene:${st[1]}') && n >= 2 && childFocusSince(g, tag) >= 2) {
    return st[1];
  }
  return null;
}

/// 足した重点（[childFocusTags] の順）。
List<FocusDef> moreChildFocusOptions(Game g) {
  final tags = childFocusTags(g);
  return [for (final t in tags) _make(g, t)];
}

FocusDef _make(Game g, String tag) {
  final forced = _stageFor(g, tag);
  switch (tag) {
    case 'yumiba':
      return FocusDef('yumiba', '弓と馬の稽古に励む', '弓馬は武家の嗜み。落馬すれば怪我もする', (g) {
        g.l.bu = _c(g.l.bu + g.rng.range(1, 2));
        if (g.rng.chance(.3)) g.l.un = _c(g.l.un + 1);
        _hurt(g, g.rng.chance(.2) ? 5 : 1);
        g.j(1);
      }, forced: forced);
    case 'yakuso':
      return FocusDef('yakuso', '野山で薬草を摘む', '草木の効き目が分かってくる。似た草と取り違えることもある', (
        g,
      ) {
        if (g.rng.chance(.7)) g.l.chi = _c(g.l.chi + 1);
        if (g.rng.chance(.3)) g.l.un = _c(g.l.un + 1);
        if (g.rng.chance(.3)) g.l.gold += 1;
        g.l.hp = g.l.hp + 2 > g.l.maxhp ? g.l.maxhp : g.l.hp + 2;
      }, forced: forced);
    case 'uta':
      return FocusDef('uta', '歌と書を習う', '筆と言葉が美しくなる。墨と紙の代がかさむ', (g) {
        g.l.mi = _c(g.l.mi + g.rng.range(1, 2));
        if (g.rng.chance(.5)) g.l.chi = _c(g.l.chi + 1);
        _pay(g, 1);
        g.j(1);
      }, forced: forced);
    case 'komori':
      return FocusDef('komori', '弟妹の子守をする', '家は助かる。背中の子が泣きやまない日もある', (g) {
        g.l.mi = _c(g.l.mi + 1);
        g.l.net += 1;
        if (g.rng.chance(.3)) g.l.sei = _c(g.l.sei + 1);
        _hurt(g, 1);
        g.j(-1);
      }, forced: forced);
    case 'kawa':
      return FocusDef('kawa', '川で魚を獲る', '腹の足しになる。流れの速い日は危ない', (g) {
        g.l.hp = g.l.hp + 3 > g.l.maxhp ? g.l.maxhp : g.l.hp + 3;
        if (g.rng.chance(.4)) g.l.bu = _c(g.l.bu + 1);
        if (g.rng.chance(.4)) g.l.gold += 1;
        g.j(2);
      }, forced: forced);
    case 'tsukai':
      return FocusDef('tsukai', '市で使い走りをする', '顔が売れ、小銭も入る。ずるい大人もいる', (g) {
        g.l.net += g.rng.range(1, 2);
        if (g.rng.chance(.5)) g.l.sei = _c(g.l.sei + 1);
        g.l.gold += 1;
      }, forced: forced);
    default: // kyo
      return FocusDef('kyo', '経を覚える', '心が静まり、字も覚える。足はしびれる', (g) {
        g.l.chi = _c(g.l.chi + g.rng.range(1, 2));
        if (g.rng.chance(.3)) g.l.mi = _c(g.l.mi + 1);
        g.j(1);
      }, forced: forced);
  }
}

// ======================================================================
// 続けた年の岐路
// ======================================================================

/// 一の段。走らせた年を旗 `cf_at:<tag>:<歳>` に残す（二の段の間を見るため）。
SceneDef _first(String tag, void Function(Game g, void Function() next) run) =>
    SceneDef(kChildFocusStages[tag]![0], 5, 14, (g) => 1, (g) => true, (
      g,
      next,
    ) {
      g.setFlag('cf_at:$tag:${g.age}');
      run(g, next);
    }, onlyForced: true);

/// 二の段。一の段があり、二年以上あいたときだけ。
SceneDef _second(String tag, void Function(Game g, void Function() next) run) {
  final st = kChildFocusStages[tag]!;
  return SceneDef(
    st[1],
    5,
    14,
    (g) => 1,
    (g) => g.hasFlag('scene:${st[0]}') && childFocusSince(g, tag) >= 2,
    run,
    onlyForced: true,
  );
}

/// 子守をしている弟妹の名（一の段で決める）。
String _sibName(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('cf_sib_name:')) return f.substring(12);
  }
  return '弟';
}

List<SceneDef> buildChildFocusScenes() => [
  // ---------------------------------------------------------------- 弓と馬
  _first('yumiba', (g, next) {
    g.ask('雁を射る', '弓馬の師に連れられて、秋の野に出た。葦の上を、雁の列が渡っていく。「射てみよ」と、師が顎をしゃくった。', [
      Choice.h('狙いすまして放つ', '当たれば褒められる。外せば笑われる', () {
        if (g.rng.chance(.35 + g.l.bu / 150)) {
          g.l.bu = _c(g.l.bu + 2);
          g.l.fame += 2;
          g.setFlag('cf_yumi_praised');
          g.mark('弓の稽古で雁を射落とし、家中の大人たちの目に留まった');
          return '矢は列の一羽を射落とした。見ていた年配の侍が、あなたの名を尋ねた。';
        }
        g.j(-2);
        return '矢は葦の中に消えた。師は笑って、もう一本を渡した。';
      }),
      Choice.h('師に一の矢を譲る', '角は立たない。腕は見せられない', () {
        g.l.mi = _c(g.l.mi + 1);
        return '師の矢が雁を射落とした。「よう見ておけ」と言われた。';
      }),
      if (g.l.bu >= 45)
        Choice.h('飛び立つ瞬間を待って射る', '腕に覚えがあれば大物を狙える。焦れば逃す', () {
          if (g.rng.chance(.5 + g.l.bu / 300)) {
            g.l.bu = _c(g.l.bu + 3);
            g.l.fame += 4;
            g.setFlag('cf_yumi_praised');
            g.mark('弓の稽古で、飛び立つ雁を射落とし、家中の語り草になった');
            return '羽ばたいた一羽が、まっすぐ落ちてきた。師が、黙ってあなたの肩を叩いた。';
          }
          return '雁は高く舞い上がり、矢は空を切った。';
        }, via: '武'),
    ], after: next);
  }),
  _second('yumiba', (g, next) {
    final praised = g.hasFlag('cf_yumi_praised');
    g.ask(
      '笠懸',
      praised
          ? '雁を射落とした子がいると聞いて、重臣の一人が笠懸の催しにあなたを呼んだ。走る馬の上から、笠の的を射るのだ。'
          : '家中の笠懸の催しに、年少の者として加えられた。走る馬の上から、笠の的を射る。前の組の子が落馬して、馬場がざわついている。',
      [
        Choice.h('馬を存分に走らせて射る', '見事に当てれば名が上がる。落馬すれば大怪我だ', () {
          if (g.rng.chance(.3 + g.l.bu / 150 + (praised ? .1 : 0))) {
            g.l.fame += 4;
            g.l.bu = _c(g.l.bu + 2);
            if (praised) {
              g.setFlag('cf_kasagake_noticed');
              g.mark('笠懸で走る馬から的を射抜き、重臣に名を覚えられた');
            } else {
              g.mark('笠懸で、走る馬から的を射抜いた');
            }
            return '笠が弾け飛んだ。馬場の端で、大人たちがどよめいた。';
          }
          _hurt(g, 12);
          g.j(-3);
          return '体が宙に浮き、地面が迫った。しばらく息ができなかった。';
        }),
        Choice.h('手綱を緩め、確かに射る', '外しはしない。目立ちもしない', () {
          g.l.bu = _c(g.l.bu + 1);
          return '矢は的の端をかすめた。「慎重な子だ」と誰かが言った。';
        }),
        if (!praised)
          Choice.h('落馬した子に駆け寄る', '催しはそっちのけになる。その子の家には感謝される', () {
            g.l.net += 3;
            g.l.mi = _c(g.l.mi + 1);
            g.setFlag('cf_kasagake_helped');
            return '泥だらけの子を助け起こした。あとで、その子の父から丁寧な礼が届いた。';
          }),
        if (g.l.bu >= 55)
          Choice.h('的を続けざまに射る', '腕のある者だけの技だ。しくじれば恥をかく', () {
            if (g.rng.chance(.55)) {
              g.l.fame += 6;
              g.l.bu = _c(g.l.bu + 2);
              g.setFlag('cf_yumi_praised');
              g.setFlag('cf_kasagake_noticed');
              g.mark('笠懸で走る馬から的を続けざまに射抜き、家中の語り草になった');
              return '二つの笠が、続けて弾け飛んだ。重臣が膝を打った。';
            }
            g.j(-4);
            return '二の矢をつがえる間に、的は後ろへ流れていった。';
          }, via: '武'),
      ],
      after: next,
    );
  }),

  // ---------------------------------------------------------------- 薬草
  _first('yakuso', (g, next) {
    g.ask('似た草', '薬草を摘んでいると、籠の中に、見慣れた草とよく似た葉が混じっていた。葉の裏の色が、少し違う気がする。', [
      Choice.h('一枚ずつ葉の裏を確かめる', '時はかかる。見分けがつけば身になる', () {
        if (g.rng.chance(.45 + g.l.chi / 150)) {
          g.l.chi = _c(g.l.chi + 2);
          g.setFlag('cf_herb_knows');
          g.mark('薬草摘みで、薬になる草とならない草の見分けを覚えた');
          return '葉の裏が紫がかったものを、より分けて捨てた。';
        }
        g.l.chi = _c(g.l.chi + 1);
        return 'どれが違うのか、とうとう分からなかった。籠ごと捨てて帰った。';
      }),
      Choice.h('村の婆さまに見せに行く', '確かだ。婆さまは話が長い', () {
        g.l.chi = _c(g.l.chi + 1);
        g.l.net += 1;
        g.setFlag('cf_herb_knows');
        return '婆さまは一目見て「これは腹を下す草だ」と笑い、見分け方を教えてくれた。';
      }),
      Choice.h('構わず持ち帰る', '手間は省ける。取り違えていれば…', () {
        if (g.rng.chance(.5)) {
          g.j(-4);
          return '煎じて飲んだ父が、一晩じゅう腹を下した。';
        }
        return '幸い、混じっていたのは一枚だけだった。';
      }),
    ], after: next);
  }),
  _second('yakuso', (g, next) {
    final who = g.rng.pick(['父', '母', '弟', '妹']);
    final knows = g.hasFlag('cf_herb_knows');
    g.ask('家の者の熱', '$whoが高い熱を出した。祈祷の山伏は銭ばかり取って、熱は下がらない。', [
      if (knows)
        Choice.h('覚えた草を煎じて飲ませる', '見分けを覚えた手なら、効くかもしれない', () {
          if (g.rng.chance(.75 + g.l.chi / 400)) {
            g.l.chi = _c(g.l.chi + 2);
            g.l.fame += 2;
            g.l.net += 2;
            g.setFlag('cf_herb_healer');
            g.mark('幼い身で薬草を煎じ、$whoの熱を下げた');
            return '三日目の朝、$whoが粥をすすった。';
          }
          return '熱はなかなか引かなかったが、やがて$whoは自分の力で持ち直した。';
        })
      else
        Choice.h('思い当たる草を煎じてみる', '効けば家の者が助かる。見分けに自信はない', () {
          if (g.rng.chance(.35)) {
            g.setFlag('cf_herb_healer');
            g.mark('幼い身で薬草を煎じ、$whoの熱を下げた');
            return '苦い煎じ薬を飲ませた翌朝、$whoの額がひんやりしていた。';
          }
          g.j(-4);
          return '煎じ薬は苦いだけだった。$whoは、長く寝込んだ。';
        }),
      Choice.h('山伏の祈祷を続けてもらう', '家の者は安心する。銭が消える', () {
        _pay(g, 2);
        return '熱は、やがて引いた。山伏は得意げに帰っていった。';
      }),
      if (g.l.chi >= 50)
        Choice.h('草の名を書き付けて、町の薬師に見せに行く', '知恵が回れば確かな薬に行き着く。遠い道のりだ', () {
          _hurt(g, 4);
          g.l.chi = _c(g.l.chi + 3);
          g.setFlag('cf_herb_healer');
          g.mark('幼い身で町の薬師を訪ね、$whoの病に効く薬を持ち帰った');
          return '薬師は書き付けを見て目を丸くし、合う薬を分けてくれた。';
        }, via: '知'),
    ], after: next);
  }),

  // ---------------------------------------------------------------- 歌と書
  _first('uta', (g, next) {
    g.ask('子どもの歌の集まり', '母の縁で、近くの屋敷の歌の集まりに招かれた。子どもも一首ずつ詠めという。題は「初雪」。', [
      Choice.h('見たままの雪を詠む', '飾らぬ歌は、届く人には届く', () {
        if (g.rng.chance(.4 + g.l.mi / 200 + g.l.chi / 300)) {
          g.l.mi = _c(g.l.mi + 2);
          g.l.fame += 2;
          g.setFlag('cf_uta_praised');
          g.mark('子どもの歌の集まりで詠んだ初雪の歌が、大人たちに褒められた');
          return '読み上げられると、上座の奥方が扇を止めた。「もう一度」と言われた。';
        }
        g.l.mi = _c(g.l.mi + 1);
        return '年かさの姫の歌に、皆の目が集まった。';
      }),
      Choice.h('習った古い歌をなぞって詠む', '無難にまとまる。見抜かれれば恥ずかしい', () {
        if (g.rng.chance(.5)) {
          return '「よく覚えておる」と言われた。褒められたのか、分からなかった。';
        }
        g.j(-3);
        return '「どこかで聞いた歌じゃな」と笑われた。';
      }),
      if (g.l.chi >= 45)
        Choice.h('初雪に、母の白髪を掛けて詠む', '知恵の回る子にしか詠めない。外せば重い歌になる', () {
          if (g.rng.chance(.6)) {
            g.l.mi = _c(g.l.mi + 3);
            g.l.fame += 3;
            g.setFlag('cf_uta_praised');
            g.mark('初雪に母の白髪を掛けた幼い歌が、屋敷の奥方の目に留まった');
            return '座が静まり返った。母が、袖で目もとを押さえていた。';
          }
          g.j(-2);
          return '「子どもらしくない歌だ」と、誰かが眉をひそめた。';
        }, via: '知'),
    ], after: next);
  }),
  _second('uta', (g, next) {
    final praised = g.hasFlag('cf_uta_praised');
    final fancy = <Choice>[
      if (g.l.chi >= 55)
        Choice.h('漢字まじりの改まった文に仕立てる', '学のある子にしか書けない。読む人を驚かせる', () {
          g.l.chi = _c(g.l.chi + 2);
          g.l.fame += 2;
          g.setFlag('cf_fine_hand');
          g.mark('幼い身で、大人顔負けの改まった文を書き上げた');
          return '書き上げた文を見て、頼んだ人が、しばらく言葉を失っていた。';
        }, via: '知'),
    ];
    if (praised) {
      g.ask('文の清書', '歌の噂を聞いた屋敷の奥方から、文の清書を頼まれた。遠くの縁者へ送る、大事な文だという。', [
        Choice.h('一字ずつ心を込めて書く', '時はかかる。奥方の覚えはめでたくなる', () {
          g.l.mi = _c(g.l.mi + 1);
          g.l.sei = _c(g.l.sei + 1);
          g.setFlag('cf_fine_hand');
          g.mark('奥方に頼まれた文を清書し、手跡の美しさを褒められた');
          return '奥方は文を光にかざして、「よい手じゃ」と言った。';
        }),
        Choice.h('自分の歌を一首添える', '気に入られれば縁になる。出過ぎだと思われるかもしれない', () {
          if (g.rng.chance(.5)) {
            g.l.fame += 3;
            g.setFlag('cf_fine_hand');
            g.mark('奥方の文に一首を添え、その歌が遠くの縁者に喜ばれた');
            return 'しばらくして、遠くの縁者から「あの歌を詠んだ子は誰か」と返事が来た。';
          }
          g.j(-3);
          return '「子どもが差し出がましい」と、侍女に叱られた。';
        }),
        ...fancy,
      ], after: next);
      return;
    }
    g.ask('代わりの文', '近所の娘が、こっそり頼みに来た。好いた人へ送る文を、代わりに書いてほしいという。', [
      Choice.h('娘の気持ちを聞いて、言葉を整えて書く', '娘は喜ぶ。秘密を一つ抱えることになる', () {
        g.l.mi = _c(g.l.mi + 2);
        g.l.net += 2;
        g.setFlag('cf_fine_hand');
        g.mark('近所の娘の恋文を、こっそり代わりに書いてやった');
        return 'ひと月ほどして、娘が真っ赤な顔で礼を言いに来た。';
      }),
      Choice.h('自分で書けるよう、字を教える', '時はかかる。娘の字は娘のものになる', () {
        g.l.chi = _c(g.l.chi + 1);
        g.l.net += 3;
        return '下手な字だったが、娘は自分の手で書き上げた。';
      }),
      Choice.h('断る', '面倒はない。娘はがっかりする', () {
        g.j(-1);
        return '娘は肩を落として帰っていった。';
      }),
      ...fancy,
    ], after: next);
  }),

  // ---------------------------------------------------------------- 子守
  _first('komori', (g, next) {
    final female = g.rng.chance(.5);
    final name = g.rng.pick(female ? kGivenF : kGivenM);
    g.setFlag('cf_sib_name:$name');
    if (!g.l.people.containsKey('弟妹')) g.meet('弟妹', name, 45);
    g.ask('見失う', '幼い弟妹を背負い、もう一人の手を引いて畑の畦を歩いていた。ふと振り返ると、手を引いていたはずの$nameがいない。', [
      Choice.h('大声で呼びながら探し回る', '見つかるかもしれない。日が暮れれば…', () {
        if (g.rng.chance(.7 + g.l.un / 300)) {
          g.l.net += 1;
          g.setFlag('cf_sib_found');
          _bond(g, name, 10);
          return '用水の土手の下で、$nameが蛙を追っていた。泣きながら抱きしめた。';
        }
        g.j(-6);
        return '日暮れに、村の者が$nameを連れてきた。父にひどく叱られた。';
      }),
      Choice.h('大人を呼びに走る', '確かに見つかる。子守を任されなくなるかもしれない', () {
        g.l.net += 1;
        g.j(-2);
        return '村じゅうで探し、$nameは藪の中で眠っていた。';
      }),
      if (g.l.chi >= 45)
        Choice.h('小さな足跡をたどる', '目ざとい子なら、すぐに見つける', () {
          g.l.chi = _c(g.l.chi + 1);
          g.setFlag('cf_sib_found');
          _bond(g, name, 10);
          return '足跡は、川とは逆の祠の方へ続いていた。$nameは祠の陰で、供え物の団子を握っていた。';
        }, via: '知'),
    ], after: next);
  }),
  _second('komori', (g, next) {
    final name = _sibName(g);
    final me = g.l.female ? 'ねえちゃん' : 'にいちゃん';
    final found = g.hasFlag('cf_sib_found');
    g.ask(
      '子守の夜',
      '${found ? 'あの日、畦で見失ってから、$nameは片時もそばを離れない。' : ''}熱を出した夜、$nameがあなたの袖をつかんで離さない。「$me、どこにも行かないで」',
      [
        Choice.h('ずっとそばにいると約束する', '弟妹は心強い。約束は、いつか重くなる', () {
          _bond(g, name, 20);
          g.j(3);
          g.setFlag('cf_sib_promise');
          g.setFlag('cf_sib_close');
          g.mark('子守をしてきた$nameに、ずっとそばにいると約束した');
          return '$nameは、あなたの指を握ったまま眠った。';
        }),
        Choice.h('昔話を聞かせて寝かしつける', '夜は穏やかに過ぎる', () {
          _bond(g, name, 10);
          g.l.mi = _c(g.l.mi + 1);
          if (found) g.setFlag('cf_sib_close');
          return '狐と狸の話の途中で、寝息が聞こえてきた。';
        }),
        Choice.h('大きくなったら自分の足で歩けと言い聞かせる', '弟妹は強くなる。寂しがるかもしれない', () {
          _bond(g, name, 5);
          g.setFlag('cf_sib_strong');
          g.mark('子守をしてきた$nameに、自分の足で歩けと言い聞かせた');
          return '$nameは口をとがらせたが、こくりとうなずいた。';
        }),
        if (g.l.mi >= 50)
          Choice.h('村の子らを集めて、交代で看る段取りをつける', '人をまとめる才があれば、誰も無理をせずに済む', () {
            g.l.net += 3;
            g.l.mi = _c(g.l.mi + 2);
            _bond(g, name, 10);
            g.setFlag('cf_sib_close');
            g.setFlag('cf_komori_leader');
            g.mark('村の子らを集めて、熱を出した弟妹を交代で看た');
            return '子らは代わるがわる、$nameの額の手ぬぐいを替えた。';
          }, via: '魅'),
      ],
      after: next,
    );
  }),

  // ---------------------------------------------------------------- 川
  _first('kawa', (g, next) {
    g.ask('淵の大鯉', '川の淵に仕掛けた籠に、見たこともない大きな鯉がかかっていた。暴れるたびに、籠が流れに引きずられていく。', [
      Choice.h('一人で籠ごと引き上げる', '獲れれば村じゅうの話の種だ。足を滑らせれば淵に落ちる', () {
        if (g.rng.chance(.4 + g.l.bu / 150)) {
          g.l.bu = _c(g.l.bu + 2);
          g.l.gold += 2;
          g.setFlag('cf_big_fish');
          g.mark('川の淵で、大人の腕ほどもある鯉を一人で引き上げた');
          return '鯉を抱えて帰ると、村の者が集まってきた。';
        }
        _hurt(g, 8);
        return '籠の縄が切れ、鯉は淵の底へ戻っていった。ずぶ濡れで帰った。';
      }),
      Choice.h('仲間を呼んで皆で引く', '確かに獲れる。分け前は減る', () {
        g.l.net += 2;
        g.l.gold += 1;
        g.setFlag('cf_big_fish');
        return '五人がかりで引き上げ、その晩は皆の家で鯉こくを食べた。';
      }),
      Choice.h('逃がしてやる', '淵の主だという者もいる', () {
        g.l.un = _c(g.l.un + 2);
        g.setFlag('cf_freed_koi');
        return '鯉はしばらく浅瀬にとどまってから、ゆっくり淵へ帰っていった。';
      }),
    ], after: next);
  }),
  _second('kawa', (g, next) {
    g.ask(
      '水の匂い',
      '上の山に黒い雲がかかっている。川はまだ澄んでいるが、さっきから水の匂いが変わった。下の河原では、村の子らが遊んでいる。',
      [
        Choice.h('仕掛けた籠を急いで上げに行く', '籠は惜しい。川はすぐに牙をむく', () {
          if (g.rng.chance(.03)) {
            g.die('増水した川へ仕掛けを上げに入り、流れに呑まれた', 'sai');
            return '足もとの石が、急に動いた。';
          }
          g.l.gold += 1;
          return '籠を抱えて土手を駆け上がると、背後で水音が変わった。';
        }),
        Choice.h('河原の子らに逃げろと叫ぶ', '子らは助かるかもしれない。笑われるかもしれない', () {
          if (g.rng.chance(.6 + g.l.chi / 200)) {
            g.l.fame += 3;
            g.l.net += 3;
            g.setFlag('cf_read_river');
            g.mark('川の水の匂いが変わったのに気づき、河原の子らを逃がした');
            return '皆が土手に上がったところへ、茶色い水が押し寄せた。';
          }
          g.j(-2);
          return '「まだ晴れておる」と子らは笑った。水が出たのは、皆が帰ったあとだった。';
        }),
        Choice.h('家へ帰って大人に知らせる', '確かだ。間に合うかは分からない', () {
          g.l.net += 1;
          return '大人が河原へ下りたときには、子らはもう帰り支度をしていた。';
        }),
        if (g.hasFlag('cf_freed_koi'))
          Choice.h('鯉を逃がした淵へ走る', '淵の様子で、水の出方が分かる気がする', () {
            g.l.un = _c(g.l.un + 2);
            g.l.fame += 2;
            g.setFlag('cf_read_river');
            g.mark('逃がした鯉の淵の濁りを見て、大水を言い当てた');
            return '淵は、もう濁り始めていた。走って戻り、村じゅうに触れて回った。';
          }),
      ],
      after: next,
    );
  }),

  // ---------------------------------------------------------------- 市の使い
  _first('tsukai', (g, next) {
    g.ask('軽い銭袋', '使いの帰り、預かった銭の袋が、いつの間にか軽い。振り返ると、さっきぶつかってきた男が人混みに消えていく。', [
      Choice.h('追いかける', '取り返せるかもしれない。相手は大人だ', () {
        if (g.rng.chance(.35 + g.l.bu / 200 + g.l.un / 300)) {
          g.l.fame += 2;
          g.setFlag('cf_errand_trusted');
          g.mark('市の使いで、銭をすった男を追いかけて取り返した');
          return '路地の奥で男の袖にかじりつくと、男は銭袋を放り出して逃げた。';
        }
        _hurt(g, 6);
        return '路地で突き飛ばされ、男は消えた。';
      }),
      Choice.h('店に戻って正直に話す', '叱られる。嘘はつかずに済む', () {
        g.setFlag('cf_errand_trusted');
        g.j(-3);
        return '主人は長いこと黙っていたが、「正直に戻ってきたのはえらい」と言った。';
      }),
      Choice.h('自分の小遣いで穴を埋める', '誰にも知られない。懐は空になる', () {
        _pay(g, 2);
        return '黙って穴を埋めた。誰も気づかなかった。';
      }),
      if (g.l.mi >= 45)
        Choice.h('市の顔なじみに声をかけ、男の行方を尋ねる', '顔の広い子なら、手はある', () {
          g.l.net += 2;
          g.setFlag('cf_errand_trusted');
          g.setFlag('cf_market_face');
          g.mark('市の顔なじみの手を借り、すりから銭を取り戻した');
          return '団子屋の婆さまが男の塒を知っていた。男は、渋々銭を返した。';
        }, via: '魅'),
    ], after: next);
  }),
  _second('tsukai', (g, next) {
    if (g.hasFlag('cf_errand_trusted')) {
      g.ask('大店の座敷', '使いの正直さを聞いた大店の主人が、あなたを座敷に呼んだ。「うちで奉公せぬか。いずれは帳場を任せてもよい」', [
        Choice.h('大店で奉公すると決める', '商いの道が開ける。家からは離れる', () {
          g.l.sei = _c(g.l.sei + 3);
          g.l.gold += 2;
          g.setFlag('cf_ootana_offer');
          g.mark('使いの正直さを買われ、大店の主人に奉公を望まれた');
          return '主人は「よし」と膝を打ち、番頭に引き合わせた。';
        }),
        Choice.h('親を手伝いたいと断る', '親は喜ぶ。大店の主人は惜しがる', () {
          g.j(2);
          g.setFlag('cf_ootana_kept');
          return '主人は「惜しいのう」と笑い、菓子を持たせて帰した。';
        }),
        if (g.l.sei >= 50)
          Choice.h('奉公より、品の目利きを教えてほしいと頼む', '銭勘定に強い子なら、主人を面白がらせる', () {
            g.l.sei = _c(g.l.sei + 3);
            g.l.chi = _c(g.l.chi + 1);
            g.setFlag('cf_ootana_offer');
            g.mark('大店の主人に、品の目利きの手ほどきを受けた');
            return '主人は面白がって、反物の良し悪しを一つずつ見せてくれた。';
          }, via: '政'),
      ], after: next);
      return;
    }
    g.ask('立ち聞き', '使いの途中、大店の番頭たちの内緒話が聞こえてしまった。明日、米の値が上がるという。', [
      Choice.h('親に知らせて米を買っておく', '家が儲かる。番頭に知れれば困ったことになる', () {
        g.l.gold += 3;
        g.j(1);
        return '次の日、米の値は本当に上がった。父は、あなたの頭をなでた。';
      }),
      Choice.h('聞かなかったことにする', '何も起きない', () => '黙って使いを済ませた。'),
      Choice.h('番頭に、聞こえてしまったと告げる', '正直は損かもしれない。番頭は覚えている', () {
        g.l.net += 2;
        g.setFlag('cf_errand_trusted');
        return '番頭は目を丸くしてから、口止めに飴をくれた。「お前は正直者だな」';
      }),
    ], after: next);
  }),

  // ---------------------------------------------------------------- 経
  _first('kyo', (g, next) {
    g.ask('代わりの経', '和尚が風邪で寝込んだ日、村の年寄りが亡くなった。「お前が経をあげてこい」と、和尚が床の中から言った。', [
      Choice.h('覚えた経を最後まで読む', '途中でつかえれば恥をかく。読み通せば一人前に近づく', () {
        if (g.rng.chance(.4 + g.l.chi / 150)) {
          g.l.chi = _c(g.l.chi + 2);
          g.l.fame += 2;
          g.setFlag('cf_sutra_read');
          g.mark('寝込んだ和尚の代わりに、幼い身で弔いの経を読み通した');
          return '声は細かったが、最後まで読み通した。遺族が深々と頭を下げた。';
        }
        g.j(-3);
        return '半ばでつかえた。遺族は黙って手を合わせてくれた。';
      }),
      Choice.h('短い経だけを心を込めて読む', '長くはない。遺族の顔を見て読める', () {
        g.l.mi = _c(g.l.mi + 2);
        g.setFlag('cf_sutra_read');
        return '短い経を、ゆっくりと読んだ。年寄りの娘が、何度も頭を下げた。';
      }),
      Choice.h('兄弟子に代わってもらう', '恥はかかずに済む。和尚は少しがっかりする', () {
        g.j(-1);
        return '兄弟子は「次はお前だぞ」と言って出かけていった。';
      }),
    ], after: next);
  }),
  _second('kyo', (g, next) {
    final read = g.hasFlag('cf_sutra_read');
    g.ask(
      '枕元の経',
      read
          ? '弔いの経を読んだ子がいると聞いて、村はずれの老いた侍が、死ぬ前にあなたの経を聞きたいと言ってきた。'
          : '寺に、行き倒れの旅の男が担ぎ込まれた。もう長くはない。和尚は留守だ。',
      [
        Choice.h('枕元で経を読む', '死にゆく人の心は静まるかもしれない', () {
          g.l.mi = _c(g.l.mi + 2);
          g.setFlag('cf_sutra_comfort');
          g.mark('死にゆく人の枕元で、幼い身で経を読んで看取った');
          return read ? '老いた侍は目を閉じたまま、経の終わりにかすかにうなずいた。' : '男の息は、経の半ばで静かになった。';
        }),
        Choice.h('経より、手を握って話を聞く', '経は読めない。残す言葉を聞ける', () {
          g.l.mi = _c(g.l.mi + 1);
          g.l.net += 1;
          g.setFlag('cf_sutra_listened');
          g.mark('死にゆく人の手を握り、残す言葉を聞いた');
          return read ? '老いた侍は、若い日に討った敵の名を、一つずつ口にした。' : '男は、国に残した娘の名を、何度も呼んだ。';
        }),
        if (g.l.chi >= 55)
          Choice.h('経の意味を、やさしい言葉で説いて聞かせる', '学のある子にしか説けない。死にゆく人の顔が和らぐ', () {
            g.l.chi = _c(g.l.chi + 2);
            g.l.fame += 3;
            g.setFlag('cf_sutra_comfort');
            g.setFlag('cf_sutra_preached');
            g.mark('死にゆく人に、経の意味をやさしく説いて聞かせた');
            return '話し終えると、その人は「そうか、そうか」と笑った。';
          }, via: '知'),
      ],
      after: next,
    );
  }),
];

void _bond(Game g, String name, int n) {
  final p = g.l.people['弟妹'];
  if (p != null && p.name == name) p.bond = _c100(p.bond + n);
}

// ======================================================================
// 大人になってから返ってくる岐路（伏線の回収 その4、`e4_`）
// ======================================================================

bool _monk(Game g) => g.hasFlag('priesthood');
bool _outlaw(Game g) => g.hasFlag('way_outlaw');

/// 主家に仕える身（大名その人は除く）。
bool _retainer(Game g) =>
    g.l.rank >= 1 &&
    g.l.rank <= 7 &&
    g.active &&
    !_monk(g) &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

bool _samurai(Game g) => _retainer(g) && g.canFight;

/// 身分のない暮らし（仏門・野の道を除く）。
bool _commoner(Game g) => g.l.rank == 0 && g.active && !_monk(g) && !_outlaw(g);

String? _strongest(Game g) {
  final a = g.alive;
  if (a.isEmpty) return null;
  final near = nearest(a, (f) => f.name, region: g.l.region, n: 3)
    ..sort((x, y) => y.power.compareTo(x.power));
  return near.first.name;
}

void _join(Game g, String lord) {
  final l = g.l;
  l.lord = lord;
  if (l.rank < 1) l.rank = 1;
  if (l.rank > l.maxRank) l.maxRank = l.rank;
  l.fav = 25;
  l.ronin = false;
}

List<SceneDef> buildChildFocusEchoScenes() => [
  // 雁を射落とした（cf_yumi_praised）→ 弓の巧者として呼ばれる。
  SceneDef(
    'e4_yumi',
    18,
    45,
    (g) => 6,
    (g) =>
        g.hasFlag('cf_yumi_praised') &&
        !g.l.female &&
        (_samurai(g) ||
            (_commoner(g) &&
                !g.hasFlag('way_merchant') &&
                _strongest(g) != null)),
    (g, next) {
      final noticed = g.hasFlag('cf_kasagake_noticed');
      if (_samurai(g)) {
        g.ask(
          '遠矢の座',
          '家中の弓の巧者を集め、殿の前で遠矢を競わせることになった。「幼い日に雁を射落とした者がおったな」と、${noticed ? 'あの笠懸の日の重臣' : '年配の侍'}があなたの名を挙げた。',
          [
            Choice.h('遠矢の座に出る', '当たれば殿の覚えがめでたい。外せば昔話は昔話で終わる', () {
              if (g.rng.chance(.4 + g.l.bu / 200 + (noticed ? .1 : 0))) {
                g.l.merit += 8;
                g.l.fav = _c100(g.l.fav + 6);
                g.l.fame += 4;
                g.setFlag('e4_yumi_archer');
                g.mark('殿の前の遠矢で、幼い日の弓の噂に違わぬ腕を見せた');
                return '矢は遠い的の真ん中に立った。殿が、手ずから盃を取らせた。';
              }
              g.l.fav = _c100(g.l.fav - 2);
              return '矢は的の手前に落ちた。「昔の話よ」と、誰かが笑った。';
            }),
            Choice.h('若い者に座を譲る', '面目は保たれる。腕は見せられない', () {
              g.l.net += 2;
              return '若い者たちが、あなたに頭を下げてから弓を取った。';
            }),
          ],
          after: next,
        );
        return;
      }
      final lord = _strongest(g)!;
      final h = houseName(g, lord);
      g.ask(
        '弓の噂',
        '近くの$h家が、弓の巧者を求めているという。あなたが子どもの頃、雁を射落としたのを覚えている者がいて、名を伝えてくれた。',
        [
          Choice.h('弓を携えて名乗り出る', '召し抱えられるかもしれない。腕が落ちていれば恥をかく', () {
            if (g.rng.chance(.45 + g.l.bu / 250 + (noticed ? .1 : 0))) {
              _join(g, lord);
              g.l.fame += 3;
              g.setFlag('e4_yumi_archer');
              g.mark('幼い日の弓の噂を頼りに名乗り出て、$h家の弓組に召し抱えられた');
              return '試しの的を三つとも射抜くと、物頭が「明日から来い」と言った。';
            }
            g.j(-3);
            return '弓を引く腕が、思ったより鈍っていた。';
          }),
          Choice.h('いまの暮らしを選ぶ', '何も変わらない', () => '弓は、壁に掛けたままにした。'),
        ],
        after: next,
      );
    },
  ),

  // 薬草で家の者の熱を下げた（cf_herb_healer）→ 熱病の村に頼られる。
  SceneDef(
    'e4_herb',
    18,
    70,
    (g) => 6,
    (g) => g.hasFlag('cf_herb_healer') && g.active,
    (g, next) {
      g.ask('熱の出た村', '近くの村に熱病が出た。「子どもの頃、薬草で家の者の熱を下げた者がいる」と、村の者があなたを頼ってきた。', [
        Choice.h('薬草を摘んで煎じて回る', '多くの者が助かるかもしれない。病をもらうこともある', () {
          if (g.rng.chance(.03)) {
            g.die('熱の出た村で薬草を煎じて回るうちに、自らも熱に倒れた');
            return '幾晩めかに、自分の額が熱いのに気づいた。';
          }
          g.l.fame += 5;
          g.l.net += 4;
          g.setFlag('e4_herb_saved');
          g.mark('熱の出た村で、幼い日に覚えた薬草を煎じて回った');
          return '十日ほどで、熱は村から引いていった。';
        }),
        Choice.h('煎じ方だけを教える', '身は守れる。助かる数は減る', () {
          g.l.net += 2;
          g.setFlag('e4_herb_taught');
          return '村の女たちに草の見分け方と煎じ方を教え、帰った。';
        }),
        Choice.h('関わらない', '何も起きない。村の者はがっかりする', () {
          g.j(-2);
          return '使いの者は、肩を落として帰っていった。';
        }),
        if (g.l.chi >= 60)
          Choice.h('病の者と元気な者の寝床を分けさせる', '知恵の回る人なら、病の広がりを止められるかもしれない', () {
            g.l.fame += 6;
            g.l.net += 3;
            g.setFlag('e4_herb_saved');
            g.mark('熱の出た村で、病の者の寝床を分けさせて広がりを止めた');
            return '病の者を寺の庫裏に移すと、新しく倒れる者がぴたりと減った。';
          }, via: '知'),
      ], after: next);
    },
  ),

  // 歌と書を褒められた（cf_uta_praised / cf_fine_hand）→ 文を任される。
  SceneDef(
    'e4_uta',
    16,
    55,
    (g) => 6,
    (g) =>
        g.l.female &&
        g.active &&
        (g.hasFlag('cf_uta_praised') || g.hasFlag('cf_fine_hand')),
    (g, next) {
      if (_retainer(g)) {
        g.ask('奥の文', '奥方が、殿の名で出す文の清書をする者を探している。「幼い頃から手跡が美しいと聞く」と、あなたが呼ばれた。', [
          Choice.h('文の役を務める', '奥の要に近づく。文の中身を知りすぎることもある', () {
            g.l.fav = _c100(g.l.fav + 6);
            g.l.merit += 5;
            g.setFlag('e4_uta_scribe');
            g.mark('手跡の美しさを買われ、奥方の文の清書を任された');
            return '奥方はあなたの書いた文を読み返し、「これなら先方も喜ぼう」と言った。';
          }),
          Choice.h('歌の会の取り持ちだけを引き受ける', '気楽に務まる。奥の要からは遠い', () {
            g.l.net += 3;
            g.j(3);
            return '歌の会の席を整える役になった。奥の女たちとの縁が深まった。';
          }),
          Choice.h('身に余ると辞退する', '何も起きない。奥方は少し残念がる', () {
            g.l.fav = _c100(g.l.fav - 1);
            return '奥方は「そうか」とだけ言った。';
          }),
        ], after: next);
        return;
      }
      g.ask(
        '娘たちの文',
        '近くの娘たちが、嫁いだ先や遠くの親へ送る文を書いてほしいと、代わるがわる頼みに来る。幼い頃の手跡の噂を、誰かが覚えていたらしい。',
        [
          Choice.h('頼まれるままに書いてやる', '頼りにされる。礼の品が届く', () {
            g.l.net += 4;
            g.l.gold += 2;
            g.setFlag('e4_uta_letters');
            g.mark('近くの娘たちに頼まれ、遠くへ送る文を書いてやった');
            return '礼に、干し柿や手拭いが、縁側に置かれるようになった。';
          }),
          Choice.h('娘たちを集めて、字と歌を教える', '時はかかる。字は娘たちのものになる', () {
            g.l.net += 5;
            g.l.mi = _c(g.l.mi + 1);
            g.setFlag('e4_uta_teacher');
            g.mark('近くの娘たちを集めて、字と歌を教えた');
            return '縁側に机を並べると、思ったより多くの娘が集まった。';
          }),
          Choice.h('忙しいと断る', '何も起きない', () => '娘たちは、別の書き手を探しに行った。'),
        ],
        after: next,
      );
    },
  ),

  // 子守をした弟妹（cf_sib_close / cf_sib_strong）→ 大人になった弟妹が訪ねてくる。
  SceneDef(
    'e4_sib',
    20,
    55,
    (g) => 6,
    (g) =>
        g.active && (g.hasFlag('cf_sib_close') || g.hasFlag('cf_sib_strong')),
    (g, next) {
      final name = _sibName(g);
      final me = g.l.female ? 'ねえさま' : 'にいさま';
      if (g.hasFlag('cf_sib_promise')) {
        g.ask(
          '弟妹の頼み',
          '$nameが、やつれた顔で訪ねてきた。「あのとき、そばにいると言ってくれた」。借りた銭が返せず、村にいられなくなったという。',
          [
            Choice.h('銭を出して助ける', '約束は果たせる。懐は痛む', () {
              _pay(g, 8);
              g.j(2);
              _bond(g, name, 10);
              g.setFlag('e4_sib_helped');
              g.mark('子守をして育てた$nameの借りを、代わりに返してやった');
              return '$nameは、あなたの手を握って泣いた。';
            }),
            Choice.h('一緒に暮らそうと迎え入れる', '家はにぎやかになる。食い扶持は増える', () {
              if (!g.l.people.containsKey('弟妹') ||
                  g.l.people['弟妹']!.name == name) {
                g.meet('弟妹', name, 80);
              }
              g.j(4);
              g.setFlag('e4_sib_helped');
              g.mark('子守をして育てた$nameを、家に迎え入れた');
              return '$nameは翌日から、誰より早く起きて水を汲んだ。';
            }),
            Choice.h('自分の力で返せと突き放す', '約束は破れる。弟妹は強くなるかもしれない', () {
              g.j(-5);
              _bond(g, name, -20);
              g.setFlag('e4_sib_refused');
              return '$nameは黙って頭を下げ、二度と振り返らなかった。';
            }),
          ],
          after: next,
        );
        return;
      }
      g.ask(
        '弟妹の礼',
        '$nameが、見違えるほど立派になって訪ねてきた。「$meに背負われた背中を、いまも覚えています」。手土産に、米と酒を持っている。',
        [
          Choice.h('酒を酌み交わす', '懐かしい夜になる', () {
            g.j(6);
            _bond(g, name, 10);
            g.setFlag('e4_sib_grown');
            g.mark('子守をして育てた$nameが、一人前になって礼に来た');
            return '畦で泣いていた子の話をすると、$nameは顔を赤くした。';
          }),
          Choice.h('困りごとはないかと尋ねる', '頼られるかもしれない。頼れるかもしれない', () {
            g.l.net += 3;
            g.l.gold += 3;
            return '$nameは笑って、「困っているのは$meのほうでしょう」と銭を置いていった。';
          }),
          Choice.h('昔の話はよせと照れる', '気恥ずかしさは残る', () {
            g.j(2);
            return '$nameは、それでも子守唄を口ずさんでいた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // 川の匂いで大水を言い当てた（cf_read_river）→ 大人になって、ふたたび大水。
  SceneDef(
    'e4_river',
    20,
    75,
    (g) => 6,
    (g) => g.hasFlag('cf_read_river') && g.active,
    (g, next) {
      const head = '長雨が続いている。上の山に、幼い日に見たのと同じ黒い雲がかかった。川の水の匂いが、あの日と同じに変わった。';
      if (_samurai(g)) {
        g.ask('河原の陣', '$headちょうど、河原に陣を敷けと命が下ったところだった。', [
          Choice.h('陣を高みへ移すよう進言する', '当たれば大勢が助かる。外れれば臆病者と言われる', () {
            if (g.rng.chance(.6 + g.l.chi / 300)) {
              g.l.merit += 10;
              g.l.fav = _c100(g.l.fav + 6);
              g.l.fame += 4;
              g.setFlag('e4_river_saved');
              g.mark('河原の陣に大水を言い当て、陣を高みへ移させた');
              return 'その夜、河原は濁流に沈んだ。物頭が、黙ってあなたに頭を下げた。';
            }
            g.l.fav = _c100(g.l.fav - 4);
            return '水は出なかった。「川の匂いで陣を動かすとは」と笑われた。';
          }),
          Choice.h('黙って命に従う', '咎めはない。水が出れば…', () {
            _hurt(g, 10);
            return '夜半に水が出た。泥にまみれて、ようやく土手へ逃げた。';
          }),
        ], after: next);
        return;
      }
      g.ask('大水の兆し', head, [
        Choice.h('村じゅうに触れて回る', '当たれば村が救われる。外れれば笑い者だ', () {
          if (g.rng.chance(.65 + g.l.chi / 300)) {
            g.l.fame += 5;
            g.l.net += 5;
            g.setFlag('e4_river_saved');
            g.mark('幼い日と同じ川の匂いに気づき、大水の前に人々を高みへ逃がした');
            return '皆が高みへ上がった夜、川はあふれた。流されたのは、空の家と畑だけだった。';
          }
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          return '水は出なかった。しばらく、川の匂いをかぐ真似をされた。';
        }),
        Choice.h('家の者だけ連れて逃げる', '家の者は助かる。人々は恨むかもしれない', () {
          g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
          g.j(-2);
          return '高みから見下ろすと、川が村の端をなめていくのが見えた。';
        }),
      ], after: next);
    },
  ),

  // 市の使いで正直を買われた（cf_ootana_offer / cf_errand_trusted）→ 大店の跡取りの頼み。
  SceneDef(
    'e4_ootana',
    20,
    60,
    (g) => 6,
    (g) =>
        (g.hasFlag('cf_ootana_offer') || g.hasFlag('cf_errand_trusted')) &&
        g.l.rank == 0 &&
        g.active &&
        !_monk(g) &&
        !_outlaw(g),
    (g, next) {
      final offer = g.hasFlag('cf_ootana_offer');
      g.ask(
        '大店の跡取り',
        '市の大店の主人が亡くなり、跡を継いだ息子が訪ねてきた。${offer ? '幼い日に奉公を望まれた、あの大店だ。' : ''}「父は、あなたの正直を最後まで褒めていました」。店の帳場が乱れ、助けがほしいという。',
        [
          Choice.h('帳場を見てやる', '店は持ち直すかもしれない。自分の暮らしの時が削られる', () {
            g.l.sei = _c(g.l.sei + 2);
            g.l.gold += 6;
            g.l.net += 3;
            g.setFlag('e4_ootana_helped');
            g.mark('幼い日に正直を買ってくれた大店の帳場を、跡取りのために立て直した');
            return '半年ほどで、帳場は元のように回り始めた。';
          }),
          Choice.h('銭を貸す', '恩は売れる。返ってくるかは分からない', () {
            if (g.l.gold < 6) return '貸せるほどの銭がなかった。跡取りは「お気持ちだけで」と帰った。';
            g.l.gold -= 6;
            if (g.rng.chance(.6)) {
              g.l.gold += 12;
              return '翌年、跡取りは利をつけて返しに来た。';
            }
            return '店は持ち直さず、銭は戻らなかった。';
          }),
          Choice.h('断る', '何も起きない', () => '跡取りは、別の者を頼りに行った。'),
          if (g.l.sei >= 60)
            Choice.h('番頭を一人ずつ呼んで帳面を突き合わせる', '銭勘定に強い人なら、帳場の穴を見つけられる', () {
              g.l.fame += 4;
              g.l.gold += 8;
              g.setFlag('e4_ootana_helped');
              g.mark('大店の帳面の穴を突き止め、番頭の不正を暴いた');
              return '三人目の番頭が、帳面を前に青ざめた。';
            }, via: '政'),
        ],
        after: next,
      );
    },
  ),

  // 死にゆく人の枕元にいた（cf_sutra_comfort / cf_sutra_listened）→ 野の骸・行き倒れを弔う。
  SceneDef(
    'e4_sutra',
    18,
    70,
    (g) => 5,
    (g) =>
        (g.hasFlag('cf_sutra_comfort') || g.hasFlag('cf_sutra_listened')) &&
        g.active,
    (g, next) {
      final war = _samurai(g);
      g.ask(
        '野の弔い',
        war
            ? '合戦のあと、野に朋輩の骸が並んでいる。弔う僧はまだ来ない。幼い日、死にゆく人の枕元に座ったことを思い出した。'
            : '街道で、行き倒れの旅人を見つけた。もう息が細い。幼い日、寺で同じように看取ったことを思い出した。',
        [
          Choice.h('経を読んで弔う', '死者は浮かばれる。先を急ぐ身には遅れになる', () {
            g.l.mi = _c(g.l.mi + 2);
            g.l.fame += 3;
            g.setFlag('e4_sutra_mourned');
            g.mark(war ? '合戦のあとの野で、朋輩の骸に経を読んで弔った' : '行き倒れの旅人を、経を読んで看取った');
            return war
                ? '経を読み始めると、ひとり、またひとりと、朋輩たちが手を合わせた。'
                : '旅人は、経の終わりに、かすかに唇を動かした。';
          }),
          Choice.h('名を聞いて、国へ知らせると約束する', '遺された者に届くかもしれない。手間はかかる', () {
            g.l.net += 3;
            g.setFlag('e4_sutra_named');
            return war
                ? '骸の腰の札を一つずつ読み、名を書き留めた。'
                : '旅人は、国と娘の名を言い残した。あとで、文を書いて送った。';
          }),
          Choice.h('手を合わせて先を急ぐ', '何も起きない', () => '一度だけ振り返り、また歩き出した。'),
        ],
        after: next,
      );
    },
  ),
];
