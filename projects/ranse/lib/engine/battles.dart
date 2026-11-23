import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';
import 'trait_scenes.dart';
import 'variety.dart';

/// 合戦の状況（2026-11-23）。足軽・侍の道は成人した人生でいちばん多いのに、出陣の岐路は
/// 書き出しが変わるだけで選択肢が毎回同じ（先陣・本陣・後詰め・断る）だった。
/// 出陣のたびに、身分・能力・主家の勢い・季節で状況を一つ選び、状況ごとの2〜3の手で戦う。
///
/// - 結果は `Game.battle` を通す（手柄・名声・主家の勢い・討死・深手の流れは従来どおり）。
///   手ごとに危うさ（risk）・手柄（gain）・勝ちやすさ（edge）を変え、能力（武・知・運・魅・政）の
///   見立てが当たるかで、その倍率が良くも悪くもなる。
/// - 直近に出た状況は旗 `bsr<0..2>:<id>`（0 が最新）に残し、同じ状況が続けて出にくくする。
///   出たことのある状況は旗 `bs:<id>`。
/// - 死ぬのは `Game.battle` の中だけ（死因の文「◯◯との合戦で討死」「戦傷が元で死去」は従来のまま）。

const kRecentBattles = 3;

class BattleSit {
  const BattleSit(
    this.id,
    this.name,
    this.lo,
    this.hi,
    this.weight,
    this.run, {
    this.cond,
  });

  final String id;

  /// 状況の短い名（テストと CLAUDE.md の一覧用）。
  final String name;

  /// 出る身分の幅（位）。
  final int lo, hi;
  final double Function(Game g, BattleCtx c) weight;
  final bool Function(Game g, BattleCtx c)? cond;

  /// 状況の文と選択肢を返す。
  final (String, List<Choice>) Function(Game g, BattleCtx c) run;
}

/// その出陣の前提（敵・季節・勢い）。
class BattleCtx {
  BattleCtx(this.enemy, this.season, this.weak, this.strong);

  /// 敵の家（内部の名）。
  final String enemy;

  /// 0 春・1 夏・2 秋・3 冬。
  final int season;

  /// 主家が敵より弱い／強い。
  final bool weak, strong;
}

int _c(int v) => clampInt(v, 0, 100);

/// 能力の見立てが当たるか。[stat] が高いほど、運もいくらか効く。
bool _try(Game g, int stat, [double base = .35]) =>
    g.rng.chance(clampD(base + (stat - 50) / 110 + (g.l.un - 50) / 400, .12, .9));

String _en(Game g, BattleCtx c) => houseName(g, c.enemy);
String _lord(Game g) => houseName(g, g.l.lord);
bool _low(Game g) => g.l.rank <= 2;
String _who(Game g) => g.l.rank <= 2 ? '組頭' : (g.l.rank <= 4 ? '大将' : '殿');

String _fight(
  Game g,
  BattleCtx c,
  String pre,
  String role, {
  double risk = 1,
  double gain = 1,
  double edge = 0,
}) =>
    '$pre${g.battle(role, enemy: c.enemy, risk: risk * traitBattleRisk(g, role), gain: gain * traitBattleGain(g, role), edge: edge)}';

bool _alive(Game g) => g.l.dead == null;

/// 一生に一度だけ、歩んだ道に残す。
void _markOnce(Game g, String flag, String text) {
  if (!_alive(g) || g.hasFlag(flag)) return;
  g.setFlag(flag);
  g.mark(text);
}

