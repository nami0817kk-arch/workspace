import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'rng.dart';

/// 大名・天下に手が届く者（位8）の年の岐路（2026-11-24）。id・旗は `dm_`。
///
/// `lords.dart` の大名23・天下8の岐路（分国法・楽市・国中の検地・金山・南蛮船の寄港・一向一揆・大寺の寺領・盟約の破り時・
/// 人質の処遇・降将・名城・兵と百姓・鉄砲・官位・将軍家の御内書・世継ぎ・弟の挙兵・院政・側室・名物・本音・旧友の内通・主の病／
/// 最後の大敵・朝廷の内意・天下の普請・国替え・海の向こう・幼い世継ぎ・猜疑・頂の孤独）と、`adult.dart` の
/// 重臣の不穏・同盟の申し出・領内の不作、`castle_life.dart`（`cl_`）とは題材を変えてある。
/// 前の段の旗がなければ次の段が出ない「筋」を持つ（[kDaimyoPrev]）。段を踏んだ年は旗 `dm_at:<筋>:<年>` に残し、
/// 次の段は何年か空けてから出す（[kDaimyoGap]）。
///
/// - 領国: 関所／大河の治水 → 川沿いの葦原か、また破れた堤／居を移して町を開く → 町の大火か、去りたい商人／
///   国人衆の所領／徳政の訴え／悪銭と撰銭。
/// - 外交: 縁組の網 → 嫁ぎ先の家の揺れ／都落ちの公家 → 勅使の和か、見下す隣家／南蛮の教え → 洗礼のその後／
///   敵の重臣の調略 → 寝返った将か遺された子／盟友の援軍。
/// - 家中: 身分を問わぬ取り立て → 取り立てた者のその後／一門の長老の叔父 → 叔父の最期・企て・文／恩賞の地。
/// - 天下に手が届く者（勢力の割合が三割から）: 都の仕置き／私の戦を禁じる命 → 背いた家／天下の居城の地／湊町の豪商／故郷からの文。
/// - 女の当主（女大名・後見に立った正室）: 女主への侮り → そのあと／婿の話／後見してきた当主の元服。
/// - 位は動かさない。勢力（主家の `power`）・銭・名声・人の縁で返し、合戦は `Game.battle` を通す。
/// - 能力（知・政・魅）が高いと出る手や、低いとしくじりやすい手がある。

// ---------------------------------------------------------------- 誰に出るか

/// 一国の主として家を治めている（位8・隠居でない・仏門でない・家が生きている）。
bool dmLord(Game g) =>
    g.l.rank == 8 &&
    g.active &&
    !g.hasFlag('priesthood') &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 天下に手が届く者（勢力の割合が三割から。`lords.dart` の天下の岐路と同じ目安）。
bool dmNear(Game g) => dmLord(g) && g.share >= .3;

/// 女の当主（女大名・後見に立った正室）。
bool dmWoman(Game g) => dmLord(g) && g.l.female;

/// 幼い当主の後見に立った女性。
bool dmRegent(Game g) =>
    dmWoman(g) && g.l.path.any((p) => p.contains('後見として'));

/// この岐路が出てよい人。テストも使う。
bool dmLife(Game g) => dmLord(g);

// ---------------------------------------------------------------- 筋

/// 筋の後段 → その前の段で立つ旗（どれか一つがあれば出られる）。テストも使う。
const kDaimyoPrev = <String, List<String>>{
  'dm_chisui_after': ['dm_chisui_big', 'dm_chisui_small', 'dm_chisui_kasumi', 'dm_chisui_none'],
  'dm_joka_after': ['dm_joka_moved', 'dm_joka_stayed'],
  'dm_konin_after': ['dm_konin_strong', 'dm_konin_weak'],
  'dm_kuge_after': ['dm_kuge_host', 'dm_kuge_sent'],
  'dm_senrei_after': ['dm_kirishitan', 'dm_senrei_allow', 'dm_senrei_refuse'],
  'dm_choryaku_after': ['dm_cho_turned', 'dm_cho_rumor'],
  'dm_toritate_after': ['dm_tori_castle', 'dm_tori_slow'],
  'dm_ichimon_after': ['dm_ichi_honored', 'dm_ichi_cut', 'dm_ichi_far'],
  'dm_t_bujirei_after': ['dm_t_buji', 'dm_t_buji_none'],
  'dm_w_anadori_after': ['dm_w_scolded', 'dm_w_yielded', 'dm_w_proved', 'dm_w_young'],
};

/// 筋の後段 → (筋の名, 前の段から空ける年)。
const kDaimyoGap = <String, (String, int)>{
  'dm_chisui_after': ('chisui', 2),
  'dm_joka_after': ('joka', 3),
  'dm_konin_after': ('konin', 3),
  'dm_kuge_after': ('kuge', 3),
  'dm_senrei_after': ('senrei', 3),
  'dm_choryaku_after': ('cho', 2),
  'dm_toritate_after': ('tori', 3),
  'dm_ichimon_after': ('ichi', 3),
  'dm_t_bujirei_after': ('buji', 2),
  'dm_w_anadori_after': ('wan', 2),
};

/// この岐路の id（テストが使う）。
const kDaimyoLifeIds = [
  'dm_sekisho',
  'dm_chisui',
  'dm_chisui_after',
  'dm_joka',
  'dm_joka_after',
  'dm_kokujin',
  'dm_tokusei',
  'dm_erizeni',
  'dm_konin',
  'dm_konin_after',
  'dm_kuge',
  'dm_kuge_after',
  'dm_senrei',
  'dm_senrei_after',
  'dm_choryaku',
  'dm_choryaku_after',
  'dm_engun',
  'dm_toritate',
  'dm_toritate_after',
  'dm_ichimon',
  'dm_ichimon_after',
  'dm_onsho',
  'dm_t_kyo',
  'dm_t_bujirei',
  'dm_t_bujirei_after',
  'dm_t_kyojo',
  'dm_t_sakai',
  'dm_t_fumi',
  'dm_w_anadori',
  'dm_w_anadori_after',
  'dm_w_muko',
  'dm_w_genpuku',
];

/// 天下に手が届く者（[dmNear]）にだけ出る岐路。テストが使う。
const kDaimyoNearIds = [
  'dm_t_kyo',
  'dm_t_bujirei',
  'dm_t_bujirei_after',
  'dm_t_kyojo',
  'dm_t_sakai',
  'dm_t_fumi',
];

/// 女の当主（[dmWoman]）にだけ出る岐路。テストが使う。
const kDaimyoWomanIds = [
  'dm_w_anadori',
  'dm_w_anadori_after',
  'dm_w_muko',
  'dm_w_genpuku',
];

/// 筋の段を踏んだ年を残す（同じ筋の古い年は消す）。
void _stamp(Game g, String chain) {
  g.l.flags.removeWhere((f) => f.startsWith('dm_at:$chain:'));
  g.setFlag('dm_at:$chain:${g.year}');
}

/// 筋の段を最後に踏んでから何年たったか。踏んでいなければ -1。
int dmSince(Game g, String chain) {
  for (final f in g.l.flags) {
    if (f.startsWith('dm_at:$chain:')) {
      return g.year - int.parse(f.substring('dm_at:$chain:'.length));
    }
  }
  return -1;
}

/// 筋の後段に進めるか（前の段の旗があり、年が空いている）。
bool dmChainReady(Game g, String id) {
  final prev = kDaimyoPrev[id];
  if (prev == null) return true;
  if (!prev.any(g.hasFlag)) return false;
  final gap = kDaimyoGap[id];
  if (gap == null) return true;
  return dmSince(g, gap.$1) >= gap.$2;
}

// ---------------------------------------------------------------- 補助

void _net(Game g, int n) => g.l.net = g.l.net + n < 0 ? 0 : g.l.net + n;
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _fame(Game g, int n) => g.l.fame = g.l.fame + n < 0 ? 0 : g.l.fame + n;
void _chi(Game g, int n) => g.l.chi = clampInt(g.l.chi + n, 0, 99);

Faction _me(Game g) => g.fa[g.l.lord]!;

/// 自分の家の勢力を足す。
void _grow(Game g, num n) => _me(g).power += n;

/// 自分の家の勢力を削る（下限は3）。
void _cut(Game g, double m) {
  final f = _me(g);
  f.power = f.power * m < 3 ? 3 : f.power * m;
}

/// ほかの家の勢力を削る（下限は3）。
void _cutOther(Faction f, double m) => f.power = f.power * m < 3 ? 3 : f.power * m;

/// 旗 `<頭><名>` から名を取り出す。なければ [fallback]。
String _named(Game g, String head, String fallback) {
  for (final f in g.l.flags) {
    if (f.startsWith(head)) return f.substring(head.length);
  }
  return fallback;
}

void _keepName(Game g, String head, String name) {
  g.l.flags.removeWhere((f) => f.startsWith(head));
  g.setFlag('$head$name');
}

String _man(Game g) => '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';

/// 家の呼び名（「◯◯家」）。
String _hn(Game g, String? f) => f == null ? '隣国の家' : '${houseName(g, f)}家';

/// 自分の家に近いほかの家（近い順に [n] 家）。
List<Faction> _near(Game g, {int n = 3}) {
  final lf = g.l.lord;
  if (lf == null) return const [];
  return nearest(g.alive.where((f) => f.name != lf), (f) => f.name, faction: lf, n: n);
}

/// 近い家の一つ。いなければ null。
Faction? _other(Game g) {
  final c = _near(g);
  return c.isEmpty ? null : g.rng.pick(c);
}

/// 近い家のうち最も強い家。
Faction? _strongNear(Game g) {
  final c = _near(g, n: 4)..sort((a, b) => b.power.compareTo(a.power));
  return c.isEmpty ? null : c.first;
}

/// 天下で最も強いほかの家。
Faction? _strongest(Game g) {
  final c = g.alive.where((f) => f.name != g.l.lord).toList()
    ..sort((a, b) => b.power.compareTo(a.power));
  return c.isEmpty ? null : c.first;
}

/// 主の一人称。
String _ware(Game g) => g.l.female ? 'わらわ' : 'わし';

double _try(int v, [double base = .45]) => clampD(base + v / 300, base, .85);

/// 重み。筋の始まり・ひとつきりは [_w1]、前の段を踏んだ人だけに出る後段は [_w2]。
const _w1 = 6.0;
const _w2 = 24.0;

/// 天下に手が届く者の場面（その年は短いので重め）。
const _wT = 9.0;

/// 女の当主の場面（女の当主はごく少ないので重め）。
const _wF = 9.0;

SceneDef _chain(
  String id,
  int minAge,
  int maxAge,
  double w,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run,
) => SceneDef(id, minAge, maxAge, (g) => w, (g) => who(g) && dmChainReady(g, id), run);

// ======================================================================
// 岐路
// ======================================================================

List<SceneDef> buildDaimyoLifeScenes() => [
  ..._realmScenes(),
  ..._outerScenes(),
  ..._houseScenes(),
  ..._tenkaScenes(),
  ..._womanScenes(),
];

// ---------------------------------------------------------------- 領国

