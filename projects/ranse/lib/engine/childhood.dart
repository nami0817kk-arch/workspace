import 'childhood_focus.dart';
import 'data.dart';
import 'game.dart';
import 'rng.dart';

/// 幼少期（5〜14歳）。1年ごとに「今年の重点」を選び、その年の途中で
/// 岐路が起きることがある（一生に6つほど）。
///
/// 重点の選択は1年ぶん流れ、選んだ回数が次に出る岐路の種類に効く。
/// 岐路の選択は旗（flags）・縁のある人（people）・歩んだ道（path）として残り、
/// のちの章で効く。結果は「匂わせるだけ」で、成功率の数字は出さない。

const _poor = ['farmer', 'fisher', 'beggar'];
const _lettered = [
  'priest',
  'merchant',
  'lowsamurai',
  'samurai',
  'kokujin',
  'daimyo',
];
const _martial = [
  'ronin',
  'ashigaru',
  'lowsamurai',
  'samurai',
  'kokujin',
  'daimyo',
  'ninja',
];

/// 今年の重点。
class FocusDef {
  FocusDef(this.tag, this.label, this.hint, this.perYear, {this.forced});
  final String tag, label, hint;

  /// これを選んだ年に必ず起きる岐路（例: 仕官の口を探す → 仕官の場面）。
  final String? forced;

  /// 1年ぶんの効果。
  final void Function(Game g) perYear;
}

List<FocusDef> childFocusOptions(Game g) {
  final rng = g.rng;
  return [
    FocusDef('work', '家の手伝いに励む', '暮らしの足しになる。遊ぶ暇は減る', (g) {
      g.l.gold += rng.range(1, 2);
      g.l.hp -= 1;
      if (rng.chance(.2) && g.l.bu < 60) g.l.bu++;
      g.j(-1);
    }),
    FocusDef('learn', '読み書きを覚える', '学べる家の子は伸びる。通えない子には難しい', (g) {
      final p = _lettered.contains(g.l.cls.id)
          ? 1.0
          : (g.l.cls.id == 'beggar' ? .15 : .45);
      if (rng.chance(p)) {
        g.l.chi = clampInt(
          g.l.chi +
              rng.range(1, 2) +
              (g.l.cls.id == 'priest' ? 1 : 0) +
              (g.has('prodigy') ? 1 : 0), // 神童は伸びが大きい（`trait_scenes.dart`）
          0,
          99,
        );
        g.j(1);
      }
    }),
    FocusDef('martial', '棒切れで武芸ごっこ', '体は鍛わるが、生傷も絶えない', (g) {
      final m = _martial.contains(g.l.cls.id) ? 1.0 : .5;
      g.l.bu = clampInt(g.l.bu + (rng.chance(m) ? rng.range(1, 2) : 1), 0, 99);
      g.l.hp -= 1;
    }),
    FocusDef('play', '野山で遊ぶ', '心と体が育つ。何かが身につくわけではない', (g) {
      g.l.hp = g.l.hp + 5 > g.l.maxhp ? g.l.maxhp : g.l.hp + 5;
      g.j(4);
    }),
    FocusDef('friend', '友と過ごす', 'のちに頼れる縁になるかもしれない', (g) {
      g.l.net += rng.range(1, 2);
      g.j(2);
    }),
    // ---- 家柄・年頃で増える重点（2026-11-23、ユーザー「寺子屋に通うなど選択肢もほしい」）----
    // 寺子屋は江戸の言葉なので、戦国の言い方で「寺へ手習いに通う」とした。
    // 寺に住む子（僧の家・小僧として寺に入った子）には出さない。
    if (g.l.cls.id != 'priest' && !g.hasFlag('monk'))
      FocusDef('tera', '寺へ手習いに通う', '字と算用が身につく。和尚への謝礼がいる', (g) {
        // 謝礼（束脩）が払えない家の子は、学びが細る。
        final paid = g.l.gold > 0;
        if (paid) g.l.gold -= 1;
        final p = paid ? (g.l.cls.id == 'beggar' ? .6 : 1.0) : .4;
        if (rng.chance(p)) {
          g.l.chi = clampInt(g.l.chi + rng.range(1, 3) + (g.has('prodigy') ? 1 : 0), 0, 99);
          if (rng.chance(.4)) g.l.sei = clampInt(g.l.sei + 1, 0, 99);
          g.j(1);
        }
      }, forced: 'c_tera'),
    if (_martial.contains(g.l.cls.id) && g.age >= 8)
      FocusDef('dojo', '道場で稽古をつけてもらう', '武芸がぐんと伸びる。荒稽古で怪我もする', (g) {
        // 剣の筋（`trait_scenes4.dart`）は、道場での伸びが大きい。
        g.l.bu = clampInt(g.l.bu + rng.range(2, 3) + (g.has('sword') ? 1 : 0), 0, 99);
        g.l.hp -= rng.chance(.25) ? 6 : 2;
        g.j(-1);
      }),
    if (g.l.cls.id == 'merchant')
      FocusDef('abacus', '算盤と商いを習う', '銭勘定に強くなる。遊ぶ暇は減る', (g) {
        g.l.sei = clampInt(g.l.sei + rng.range(1, 2), 0, 99);
        if (rng.chance(.4)) g.l.chi = clampInt(g.l.chi + 1, 0, 99);
        g.l.gold += 1;
        g.j(-1);
      }),
    if (g.l.female && g.age >= 10 && g.l.cls.id != 'beggar')
      FocusDef('manners', '行儀見習いに上がる', '立ち居振る舞いが身につく。家からは離れる', (g) {
        g.l.mi = clampInt(g.l.mi + rng.range(1, 2), 0, 99);
        if (rng.chance(.4)) g.l.sei = clampInt(g.l.sei + 1, 0, 99);
        g.l.net += 1;
        g.j(-2);
      }),
    // ---- 身分で増える重点 その2（弓馬・薬草・歌と書・子守・川・市の使い・経。`childhood_focus.dart`）----
    ...moreChildFocusOptions(g),
  ];
}