List<BattleSit> buildBattleSits() => [
  // ---------------- 夜襲を命じられる ----------------
  BattleSit('bt_night_order', '夜襲を命じられる', 1, 4, (g, c) => c.season == 3 ? 1.6 : 1, (g, c) {
    final t = _low(g)
        ? '${_en(g, c)}勢と川を挟んで睨み合って三日。組頭が声を落として告げた。「今夜、敵陣に夜討ちをかける」'
        : '${_en(g, c)}勢と睨み合ったまま日が過ぎる。大将から、手勢を率いて夜討ちをかけよと命じられた。';
    return (t, [
      Choice.h('先頭で斬り込む', '夜討ちの一番乗りは大きな手柄。闇の中では討死もある', () {
        // 忍び足（`trait_scenes4.dart`）は、気づかれずに敵陣へ寄れる。
        final ok = traitNightRaid(g) || _try(g, g.l.bu);
        return _fight(
          g,
          c,
          ok ? '寝込みを襲われた敵は、刀も取れずに逃げ惑った。' : '敵の不寝番に気づかれ、闇の中で乱戦になった。',
          'van',
          risk: ok ? .8 : 1.3,
          gain: ok ? 1.5 : 1.1,
          edge: ok ? .15 : 0,
        );
      }),
      Choice.h('陣小屋に火を放って回る', '知恵が回れば敵は崩れる。しくじれば囲まれる', () {
        final ok = traitNightRaid(g) || _try(g, g.l.chi);
        return _fight(
          g,
          c,
          ok ? '風上から放った火が、敵の陣小屋を次々に呑んだ。' : '火口が湿っていた。もたつくうちに、敵が起き出してきた。',
          'main',
          risk: ok ? .7 : 1.4,
          gain: ok ? 1.3 : .9,
          edge: ok ? .2 : -.05,
        );
      }),
      Choice.h('道案内と見張りに徹する', '命は守りやすい。手柄は小さい', () {
        return _fight(g, c, '味方の背を見送り、退き口を固めた。', 'rear', gain: .8);
      }),
    ]);
  }),

  // ---------------- 敵の夜襲を受ける ----------------
  BattleSit('bt_night_attacked', '夜襲を受ける', 1, 7, (g, c) => (c.season == 3 ? 1.4 : 1) * (c.weak ? 1.3 : 1), (g, c) {
    final t = '夜半、陣のあちこちで鬨の声が上がった。${_en(g, c)}勢の夜討ちだ。'
        '${_low(g) ? '寝ていた足軽たちが、具足もつけずに右往左往している。' : '本陣の篝火が揺れ、伝令が駆け込んでくる。'}';
    return (t, [
      Choice.h('飛び起きて槍を取る', '腕が立てば押し返して手柄。囲まれれば危うい', () {
        final ok = _try(g, g.l.bu);
        return _fight(
          g,
          c,
          ok ? '真っ先に槍を取り、斬り込んできた敵を押し返した。' : '闇の中で敵味方の見分けがつかず、刃が四方から来た。',
          'main',
          risk: ok ? .9 : 1.5,
          gain: ok ? 1.4 : .9,
          edge: ok ? .1 : -.1,
        );
      }),
      Choice.h('篝火を焚いて味方を起こす', '陣が立ち直れば主君の目に留まる', () {
        final ok = _try(g, g.l.mi + traitPersuade(g));
        if (ok) g.l.fav = _c(g.l.fav + 4);
        return _fight(
          g,
          c,
          ok ? '火の明かりに味方が集まり、陣は持ち直した。' : '声を嗄らしたが、陣の乱れはなかなか収まらなかった。',
          'main',
          risk: .8,
          gain: 1.0,
          edge: ok ? .1 : -.05,
        );
      }),
      Choice.h('闇にまぎれて陣を離れる', '命は守れる。見る者は見ている', () {
        g.l.fav = _c(g.l.fav - 4);
        g.j(-2);
        return _fight(g, c, '夜明けまで、藪の中で息を潜めた。', 'rear', risk: .6, gain: .5);
      }),
    ]);
  }),

  // ---------------- 川を渡って攻める ----------------
  BattleSit('bt_river', '川を渡って攻める', 1, 7, (g, c) => c.season <= 1 ? 1.5 : 1, (g, c) {
    final t = '${_en(g, c)}勢は川向こうに陣を敷いた。'
        '${c.season == 1 ? '雨続きで水かさが増し、' : ''}流れは速い。渡らねば攻められない。';
    return (t, [
      Choice.h('浅瀬を探す', '見つかれば楽に渡れる。手間取れば敵に気づかれる', () {
        final ok = _try(g, g.l.chi);
        if (ok) g.l.fav = _c(g.l.fav + 2);
        return _fight(
          g,
          c,
          ok ? '馬の足跡をたどって、膝ほどの浅瀬を見つけた。味方はそこから渡った。' : '浅瀬を探すうちに日が傾き、敵に備えを固められた。',
          ok ? 'van' : 'main',
          risk: ok ? .6 : 1.1,
          gain: ok ? 1.3 : .8,
          edge: ok ? .15 : -.05,
        );
      }),
      Choice.h('正面から押し渡る', '一番乗りは名を上げる。流れに足を取られ、命を落とす者もいる', () {
        final ok = _try(g, g.l.bu, .3);
        return _fight(
          g,
          c,
          ok ? '腰まで水に浸かりながら、真っ先に向こう岸へ上がった。' : '流れに足を取られ、矢の雨の中を這うように渡った。',
          'van',
          risk: ok ? 1.0 : 1.5,
          gain: ok ? 1.6 : 1.0,
        );
      }),
      Choice.h('敵が渡ってくるのを待つ', '守りは堅い。手柄は少ない', () {
        return _fight(g, c, '岸に柵を立て、敵が渡ってくるのを待った。', 'main', risk: .7, gain: .7, edge: .05);
      }),
    ]);
  }),

  // ---------------- 敵将の旗 ----------------
  BattleSit('bt_banner', '敵将の旗が見えた', 1, 7, (g, c) => 1 + g.l.bu / 100, (g, c) {
    final t = '乱戦の向こうに、${_en(g, c)}の将の旗印が見えた。供回りは少ない。'
        '${_low(g) ? '朋輩が「あれを討てば、足軽でも侍になれるぞ」と叫んだ。' : '討ち取れば、この戦の帰趨が決まる。'}';
    return (t, [
      Choice.h('旗を目がけて駆ける', '討ち取れば大きな手柄。旗本は手練ればかりで、返り討ちにされて死ぬ者も多い', () {
        final ok = _try(g, (g.l.bu + g.l.un) ~/ 2, .25);
        final r = _fight(
          g,
          c,
          ok ? '旗本の槍をかいくぐり、敵将に組みついた。' : '旗本の槍衾に阻まれ、何度も押し返された。',
          'van',
          risk: ok ? 1.1 : 1.5,
          gain: ok ? 2.2 : 1.0,
          edge: ok ? .2 : 0,
        );
        if (ok && _alive(g)) {
          g.l.fame += 8;
          _markOnce(g, 'bt_slew_general', '乱戦の中で、敵の将を討ち取った');
          return '$r敵将の首を挙げた。';
        }
        return r;
      }),
      Choice.h('持ち場を守り抜く', '手柄は人に譲る。持ち場を崩さなければ主君の覚えはよい', () {
        g.l.fav = _c(g.l.fav + 3);
        return _fight(g, c, '目の前の敵だけを見て、持ち場を崩さなかった。', 'main', risk: .8, gain: .9, edge: .05);
      }),
      if (g.l.bu >= 65)
        Choice.h('名乗りを上げ、敵将に一騎打ちを挑む', '腕に覚えのある者だけの手だ。応じられれば、旗本の槍衾を相手にせずに済む。敗れれば命はない', () {
          final ok = _try(g, g.l.bu, .3);
          final r = _fight(
            g,
            c,
            ok ? '大音声の名乗りに、敵将が馬を返した。旗本が道を開け、槍と槍が正面からぶつかった。' : '名乗りは乱戦の声にかき消され、敵将は旗本の陰へ下がった。',
            'van',
            risk: ok ? 1.0 : 1.3,
            gain: ok ? 2.2 : 1.0,
            edge: ok ? .2 : 0,
          );
          if (ok && _alive(g)) {
            g.l.fame += 8;
            _markOnce(g, 'bt_slew_general', '乱戦の中で、敵の将を討ち取った');
            return '$r一騎打ちの末、敵将の首を挙げた。';
          }
          return r;
        }, via: '武'),
    ]);
  }),

  // ---------------- 味方の陣が崩れた ----------------
  BattleSit('bt_collapse', '味方の陣が崩れた', 1, 7, (g, c) => c.weak ? 1.8 : .8, (g, c) {
    final t = '${_en(g, c)}勢の新手が横合いから突きかかり、隣の備えが崩れた。'
        '逃げてくる味方に押されて、${_low(g) ? '組' : '手勢'}の列も乱れ始めている。';
    return (t, [
      Choice.h('踏みとどまって槍を振るう', '持ちこたえれば名が残る。崩れに呑まれれば危うい', () {
        final ok = _try(g, g.l.bu);
        return _fight(
          g,
          c,
          ok ? '「退くな！」と叫んで踏みとどまると、周りの兵も足を止めた。' : '踏みとどまったが、崩れの勢いは止まらなかった。',
          'van',
          risk: ok ? .9 : 1.4,
          gain: ok ? 1.5 : .9,
          edge: ok ? .2 : -.05,
        );
      }),
      Choice.h('崩れた味方を助けに戻る', '人を救えば慕われる。乱戦に飛び込むことになる', () {
        final ok = _try(g, g.l.mi + traitPersuade(g));
        g.l.net += ok ? 4 : 2;
        g.j(3);
        return _fight(
          g,
          c,
          ok ? '倒れていた朋輩を担ぎ、味方の陣まで引きずって戻った。' : '取り残された者を探して、敵の中を走り回った。',
          'main',
          risk: ok ? 1.0 : 1.3,
          gain: 1.0,
        );
      }),
      Choice.h('列を崩さずに退く', '命は守れる。手柄はない', () {
        return _fight(g, c, '兵をまとめ、背を見せずに下がった。', 'rear', risk: .8, gain: .5, edge: -.05);
      }),
    ]);
  }),

  // ---------------- 首を取るか、先へ進むか ----------------
  BattleSit('bt_head', '首を取るか、先へ進むか', 1, 4, (g, c) => c.strong ? 1.5 : 1, (g, c) {
    final t = '突き伏せた${_en(g, c)}の武者が、足もとで動かなくなった。立派な兜だ。'
        '首を取れば手柄の証になる。だが、味方は先へ先へと押している。';
    return (t, [
      Choice.h('首を取る', '確かな手柄になる。遅れを取る', () {
        return _fight(g, c, '首を挙げて腰に下げた。追いついたときには、戦は山場を越えていた。', 'main', risk: .9, gain: 1.4, edge: -.03);
      }),
      Choice.h('首は捨てて先へ進む', '勝ち戦に近づく。手柄の証は残らない', () {
        g.l.fav = _c(g.l.fav + 4);
        return _fight(g, c, '首には目もくれず、次の敵へ向かった。${_who(g)}がそれを見ていた。', 'van', risk: .9, gain: .9, edge: .12);
      }),
      if (g.l.bu >= 60)
        Choice.h('首を腰に下げたまま、先へ駆ける', '力と足があれば、手柄の証も勝ち戦も取れる。重い首は、動きを鈍らせる', () {
          final ok = _try(g, g.l.bu, .4);
          if (ok) g.l.fav = _c(g.l.fav + 3);
          return _fight(
            g,
            c,
            ok ? '首を腰に結わえ、そのまま味方の先頭に追いついた。${_who(g)}が、腰の首とあなたの顔を見比べた。' : '腰の首が足にからみ、思うように駆けられなかった。',
            'van',
            risk: ok ? .9 : 1.3,
            gain: ok ? 1.5 : 1.1,
            edge: ok ? .1 : 0,
          );
        }, via: '武'),
    ]);
  }),

  // ---------------- 鉄砲の撃ち合い ----------------
  BattleSit(
    'bt_guns',
    '鉄砲の撃ち合い',
    1,
    7,
    (g, c) => g.year >= 1570 ? 1.6 : 1,
    cond: (g, c) => g.year >= 1555,
    (g, c) {
      final t = '${_en(g, c)}勢の竹束の陰から、鉄砲が火を噴いた。轟音のたびに、前の列の兵が倒れる。'
          '弾込めの間合いは、そう長くない。';
      return (t, [
        Choice.h('物陰で撃ち止むのを待つ', '危うさは少ない。手柄も少ない', () {
          return _fight(g, c, '土塁の陰で、玉薬が尽きるのを待った。', 'main', risk: .6, gain: .7);
        }),
        Choice.h('弾込めの合間に突っ込む', '間合いを読めば大きな手柄。読み違えれば狙い撃ちにされ、命はない', () {
          final ok = _try(g, (g.l.chi + g.l.un) ~/ 2);
          return _fight(
            g,
            c,
            ok ? '一斉に放たれた直後に駆け出し、鉄砲足軽の列に躍り込んだ。' : '駆け出したところへ、次の一斉射ちが来た。',
            'van',
            risk: ok ? .9 : 1.5,
            gain: ok ? 1.7 : 1.0,
            edge: ok ? .15 : 0,
          );
        }),
        if (g.l.gun)
          Choice.h('こちらも鉄砲で撃ち返す', '腕があれば、敵の鉄砲を黙らせられる', () {
            final ok = _try(g, g.l.bu);
            return _fight(
              g,
              c,
              ok ? '狙いすました一発で、敵の鉄砲頭が倒れた。' : '撃ち合いは長引き、互いに玉薬を減らすばかりだった。',
              'main',
              risk: .8,
              gain: ok ? 1.4 : .9,
              edge: ok ? .12 : 0,
            );
          }, via: '鉄砲'),
      ]);
    },
  ),

  // ---------------- 籠城の夜の見回り ----------------
  BattleSit('bt_siege_watch', '籠城の夜の見回り', 1, 6, (g, c) => c.weak ? 1.8 : .6, (g, c) {
    final t = '${_lord(g)}方の城は、${_en(g, c)}勢に囲まれて十日になる。'
        '${_low(g) ? '今夜は塀の見回りの番だ。' : '夜ごと、自ら塀を見回っている。'}堀の向こうで、何かが動いた気がした。';
    return (t, [
      Choice.h('影を追って堀端へ下りる', '曲者を捕らえれば手柄。罠かもしれない', () {
        final ok = _try(g, (g.l.bu + g.l.chi) ~/ 2);
        if (ok) {
          g.l.merit += 4 + g.l.chi ~/ 20;
          g.l.fav = _c(g.l.fav + 4);
          final r = _fight(g, c, '石垣に取りついていた敵の忍びを、組み伏せて捕らえた。', 'main', risk: .7, gain: 1.1, edge: .1);
          _markOnce(g, 'bt_caught_spy', '籠城の夜、石垣に取りついた敵の忍びを捕らえた');
          return r;
        }
        return _fight(g, c, '影は闇に消えた。追ううちに、堀端で矢を射かけられた。', 'main', risk: 1.3, gain: .9);
      }),
      Choice.h('持ち場の兵に声をかけて回る', '兵の心がまとまる。人の縁が深まる', () {
        g.l.net += 3;
        g.j(2);
        final ok = _try(g, g.l.mi + traitPersuade(g));
        if (ok) g.l.fav = _c(g.l.fav + 3);
        return _fight(g, c, '眠れぬ兵たちと、国の話をして夜を明かした。', 'main', risk: .8, gain: .9, edge: ok ? .08 : 0);
      }),
      Choice.h('見間違いと思って持ち場に戻る', '何事もなければよい', () {
        if (g.rng.chance(.35)) {
          return _fight(g, c, '明け方、その塀から敵が乗り込んできた。', 'main', risk: 1.2, gain: .8, edge: -.1);
        }
        return _fight(g, c, '夜は何事もなく明けた。', 'rear', gain: .7);
      }),
    ]);
  }),

  // ---------------- 兵糧の尽きかけた城 ----------------
  BattleSit('bt_siege_hunger', '兵糧の尽きかけた城', 1, 7, (g, c) => (c.weak ? 1.6 : .5) * (c.season == 3 ? 1.4 : 1), (g, c) {
    final t = '囲まれて二月。城の蔵は底をつきかけ、兵は壁土をなめ、草の根を煮ている。'
        '${_en(g, c)}方からは、城を開けば命は助けるという矢文が届いた。';
    return (t, [
      Choice.h('打って出て囲みを破る', '破れば手柄は大きい。飢えた体では、討死する者も多い', () {
        g.l.hp -= 6;
        final ok = _try(g, g.l.bu, .3);
        return _fight(
          g,
          c,
          ok ? '夜明けに城門を開いて打って出ると、油断していた敵の囲みが崩れた。' : '打って出たが、足がもつれ、思うように槍が振るえなかった。',
          'van',
          risk: ok ? 1.0 : 1.4,
          gain: ok ? 1.7 : 1.0,
          edge: ok ? .2 : -.1,
        );
      }),
      Choice.h('馬を潰して食いつなぐ', '城は持ちこたえる。体は痩せ細る', () {
        g.l.hp -= 8;
        g.j(-4);
        return _fight(g, c, '馬を潰して分け合った。味方の後詰めが来るまで、どうにか持ちこたえた。', 'main', risk: .7, gain: 1.0, edge: .05);
      }),
      Choice.h('城を開くよう説く', '兵の命は救える。主君の怒りを買うかもしれない', () {
        final ok = _try(g, (g.l.chi + g.l.sei) ~/ 2);
        if (ok) {
          g.l.net += 4;
          g.j(3);
          return _fight(g, c, '和議がまとまり、兵は命を拾った。城方の兵が、あなたに頭を下げた。', 'rear', risk: .3, gain: .5, edge: -.1);
        }
        g.l.fav = _c(g.l.fav - 10);
        return _fight(g, c, '「臆したか」と一喝された。それきり、評定には呼ばれなくなった。', 'main', risk: 1.0, gain: .7);
      }),
    ]);
  }),

  // ---------------- 槍衾の押し合い（足軽） ----------------
  BattleSit('bt_spear_wall', '槍衾の押し合い', 1, 2, (g, c) => 1.6, (g, c) {
    final t = '三間の長槍を並べた${_en(g, c)}の足軽と、こちらの槍衾がぶつかった。'
        '上から叩き、突き、押し合う。前の列が崩れたほうが負ける。';
    return (t, [
      Choice.h('最前列で踏ん張る', '押し勝てば手柄。前の列ほど討死が多い', () {
        final ok = _try(g, g.l.bu);
        if (ok) g.l.bu = _c(g.l.bu + 1);
        return _fight(
          g,
          c,
          ok ? '腰を落として踏ん張り、敵の列を押し返した。' : '敵の槍に叩かれ、膝をつきかけた。',
          'van',
          risk: ok ? .8 : 1.3,
          gain: ok ? 1.4 : 1.0,
          edge: ok ? .1 : -.05,
        );
      }),
      Choice.h('声を合わせて列を揃える', '組がまとまれば崩れない。組頭の目にも留まる', () {
        final ok = _try(g, g.l.mi + traitPersuade(g));
        if (ok) {
          g.l.fav = _c(g.l.fav + 4);
          g.l.net += 2;
        }
        return _fight(
          g,
          c,
          ok ? '掛け声に合わせて槍が揃い、組は一つの塊になった。' : '声を張り上げたが、戦の音にかき消された。',
          'main',
          risk: .9,
          gain: 1.1,
          edge: ok ? .1 : 0,
        );
      }),
      Choice.h('後ろの列に下がる', '命は守りやすい。臆病者と言われる', () {
        g.l.fav = _c(g.l.fav - 2);
        return _fight(g, c, '人の背の陰で、槍を突き出すふりをした。', 'rear', gain: .6);
      }),
    ]);
  }),

  // ---------------- 伝令 ----------------
  BattleSit('bt_messenger', '伝令を命じられる', 1, 3, (g, c) => .8 + (g.l.bu + g.l.un) / 200, (g, c) {
    final t = '「この書状を、山向こうの味方の陣へ届けよ」。${_who(g)}から伝令を命じられた。'
        '近道は${_en(g, c)}勢の見張りのそばを抜ける。';
    return (t, [
      Choice.h('近道を駆け抜ける', '間に合えば大きな手柄。見つかれば、生きて帰れぬこともある', () {
        final ok = _try(g, (g.l.bu + g.l.un) ~/ 2);
        if (ok) {
          g.l.merit += 3 + g.l.un ~/ 25;
          g.l.fav = _c(g.l.fav + 6);
          return _fight(g, c, '見張りの目をかすめて駆け抜け、書状を届けた。味方の後詰めが間に合った。', 'main', risk: .8, gain: 1.2, edge: .15);
        }
        return _fight(g, c, '見張りに見つかり、矢を背に受けながら逃げた。書状は届いたが、遅れた。', 'main', risk: 1.6, gain: .8, edge: -.05);
      }),
      Choice.h('遠回りでも確かな道を行く', '命は守りやすい。間に合うかは運しだい', () {
        final ok = _try(g, g.l.un, .45);
        return _fight(
          g,
          c,
          ok ? '山道を夜通し駆け、どうにか間に合った。' : '届いたときには、味方はもう動き出したあとだった。',
          'rear',
          gain: ok ? 1.0 : .6,
          edge: ok ? .05 : -.1,
        );
      }),
    ]);
  }),

  // ---------------- 敵方に旧友・同郷の者 ----------------
  BattleSit(
    'bt_old_friend',
    '敵方に旧友を見つける',
    1,
    7,
    (g, c) => g.l.people.containsKey('幼なじみ') ? 1.6 : .9,
    (g, c) {
      final fr = g.l.people['幼なじみ'];
      final who = fr != null ? '幼なじみの${fr.name}' : '同じ村で育った${g.rng.pick(kGivenM)}';
      final t = '槍を交えようとした${_en(g, c)}方の武者の顔に、見覚えがあった。$whoだ。'
          '向こうも気づいたのか、槍先がわずかに下がった。';
      return (t, [
        Choice.h('名乗りを上げて討ち合う', '手柄にはなる。胸に重いものが残る', () {
          g.j(-8);
          if (fr != null) fr.bond = clampInt(fr.bond - 30, 0, 100);
          return _fight(g, c, '名乗りを上げ、昔なじみと槍を合わせた。勝負は、つかずに分かれた。', 'van', risk: 1.0, gain: 1.3);
        }),
        Choice.h('気づかぬふりで見逃す', '手柄は減る。見咎められれば咎めを受ける', () {
          g.j(4);
          if (fr != null) fr.bond = clampInt(fr.bond + 10, 0, 100);
          if (g.rng.chance(.2)) g.l.fav = _c(g.l.fav - 6);
          final r = _fight(g, c, '槍先をそらし、別の敵へ向かった。背中で、相手が去っていくのが分かった。', 'main', risk: .9, gain: .8);
          _markOnce(g, 'bt_spared_friend', '戦場で、敵方にいた昔なじみを見逃した');
          return r;
        }),
        Choice.h('味方に降るよう説く', '引き入れれば手柄。しくじれば斬りかかられる', () {
          final ok = _try(g, g.l.mi + traitPersuade(g), .3);
          if (ok) {
            g.l.merit += 5 + g.l.mi ~/ 15;
            g.l.fame += 4;
            g.l.fav = _c(g.l.fav + 4);
            return _fight(g, c, '「俺の陣へ来い」。昔なじみは槍を伏せ、手勢ごとこちらへついた。', 'main', risk: .8, gain: 1.1, edge: .12);
          }
          return _fight(g, c, '言葉は届かなかった。相手は黙って槍を構え直した。', 'main', risk: 1.3, gain: .9);
        }),
      ]);
    },
  ),

  // ---------------- 雨・霧の戦 ----------------
  BattleSit('bt_fog', '霧の中の戦', 1, 7, (g, c) => c.season == 0 || c.season == 2 ? 1.5 : .8, (g, c) {
    final t = '${c.season == 2 ? '秋の' : ''}深い霧が野を覆い、十歩先も見えない。'
        '${_en(g, c)}勢がどこにいるのか、物音と馬のいななきで探るほかない。';
    return (t, [
      Choice.h('霧にまぎれて敵の横へ回り込む', '読みが当たれば敵は総崩れ。迷えば敵中に孤立する', () {
        final ok = _try(g, (g.l.chi + g.l.un) ~/ 2, .3);
        return _fight(
          g,
          c,
          ok ? '水音を頼りに沢を回り込み、霧の中から敵の横腹を突いた。' : '霧の中で道を失い、気づけば敵の陣のただ中にいた。',
          'van',
          risk: ok ? .7 : 1.6,
          gain: ok ? 1.7 : .9,
          edge: ok ? .22 : -.08,
        );
      }),
      Choice.h('霧が晴れるまで動かない', '危うさは少ない。好機も逃すかもしれない', () {
        return _fight(g, c, '兵を伏せさせ、霧が晴れるのを待った。', 'main', risk: .7, gain: .8);
      }),
      if (g.l.un >= 60)
        Choice.h('勘の指すほうへ、まっすぐ押し出す', '理屈はない。霧の向こうに敵の本陣があるかどうかは、行ってみてのこと', () {
          final ok = g.luck(.25);
          return _fight(
            g,
            c,
            ok ? '霧が切れた先に、敵の本陣の幔幕があった。向こうは、まだこちらに気づいていなかった。' : '霧の中を進んだ先は、葦の茂る沼だった。引き返すうちに、戦の山場は過ぎていた。',
            ok ? 'van' : 'main',
            risk: ok ? .8 : 1.0,
            gain: ok ? 1.8 : .6,
            edge: ok ? .2 : -.05,
          );
        }, via: '運'),
    ]);
  }),

  // ---------------- 負傷した敵兵 ----------------
  BattleSit('bt_wounded_foe', '負傷した敵兵', 1, 4, (g, c) => c.strong ? 1.3 : .9, (g, c) {
    final t = '勝ち戦の追い討ちのさなか、藪の中に${_en(g, c)}の足軽がうずくまっていた。'
        'まだ前髪の残る若者だ。脚から血を流し、命乞いの目でこちらを見ている。';
    return (t, [
      Choice.h('首を取る', '首は首。手柄になる。目が忘れられないかもしれない', () {
        g.j(-4);
        return _fight(g, c, '目をつぶって、刀を振り下ろした。', 'main', risk: .7, gain: 1.3, edge: .05);
      }),
      Choice.h('見逃して先へ行く', '心は軽い。手柄は減る', () {
        g.j(5);
        g.setFlag('bt_spared_foe');
        return _fight(g, c, '「早う、国へ帰れ」とだけ言って、背を向けた。', 'main', risk: .8, gain: .8, edge: .05);
      }),
      Choice.h('手当てをして捕らえる', '情けは人のためならず。手間はかかる', () {
        final ok = _try(g, g.l.mi + traitPersuade(g));
        g.l.net += ok ? 3 : 1;
        if (ok) g.l.fav = _c(g.l.fav + 2);
        return _fight(
          g,
          c,
          ok ? '傷を縛ってやると、若者は泣きながら敵の陣立てを白状した。' : '傷を縛ってやったが、若者は一言も口をきかなかった。',
          'rear',
          gain: ok ? 1.2 : .7,
          edge: ok ? .08 : 0,
        );
      }),
    ]);
  }),

  // ---------------- 手柄の横取り ----------------
  BattleSit(
    'bt_stolen_credit',
    '手柄の横取り',
    1,
    3,
    (g, c) => 1,
    cond: (g, c) => g.l.merit >= 8,
    (g, c) {
      final thief = '同じ${g.l.rank <= 2 ? '組' : '馬廻'}の${g.rng.pick(kGivenM)}';
      final t = '${_en(g, c)}勢との小競り合いで、あなたが突き伏せた武者の首を、$thiefが拾って本陣へ届け出たという。'
          '首帳には、もうその名が記されている。';
      return (t, [
        Choice.h('首実検の場で訴え出る', '筋が通れば手柄は戻る。言い負ければ恥をかく', () {
          final ok = _try(g, (g.l.chi + g.l.sei) ~/ 2);
          if (ok) {
            g.l.merit += 6;
            g.l.fame += 3;
            g.j(3);
            return _fight(g, c, '槍の穂先の傷と、見ていた朋輩の証言で、首はあなたのものと認められた。', 'main', gain: 1.0);
          }
          g.l.fav = _c(g.l.fav - 4);
          g.j(-4);
          return _fight(g, c, '証を立てられず、「見苦しい」と退けられた。', 'main', gain: .9);
        }),
        Choice.h('黙って譲る', '恨みは買わない。手柄は戻らない', () {
          g.l.net += 2;
          g.j(-3);
          return _fight(g, c, '何も言わなかった。次の戦で、取り返せばいい。', 'main', gain: 1.1);
        }),
        Choice.h('陣の裏で詰め寄る', '取り返せるかもしれない。喧嘩は御法度だ', () {
          final ok = _try(g, g.l.bu);
          if (ok) {
            g.l.merit += 4;
            return _fight(g, c, '胸倉をつかむと、相手は青い顔で届け出を取り下げた。', 'main');
          }
          g.l.fav = _c(g.l.fav - 6);
          g.l.hp -= 6;
          return _fight(g, c, '殴り合いになり、二人とも${_who(g)}に叱りつけられた。', 'main', gain: .9);
        }),
      ]);
    },
  ),

  // ---------------- 殿（しんがり） ----------------
  BattleSit('bt_rearguard', '殿を命じられる', 2, 6, (g, c) => c.weak ? 1.8 : .7, (g, c) {
    final t = '${_en(g, c)}勢の新手が現れ、味方は退くことになった。'
        '${_who(g)}が、あなたの顔を見て言った。「殿を、頼めるか」。退く味方の背を守る、いちばん危うい役目だ。';
    return (t, [
      Choice.h('引き受けて踏みとどまる', '名は上がる。生きて帰れる者は少ない', () {
        g.l.fav = _c(g.l.fav + 8);
        final ok = _try(g, g.l.bu, .3);
        final r = _fight(
          g,
          c,
          ok ? '追いすがる敵を三度押し返し、味方が退く時を稼いだ。' : '押し寄せる敵に、手勢が一人また一人と呑まれていった。',
          'van',
          risk: ok ? 1.1 : 1.6,
          gain: ok ? 2.0 : 1.3,
        );
        if (_alive(g)) {
          g.l.fame += 6;
          _markOnce(g, 'bt_rearguard_done', '負け戦で殿を務め、味方を逃がした');
        }
        return r;
      }),
      Choice.h('鉄砲と伏兵で時を稼ぐ', '知恵が回れば、手柄も命も拾える', () {
        g.l.fav = _c(g.l.fav + 5);
        final ok = _try(g, g.l.chi);
        return _fight(
          g,
          c,
          ok ? '道の両脇に兵を伏せ、追ってきた敵の先手を散々に打ち崩した。' : '伏兵は見破られ、敵はかまわず押し寄せてきた。',
          'main',
          risk: ok ? .7 : 1.4,
          gain: ok ? 1.6 : 1.0,
        );
      }),
      Choice.h('役目を辞退する', '命は守れる。主君の目は冷たくなる', () {
        g.l.fav = _c(g.l.fav - 8);
        g.j(-3);
        return _fight(g, c, '殿は別の者が引き受けた。退く道で、誰もあなたと目を合わせなかった。', 'rear', risk: .7, gain: .4);
      }),
    ]);
  }),

  // ---------------- 采配（侍大将以上） ----------------
  BattleSit('bt_command', '采配を振るう', 4, 7, (g, c) => 2.0, (g, c) {
    final t = '${_lord(g)}家の軍議で、${_en(g, c)}勢に当たる一手を任された。'
        '物見の知らせでは、敵は山裾の道を通ってくる。あなたの采配で、手勢${g.l.troops > 0 ? 'が動く' : 'を借りて戦う'}。';
    return (t, [
      Choice.h('山裾に伏兵を置く', '読みが当たれば大勝ち。外れれば兵を遊ばせる', () {
        final ok = _try(g, g.l.chi);
        final r = _fight(
          g,
          c,
          ok ? '敵の先手が山裾に差しかかったところで、伏せていた兵が一斉に立ち上がった。' : '敵は別の道を来た。伏兵は空しく待ちぼうけた。',
          'main',
          risk: .8,
          gain: ok ? 1.6 : .8,
          edge: ok ? .25 : -.12,
        );
        if (ok && _alive(g)) _markOnce(g, 'bt_ambush_win', '自らの采配で伏兵を置き、敵を破った');
        return r;
      }),
      Choice.h('正面から堂々と当たる', '兵が多ければ押し切れる。損も大きい', () {
        final edge = clampD((g.l.troops - 60) / 400, -.1, .15);
        return _fight(g, c, '陣太鼓を打ち鳴らし、正面から押し出した。', 'van', risk: 1.0, gain: 1.3, edge: edge);
      }),
      Choice.h('使いを送って和を探る', '戦わずに済めば兵は減らない。弱腰と見られることもある', () {
        final ok = _try(g, (g.l.sei + g.l.mi) ~/ 2, .3);
        if (ok) {
          g.l.merit += 5 + g.l.sei ~/ 15;
          g.l.fav = _c(g.l.fav + 3);
          g.j(3);
          return '${_en(g, c)}方の重臣と談判し、国境を退かせた。一兵も損なわずに済んだ。';
        }
        g.l.fav = _c(g.l.fav - 4);
        return _fight(g, c, '使いは追い返され、遅れて戦に入った。', 'main', gain: .8, edge: -.08);
      }),
    ]);
  }),
];