List<SceneDef> _realmScenes() => [
  // ============================================ ひとつきり: 関所
  SceneDef('dm_sekisho', 20, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('街道の関所', '領内の街道には、国人や寺社が勝手に立てた関所がいくつもある。旅の商人は関ごとに関銭を払い、荷は城下に届くまでに値が倍になるという。関の主たちは、古くからの取り分だと言い張っている。', [
      Choice.h('関所をすべて取り払う', '人と荷が流れ、国は富む。取り分を失う者の恨みを買う', () {
        _grow(g, g.rng.range(2, 3));
        l.gold += 8;
        _net(g, -2);
        g.setFlag('dm_sekisho_open');
        g.mark('領内の関所を取り払い、街道を開いた');
        if (g.rng.chance(.25)) {
          g.j(-2);
          return '関の柵は焼かれ、街道に荷車が連なった。関の主だった古い寺は門を閉ざし、祈祷の願いを断ってきた。';
        }
        return '関の柵は焼かれた。翌月には、見慣れぬ国の商人が城下の市に荷を広げていた。';
      }),
      Choice.h('関銭を国の蔵に納めさせる', '蔵は潤う。商人の足は遠のく', () {
        l.gold += 15;
        _fame(g, -1);
        g.setFlag('dm_sekisho_tax');
        return '関の主には取り分の半ばを残し、残りを国の蔵に納めさせた。市に並ぶ荷は、少しずつ減っていった。';
      }),
      Choice.h('古い取り分のまま置く', '国人も寺社も騒がない。町は伸び悩む', () {
        _net(g, 2);
        return '関のことには口を出さなかった。街道は、これまでどおり関銭を払う商人の列で詰まっていた。';
      }),
      if (l.sei >= 60)
        Choice.h('関を廃した代わりに、関の主へ市の取り分を分ける', '政の才があれば誰も損をしない形にできる。帳尻が合わなければ双方から恨まれる', () {
          if (g.rng.chance(_try(l.sei))) {
            _grow(g, 3);
            _net(g, 3);
            _fame(g, 2);
            g.setFlag('dm_sekisho_open');
            g.setFlag('dm_sekisho_fair');
            g.mark('関所を廃し、関の主たちには城下の市の取り分を分けて納得させた');
            return '関銭の代わりに市の売り上げの一分を約した。寺も国人も、帳面を見て黙ってうなずいた。';
          }
          _net(g, -2);
          _pay(g, 5);
          return '取り分の割り振りで揉め、関の主たちはそろって城へ訴えに来た。話はまとまらなかった。';
        }, via: '政'),
    ], after: next);
  }),

  // ============================================ 筋: 大河の治水
  SceneDef('dm_chisui', 22, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('大河の治水', '国の真ん中を流れる大河は、何年かおきに堤を破り、下流の田を泥で埋める。家臣の中には、川筋そのものを変える大普請を説く者もいる。費えも人手も、城一つを築くほどかかる。', [
      Choice.h('大普請を起こし、川筋を変える', '成れば広い田が生まれる。国中の民が駆り出される', () {
        _pay(g, 30);
        g.j(-2);
        _net(g, -1);
        _stamp(g, 'chisui');
        g.setFlag('dm_chisui_big');
        if (g.rng.chance(.7)) {
          _grow(g, 2);
          g.mark('国を貫く大河の川筋を変える大普請を起こした');
          return '二つの夏をかけて、川は新しい筋を流れ始めた。古い川床には、葦が揺れていた。';
        }
        _cut(g, .97);
        return '普請の半ばで大水が来て、積んだ土は流された。それでも、川筋はどうにか変わった。';
      }),
      Choice.h('堤を高く積み増すだけにする', '費えは軽い。いずれまた破れるかもしれない', () {
        _pay(g, 10);
        _stamp(g, 'chisui');
        g.setFlag('dm_chisui_small');
        return '古い堤の上に土を盛り、杭を打ち直させた。下流の村の者は、堤を見上げて手を合わせた。';
      }),
      if (l.chi >= 60)
        Choice.h('水を逃がす切れ目を残した堤を、自ら縄張りする', '才が当たれば水は田を荒らさずに引く。見立てを誤れば無駄になる', () {
          _stamp(g, 'chisui');
          if (g.rng.chance(_try(l.chi, .5))) {
            _grow(g, 2);
            _fame(g, 3);
            g.setFlag('dm_chisui_kasumi');
            g.mark('大河に、水を逃がす切れ目を残した堤を築かせた');
            return '堤をわざと途切れさせ、溢れた水が遊水の野に逃げるように縄を張った。家臣は首をかしげたが、秋の大水は田を避けて引いていった。';
          }
          _pay(g, 8);
          g.setFlag('dm_chisui_small');
          return '切れ目の位置を誤り、水は思わぬ村へ流れ込んだ。慌てて切れ目を塞がせ、ただの堤にした。';
        }, via: '知'),
      Choice.h('川には手を触れない', '銭も人手も残る。下流の村は大水を恐れ続ける', () {
        _net(g, -1);
        _stamp(g, 'chisui');
        g.setFlag('dm_chisui_none');
        return '大普請の絵図は巻かれたままになった。下流の村では、今年も屋根の上に舟をくくりつけている。';
      }),
    ], after: next);
  }),

  _chain('dm_chisui_after', 24, 84, _w2, dmLord, (g, next) {
    final l = g.l;
    if (g.hasFlag('dm_chisui_big') || g.hasFlag('dm_chisui_kasumi')) {
      g.ask('川沿いの葦原', '川が落ち着いてから、古い川床と川沿いに広い葦原が残った。拓けば田になるが、耕す者が足りない。', [
        Choice.h('他国から流れてきた百姓を呼び集める', '人が増え、国は太る。よそ者と古い村の揉め事も増える', () {
          _grow(g, 2);
          _net(g, 1);
          g.setFlag('dm_shinden_yoso');
          _stamp(g, 'chisui');
          return '戦で村を焼かれた者たちが、鍬を担いで集まってきた。古い村の者は、遠巻きにそれを見ていた。';
        }),
        Choice.h('家臣の次男三男に土地を与えて拓かせる', '家中の不満は減る。田に慣れぬ者の手は遅い', () {
          _grow(g, 1);
          l.troops += 5;
          g.setFlag('dm_shinden_kashin');
          _stamp(g, 'chisui');
          return '部屋住みの若侍たちが、刀を置いて鍬を握った。最初の年の稲は、まばらにしか実らなかった。';
        }),
        if (l.sei >= 60)
          Choice.h('年貢を幾年か免じて、村ごと移り住ませる', '政の才があれば葦原が一つの郷になる。免じた年の分、蔵は軽い', () {
            _stamp(g, 'chisui');
            if (g.rng.chance(_try(l.sei, .5))) {
              _grow(g, 3);
              _net(g, 3);
              g.setFlag('dm_shinden_menjo');
              g.mark('大河の川筋が落ち着いたあとの葦原に、年貢を免じて村を移り住ませた');
              return '免じる年を札に書いて立てさせた。三つの村がそっくり移ってきて、葦原は一面の青い田に変わった。';
            }
            _pay(g, 10);
            return '移ってきた村は、水の引きの悪さに音を上げ、二年もたたずに元の地へ帰っていった。';
          }, via: '政'),
      ], after: next);
      return;
    }
    g.ask('また破れた堤', '秋の長雨で、大河がまた堤を破った。下流の村々は泥に埋まり、蔵の米を求める者が城下に集まっている。', [
      Choice.h('蔵を開いて村々を救う', '民の心はつなぎとめられる。蔵は空く', () {
        _pay(g, 15);
        _net(g, 3);
        g.j(2);
        g.setFlag('dm_chisui_relief');
        _stamp(g, 'chisui');
        g.mark('大水に遭った村々に、城の蔵を開いた');
        return '城の蔵から米俵が運び出された。泥まみれの子らが、炊き出しの鍋の前に並んだ。';
      }),
      Choice.h('年貢を軽くするだけにとどめる', '蔵は守れる。村の立ち直りは遅い', () {
        _cut(g, .97);
        _stamp(g, 'chisui');
        return '今年の年貢を半ばに減らす触れを出した。泥をかき出す村の者の背は、いつまでも曲がったままだった。';
      }),
      Choice.h('自ら川の見回りに出る', '民は主の姿を見る。大水の川は危うい', () {
        _stamp(g, 'chisui');
        if (g.rng.chance(.03)) {
          g.die('大水の夜、川の見回りに出て足をすくわれ、そのまま流された', 'sai');
          return '松明を掲げて土手を歩いていたとき、足元の土が崩れた。';
        }
        _net(g, 3);
        _fame(g, 3);
        g.setFlag('dm_chisui_walked');
        g.mark('大水の夜、自ら馬を出して破れた堤を見回った');
        return '雨の中、破れ目の前に馬を止めた。村の者たちが、泥だらけの顔で主の名を呼んだ。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 居を移して町を開く
  SceneDef('dm_joka', 25, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('居を移すか', '父祖の代からの居城は、山の上にある。守りは固いが、麓の町は狭く、商人も職人も寄りつかない。平らな地に居を移し、大きな町を開くべきだという声がある。', [
      Choice.h('平地に移り、町を開く', '町は大きく育つ。守りは薄くなる', () {
        _pay(g, 25);
        _grow(g, 2);
        g.setFlag('dm_joka_moved');
        _stamp(g, 'joka');
        g.mark('父祖の山の居を降り、平地に新しい町を開いた');
        return '山の上の館を降り、川の合わさる平地に縄を張らせた。家臣たちも、渋々ながら屋敷を移してきた。';
      }),
      Choice.h('山の居城のまま、麓の町を広げる', '守りは固いまま。町は大きくならない', () {
        _pay(g, 8);
        _grow(g, 1);
        g.setFlag('dm_joka_stayed');
        _stamp(g, 'joka');
        return '麓の田を一枚つぶして、町を少しだけ広げた。市の立つ日は、前よりいくらか賑わった。';
      }),
      if (l.chi >= 60)
        Choice.h('町割りを自ら引き、寺町と職人の町を分けて置く', '才が当たれば町は火にも敵にも強くなる。人が思うように集まらないこともある', () {
          _pay(g, 15);
          g.setFlag('dm_joka_moved');
          _stamp(g, 'joka');
          if (g.rng.chance(_try(l.chi, .5))) {
            _grow(g, 3);
            _fame(g, 3);
            g.setFlag('dm_joka_plan');
            g.mark('新しい町を開き、寺町と職人の町を自ら割り付けた');
            return '外の守りに寺を並べ、鍛冶と紺屋は川下に、商人は大通りに置いた。絵図のとおりに、町は年ごとに埋まっていった。';
          }
          return '割り付けた町は、まだらにしか埋まらなかった。職人たちは、決められた町より古い馴染みの隣を選んだ。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('dm_joka_after', 27, 84, _w2, dmLord, (g, next) {
    if (g.hasFlag('dm_joka_moved')) {
      final plan = g.hasFlag('dm_joka_plan');
      g.ask('町の大火', '新しい町に、諸国から人が集まった。冬の夜、町の一角から火が出て、乾いた風にあおられて燃え広がっている。', [
        Choice.h('自ら火元へ馬を出し、家を引き倒させる', '町は救える。火の粉の中は危うい', () {
          _stamp(g, 'joka');
          if (g.rng.chance(.03)) {
            g.die('町の大火の夜、火を止めようと馬を出し、崩れた梁の下敷きになった', 'sai');
            return '火の手の前で指図していたとき、頭の上で梁がきしんだ。';
          }
          _net(g, 4);
          _fame(g, 4);
          g.setFlag('dm_joka_fire_fought');
          g.mark('新しい町の大火の夜、自ら馬を出して火を止めさせた');
          return '風下の家を三軒引き倒させ、火はそこで止まった。夜明けに焼け跡を歩くと、町の者たちが道の両側で頭を下げた。';
        }),
        Choice.h('焼け出された者に蔵の米と材木を下げ渡す', '町は早く立ち直る。蔵は軽くなる', () {
          _pay(g, 15);
          _net(g, 3);
          _grow(g, 1);
          g.setFlag('dm_joka_rebuilt');
          _stamp(g, 'joka');
          return '火が収まると、焼け跡に材木を積ませた。春には、前より広い通りに新しい家が並んでいた。';
        }),
        if (plan)
          Choice.h('割り付けた広い通りで火を食い止めさせる', '町割りが生きれば火は通りを越えない', () {
            _stamp(g, 'joka');
            if (g.rng.chance(.75)) {
              _fame(g, 4);
              _grow(g, 2);
              g.setFlag('dm_joka_plan_saved');
              g.mark('町割りの広い通りで、大火を一つの町内で食い止めた');
              return '大通りに水桶の列を並べさせた。火は通りの向こうで力尽き、寺町にも職人の町にも届かなかった。';
            }
            _net(g, -1);
            return '風が強すぎた。火の粉は大通りを飛び越え、職人の町の半ばが焼けた。';
          }),
      ], after: next);
      return;
    }
    g.ask('去りたい商人', '麓の町の商人たちが連れ立って来た。町が狭く、隣国に開かれた新しい町のほうが商いになるので、そちらへ移りたいという。', [
      Choice.h('座の特権を与えて引き止める', '商人は残る。特権は町の外の者を締め出す', () {
        _pay(g, 10);
        _grow(g, 1);
        g.setFlag('dm_joka_kept');
        _stamp(g, 'joka');
        return '城下の商いは座の者に限るという判物を与えた。商人たちは、ほっとした顔で帰っていった。';
      }),
      Choice.h('去る者は去らせる', '口は出さずに済む。町はさびれる', () {
        _cut(g, .97);
        g.j(-1);
        _stamp(g, 'joka');
        return '商人の荷車が、峠を越えて隣国へ下っていった。市の立つ日の通りに、空いた軒が目立つようになった。';
      }),
      Choice.h('今からでも平地に町を広げる', '遅ればせでも町は育つ。費えは重い', () {
        _pay(g, 15);
        _grow(g, 2);
        g.setFlag('dm_joka_late');
        _stamp(g, 'joka');
        return '山の居はそのままに、麓の平地へ新しい町を割り付けた。去りかけた商人たちも、様子を見に戻ってきた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 国人衆
  SceneDef('dm_kokujin', 20, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('国人衆の所領', '国の中には、先祖代々の所領に館を構える国人たちがいる。戦のときは兵を出すが、平時は年貢も裁きも勝手にしている。家臣の中から、国人の館を割り、所領を召し上げて直に治めるべきだという声が上がった。', [
      Choice.h('国人の館を割り、直に治める', '国の力は一つにまとまる。抗う国人も出る', () {
        if (g.rng.chance(.3)) {
          _cut(g, .92);
          g.j(-3);
          g.setFlag('dm_kokujin_revolt');
          return '三つの国人が手を組んで館に立て籠もった。半年かけて鎮めたが、国は大きく傷ついた。';
        }
        _grow(g, 4);
        g.setFlag('dm_kokujin_direct');
        g.mark('国人たちの館を割り、所領を直に治めた');
        return '国人たちは、うなだれて館の門を開いた。所領には、新しく代官が送り込まれた。';
      }),
      Choice.h('所領を安堵し、起請文を取る', '国人は従う。国はまとまりきらない', () {
        _grow(g, 1);
        _net(g, 2);
        g.setFlag('dm_kokujin_oath');
        return '国人たちは、牛王の札の裏に血判を押した。それぞれの館へ帰る足取りは軽かった。';
      }),
      if (l.mi >= 60)
        Choice.h('国人の子らを呼び寄せ、近習として共に育てる', '人柄が通じれば次の代から一つになる。人質と受け取られることもある', () {
          if (g.rng.chance(_try(l.mi))) {
            _grow(g, 2);
            _net(g, 3);
            g.setFlag('dm_kokujin_sons');
            g.mark('国人たちの子らを呼び寄せ、近習として共に育てた');
            return '国人の子らは、館の庭で一緒に槍を習い、同じ膳で飯を食った。親たちの文の書き出しが、少しずつ柔らかくなった。';
          }
          _net(g, -2);
          return '国人たちは、子を差し出せというのは人質のことだと受け取った。何人かは、病と称して子を出さなかった。';
        }, via: '魅'),
    ], after: next);
  }),

  // ============================================ ひとつきり: 徳政
  SceneDef('dm_tokusei', 20, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('徳政の訴え', '凶作が続き、村々は土倉や酒屋への借りで首が回らなくなった。借りを棒引きにする徳政を出してほしいと、百姓の代表が門前に座り込んでいる。土倉の主たちは、徳政を出せば国の銭の流れが止まると言う。', [
      Choice.h('国中に徳政を出す', '村は救われる。銭を貸す者がいなくなる', () {
        _net(g, 3);
        _pay(g, 5);
        g.j(1);
        g.setFlag('dm_tokusei_all');
        g.mark('借りに苦しむ村々のため、国中に徳政を出した');
        return '辻という辻に徳政の札が立った。村は沸き立ち、土倉の主たちは蔵の戸を固く閉ざした。';
      }),
      Choice.h('徳政は出さず、年貢を一年免じる', '村も土倉も立つ。蔵が軽くなる', () {
        _pay(g, 20);
        _net(g, 2);
        g.setFlag('dm_tokusei_menjo');
        return '借りはそのままに、今年の年貢だけを免じた。座り込んでいた百姓たちは、しばらく顔を見合わせてから帰っていった。';
      }),
      Choice.h('訴えを退ける', '土倉の銭は流れ続ける。村の恨みが残る', () {
        l.gold += 5;
        _net(g, -3);
        g.j(-1);
        g.setFlag('dm_tokusei_refused');
        if (g.rng.chance(.25)) {
          _cut(g, .96);
          return '訴えを退けると、いくつもの村が年貢を拒み、家を空にして隣国へ逃げ散った。';
        }
        return '門前の百姓たちは、追い立てられて帰っていった。その秋の年貢は、どの村も遅れて納められた。';
      }),
      if (l.sei >= 60)
        Choice.h('借りの証文を改めさせ、利が元を越えた分だけ棒引きにする', '政の才があれば村も土倉も得心する。改めの手間は大きい', () {
          if (g.rng.chance(_try(l.sei))) {
            _net(g, 4);
            _fame(g, 2);
            _grow(g, 1);
            g.setFlag('dm_tokusei_fair');
            g.mark('借りの証文を改めさせ、利が元を越えた分だけを棒引きにした');
            return '奉行たちが証文を一枚ずつ読み上げた。土倉の主は苦い顔をしたが、元銭が戻ると知って判を押した。';
          }
          _net(g, -1);
          return '証文の山は改めきれず、冬が来た。村も土倉も、待たされたことだけを恨んだ。';
        }, via: '政'),
    ], after: next);
  }),

  // ============================================ ひとつきり: 撰銭
  SceneDef('dm_erizeni', 20, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('悪銭と撰銭', '市では、欠けた銭や勝手に鋳た悪銭が混じり、商人たちが銭を選り好みして、取り引きが滞っている。米で払うか銭で払うか、値の決め方も町ごとにまちまちだ。', [
      Choice.h('撰銭を禁じ、悪銭にも定めた値をつける', '市は動き出す。損をかぶる商人が騒ぐ', () {
        _grow(g, 2);
        l.gold += 5;
        g.setFlag('dm_erizeni_law');
        g.mark('撰銭の掟を定め、悪銭にも値をつけて市を動かした');
        return '悪銭は良銭の何分の一と定めた札を、市の入口に掲げさせた。商人たちはぶつぶつ言いながらも、また銭を受け取るようになった。';
      }),
      Choice.h('年貢も取り引きも米で払わせる', '値は揺れにくくなる。銭の便は失われる', () {
        _grow(g, 1);
        g.setFlag('dm_erizeni_rice');
        return '年貢も市の取り引きも、米で決めるよう触れを出した。荷車に積まれた米俵が、市の真ん中を行き来するようになった。';
      }),
      Choice.h('商人たちに任せる', '口は出さずに済む。市の滞りは続く', () {
        _cut(g, .98);
        return '銭のことは商人に任せた。市では、今日も銭の目利きをめぐる口論が続いている。';
      }),
      if (l.chi >= 60)
        Choice.h('大きな取り引きは金銀で決めさせ、銭は小さな買い物に回す', '才が当たれば市は大きく動く。金銀の目方をごまかす者も出る', () {
          if (g.rng.chance(_try(l.chi))) {
            _grow(g, 3);
            l.gold += 10;
            _fame(g, 2);
            g.setFlag('dm_erizeni_gold');
            g.mark('大きな取り引きを金銀で決めさせ、市の滞りを解いた');
            return '金銀の目方を量る秤を城下に置かせた。遠国の大商人が、金の小粒を袋に詰めて荷を買い付けに来るようになった。';
          }
          _pay(g, 5);
          return '金銀の目方をごまかす者が後を絶たず、秤の番人が足りなくなった。触れは半年で取り下げた。';
        }, via: '知'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 外交

List<SceneDef> _outerScenes() => [
  // ============================================ 筋: 縁組の網
  SceneDef('dm_konin', 25, 84, (g) => _w1, (g) => dmLord(g) && _near(g, n: 4).length >= 2, (g, next) {
    final l = g.l;
    final c = _near(g, n: 4)..sort((a, b) => b.power.compareTo(a.power));
    final strong = c.first, weak = c.last;
    final hime = g.rng.pick(kHimeNames);
    final sn = _hn(g, strong.name), wn = _hn(g, weak.name);
    _keepName(g, 'dm_konin_hime:', hime);
    g.ask('縁組の網', '隣り合う家々との縁を固めねば、四方に敵を抱えることになる。家老が、一門の姫の$himeをどこへ送るか決めてほしいと言ってきた。強い$snに送れば背は守られ、弱い$wnに送れば、いずれその家を取り込める。', [
      Choice.h('$snへ送り、背を守る', '攻められる憂いは減る。強い家に頭が上がらなくなる', () {
        _keepName(g, 'dm_konin_to:', strong.name);
        g.setFlag('dm_konin_strong');
        _net(g, 2);
        g.j(1);
        _stamp(g, 'konin');
        g.mark('一門の姫$himeを$snへ送り、縁を結んだ');
        return '$himeの輿が国境を越えた。$snからは、引き出物の太刀と馬が届いた。';
      }),
      Choice.h('$wnへ送り、いずれ取り込む', '先の国取りの足がかりになる。姫の行く末は危うい', () {
        _keepName(g, 'dm_konin_to:', weak.name);
        g.setFlag('dm_konin_weak');
        _grow(g, 1);
        _stamp(g, 'konin');
        g.mark('一門の姫$himeを$wnへ送り、縁を結んだ');
        return '$wnの当主は、こちらの姫を迎えると聞いて涙を流して喜んだという。$himeは、何も言わずに輿に乗った。';
      }),
      Choice.h('姫は手元に置き、縁組を急がない', '姫は穏やかに暮らす。四方の家との溝は残る', () {
        _net(g, -1);
        g.j(1);
        return '縁組の話は、どれも返事を延ばした。$himeは、城の庭で花を摘んでいた。';
      }),
      if (l.mi >= 60)
        Choice.h('両家に一門の姫を送り、三つの家で盟を結ぶ', '人柄が通じれば国境が静まる。どちらかが破れば板挟みになる', () {
          _keepName(g, 'dm_konin_to:', strong.name);
          g.setFlag('dm_konin_strong');
          _stamp(g, 'konin');
          if (g.rng.chance(_try(l.mi))) {
            _grow(g, 2);
            _net(g, 4);
            _fame(g, 3);
            g.setFlag('dm_konin_triple');
            g.mark('二つの隣家に一門の姫を送り、三つの家の盟を結んだ');
            return '三つの家の使いが一つの寺に集まり、起請文を取り交わした。国境の砦から、物見の兵が引き上げられた。';
          }
          return '$wnは話に乗らなかった。$himeだけが、$snへ嫁いでいった。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('dm_konin_after', 28, 84, _w2, dmLord, (g, next) {
    final l = g.l;
    final hime = _named(g, 'dm_konin_hime:', '一門の姫');
    final tf = g.fa[_named(g, 'dm_konin_to:', '')];
    if (tf == null || !tf.alive) {
      g.ask('戻ってきた姫', '$himeの嫁いだ家は、もう滅んだ。落ち延びた$himeが、幼い子の手を引いて国へ戻ってきた。', [
        Choice.h('姫と子を館に迎える', '一門の情は守れる。子はいずれ旗頭に担がれるかもしれない', () {
          g.j(2);
          _net(g, 2);
          g.setFlag('dm_konin_returned');
          _stamp(g, 'konin');
          return '$himeは、館の奥の一間に落ち着いた。子は、すぐに城の子らと駆け回るようになった。';
        }),
        Choice.h('寺に預け、静かに暮らさせる', '火種は遠ざけられる。姫の顔は曇る', () {
          g.j(-2);
          _stamp(g, 'konin');
          return '母子は、国の外れの尼寺に預けられた。$himeからの文は、それきり来なかった。';
        }),
      ], after: next);
      return;
    }
    final tn = _hn(g, tf.name);
    if (g.hasFlag('dm_konin_strong')) {
      g.ask('嫁ぎ先からの文', '$himeから文が届いた。嫁ぎ先の$tnが、こちらの国境の砦を一つ譲れと言い出し、断れば縁を切ると迫っているという。文の終わりに、姫の字で「どうか国を先に」とあった。', [
        Choice.h('砦を譲って縁をつなぐ', '縁は保てる。国境は一つ細る', () {
          _cut(g, .95);
          _net(g, 2);
          g.setFlag('dm_konin_yielded');
          _stamp(g, 'konin');
          return '砦の鍵を$tnの使いに渡した。$himeからは、詫びと礼を書き連ねた長い文が届いた。';
        }),
        Choice.h('断り、姫を取り戻す使いを出す', '国は守れる。姫の身が危うい', () {
          _stamp(g, 'konin');
          if (g.rng.chance(.7)) {
            g.j(-2);
            g.setFlag('dm_konin_returned');
            g.mark('嫁ぎ先と手切れになった一門の姫$himeを、使いを出して取り戻した');
            return '夜の峠を越えて、$himeの輿が戻ってきた。輿を降りた姫は、門の前で長いあいだ館を見上げていた。';
          }
          g.j(-8);
          g.setFlag('dm_konin_lost');
          return '使いは国境で追い返された。$himeがどうなったかは、それきり聞こえてこなかった。';
        }),
        if (l.chi >= 60)
          Choice.h('姫の文を通じて、向こうの家中の争いに楔を打つ', '才が当たれば相手が内から揺らぐ。見抜かれれば姫が責めを負う', () {
            _stamp(g, 'konin');
            if (g.rng.chance(_try(l.chi))) {
              _grow(g, 2);
              _cutOther(tf, .95);
              g.setFlag('dm_konin_wedge');
              g.mark('嫁いだ姫の文を通じて、$tnの家中に楔を打った');
              return '$himeの文は、向こうの重臣どうしの仲違いを細かく伝えてきた。砦を譲れという話は、いつの間にか立ち消えた。';
            }
            g.j(-4);
            _net(g, -2);
            return '文は$tnの目付に読まれていた。$himeは奥の一間に押し込められたという。';
          }, via: '知'),
      ], after: next);
      return;
    }
    g.ask('嫁ぎ先の跡目', '$tnの当主が病に倒れた。家中は、嫁いだ$himeの産んだ幼い子を立てる者と、当主の兄弟を立てる者とで割れている。$himeから、助けを求める文が来た。', [
      Choice.h('兵を出して幼い子を立て、後ろ盾になる', '縁の家は手の内に入る。戦は戦だ', () {
        _stamp(g, 'konin');
        final r = g.battle('main', enemy: tf.name, risk: .7, gain: 1, edge: .1);
        if (l.dead != null) return '国境を越えて兵を進めた。$r';
        _grow(g, 2);
        g.setFlag('dm_konin_backed');
        g.mark('縁を結んだ家の跡目争いに兵を出し、一門の姫の子を立てた');
        return '国境を越えて兵を進めた。$r幼い当主の横に、$himeが静かに座っていた。';
      }),
      Choice.h('争いには加わらず、姫と子を引き取る', '血は流れない。縁の家は遠のく', () {
        g.j(-2);
        g.setFlag('dm_konin_returned');
        _stamp(g, 'konin');
        return '$himeと子を、夜のうちに国へ迎え入れた。$tnの家督は、当主の兄弟が継いだという。';
      }),
      Choice.h('当主の兄弟の側と結び、家ごと取り込む', '国は大きく広がる。姫と子の恨みは消えない', () {
        _grow(g, 4);
        _cutOther(tf, .85);
        g.j(-6);
        g.setFlag('dm_konin_betrayed');
        _stamp(g, 'konin');
        return '新しい当主は、こちらに頭を下げて所領の半ばを差し出した。$himeからの文は、二度と来なかった。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 都落ちの公家
  SceneDef('dm_kuge', 20, 84, (g) => _w1, (g) => dmLord(g) && g.year <= 1590, (g, next) {
    final l = g.l;
    g.ask('都落ちの公家', '都の戦乱を逃れて、名のある公家が身を寄せたいと言ってきた。歌や書や有職の作法に通じた人だが、伴の者も多く、養うには銭が要る。', [
      Choice.h('屋敷を建てて迎える', '国に都の風が入る。銭はかかり続ける', () {
        _pay(g, 15);
        _fame(g, 4);
        _net(g, 2);
        g.setFlag('dm_kuge_host');
        _stamp(g, 'kuge');
        g.mark('都落ちの公家を迎え、城下に屋敷を建てた');
        return '公家は、牛車の代わりに輿で国境を越えてきた。城下の者たちは、烏帽子姿の伴の者を物珍しげに眺めた。';
      }),
      if (l.chi >= 55)
        Choice.h('公家を迎え、家臣にも歌と書を学ばせる', '才があれば家中に学びが根づく。武骨な者は退屈がる', () {
          _pay(g, 15);
          g.setFlag('dm_kuge_host');
          _stamp(g, 'kuge');
          if (g.rng.chance(_try(l.chi, .5))) {
            _chi(g, 2);
            _fame(g, 3);
            g.setFlag('dm_kuge_poem');
            g.mark('都落ちの公家を師として、家中に歌と書を学ばせた');
            return '月に一度、館で歌の会が開かれるようになった。槍しか知らなかった侍大将が、恥ずかしそうに短冊を差し出した。';
          }
          g.j(-1);
          return '家臣たちは、歌の会のたびに居眠りをした。公家は、困ったように扇で口元を隠した。';
        }, via: '知'),
      Choice.h('銭だけ渡して、ほかの国へ送る', '費えは軽い。都とのつながりは得られない', () {
        _pay(g, 4);
        g.setFlag('dm_kuge_sent');
        _stamp(g, 'kuge');
        return '路銀を持たせ、丁重に送り出した。公家は、振り返りもせずに次の国へ向かった。';
      }),
    ], after: next);
  }),

  _chain('dm_kuge_after', 24, 84, _w2, (g) => dmLord(g) && _strongNear(g) != null, (g, next) {
    final e = _strongNear(g)!;
    final en = _hn(g, e.name);
    if (g.hasFlag('dm_kuge_host')) {
      g.ask('勅使の和', '$enとの境の争いが長引き、国は疲れている。屋敷に迎えた公家が、都に文を送れば、帝の仰せとして和を取り持つ勅使を下せるかもしれないと言う。', [
        Choice.h('勅使を願い、和を結ぶ', '名分を保ったまま戦をやめられる。礼の銭は重い', () {
          _pay(g, 20);
          _fame(g, 6);
          _grow(g, 1);
          g.j(3);
          g.setFlag('dm_chokumei');
          _stamp(g, 'kuge');
          g.mark('都の公家を通じて勅使を仰ぎ、$enとの和を結んだ');
          return '勅使の前では、$enの当主も膝を折るほかなかった。国境の砦から、久しぶりに兵が村へ帰った。';
        }),
        Choice.h('勅使には頼らず、戦で決着をつける', '借りは作らない。戦は戦だ', () {
          _stamp(g, 'kuge');
          g.setFlag('dm_chokumei_refused');
          final r = g.battle('main', enemy: e.name, risk: .8);
          return '公家の申し出を断り、兵を出した。$r';
        }),
        if (g.hasFlag('dm_kuge_poem'))
          Choice.h('公家と共に、$enの当主を歌の会に招く', '歌の席で話がつけば礼の銭も要らない。席を蹴られることもある', () {
            _stamp(g, 'kuge');
            if (g.rng.chance(.6)) {
              _net(g, 4);
              _fame(g, 3);
              g.setFlag('dm_chokumei');
              g.setFlag('dm_kuge_utakai');
              g.mark('敵の当主を歌の会に招き、一首を交わして境の争いを収めた');
              return '$enの当主は、意外にも歌を好んだ。下の句を付け合ううちに、境の話は笑いのうちにまとまった。';
            }
            _fame(g, -2);
            return '$enの当主は、座に着くなり「歌で国は守れぬ」と言い捨てて帰っていった。';
          }),
      ], after: next);
      return;
    }
    g.ask('見下す隣家', 'かつて送り出した公家は、$enに迎えられていた。その口添えで、$enに都から官途が下されたという。$enの使いは、境の争いを和で収めようと言ってきたが、言葉の端に見下した色がある。', [
      Choice.h('頭を下げて和を受ける', '戦は止む。家中の面目は潰れる', () {
        _fame(g, -2);
        g.j(-2);
        _net(g, 1);
        g.setFlag('dm_chokumei_bowed');
        _stamp(g, 'kuge');
        return '和の起請文に判を押した。使いは、満足そうに扇を鳴らして帰っていった。';
      }),
      Choice.h('使いを追い返し、兵を出す', '面目は立つ。戦は戦だ', () {
        _stamp(g, 'kuge');
        final r = g.battle('main', enemy: e.name, risk: .9);
        return '使いを門から叩き出し、その足で陣触れをした。$r';
      }),
      Choice.h('こちらも都へ使いを出し、献金する', '名分は取り戻せる。銭は重い', () {
        _pay(g, 20);
        _fame(g, 3);
        _stamp(g, 'kuge');
        return '都への献金の返しに、こちらにも官途の口宣案が届いた。$enの使いは、それを聞くと口をつぐんだ。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 南蛮の教え
  SceneDef('dm_senrei', 25, 84, (g) => _w1, (g) => dmLord(g) && g.year >= 1550 && g.year <= 1600, (g, next) {
    final l = g.l;
    g.ask('南蛮の教え', '南蛮の伴天連が、館に招かれたいと願い出ている。その教えに帰依した大名の湊には、南蛮の船が真っ先に入り、玉薬も回ってくると噂される。家臣の中には、すでに洗礼を受けた者もいる。', [
      Choice.h('自ら洗礼を受ける', '南蛮の船と銭が近づく。寺社と古い家臣は離れる', () {
        l.gold += 10;
        l.gun = true;
        _grow(g, 2);
        _net(g, -2);
        g.j(2);
        g.setFlag('dm_kirishitan');
        _stamp(g, 'senrei');
        g.mark('南蛮の教えに帰依し、伴天連の手で洗礼を受けた');
        return '水を額に受け、南蛮の名を授けられた。首に掛けた十字の飾りを、家臣たちは見ないふりをした。';
      }),
      Choice.h('布教は許すが、自らは受けない', '船は来る。深入りはしない', () {
        l.gold += 5;
        g.setFlag('dm_senrei_allow');
        _stamp(g, 'senrei');
        return '伴天連には城下の一角に寺を建てることを許した。自らは、ていねいに頭を下げるだけにとどめた。';
      }),
      Choice.h('伴天連を国から出す', '寺社と家臣は安堵する。南蛮の品は遠のく', () {
        _net(g, 2);
        g.setFlag('dm_senrei_refuse');
        _stamp(g, 'senrei');
        return '伴天連には路銀を持たせて国境まで送らせた。古い寺の僧たちは、そろって礼に来た。';
      }),
      if (l.chi >= 60)
        Choice.h('伴天連を招き、その国の学びだけを取り入れる', '才があれば天文や医術が手に入る。教えを拒まれた伴天連は不満を抱く', () {
          g.setFlag('dm_senrei_allow');
          _stamp(g, 'senrei');
          if (g.rng.chance(_try(l.chi, .5))) {
            _chi(g, 3);
            _fame(g, 2);
            g.setFlag('dm_senrei_learn');
            g.mark('伴天連を招き、南蛮の天文と医術を家臣に学ばせた');
            return '伴天連は、丸い地の模型と、傷を縫う細い針を持ってきた。若い家臣たちは、目を輝かせて南蛮の言葉を書き留めた。';
          }
          return '伴天連は、教えを聞かぬ者に学びだけを渡すことはできぬと言った。話は、半ばで終わった。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('dm_senrei_after', 28, 84, _w2, dmLord, (g, next) {
    final l = g.l;
    if (g.hasFlag('dm_kirishitan')) {
      g.ask('寺社と南蛮寺', '洗礼を受けた家臣たちが、領内の寺社を壊し、仏像を焼くべきだと言い出した。伴天連もそれを望んでいる。古い寺の僧たちは、門前に集まって声を上げている。', [
        Choice.h('寺社を壊させる', '教えには忠実になれる。僧たちの恨みは深い', () {
          _stamp(g, 'senrei');
          _grow(g, 1);
          _net(g, -4);
          g.j(-2);
          g.setFlag('dm_senrei_burned');
          if (g.rng.chance(.03)) {
            g.die('寺を壊させた恨みを抱く僧の手の者に、鷹狩りの帰り道で襲われた', 'ansatsu');
            return '鷹狩りの帰り、薄の原から墨染めの衣の男が飛び出してきた。';
          }
          return '寺の鐘が下ろされ、南蛮寺の鐘楼に吊り直された。古い寺の僧たちは、国境を越えて去っていった。';
        }),
        Choice.h('寺社には手を出させない', '国は静かなまま。伴天連と熱心な家臣は不満を抱く', () {
          _net(g, 2);
          g.j(1);
          g.setFlag('dm_senrei_tolerant');
          _stamp(g, 'senrei');
          g.mark('南蛮の教えに帰依しながら、領内の寺社には手を出させなかった');
          return '「教えは心でするものだ」と家臣たちを諭した。伴天連は肩をすくめたが、それ以上は言わなかった。';
        }),
        if (l.mi >= 60)
          Choice.h('南蛮寺の伴天連と古い寺の僧を、同じ席に呼ぶ', '人柄が通じれば国の中の争いが収まる。どちらも譲らなければ溝が深まる', () {
            _stamp(g, 'senrei');
            if (g.rng.chance(_try(l.mi))) {
              _net(g, 4);
              _fame(g, 3);
              g.setFlag('dm_senrei_tolerant');
              g.setFlag('dm_senrei_table');
              g.mark('南蛮寺の伴天連と古い寺の僧を同じ席に呼び、互いの寺に手を出さぬと誓わせた');
              return '一つの膳を挟んで、僧と伴天連が向かい合った。最後には、互いの寺に手を出さぬという書付に、二人とも名を記した。';
            }
            _net(g, -2);
            return '僧は席に着くなり経を唱え始め、伴天連は十字を切って立ち去った。';
          }, via: '魅'),
      ], after: next);
      return;
    }
    if (g.hasFlag('dm_senrei_allow')) {
      g.ask('南蛮の船の頭', '南蛮寺が建ち、領民の中にも十字を切る者が増えた。湊に着いた南蛮の船の頭が、硝石と引き換えに、領内の者を船に乗せて連れて行きたいと言う。', [
        Choice.h('断り、領民は一人も渡さない', '民は守れる。硝石は遠のく', () {
          _net(g, 3);
          g.setFlag('dm_senrei_noslave');
          _stamp(g, 'senrei');
          g.mark('南蛮の船に、領内の者を一人も渡さなかった');
          return '船の頭は顔をしかめて帆を上げた。湊で見送った漁師たちが、主の館のほうへ頭を下げた。';
        }),
        Choice.h('硝石のために目をつぶる', '玉薬は手に入る。民の心は離れる', () {
          l.gold += 15;
          l.gun = true;
          _grow(g, 1);
          g.j(-5);
          _net(g, -2);
          g.setFlag('dm_senrei_sold');
          _stamp(g, 'senrei');
          return '船は、縄を打たれた者たちを乗せて沖へ出ていった。その夜、湊の村から泣き声が絶えなかった。';
        }),
        Choice.h('その船を湊から出し、二度と入れない', '国の静けさは守れる。南蛮の品も遠のく', () {
          _pay(g, 5);
          g.setFlag('dm_senrei_closed');
          _stamp(g, 'senrei');
          return '湊の口に番船を出し、船を外海へ追い出した。南蛮寺の伴天連は、困ったように黙り込んだ。';
        }),
      ], after: next);
      return;
    }
    final e = _other(g);
    final en = _hn(g, e?.name);
    g.ask('隣国の南蛮船', '国から出した伴天連は、$enに迎えられた。$enの湊には南蛮の船が着き、鉄砲の数がこちらの倍になったという噂だ。', [
      Choice.h('堺の商人から鉄砲を買い入れる', '備えは追いつく。銭は重い', () {
        _pay(g, 20);
        l.gun = true;
        _grow(g, 1);
        _stamp(g, 'senrei');
        return '堺の商人が、油紙に包んだ鉄砲を荷車で運んできた。射場の音が、前より多くなった。';
      }),
      Choice.h('今からでも伴天連を呼び戻す', '船は来るかもしれない。寺社には侮られる', () {
        l.gold += 5;
        g.j(-1);
        _stamp(g, 'senrei');
        return '使いを出したが、伴天連は「もう遅い」とだけ書いて寄こした。南蛮の小間物だけが、少し届くようになった。';
      }),
      Choice.h('構わず、弓と槍で備える', '国の古い形は守れる。戦の形が変わっても遅れを取るかもしれない', () {
        _net(g, 1);
        g.setFlag('dm_senrei_old_ways');
        _stamp(g, 'senrei');
        return '弓組を増やし、槍の稽古を倍にさせた。古い家臣たちは、満足そうにうなずいた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 敵の重臣の調略
  SceneDef('dm_choryaku', 22, 84, (g) => _w1, (g) => dmLord(g) && _other(g) != null, (g, next) {
    final l = g.l;
    final e = _other(g)!;
    final en = _hn(g, e.name);
    final n = _man(g);
    _keepName(g, 'dm_cho_name:', n);
    _keepName(g, 'dm_cho_house:', e.name);
    g.ask('敵の重臣', '$enの重臣、$nが、主君に疎まれていると忍びの者が知らせてきた。こちらに寝返らせれば、$enの境の砦がいくつも手に入る。', [
      Choice.h('所領を約して寝返らせる', '敵の砦が手に入る。寝返った者は、また寝返るかもしれない', () {
        _stamp(g, 'cho');
        if (g.rng.chance(clampD(.55 + l.chi / 400, .55, .85))) {
          _cutOther(e, .9);
          _grow(g, 2);
          g.setFlag('dm_cho_turned');
          g.mark('$enの重臣$nを調略し、寝返らせた');
          return '$nは、夜のうちに境の砦の門を開いた。$enの旗が下ろされ、こちらの旗が上がった。';
        }
        _fame(g, -2);
        return '使いは戻らなかった。十日ののち、使いの髷だけが文箱に入って送り返されてきた。';
      }),
      if (l.chi >= 60)
        Choice.h('寝返らせず、$enの家中に疑いの種をまく', '才が当たれば敵が自ら重臣を除く。見抜かれれば逆手に取られる', () {
          _stamp(g, 'cho');
          if (g.rng.chance(_try(l.chi))) {
            _cutOther(e, .92);
            g.setFlag('dm_cho_rumor');
            g.mark('偽りの書状で、$enに重臣$nを疑わせた');
            return '$n宛ての偽りの返書を、わざと$enの関所で見つかるように運ばせた。ひと月ののち、$nが主君の勘気をこうむったと聞こえてきた。';
          }
          _cut(g, .97);
          return '偽りの書状はすぐに見抜かれた。$enは、こちらの使いを捕らえて晒した。';
        }, via: '知'),
      Choice.h('調略は好まぬ、と忍びを下がらせる', '名は汚れない。好機は去る', () {
        _fame(g, 2);
        g.setFlag('dm_cho_clean');
        return '忍びの者は、黙って頭を下げて下がった。$nのことは、それきり聞かなかった。';
      }),
    ], after: next);
  }),

  _chain('dm_choryaku_after', 25, 84, _w2, dmLord, (g, next) {
    final n = _named(g, 'dm_cho_name:', '寝返った将');
    final en = _hn(g, _named(g, 'dm_cho_house:', ''));
    if (g.hasFlag('dm_cho_turned')) {
      g.ask('寝返った将', '寝返らせた$nが、約した所領の残りを求めてきた。家臣たちは、一度主を裏切った者に大きな所領を与えるのは危ういと言う。$nの目は、こちらの顔色をうかがっている。', [
        Choice.h('約したとおり所領を与える', '約を守った名が残る。あの者の野心は育つ', () {
          _grow(g, 1);
          _fame(g, 3);
          g.setFlag('dm_cho_kept');
          _stamp(g, 'cho');
          g.mark('寝返らせた$nに、約したとおりの所領を与えた');
          return '$nは平伏して判物を受け取った。その後の調略には、敵方の侍が自ら名乗り出てくるようになった。';
        }),
        Choice.h('所領は与えず、遠い砦の守りにつける', '危うさは遠ざけられる。恨みは残る', () {
          _stamp(g, 'cho');
          if (g.rng.chance(.04)) {
            g.die('寝返らせた敵の将を遠ざけたのち、招いた茶の席で刺された', 'ansatsu');
            return '詫びの茶を点てたいと言う$nを、つい席に入れてしまった。';
          }
          _cut(g, .98);
          g.setFlag('dm_cho_far');
          return '$nは黙って遠い砦へ向かった。挨拶の文は、一度も来なかった。';
        }),
        Choice.h('疑わしいとして腹を切らせる', '後の憂いはない。調略に応じる者はいなくなる', () {
          _fame(g, -4);
          g.j(-3);
          g.setFlag('dm_cho_purged');
          _stamp(g, 'cho');
          return '$nは、何も言わずに腹を切った。敵方の侍たちは、その話を聞いて二度とこちらの使いに会わなくなった。';
        }),
      ], after: next);
      return;
    }
    g.ask('遺された子', '疑われた$nは、$enの主君に腹を切らされたという。$nの遺した幼い子が、母に連れられてこちらの国境に逃れてきた。父を死なせたのが誰の策か、子は知らない。', [
      Choice.h('子を引き取り、家臣の家で育てさせる', '償いの真似はできる。いつか真実を知るかもしれない', () {
        g.j(1);
        _net(g, 1);
        g.setFlag('dm_cho_orphan');
        _stamp(g, 'cho');
        g.mark('策で死なせた敵の重臣の遺児を、家臣の家で育てさせた');
        return '子は、家臣の家の縁側で、母の膝に頭を載せて眠っていた。その寝顔を、長くは見ていられなかった。';
      }),
      Choice.h('国境から追い返す', '関わらずに済む。胸の奥に棘が残る', () {
        g.j(-2);
        _stamp(g, 'cho');
        return '母子は、国境の番所から追い返された。振り返った子の目が、しばらく夢に出た。';
      }),
      Choice.h('母子に銭を持たせ、遠い寺へ送る', '母子は生き延びる。名乗りはしない', () {
        _pay(g, 5);
        g.setFlag('dm_cho_temple');
        _stamp(g, 'cho');
        return '名を伏せて銭を持たせ、遠い国の寺へ送らせた。寺からは、母子が無事に着いたとだけ知らせてきた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 盟友の援軍
  SceneDef('dm_engun', 20, 84, (g) => _w1, (g) => dmLord(g) && _near(g).length >= 2, (g, next) {
    final l = g.l;
    final c = _near(g);
    final ally = c.first;
    final foes = nearest(g.alive.where((f) => f.name != ally.name && f.name != l.lord), (f) => f.name, faction: ally.name, n: 2);
    if (foes.isEmpty) {
      next();
      return;
    }
    final enemy = foes.first;
    final an = _hn(g, ally.name), en = _hn(g, enemy.name);
    g.ask('盟友の援軍', '誼を通じてきた$anが、$enに攻められていると援軍を求めてきた。兵を出せば、自分の国の守りは薄くなる。', [
      Choice.h('自ら兵を率いて駆けつける', '盟友の信は厚くなる。戦は戦だ', () {
        final r = g.battle('main', enemy: enemy.name, risk: .8);
        if (l.dead != null) return '自ら兵を率いて駆けつけた。$r';
        ally.power += 2;
        _net(g, 3);
        g.setFlag('dm_engun_went');
        g.mark('盟友の$anを救うため、自ら兵を率いて駆けつけた');
        return '自ら兵を率いて駆けつけた。$r';
      }),
      Choice.h('兵だけを送り、自らは国に残る', '義理は果たせる。助けが足りぬと言われるかもしれない', () {
        if (g.rng.chance(.5)) {
          ally.power += 1;
          _net(g, 1);
          return '送った兵は、$anの砦の守りに加わった。$enは、ひと月ほどで兵を引いた。';
        }
        _net(g, -1);
        return '送った兵は少なすぎた。$anの使いは、礼の言葉もそこそこに帰っていった。';
      }),
      Choice.h('援軍を出さない', '国の兵は温存できる。盟友は離れていく', () {
        _net(g, -3);
        _fame(g, -2);
        g.setFlag('dm_engun_refused');
        return '使いには、国の事情を述べて断った。$anの城がいくつも落ちたと聞いたのは、その冬だった。';
      }),
      if (l.chi >= 60)
        Choice.h('$enの背後の国を突くよう、別の家に使いを出す', '才が当たれば戦わずに囲みが解ける。読みを誤れば盟友を見殺しにする', () {
          if (g.rng.chance(_try(l.chi))) {
            _cutOther(enemy, .92);
            _fame(g, 3);
            _net(g, 2);
            g.setFlag('dm_engun_ruse');
            g.mark('別の家に$enの背後を突かせ、盟友の囲みを解いた');
            return '$enの背後の国が兵を動かすと、$enは慌てて囲みを解いた。$anからは、礼の太刀が届いた。';
          }
          _net(g, -2);
          return '背後の家は動かなかった。$anは、ひとりで持ちこたえるほかなかった。';
        }, via: '知'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 家中

List<SceneDef> _houseScenes() => [
  // ============================================ 筋: 身分を問わぬ取り立て
  SceneDef('dm_toritate', 22, 84, (g) => _w1, dmLord, (g, next) {
    final n = _man(g);
    _keepName(g, 'dm_tori_name:', n);
    g.ask('足軽の才', '足軽の中に、$nという男がいる。百姓の出で字も満足に書けないが、砦攻めの段取りを立てさせれば、古参の侍大将より速い。この者に砦を一つ預けてはどうかと、近習が言う。譜代の家臣たちは、眉をひそめている。', [
      Choice.h('$nに砦を預ける', '才は生きる。譜代の誇りは傷つく', () {
        _grow(g, 2);
        _net(g, -1);
        g.setFlag('dm_tori_castle');
        _stamp(g, 'tori');
        g.mark('百姓あがりの足軽$nに、砦を一つ預けた');
        return '$nは、砦の鍵を両手で受け取ったまま、しばらく顔を上げられなかった。';
      }),
      Choice.h('侍大将の下につけ、まず手柄を立てさせる', '譜代も納得する。才が埋もれるかもしれない', () {
        _grow(g, 1);
        g.setFlag('dm_tori_slow');
        _stamp(g, 'tori');
        return '$nを侍大将の組に入れた。譜代の家臣たちは、それなら、とうなずいた。';
      }),
      Choice.h('身分の外の者は取り立てない', '家中の秩序は保たれる。才ある者は他国へ去る', () {
        _fame(g, -1);
        _net(g, 1);
        return '近習の話は、それきりにした。半年ののち、$nの姿は足軽長屋から消えていた。';
      }),
      if (g.l.bu >= 60)
        Choice.h('譜代の前で、自ら$nと槍を合わせる', '主が腕で確かめた者なら、誰も文句は言えない。あしらわれれば主の面目が立たない', () {
          _stamp(g, 'tori');
          if (g.might()) {
            _grow(g, 2);
            _fame(g, 2);
            g.setFlag('dm_tori_castle');
            return '三合打ち合って、槍を引いた。「この者の槍は本物だ。砦を預ける」。譜代の家臣たちは、黙って頭を下げた。';
          }
          _grow(g, 1);
          _fame(g, -1);
          g.setFlag('dm_tori_slow');
          return '$nの槍は速く、二合目で穂先が喉元に止まった。$nは青くなって平伏したが、譜代の者たちの目は冷たかった。ひとまず、侍大将の下に置くことにした。';
        }, via: '武'),
    ], after: next);
  }),

  _chain('dm_toritate_after', 25, 84, _w2, dmLord, (g, next) {
    final l = g.l;
    final n = _named(g, 'dm_tori_name:', '取り立てた男');
    if (g.hasFlag('dm_tori_castle')) {
      g.ask('百姓あがりの将', '砦を預けた$nが、隣国との境で砦を守り抜き、名を上げた。譜代の家老たちが連れ立って来て、百姓あがりが自分たちより上座に座るのは耐えられぬと言う。', [
        Choice.h('$nを家老に引き上げる', '才ある者が集まる国になる。譜代の離反を招くかもしれない', () {
          _fame(g, 3);
          g.setFlag('dm_tori_raised');
          _stamp(g, 'tori');
          g.mark('百姓あがりの$nを家老に引き上げた');
          if (g.rng.chance(.25)) {
            _cut(g, .94);
            return '$nが評定の席に着いた日、譜代の家老が二人、所領に引き籠もった。それでも、諸国から腕に覚えのある者が集まり始めた。';
          }
          _grow(g, 2);
          return '$nが評定の席に着いた。足軽長屋では、その夜遅くまで酒盛りの声が続いた。';
        }),
        Choice.h('譜代を立て、$nには褒美の銭だけ与える', '家中は静まる。あの者の心は冷めるかもしれない', () {
          _pay(g, 10);
          _net(g, 1);
          g.setFlag('dm_tori_paid');
          _stamp(g, 'tori');
          return '$nは、褒美の銭を押しいただいて砦へ戻った。それからは、あまり口を開かなくなった。';
        }),
        if (l.mi >= 60)
          Choice.h('$nと譜代の家老を一つの席に呼び、酒を酌み交わさせる', '人柄が通じれば家中が一つになる。席が荒れれば溝は深まる', () {
            _stamp(g, 'tori');
            if (g.rng.chance(_try(l.mi))) {
              _net(g, 4);
              _grow(g, 1);
              g.setFlag('dm_tori_mended');
              g.mark('百姓あがりの$nと譜代の家老に、一つの席で酒を酌み交わさせた');
              return '最初は黙りこくっていた家老も、$nの砦の守りの話に身を乗り出した。夜更けには、二人で肩を組んで謡っていた。';
            }
            _net(g, -2);
            return '盃が三巡したところで、家老が「土の匂いがする」と言った。$nは盃を置いて、黙って席を立った。';
          }, via: '魅'),
      ], after: next);
      return;
    }
    g.ask('埋もれた才', '侍大将の下に置いた$nが、上役に手柄を奪われ続けていると噂に聞いた。このままでは、あの者は他国へ去るかもしれない。', [
      Choice.h('自ら$nを呼び、直に仕えさせる', 'あの者の才は生きる。侍大将の面目は潰れる', () {
        _grow(g, 1);
        g.setFlag('dm_tori_direct');
        _stamp(g, 'tori');
        return '$nを近習の列に加えた。侍大将は苦い顔をしたが、何も言わなかった。';
      }),
      Choice.h('手柄を奪った上役を咎める', '筋は通る。上役の恨みを買う', () {
        _net(g, -1);
        _fame(g, 1);
        _stamp(g, 'tori');
        return '侍大将を呼び、首帳を改めさせた。$nの名が、ようやく首帳に記された。';
      }),
      Choice.h('捨て置く', '家中は波立たない。才は去るかもしれない', () {
        _stamp(g, 'tori');
        if (g.rng.chance(.5)) {
          _cut(g, .98);
          g.setFlag('dm_tori_lost');
          return '翌年、$nが隣国の家で砦を任されたと聞いた。';
        }
        return '$nは、何も言わずに槍を担いで戦に出続けた。';
      }),
    ], after: next);
  }),

  // ============================================ 筋: 一門の長老
  SceneDef('dm_ichimon', 22, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    final n = g.rng.pick(kGivenM);
    _keepName(g, 'dm_ichi_name:', n);
    g.ask('一門の長老', '先代の兄弟にあたる叔父の$nは、一門の長老として家中に重きをなしている。評定では、当主の言葉より叔父の一言で事が決まることもある。叔父の屋敷には、近ごろ家臣たちの出入りが多い。', [
      Choice.h('叔父を重く用い、一門の筆頭に据える', '一門はまとまる。当主の声は軽くなる', () {
        _net(g, 2);
        g.j(-1);
        g.setFlag('dm_ichi_honored');
        _stamp(g, 'ichi');
        return '叔父を評定の上座に据えた。叔父は満足そうに、扇で膝を叩いた。';
      }),
      Choice.h('叔父を隠居させ、所領を減らす', '当主の声は通る。一門に溝が残る', () {
        _grow(g, 1);
        _net(g, -2);
        g.setFlag('dm_ichi_cut');
        _stamp(g, 'ichi');
        g.mark('一門の長老だった叔父$nを隠居させた');
        return '叔父は、隠居の沙汰を黙って聞いた。立ち上がるとき、一度だけこちらを見た。';
      }),
      if (l.chi >= 60)
        Choice.h('叔父に遠い砦を任せ、評定から自然に遠ざける', '才が当たれば角を立てずに済む。叔父に見透かされることもある', () {
          _stamp(g, 'ichi');
          if (g.rng.chance(_try(l.chi, .5))) {
            _grow(g, 1);
            _fame(g, 1);
            g.setFlag('dm_ichi_far');
            return '国境の要の砦は叔父どのにしか任せられぬ、と頭を下げた。叔父は胸を張って任地へ向かった。';
          }
          _net(g, -2);
          g.setFlag('dm_ichi_cut');
          return '叔父は「体よく追い払うつもりか」と笑い、所領に引き籠もった。';
        }, via: '知'),
    ], after: next);
  }),

  _chain('dm_ichimon_after', 25, 84, _w2, (g) => dmLord(g) && _other(g) != null, (g, next) {
    final l = g.l;
    final n = _named(g, 'dm_ichi_name:', '叔父');
    if (g.hasFlag('dm_ichi_honored')) {
      g.ask('叔父の枕元', '一門の筆頭に据えた叔父の$nが、病の床についた。枕元に呼ばれると、叔父は家中の誰が当主を軽んじているかを、一人ずつ名を挙げて語った。', [
        Choice.h('叔父の言葉どおり、その者たちを遠ざける', '家中は引き締まる。名を挙げられた者の恨みが残る', () {
          _grow(g, 1);
          _net(g, -1);
          g.setFlag('dm_ichi_heeded');
          _stamp(g, 'ichi');
          return '叔父の葬儀が済むと、名を挙げられた者たちを遠い所領へ移した。評定は、前より静かになった。';
        }),
        Choice.h('聞くだけにとどめ、皆を変わらず使う', '家中の和は保たれる。叔父の案じた火種は残る', () {
          _net(g, 2);
          g.setFlag('dm_ichi_trust');
          _stamp(g, 'ichi');
          g.mark('死の床の叔父$nから家中の内情を聞き、なお皆を変わらず使った');
          return '叔父の手を握り、「よく分かった」とだけ答えた。叔父は、それで安心したように目を閉じた。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('dm_ichi_cut')) {
      g.ask('隠居した叔父の屋敷', '隠居させた叔父の$nのもとに、家中の不満を抱く者たちが集まっているという。叔父を担いで兵を挙げる企てがあると、忍びの者が知らせてきた。', [
        Choice.h('先に叔父の屋敷を囲む', '芽は摘める。一門の血を流すことになる', () {
          _cut(g, .97);
          g.j(-6);
          g.setFlag('dm_ichi_crushed');
          _stamp(g, 'ichi');
          return '夜明けに屋敷を囲ませた。叔父は、集まっていた者たちの名を記した帳面を自ら差し出し、寺へ入った。';
        }),
        Choice.h('自ら叔父を訪ね、膝を詰めて話す', '叔父の心が解ければ家は一つになる。刃を向けられることもある', () {
          _stamp(g, 'ichi');
          if (g.rng.chance(.03)) {
            g.die('隠居させた叔父の屋敷を一人で訪ね、控えていた者に斬りつけられた', 'ansatsu');
            return '奥の間の襖の陰で、刀の鯉口を切る音がした。';
          }
          if (g.rng.chance(.65)) {
            _net(g, 4);
            g.setFlag('dm_ichi_reconciled');
            g.mark('隠居させた叔父$nの屋敷を自ら訪ね、和を結んだ');
            return '叔父と夜更けまで盃を重ねた。帰り際、叔父は「先代によう似てきた」と言って、門まで送ってくれた。';
          }
          _cut(g, .95);
          return '叔父は、一言も口をきかなかった。ひと月ののち、叔父に従う者たちが所領を捨てて隣国へ走った。';
        }),
        Choice.h('捨て置く', '騒ぎは起きないかもしれない。起きれば大きい', () {
          _stamp(g, 'ichi');
          if (g.rng.chance(.35)) {
            _cut(g, .9);
            return '秋、叔父を担いだ者たちが兵を挙げた。鎮めるまでに、国の三分の一が荒れた。';
          }
          return '企ては噂のままに終わった。叔父の屋敷の灯は、早く消えるようになった。';
        }),
      ], after: next);
      return;
    }
    final e = _other(g)!;
    final en = _hn(g, e.name);
    g.ask('叔父の文', '遠い砦に任せた叔父の$nが、境を接する$enと文を交わしているという。叔父は、国境を静めるための文だと言っている。', [
      Choice.h('叔父を信じる', '一門の信は保たれる。叔父の真意は分からない', () {
        _stamp(g, 'ichi');
        if (g.rng.chance(.2)) {
          _cut(g, .93);
          return '叔父は、砦ごと$enに降った。文の中身は、国境を静めるためのものではなかった。';
        }
        _net(g, 2);
        g.setFlag('dm_ichi_trust');
        return '叔父の文のおかげで、国境の小競り合いは目に見えて減った。';
      }),
      Choice.h('叔父を呼び戻す', '危うさは除ける。叔父の面目は潰れる', () {
        _net(g, -1);
        _stamp(g, 'ichi');
        return '叔父は呼び戻され、館の一間で暮らすことになった。砦には若い侍大将が入った。';
      }),
      if (l.chi >= 60)
        Choice.h('叔父の文を写させ、$enの内情を探る手立てにする', '才が当たれば敵の内が見える。叔父に気づかれれば溝ができる', () {
          _stamp(g, 'ichi');
          if (g.rng.chance(_try(l.chi))) {
            _fame(g, 2);
            _grow(g, 1);
            g.setFlag('dm_ichi_used');
            g.mark('叔父と隣国の文の往来を写させ、$enの内情を探った');
            return '写しの文から、$enの重臣どうしの不和が透けて見えた。叔父には何も言わず、写しだけを手元に積んだ。';
          }
          _net(g, -2);
          return '文を写させていたことが叔父に知れた。叔父は、それきり文を寄こさなくなった。';
        }, via: '知'),
    ], after: next);
  }),

  // ============================================ ひとつきり: 恩賞の地
  SceneDef('dm_onsho', 22, 84, (g) => _w1, dmLord, (g, next) {
    final l = g.l;
    g.ask('恩賞の地', '戦が続き、手柄を立てた家臣たちに与える土地が足りなくなった。恩賞を待つ者たちの不満が、評定の間にまで聞こえてくる。', [
      Choice.h('直に治める地を削って分け与える', '家臣は奮い立つ。国の蔵は細る', () {
        _pay(g, 10);
        _net(g, 3);
        g.j(1);
        g.setFlag('dm_onsho_land');
        return '蔵入地の村をいくつも割いて与えた。恩賞の判物を受け取った家臣たちは、次の戦を待ちかねるようになった。';
      }),
      Choice.h('土地の代わりに茶道具や感状を与える', '土地を減らさずに済む。値打ちの分からぬ者は不満を残す', () {
        _pay(g, 10);
        _net(g, 1);
        g.setFlag('dm_onsho_cha');
        if (g.rng.chance(.3)) {
          _net(g, -2);
          return '感状を受け取った古参の侍は、「紙では飯は炊けぬ」と言って広間を出ていった。';
        }
        return '茶入れを賜った侍大将は、土地をもらうより喜び、家中で自慢して回った。';
      }),
      Choice.h('次の国取りまで待たせる', '蔵も土地も守れる。待たされた者は働かなくなる', () {
        _cut(g, .97);
        g.setFlag('dm_onsho_wait');
        return '恩賞は次の国取りのあとに、と触れを出した。その年の戦では、どの組も槍の出が遅かった。';
      }),
      if (l.sei >= 60)
        Choice.h('手柄を帳面に記させ、一人ずつ見合った恩賞を決める', '政の才があれば不満が収まる。手間は大きい', () {
          if (g.rng.chance(_try(l.sei, .5))) {
            _grow(g, 2);
            _net(g, 3);
            _fame(g, 2);
            g.setFlag('dm_onsho_fair');
            g.mark('家臣の手柄を帳面に記させ、見合った恩賞を一人ずつ決めた');
            return '首帳と感状を突き合わせ、一人ずつ恩賞を決めた。帳面を見せられた家臣は、誰も文句を言わなかった。';
          }
          _net(g, -1);
          return '帳面を作るうちに、手柄の取り合いで家臣どうしの口論が始まった。';
        }, via: '政'),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 天下に手が届く者

List<SceneDef> _tenkaScenes() => [
  // ============================================ ひとつきり: 都の仕置き
  SceneDef('dm_t_kyo', 25, 84, (g) => _wT, dmNear, (g, next) {
    final l = g.l;
    g.ask('都の仕置き', '都を押さえた。焼け跡の残る洛中では、町衆が自ら木戸を固め、寺社はそれぞれの言い分を持って門前に列をなしている。都をどう治めるかを、諸国の大名が見ている。', [
      Choice.h('洛中に禁制を出し、兵の乱暴を固く禁じる', '町衆の信が得られる。兵の不満は溜まる', () {
        _fame(g, 5);
        _net(g, 3);
        g.setFlag('dm_t_kinsei');
        g.mark('都に禁制を出し、兵の乱暴を固く禁じた');
        return '町の辻に禁制の札が立った。銭一つ奪った足軽が首を打たれると、洛中の木戸は昼のあいだ開かれるようになった。';
      }),
      Choice.h('町衆に矢銭を課し、兵糧に充てる', '蔵は満ちる。都の人の心は離れる', () {
        l.gold += 25;
        _fame(g, -3);
        g.setFlag('dm_t_yasen');
        return '町衆の年寄たちは、黙って銭を差し出した。都の童たちが、こちらの家の名を入れた戯れ歌を歌い始めた。';
      }),
      Choice.h('内裏と寺社の修理に銭を出す', '名分と信望が得られる。銭は重い', () {
        _pay(g, 30);
        _fame(g, 6);
        _grow(g, 1);
        g.setFlag('dm_t_shuri');
        g.mark('都を押さえると、内裏と寺社の修理に銭を出した');
        return '崩れた築地に足場が組まれ、槌の音が都に戻った。';
      }),
      if (l.mi >= 60)
        Choice.h('町衆の年寄たちを宿所に招き、自ら話を聞く', '都の人の心をつかめる。宿所の守りは手薄になる', () {
          if (g.rng.chance(.03)) {
            g.die('都の宿所で町衆の年寄たちと語り明かした夜、紛れ込んだ刺客の刃を受けた', 'ansatsu');
            return '年寄たちが帰ったあと、灯りの消えた廊下で足音がした。';
          }
          _net(g, 5);
          _fame(g, 4);
          g.setFlag('dm_t_machishu');
          g.mark('都の町衆の年寄たちを宿所に招き、自ら言い分を聞いた');
          return '年寄たちは最初こそ身を固くしていたが、夜更けには祇園の祭りの話で笑い声を上げた。';
        }, via: '魅'),
    ], after: next);
  }),

  // ============================================ 筋: 私の戦を禁じる命
  SceneDef('dm_t_bujirei', 25, 84, (g) => _wT, dmNear, (g, next) {
    final l = g.l;
    g.ask('私の戦を禁じる', '諸国では、まだ大名どうしが境を争っている。家臣が、天下の主として、私の戦を一切禁じる命を諸国に下してはどうかと言う。従わぬ者を討つ名分にもなる。', [
      Choice.h('私の戦を禁じる命を下す', '従う者は増える。背く者とは戦になる', () {
        _fame(g, 5);
        g.setFlag('dm_t_buji');
        _stamp(g, 'buji');
        g.mark('諸国の大名に、私の戦を禁じる命を下した');
        return '朱印を押した命が、諸国へ運ばれていった。国境で睨み合っていた大名たちが、そろって兵を引き始めた。';
      }),
      Choice.h('命は下さず、一つずつ従えていく', '名分はないが、手は縛られない', () {
        _grow(g, 1);
        g.setFlag('dm_t_buji_none');
        _stamp(g, 'buji');
        return '命など紙にすぎぬと、家臣の献策を退けた。従わぬ家は、一つずつ兵で従えると決めた。';
      }),
      if (l.sei >= 60)
        Choice.h('境の争いを裁く奉行を置き、訴えを聞く場を設ける', '政の才があれば争いが裁きに変わる。訴えが山のように積まれる', () {
          _stamp(g, 'buji');
          g.setFlag('dm_t_buji');
          if (g.rng.chance(_try(l.sei, .5))) {
            _net(g, 3);
            _fame(g, 3);
            g.setFlag('dm_t_buji_court');
            g.mark('私の戦を禁じ、境の争いを裁く奉行を置いた');
            return '奉行所の前に、諸国の大名の使いが訴えの文を抱えて列をなした。刀を抜く代わりに、絵図と証文が持ち込まれるようになった。';
          }
          return '奉行は置いたが、訴えは裁ききれずに積み上がった。命だけが、諸国に届いた。';
        }, via: '政'),
    ], after: next);
  }),

  _chain('dm_t_bujirei_after', 27, 84, _w2, (g) => dmNear(g) && _strongest(g) != null, (g, next) {
    final l = g.l;
    final e = _strongest(g)!;
    final en = _hn(g, e.name);
    if (g.hasFlag('dm_t_buji')) {
      g.ask('命に背いた家', '私の戦を禁じた命に、$enが背いた。境を越えて隣の家の砦を攻め落とし、天下の主の命など知らぬと言い放ったという。諸国の大名が、どう出るかを見ている。', [
        Choice.h('諸国の大名に陣触れし、$enを討つ', '命の重みを示せる。戦は戦だ', () {
          _stamp(g, 'buji');
          final r = g.battle('main', enemy: e.name, risk: .7, gain: 1.2, edge: .1);
          if (l.dead != null) return '諸国に陣触れをした。$r';
          _fame(g, 3);
          g.setFlag('dm_t_buji_punish');
          g.mark('私の戦を禁じた命に背いた$enに、諸国の兵を差し向けた');
          return '諸国に陣触れをした。$r';
        }),
        Choice.h('使いを送り、奪った砦を返させる', '血は流れない。侮られるかもしれない', () {
          _stamp(g, 'buji');
          if (g.rng.chance(clampD(.4 + g.share, .4, .85))) {
            _cutOther(e, .95);
            _fame(g, 3);
            g.setFlag('dm_t_buji_returned');
            return '$enの当主は、使いの前で渋々と砦の明け渡しの書付に判を押した。';
          }
          _fame(g, -3);
          return '$enは使いを門前で追い返した。諸国の大名のあいだに、天下の主の命は軽いという声が広がった。';
        }),
        if (g.hasFlag('dm_t_buji_court'))
          Choice.h('奉行に裁かせ、$enの言い分も聞く', '裁きの名が天下に広まる。手ぬるいと言う者も出る', () {
            _net(g, 3);
            _fame(g, 4);
            _cutOther(e, .97);
            g.setFlag('dm_t_buji_judged');
            _stamp(g, 'buji');
            g.mark('命に背いた$enを奉行の裁きの場に呼び、言い分を聞いた上で砦を返させた');
            return '奉行所の白洲に、$enの家老が座らされた。言い分は聞かれ、そのうえで砦は返された。';
          }),
      ], after: next);
      return;
    }
    g.ask('頭を下げぬ家', '一つずつ従えてきた諸国の大名のうち、$enだけが、まだ頭を下げない。家臣たちは、天下の主に従わぬ者を討つ名分がないと案じている。', [
      Choice.h('名分などいらぬ、と攻める', '決着は早い。諸国は次は我が身かと身構える', () {
        _stamp(g, 'buji');
        final r = g.battle('main', enemy: e.name);
        return '名分のない戦に、諸国は息を潜めて見守った。$r';
      }),
      Choice.h('朝廷を通じて名分を得てから動く', '名分は立つ。銭と時はかかる', () {
        _pay(g, 20);
        _fame(g, 3);
        _grow(g, 1);
        g.setFlag('dm_t_buji_rinji');
        _stamp(g, 'buji');
        return '都からの綸旨が届くと、$enの家中からも寝返る者が出始めた。';
      }),
      Choice.h('$enの所領を安堵し、まず形だけ従わせる', '戦は避けられる。牙は残る', () {
        _cutOther(e, .95);
        _grow(g, 1);
        g.setFlag('dm_t_buji_nominal');
        _stamp(g, 'buji');
        return '$enの当主は、所領の安堵状を受け取ると、型どおりに頭を下げた。目は伏せたままだった。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 天下の居城の地
  SceneDef('dm_t_kyojo', 30, 84, (g) => _wT, dmNear, (g, next) {
    g.ask('天下の居城の地', '天下の主にふさわしい居城をどこに置くか、評定は割れている。海に面した湊の地、都に近い湖の畔、そして生まれ育った国。それぞれに、推す家臣がいる。', [
      Choice.h('海に面した湊の地に築く', '諸国の船が集まり、蔵が満ちる。海からの守りは難しい', () {
        _pay(g, 30);
        _grow(g, 2);
        g.l.gold += 15;
        g.setFlag('dm_t_kyo_minato');
        g.mark('天下の居城を、海に面した湊の地に定めた');
        return '湊の埋め立てが始まり、石を積んだ船が沖に列をなした。南蛮の船の帆柱が、普請の足場の向こうに見えた。';
      }),
      Choice.h('都に近い湖の畔に築く', '都と諸国を見張れる。天下の目が集まる', () {
        _pay(g, 30);
        _fame(g, 6);
        _grow(g, 1);
        g.setFlag('dm_t_kyo_kohan');
        g.mark('天下の居城を、都に近い湖の畔に定めた');
        return '湖の水面に、高い天守の影が映るようになった。都から見物に来る公家も多かった。';
      }),
      Choice.h('生まれ育った国に留まる', '守りも家臣の心も固い。都は遠い', () {
        _net(g, 3);
        g.j(2);
        g.setFlag('dm_t_kyo_furusato');
        return '「${_ware(g)}の城はここでよい」と言い切った。古い家臣たちは、目を潤ませてうなずいた。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 湊町の豪商
  SceneDef('dm_t_sakai', 25, 84, (g) => _wT, dmNear, (g, next) {
    final l = g.l;
    final town = g.rng.pick(['堺', '博多']);
    g.ask('湊町の豪商', '$townの会合衆は、町を濠で囲み、牢人を雇って自ら守っている。天下の主に従うなら、町の自治は認めてもよい。だが矢銭を拒めば、町を焼くしかないと言う家臣もいる。', [
      Choice.h('矢銭を課し、従わねば町を焼くと告げる', '銭と町が手に入る。商人たちの心は離れる', () {
        if (g.rng.chance(.8)) {
          l.gold += 30;
          _grow(g, 2);
          _fame(g, -2);
          g.setFlag('dm_t_sakai_forced');
          return '会合衆は、蒼い顔で矢銭を差し出した。濠の水は、そのまま抜かれた。';
        }
        _cut(g, .97);
        g.j(-4);
        g.setFlag('dm_t_sakai_burned');
        return '会合衆は矢銭を拒んだ。$townの町は三日燃え、焼け跡からは、何も持ち出せなかった。';
      }),
      Choice.h('会合衆の主だった者を茶頭に取り立てる', '銭も茶の湯も味方になる。町の誇りは残る', () {
        l.gold += 15;
        _net(g, 3);
        _fame(g, 3);
        g.setFlag('dm_t_sakai_chado');
        g.mark('$townの豪商を茶頭に取り立て、町を従えた');
        return '茶頭となった豪商は、最初の茶会で、名物の茶入れを一つ献上してきた。';
      }),
      Choice.h('町の自治を認め、冥加金だけを納めさせる', '町は栄え続ける。天下の威は軽く見られる', () {
        l.gold += 10;
        _net(g, 2);
        g.setFlag('dm_t_sakai_free');
        return '会合衆は、毎年の冥加金を約した。$townの濠には、今日も舟が行き交っている。';
      }),
      if (l.sei >= 60)
        Choice.h('濠を埋めさせる代わりに、諸国の湊での商いの特権を与える', '政の才があれば町も天下も得をする。帳尻が合わなければ双方から恨まれる', () {
          if (g.rng.chance(_try(l.sei))) {
            _grow(g, 3);
            l.gold += 20;
            g.setFlag('dm_t_sakai_deal');
            g.mark('$townの濠を埋めさせる代わりに、諸国の湊での商いの特権を与えた');
            return '会合衆は、天下の湊に船を出せると聞くと、自ら濠を埋める人足を集めた。';
          }
          _net(g, -2);
          return '会合衆は特権の中身に満足せず、話はこじれたまま年を越した。';
        }, via: '政'),
    ], after: next);
  }),

  // ============================================ ひとつきり: 故郷からの文
  SceneDef('dm_t_fumi', 35, 84, (g) => _wT, dmNear, (g, next) {
    g.ask('故郷からの文', '故郷の国から、古い文が届いた。差し出したのは、まだ名もなかったころの自分を知る、村の年寄だ。「お偉くなられたが、お体は大事に」と、たどたどしい字で書いてある。使いの者は、主がそれを読むあいだ、目を伏せたままでいる。', [
      Choice.h('自ら返事を書く', '心が少し温まる。天下の主の文は、村の宝になる', () {
        g.j(6);
        _net(g, 1);
        g.setFlag('dm_t_fumi_wrote');
        g.mark('天下を前にして、故郷の年寄からの文に自ら返事を書いた');
        return '祐筆を下がらせ、自ら筆を取った。書き終えるまでに、灯りの油を一度足させた。';
      }),
      Choice.h('故郷の村の年貢を、末代まで免じる', '恩は返せる。ほかの村は妬む', () {
        _pay(g, 10);
        g.j(4);
        _fame(g, 2);
        g.setFlag('dm_t_fumi_menjo');
        return '故郷の村の年貢を末代まで免じる朱印状を書かせた。使いの者は、それを押しいただいて泣いた。';
      }),
      Choice.h('文を読み終えると、黙って火鉢にくべる', '振り返らずに済む。胸の奥は冷えていく', () {
        g.j(-5);
        _grow(g, 1);
        g.setFlag('dm_t_fumi_burned');
        return '文は、火鉢の中で小さく丸まって燃えた。使いの者は、何も言わずに下がっていった。';
      }),
    ], after: next);
  }),
];

// ---------------------------------------------------------------- 女の当主

List<SceneDef> _womanScenes() => [
  // ============================================ 筋: 女主への侮り
  SceneDef('dm_w_anadori', 20, 84, (g) => _wF, dmWoman, (g, next) {
    final l = g.l;
    final head = dmRegent(g) ? '幼い当主に代わって評定に出るようになってから' : '女の身で家を継いでから';
    g.ask('女主への侮り', '$head、年かさの重臣たちが目配せを交わすようになった。女の言うことと、まともに取り合わない者がいる。今日も、筆頭の重臣が「それは奥でお考えになることではござらぬ」と口にした。', [
      Choice.h('評定の席で、その重臣を叱りつける', '女主の威が立つ。重臣の面目は潰れる', () {
        _fame(g, 3);
        _net(g, -2);
        g.setFlag('dm_w_scolded');
        _stamp(g, 'wan');
        return '「この家の主は誰か」と声を張った。広間が静まり返り、重臣は顔を赤くして平伏した。';
      }),
      Choice.h('重臣の言い分を聞き、事は家老たちに任せる', '評定は穏やかに回る。主の声は軽くなる', () {
        _net(g, 2);
        g.j(-3);
        g.setFlag('dm_w_yielded');
        _stamp(g, 'wan');
        return '「よきにはからえ」と言って席を立った。背中で、重臣たちが小さく笑う気配がした。';
      }),
      if (l.chi >= 60)
        Choice.h('重臣の持ち出した算用の誤りを、その場で一つずつ正す', '才が通じれば誰も侮らなくなる。外せば笑い者になる', () {
          _stamp(g, 'wan');
          if (g.rng.chance(_try(l.chi, .5))) {
            _fame(g, 5);
            g.setFlag('dm_w_proved');
            g.mark('評定の席で重臣の算用の誤りを正し、女主を侮る声を黙らせた');
            return '兵糧の俵の数と、村ごとの年貢の高を、帳面も見ずに言い当てた。重臣は額に汗を浮かべ、算盤を置いた。';
          }
          _fame(g, -2);
          g.setFlag('dm_w_yielded');
          return '正したはずの数が、帳面と合わなかった。重臣たちは、扇の陰で笑った。';
        }, via: '知'),
      if (l.mi >= 60)
        Choice.h('若い家臣たちを奥の茶の席に招き、味方につける', '人柄が通じれば次の世の家中が味方になる。年寄たちはなお遠ざかる', () {
          _stamp(g, 'wan');
          if (g.rng.chance(_try(l.mi, .5))) {
            _net(g, 4);
            g.setFlag('dm_w_young');
            g.mark('奥の茶の席に若い家臣たちを招き、味方につけた');
            return '若い侍たちは、茶の作法もおぼつかないまま、国の行く末を熱っぽく語った。評定で、彼らが真っ先にうなずくようになった。';
          }
          g.setFlag('dm_w_yielded');
          return '若い侍たちは、奥の席を居心地悪そうにして、早々に帰っていった。';
        }, via: '魅'),
    ], after: next);
  }),

  _chain('dm_w_anadori_after', 22, 84, _w2, dmWoman, (g, next) {
    final l = g.l;
    if (g.hasFlag('dm_w_scolded')) {
      g.ask('籠もった重臣', '叱りつけた重臣が、病と称して評定に出なくなった。その屋敷に、ほかの重臣たちが夜ごと集まっているという。', [
        Choice.h('重臣の屋敷へ自ら見舞いに行く', '和が成れば家中は一つになる。女主を侮る者たちの中へ入ることになる', () {
          _stamp(g, 'wan');
          if (g.rng.chance(.03)) {
            g.die('侮る重臣たちの屋敷を見舞いに訪ねた帰り、輿の中で襲われた', 'ansatsu');
            return '帰りの夜道で、輿がふいに止まった。';
          }
          if (g.rng.chance(.6)) {
            _net(g, 4);
            g.setFlag('dm_w_mended');
            g.mark('病と称して籠もった重臣を自ら見舞い、和を結んだ');
            return '床から起き上がった重臣は、しばらく黙っていたが、やがて「先代の御台所さまに、よう似ておられる」と言って頭を下げた。';
          }
          _net(g, -1);
          return '重臣は、几帳の向こうから咳をするばかりで、顔を見せなかった。';
        }),
        Choice.h('重臣の所領を削る', '主の威は示せる。家中の溝は深まる', () {
          _grow(g, 1);
          _net(g, -3);
          g.setFlag('dm_w_cut');
          _stamp(g, 'wan');
          return '重臣の所領の半ばを召し上げた。集まっていた者たちは、それきり屋敷へ行かなくなった。';
        }),
        Choice.h('一門の男を後ろ盾に立てる', '家中は落ち着く。主の声はまた軽くなる', () {
          _net(g, 1);
          g.j(-3);
          _stamp(g, 'wan');
          return '一門の年長の男を評定の上座に据えた。重臣たちは、その男に向かって話すようになった。';
        }),
      ], after: next);
      return;
    }
    if (g.hasFlag('dm_w_yielded')) {
      g.ask('お方さまへの訴え', '家老たちに任せてきた政で、年貢の取り立てが重くなり、村々から訴えが届くようになった。訴えの文は、どれも「お方さまへ」と宛てられている。', [
        Choice.h('自ら訴えを裁く', '民の信が得られる。家老たちは面白くない', () {
          _net(g, 3);
          _fame(g, 2);
          g.setFlag('dm_w_judged');
          _stamp(g, 'wan');
          g.mark('家老任せの政を改め、村々の訴えを自ら裁いた');
          return '訴えの文を一通ずつ読み、年貢を定めの高に戻させた。村からは、礼の青物が館の台所に届いた。';
        }),
        Choice.h('家老たちに任せたままにする', '評定は荒れない。村の恨みは主に向く', () {
          _cut(g, .97);
          g.j(-2);
          _stamp(g, 'wan');
          return '訴えの文は、読まずに家老へ回した。村々の年貢は、その秋も遅れた。';
        }),
      ], after: next);
      return;
    }
    final e = _other(g);
    final en = _hn(g, e?.name);
    g.ask('侮る隣国の使い', '家中で女主を侮る声が消えたころ、$enから使いが来た。「女の治める国なら」と、境の村を譲れと言ってきたのだ。', [
      if (e != null)
        Choice.h('自ら具足をつけて国境へ出る', '侮りは晴れる。戦は戦だ', () {
          _stamp(g, 'wan');
          final r = g.battle('main', enemy: e.name, risk: .7, edge: .05);
          if (l.dead != null) return '自ら具足をつけ、国境へ馬を出した。$r';
          _fame(g, 3);
          g.setFlag('dm_w_armored');
          g.mark('女の治める国と侮った隣国の使いを追い返し、自ら具足をつけて国境に出た');
          return '自ら具足をつけ、国境へ馬を出した。$r';
        }),
      Choice.h('使いを丁重にもてなして帰す', '争いは先へ延びる。侮りは残る', () {
        _net(g, 1);
        _stamp(g, 'wan');
        return '使いに酒と引き出物を持たせて帰した。村の話には、一言も答えなかった。';
      }),
      if (l.chi >= 60)
        Choice.h('使いに国の帳面を見せ、兵と兵糧の多さを悟らせる', '才が当たれば戦わずに退かせられる。手の内を明かすことにもなる', () {
          _stamp(g, 'wan');
          if (g.rng.chance(_try(l.chi, .5))) {
            _fame(g, 3);
            g.setFlag('dm_w_bluff');
            return '蔵の米俵と、槍の数を記した帳面を、使いの前に広げさせた。使いは顔色を変え、村の話は二度と出なかった。';
          }
          _net(g, -1);
          return '使いは帳面を眺めて鼻で笑った。「紙の上の兵は、槍を持ちませぬ」。';
        }, via: '知'),
      if (l.bu >= 60)
        Choice.h('使いの前で薙刀を取り、庭の巻藁を断って見せる', '言葉は要らない。腕が鈍っていれば、侮りは深まる', () {
          _stamp(g, 'wan');
          if (g.might()) {
            _fame(g, 4);
            return '白刃が一度閃き、巻藁が斜めに滑り落ちた。「境の村が欲しくば、これを越えて参られよ」。使いは茶にも手をつけずに帰った。';
          }
          _net(g, -1);
          return '刃は巻藁の半ばで止まった。使いは目を伏せたが、口元は笑っていた。';
        }, via: '武'),
    ], after: next);
  }),

  // ============================================ ひとつきり: 婿の話
  SceneDef('dm_w_muko', 18, 45, (g) => _wF, (g) => dmWoman(g) && !g.l.married && !dmRegent(g), (g, next) {
    final n = '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';
    g.ask('婿の話', '家中の重臣たちが、一門の若者か、他家の次男を婿に迎えるべきだと言い出した。女の当主では、いずれ家が割れるというのだ。名が挙がっているのは、近い家の次男の$nだ。', [
      Choice.h('$nを婿に迎える', '他家との縁が固まる。婿の後ろの家が口を出すかもしれない', () {
        g.l.married = true;
        g.meet('伴侶', n, 50);
        _grow(g, 2);
        g.setFlag('dm_w_muko_other');
        g.mark('他家の次男$nを婿に迎えた');
        return '$nは、婿として館に入った。評定では、いつも一歩下がった席に座った。';
      }),
      Choice.h('一門の若者を婿に迎える', '家中はまとまる。外の後ろ盾は得られない', () {
        final m = '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';
        g.l.married = true;
        g.meet('伴侶', m, 55);
        _net(g, 2);
        g.setFlag('dm_w_muko_kin');
        g.mark('一門の若者$mを婿に迎えた');
        return '幼いころから知る一門の$mが、婿として館に入った。古い家臣たちは、胸をなで下ろした。';
      }),
      Choice.h('婿は取らず、当主のままでいる', '家は自らの手で治める。跡継ぎを案じる声は消えない', () {
        g.j(2);
        _fame(g, 2);
        g.setFlag('dm_w_muko_none');
        g.mark('婿を迎えよとの声を退け、女の当主のまま家を治めた');
        return '「この家の当主は${_ware(g)}だ」と言って、話を打ち切った。重臣たちは、顔を見合わせて黙り込んだ。';
      }),
    ], after: next);
  }),

  // ============================================ ひとつきり: 後見してきた当主の元服
  SceneDef('dm_w_genpuku', 25, 84, (g) => _wF * 2, (g) => dmRegent(g) && g.l.hasKidAged(g.year, 14, 20), (g, next) {
    final l = g.l;
    g.ask('当主の元服', '後見してきた幼い当主が、元服の年を迎えた。烏帽子をつけた姿は、まだ細い。家臣たちは、政をいつ当主に返すのかと、そっと様子をうかがっている。', [
      Choice.h('元服の日に、政を当主に返す', '当主は早く育つ。若い当主の過ちは止められない', () {
        g.j(3);
        _net(g, 2);
        g.setFlag('dm_w_returned');
        g.mark('後見してきた当主の元服の日に、政を返した');
        if (g.rng.chance(.2)) {
          _cut(g, .95);
          return '若い当主は、最初の評定で重臣の言いなりに兵を動かし、境の砦を一つ失った。';
        }
        return '元服の祝いの席で、印判を当主の前に置いた。当主は、それを両手で受け取った。';
      }),
      Choice.h('数年は後ろで政を見る', '国は揺れない。当主との間に溝ができるかもしれない', () {
        _grow(g, 1);
        g.j(-1);
        g.setFlag('dm_w_kept');
        return '印判は、まだ手元に置いた。当主は何も言わなかったが、評定の席で目を合わせなくなった。';
      }),
      if (l.chi >= 60)
        Choice.h('評定に当主を座らせ、自らは隣で黙って聞く', '才が当たれば当主は早く一人で立てる。口を挟みたくなる日も続く', () {
          if (g.rng.chance(_try(l.chi, .5))) {
            _fame(g, 3);
            _net(g, 2);
            g.setFlag('dm_w_taught');
            g.mark('元服した当主を評定に座らせ、隣で黙って政を見守った');
            return '当主が言葉に詰まるたびに、膝の上の扇を少しだけ動かした。半年もすると、扇を動かすことはなくなった。';
          }
          g.setFlag('dm_w_kept');
          return '黙っているつもりが、つい口を挟んでしまった。重臣たちは、やはり後見の顔色をうかがった。';
        }, via: '知'),
    ], after: next);
  }),
];