class SceneDef {
  SceneDef(
    this.id,
    this.minAge,
    this.maxAge,
    this.weight,
    this.cond,
    this.run, {
    this.ageOk,
    this.repeat = false,
    this.onlyForced = false,
  });
  final String id;

  /// 一生に何度でも起きる（合戦・疫病など）。false なら一生に一度。
  final bool repeat;

  /// 重点で選んだときにだけ起きる（仕官・侵攻など）。
  final bool onlyForced;

  /// その年齢で起きてよいか（史実の年代に合わせるときなど）。null なら年齢の範囲だけ。
  final bool Function(Game g, int age)? ageOk;

  /// この年齢のあいだにだけ起きる。
  final int minAge, maxAge;

  /// 出やすさ。過ごし方の選択回数などで増える。
  final double Function(Game g) weight;
  final bool Function(Game g) cond;

  /// 場面を出す。選び終わったら [next] を呼ぶ。
  final void Function(Game g, void Function() next) run;
}

List<SceneDef> buildChildScenes() {
  int f(Game g, String tag) => g.l.focus[tag] ?? 0;
  return [
    // ---- 病と貧しさ ----
    SceneDef('fever', 5, 14, (g) => 3, (g) => true, (g, next) {
      g.ask('熱病', '村に熱病が流行り、あなたも床に伏した。', [
        Choice.h('薬湯を飲ませてもらう（銭3貫）', '効くと聞くが、銭がかかる', () {
          final l = g.l;
          g.mark('熱病に伏した');
          if (l.gold >= 3) {
            l.gold -= 3;
            l.hp -= g.rng.range(3, 8);
            g.j(-2);
            return '薬湯が効き、数日で熱が引いた。';
          }
          l.hp -= g.rng.range(15, 30);
          g.j(-4);
          return '銭がなく、薬湯は手に入らなかった。ただ耐えるしかなかった。';
        }),
        // 薬の心得（`trait_scenes.dart`）: 野の草で熱を下げる手。
        if (g.has('herbal'))
          Choice.h('裏の野で熱さましの草を摘み、自分で煎じる', '銭はかからない。床を抜け出すぶん体はこたえる', () {
            final l = g.l;
            g.mark('熱病に伏した');
            l.hp -= g.rng.range(4, 10);
            g.j(-1);
            g.setFlag('tr_herbal_fever');
            return 'ふらつく足で摘んだ草を煎じて飲むと、その晩のうちに汗が噴き出し、熱が引いた。';
          }, via: '薬の心得'),
        Choice.h('ただ耐える', '丈夫な子なら乗り切れる。そうでなければ…', () {
          final l = g.l;
          g.mark('熱病に伏した');
          g.j(-4);
          if (g.rng.chance(
            (l.hp < 50 ? .22 : .08) / (g.has('hardy') ? 2 : 1),
          )) {
            g.die('熱病で亡くなった');
            return '熱は下がらなかった。';
          }
          l.hp -= g.rng.range(10, 28);
          return g.rng.chance(.5 + l.un / 300)
              ? '運よく熱は引いた。'
              : '長く寝込み、体力を大きく削られた。';
        }),
      ], after: next);
    }),
    SceneDef('famine', 5, 14, (g) => 2.5, (g) => _poor.contains(g.l.cls.id), (
      g,
      next,
    ) {
      g.ask('飢饉', '凶作で、家の蔵は空になった。', [
        Choice.h('草の根や木の皮を食べて凌ぐ', '誰もがしていることだ。体は弱る', () {
          g.l.hp -= 10;
          g.j(-6);
          g.mark('飢饉の冬を越した');
          return '空腹に耐え、冬を越した。';
        }),
        Choice.h('山に入って獲物を探す', '獲れれば家族が助かる。山は子どもに優しくない', () {
          g.mark('飢饉の冬を越した');
          if (g.rng.chance(.5)) {
            g.l.bu++;
            g.j(2);
            return 'ウサギを仕留め、家族で分け合った。';
          }
          g.l.hp -= 12;
          g.j(-6);
          return '何も獲れなかった。';
        }),
      ], after: next);
    }),
    SceneDef('warfire', 5, 14, (g) => 2, (g) => true, (g, next) {
      g.ask('戦火', '近くで合戦があり、村が焼かれた。', [
        Choice.h('家族と山に逃げる', '命は守れる。家は焼ける', () {
          g.l.gold = g.l.gold >= 2 ? g.l.gold - 2 : 0;
          g.j(-8);
          g.mark('戦火で村を焼かれた');
          return '命からがら逃げ延びたが、家は焼けた。';
        }),
        Choice.h('物陰から戦を見つめる', '目に焼きつくものがある。見つかれば…', () {
          g.l.chi++;
          g.j(-10);
          g.setFlag('saw_battle');
          g.mark('戦を物陰から見た');
          if (g.rng.chance(.1)) {
            g.l.hp -= 20;
            return '流れ矢がかすめた。人が人を殺すさまを、目に焼き付けた。';
          }
          return '人が人を殺すさまを、目に焼き付けた。';
        }),
      ], after: next);
    }),
    SceneDef('slaver', 8, 14, (g) => 1.2, (g) => _poor.contains(g.l.cls.id), (
      g,
      next,
    ) {
      g.ask('人買い', '戦で攫われ、人買いの手に落ちかけている。', [
        Choice.h('必死に逃げる', '足の速さと運がものを言う', () {
          final l = g.l;
          if (g.rng.chance(.4 + l.bu / 200 + l.un / 300)) {
            l.bu += 2;
            g.j(-6);
            g.mark('人買いから逃げ延びた');
            return '縄を抜け、夜の闇に逃げ延びた。';
          }
          l.hp -= 20;
          l.net = l.net >= 2 ? l.net - 2 : 0;
          g.j(-20);
          g.mark('人買いに攫われ、心に傷を負った');
          return '捕まり、殴られた。心に深い傷が残った。';
        }),
        Choice.h('耐えて機会を待つ', '傷は浅く済むかもしれない。心には残る', () {
          g.l.hp -= 8;
          g.l.chi++;
          g.j(-15);
          g.mark('人買いに攫われたが、解き放たれた');
          return '従順に装い、やがて解き放たれた。何かが心から欠け落ちた。';
        }),
      ], after: next);
    }),
    // ---- 家と親 ----
    SceneDef(
      'fatherdeath',
      7,
      14,
      (g) => 1.5,
      (g) => !g.hasFlag('fatherdead'),
      (g, next) {
        g.ask('父の死', '父が病に倒れ、この世を去った。', [
          Choice.h('母と家を支える', '家は苦しくなる。一家を背負う覚悟が育つ', () {
            final l = g.l;
            l.gold = l.gold >= 2 ? l.gold - 2 : 0;
            l.sei++;
            g.j(-12);
            g.setFlag('fatherdead');
            g.setFlag('family_head');
            g.mark('父を亡くし、母と家を支えた');
            if (l.birthRank >= 1) {
              l.birthRank--;
              return '幼いながら家を支える覚悟を決めた。家の暮らしは苦しくなった。';
            }
            return '幼いながら家を支える覚悟を決めた。';
          }),
          Choice.h('寺に預けられる', '食い扶持は減る。文字と経を学べるが、家からは離れる', () {
            g.l.chi += 5;
            g.j(-10);
            g.setFlag('fatherdead');
            g.setFlag('temple');
            g.meet('師', '寺の和尚', 30);
            g.mark('父を亡くし、寺に預けられた');
            return '寺に入り、経と文字を学び始めた。';
          }),
        ], after: next);
      },
    ),
    SceneDef(
      'service',
      9,
      14,
      (g) => 1.8 + f(g, 'work') * .5,
      (g) =>
          g.l.order >= 2 && g.l.cls.id != 'beggar' && !g.hasFlag('apprentice'),
      (g, next) {
        g.ask('奉公の話', '継ぐ家のない子は、よそへ出される。奉公の口が回ってきた。', [
          Choice.h('奉公に出る', '手に職がつく。朝から晩まで働き通しになる', () {
            g.l.gold += 3;
            g.l.sei += 3;
            g.l.hp -= 5;
            g.j(-5);
            g.setFlag('apprentice');
            g.mark('奉公に出て、算盤と商いを覚えた');
            return '見知らぬ家で、朝から晩まで働いた。商いや算盤を覚えた。';
          }),
          Choice.h('家に居座る', '楽ではないが、慣れた場所にいられる', () {
            g.j(-3);
            g.mark('継ぐ家のない家で肩身の狭い思いをした');
            return '居場所のない家で、肩身の狭い思いをした。';
          }),
        ], after: next);
      },
    ),
    // はじめて寺へ手習いに通った年（重点「寺へ手習いに通う」で一度だけ）。
    SceneDef('c_tera', 5, 14, (g) => 1, (g) => true, (g, next) {
      g.ask('寺の手習い', '村の寺で、和尚が子らに手習いを教えている。初めての日、硯と筆を抱えて本堂の隅に座った。', [
        Choice.h('一番前で熱心に学ぶ', '和尚に目をかけられる。遊び仲間には煙たがられる', () {
          g.l.chi = clampInt(g.l.chi + 3, 0, 99);
          g.j(-1);
          g.setFlag('tera_diligent');
          if (!g.l.people.containsKey('師')) g.meet('師', '手習いの和尚', 30);
          g.mark('寺へ手習いに通い、和尚に目をかけられた');
          return '和尚は、あなたの字を見て「筋がよい」と言った。';
        }),
        Choice.h('仲間と机を並べて学ぶ', '友ができる。学びはほどほど', () {
          g.l.chi = clampInt(g.l.chi + 1, 0, 99);
          g.l.net += 2;
          g.j(3);
          g.setFlag('tera_friends');
          g.mark('寺の手習いで、机を並べる仲間ができた');
          return '筆の持ち方を教え合ううちに、仲間ができた。';
        }),
        Choice.h('抜け出して遊ぶ', '気は晴れる。親に知れれば叱られる', () {
          g.j(3);
          if (g.rng.chance(.5)) {
            g.j(-4);
            return '川で遊んでいたところを見つかり、こっぴどく叱られた。';
          }
          return '裏山へ抜け出した。誰にも気づかれなかった。';
        }),
      ], after: next);
    }, onlyForced: true),
    SceneDef(
      'temple_offer',
      8,
      13,
      // 寺へ手習いに通う子ほど、和尚から寺入りの話が来やすい。
      (g) => g.l.cls.id == 'priest'
          ? 3
          : 1.2 + (f(g, 'learn') + f(g, 'tera')) * .6,
      (g) =>
          !g.hasFlag('temple') && !g.hasFlag('monk') && g.l.cls.id != 'beggar',
      (g, next) {
        g.ask('寺入りの話', '寺の和尚が、あなたを小僧として預からないかと言ってきた。', [
          Choice.h('小僧として寺に入る', '学問の道が開ける。世俗の出世とは遠ざかる', () {
            g.l.chi += 6;
            g.l.bu = g.l.bu - 3 < 3 ? 3 : g.l.bu - 3;
            g.j(-4);
            g.setFlag('monk');
            g.setFlag('temple');
            g.meet('師', '寺の和尚', 40);
            g.mark('幼くして寺に入った');
            return '寺に入り、掃除と読経の日々が始まった。';
          }),
          Choice.h('家に残る', '親のそばにいられる。その道は閉じる', () {
            g.j(2);
            return '寺入りは断り、家に残った。';
          }),
        ], after: next);
      },
    ),
    // ---- 出会い ----
    SceneDef(
      'master',
      8,
      14,
      (g) => 2 + (f(g, 'learn') + f(g, 'martial')) * .8,
      (g) => !g.hasFlag('master_lit') && !g.hasFlag('master_bu'),
      (g, next) {
        g.ask('旅の師', '旅の者が、一晩の宿の礼に、何か教えてやろうと言う。', [
          Choice.h('文字と算術を教わる', '頭を使う道に通じる', () {
            g.l.chi += 3;
            g.l.sei += 1;
            g.j(3);
            g.setFlag('master_lit');
            g.meet('師', '旅の僧', 40);
            g.mark('旅の僧に文字と算術を教わった');
            return '知が3上がった。';
          }),
          Choice.h('棒術を教わる', '腕を使う道に通じる', () {
            g.l.bu += 3;
            g.j(3);
            g.setFlag('master_bu');
            g.meet('師', '旅の剣客', 40);
            g.mark('旅の剣客に棒術を教わった');
            return '武が3上がった。';
          }),
        ], after: next);
      },
    ),
    SceneDef(
      'friend',
      6,
      14,
      (g) => 2.5 + f(g, 'friend') * .8,
      (g) => !g.l.people.containsKey('幼なじみ'),
      (g, next) {
        final name = g.rng.chance(.5)
            ? g.rng.pick(kGivenM)
            : g.rng.pick(kGivenF);
        g.ask('友', '同じ年頃の$nameと、ささいなことで喧嘩になった。', [
          Choice.h('殴り合って決着をつける', '本気でぶつかれば、何かが生まれる。生まれないこともある', () {
            g.l.bu++;
            g.l.hp -= 4;
            if (g.rng.chance(.55)) {
              g.l.net += 2;
              g.j(4);
              g.meet('幼なじみ', name, 55);
              g.mark('殴り合った相手が、生涯の友になった');
              return '殴り合ううち、$nameとは無二の友になった。';
            }
            g.j(-2);
            g.meet('幼なじみ', name, 15);
            g.mark('殴り合って、仲違いのままになった');
            return '痣だけが残った。$nameとは、気まずいままになった。';
          }),
          Choice.h('先に謝る', '角が立たない。ただ、強い絆にはなりにくい', () {
            g.l.mi++;
            g.l.net += 2;
            g.j(2);
            g.meet('幼なじみ', name, 40);
            g.mark('先に頭を下げ、友ができた');
            return '先に頭を下げ、$nameという友ができた。';
          }),
        ], after: next);
      },
    ),
    SceneDef(
      'festival',
      5,
      14,
      (g) => 2 + f(g, 'play') * .5 + f(g, 'friend') * .5,
      (g) => true,
      (g, next) {
        g.ask('村の祭り', '年に一度の祭りの日がきた。', [
          Choice.h('夜通し踊り明かす', 'ひとときの楽しさ。あとの心の支えになる', () {
            g.j(10);
            g.l.net += 2;
            g.mark('祭りの夜を踊り明かした');
            return '笛と太鼓に合わせ、夜通し踊った。胸に残る夜になった。';
          }),
          Choice.h('露店の手伝いで稼ぐ', '手元に銭が残る。楽しみは人のものを見るだけ', () {
            g.l.gold += 3;
            g.j(2);
            return '露店の手伝いで、銭3貫を稼いだ。';
          }),
        ], after: next);
      },
    ),
    // ---- 歴史上の人物との出会い ----
    SceneDef(
      'cameo_oda',
      8,
      14,
      (g) => 3,
      (g) => g.l.region == '尾張' && !g.hasFlag('cameo'),
      (g, next) {
        g.setFlag('cameo');
        g.ask('城下の若殿', '那古野の城下で、若殿の吉法師（のちの織田信長）が、供も連れず野を駆けているのを見かけた。', [
          Choice.h('後を追って、一緒に遊ぶ', '身分は違う。叱られるかもしれない。縁が生まれるかもしれない', () {
            if (g.rng.chance(.5 + g.l.mi / 300)) {
              g.l.fame += 3;
              g.j(8);
              g.setFlag('met_nobunaga');
              g.meet('若殿', '吉法師', 25);
              g.mark('尾張の若殿・吉法師と野で遊んだ');
              return '若殿は笑って、あなたを子分に加えた。';
            }
            g.l.hp -= 3;
            g.j(-3);
            g.mark('若殿に近づいて、追い払われた');
            return '供の者に見つかり、追い払われた。';
          }),
          Choice.h('遠くから見ているだけにする', '何も起きない。ただ、見たことは覚えている', () {
            g.setFlag('saw_nobunaga');
            g.mark('尾張の若殿を、遠くから見た');
            return '若殿の姿が見えなくなるまで、野の隅から眺めていた。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => g.l.startYear + a >= 1542 && g.l.startYear + a <= 1546,
    ),
    SceneDef(
      'cameo_echigo',
      8,
      14,
      (g) => 3,
      (g) => g.l.region == '越後' && !g.hasFlag('cameo'),
      (g, next) {
        g.setFlag('cameo');
        g.ask('寺の少年', '春日山のふもとで、寺に預けられた少年の噂を聞いた。のちに上杉謙信と名乗る人物だという。', [
          Choice.h('寺まで様子を見に行く', '近づけるかは分からない。縁があれば何かが残る', () {
            if (g.rng.chance(.4 + g.l.chi / 300)) {
              g.l.chi += 1;
              g.j(5);
              g.setFlag('met_kenshin');
              g.meet('少年', '寺の少年', 20);
              g.mark('越後の寺に預けられた少年と言葉を交わした');
              return '寺の庭で、少年と短く言葉を交わした。';
            }
            g.mark('寺の少年に近づけなかった');
            return '門前で追い返された。';
          }),
          Choice.h('噂だと聞き流す', '何も起きない', () => '噂は、遠い話として聞き流した。'),
        ], after: next);
      },
      ageOk: (g, a) => g.l.startYear + a >= 1537 && g.l.startYear + a <= 1543,
    ),
  ];
}

const _yearLines = <int, String>{
  5: '五つの春。まだ小さな体で、今年は何をして過ごす？',
  6: '六つ。家の仕事が少しずつ回ってくる歳だ。今年の重点は？',
  7: '七つ。村の子らと走り回る日々。今年は何に打ち込む？',
  8: '八つ。体も大きくなってきた。今年は何に力を入れる？',
  9: '九つ。周りの子との違いが、少しずつ見えてくる。今年は？',
  10: '十になった。もう半人前と見られ始める歳だ。今年は何を重んじる？',
  11: '十一。大人の背中が近づいてきた。今年は何に励む？',
  12: '十二。先の身の振り方が、話に上り始める。今年の重点は？',
  13: '十三。元服が目の前に見えてきた。今年は何をする？',
  14: '十四。子どもでいられる最後の一年。どう過ごす？',
};

/// 今年の重点を聞くときの一文。歳ごとに変え、縁のある人がいれば一言添える。
String childYearText(Game g) {
  final base = _yearLines[g.age] ?? '今年は何に打ち込む？';
  final f = g.l.people['幼なじみ'];
  if (f != null && f.bond >= 40 && g.age >= 8) {
    return '$base\n${f.name}が、今年も遊びに誘ってくる。';
  }
  return base;
}