final List<BattleSit> kBattleSits = buildBattleSits();

/// 直近に出た状況（新しい順）。
List<String> recentBattles(Game g) {
  final r = List<String?>.filled(kRecentBattles, null);
  for (final f in g.l.flags) {
    if (!f.startsWith('bsr')) continue;
    final i = f.indexOf(':');
    final k = int.tryParse(f.substring(3, i));
    if (k != null && k < kRecentBattles) r[k] = f.substring(i + 1);
  }
  return r.whereType<String>().toList();
}

void _remember(Game g, String id) {
  final old = recentBattles(g);
  g.l.flags.removeWhere((f) => f.startsWith('bsr'));
  final now = [id, ...old.where((x) => x != id)].take(kRecentBattles).toList();
  for (var i = 0; i < now.length; i++) {
    g.setFlag('bsr$i:${now[i]}');
  }
  g.setFlag('bs:$id');
}

BattleCtx _ctx(Game g) {
  final lf = g.fa[g.l.lord]!;
  final others = g.alive.where((f) => f != lf).toList();
  final near = nearest(others, (f) => f.name, faction: lf.name, n: 4);
  final e = near.isEmpty ? (others.isEmpty ? lf : g.rng.pick(others)) : g.rng.pick(near);
  final ratio = lf.power / (e.power <= 0 ? 1 : e.power);
  return BattleCtx(e.name, g.rng.range(0, 3), ratio < .8, ratio > 1.25);
}

/// その人に出せる状況（直近のものも含む）。
List<BattleSit> battleSitsFor(Game g, BattleCtx c) => [
  for (final s in kBattleSits)
    if (g.l.rank >= s.lo && g.l.rank <= s.hi && (s.cond?.call(g, c) ?? true)) s,
];

/// 出陣の岐路。状況を一つ選んで出す。
void runBattleScene(Game g, void Function() next) {
  final c = _ctx(g);
  final all = battleSitsFor(g, c);
  final recent = recentBattles(g);
  var cand = all.where((s) => !recent.contains(s.id)).toList();
  if (cand.isEmpty) {
    cand = all.where((s) => recent.isEmpty || s.id != recent.first).toList();
  }
  if (cand.isEmpty) cand = all;
  final s = g.rng.wpick(cand, (x) => x.weight(g, c));
  _remember(g, s.id);
  final (text, choices) = s.run(g, c);
  final head = battleHead(g, season: c.season);
  g.ask('出陣', '$head$text', choices, after: next);
}
