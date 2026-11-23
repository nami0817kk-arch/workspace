import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'life.dart';
import 'rng.dart';

/// 城を預かる者・一国の主・天下に手が届く者の岐路（史実ではない、名もない場面）。
///
/// 城主・家老（位5〜7）は主家との間合いと城下の切り盛り、
/// 大名（位8）は国の治め方と家の行く末、
/// 天下に手が届く者（位8で勢力が大きい）は天下の仕上げと頂の孤独。
/// どれも一生に一度。結果は匂わせるだけで、数字は出さない。

Faction _me(Game g) => g.fa[g.l.lord]!;

/// 主家（自分の家）が生きている。
bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);

void _grow(Game g, num n) => _me(g).power += n;

void _cut(Game g, double m) {
  final f = _me(g);
  f.power = f.power * m < 3 ? 3 : f.power * m;
}

void _fav(Game g, int d) => g.l.fav = clampInt(g.l.fav + d, 0, 100);

bool _pay(Game g, int n) {
  if (g.l.gold < n) return false;
  g.l.gold -= n;
  return true;
}

void _heal(Life l, int n) => l.hp = l.hp + n > l.maxhp ? l.maxhp : l.hp + n;

String _man(Game g) => '${g.rng.pick(kSurnames)}${g.rng.pick(kGivenM)}';

String _kid(Game g) => g.rng.pick(g.rng.chance(.5) ? kHeirNames : kHimeNames);

/// 城を預かる身（城主・家老・宿老）。
bool _castle(Game g) =>
    g.l.rank >= 5 && g.l.rank < 8 && g.active && _lordAlive(g);

/// 城と兵を自ら差配する身（奥の道の女性は除く）。
bool _keep(Game g) => _castle(g) && g.canFight;

/// 一国の主。
bool _daimyo(Game g) => g.l.rank == 8 && g.active && _lordAlive(g);

/// 天下に手が届く者。
bool _near(Game g, double s) => _daimyo(g) && g.share >= s;

Faction? _rival(Game g, {bool strongest = false}) {
  final others = g.alive.where((f) => f.name != g.l.lord).toList();
  if (others.isEmpty) return null;
  if (strongest) {
    others.sort((a, b) => b.power.compareTo(a.power));
    return others.first;
  }
  // 好敵手は近い家から。
  return g.rng.pick(
    nearest<Faction>(
      others,
      (f) => f.name,
      faction: g.l.lord ?? '',
      region: g.l.lord == null ? g.l.region : null,
    ),
  );
}

List<SceneDef> buildLordScenes() {
  return [
    // ==================================================================
    // 城主・家老（位5〜7）
    // ==================================================================
    SceneDef('l_castletown', 20, 84, (g) => 1.5, _keep, (g, next) {
      final l = g.l;
      g.ask('城下の町割り', '城の麓に、商人や職人が少しずつ集まり始めた。町割りをどうするか、奉行が指図を待っている。', [
        Choice.h('市の税を免じて商人を呼ぶ（銭15貫）', '町は賑わう。すぐには銭にならない', () {
          if (!_pay(g, 15)) return '銭が足りず、町割りは絵図のままに終わった。';
          l.fame += 5;
          l.net += 3;
          g.j(3);
          g.setFlag('castletown');
          g.mark('城下に市を開き、町を育てた');
          return '市の立つ日には、遠くの村からも人が来るようになった。';
        }),
        Choice.h('座の商人に任せ、運上を取る', '銭は確かに入る。町は大きくならない', () {
          final n = g.rng.range(8, 15);
          l.gold += n;
          l.net += 1;
          return '座の商人から運上が納められた。町は、静かなままだ。';
        }),
        Choice.h('武家屋敷で城の守りを固める', '守りは堅くなる。町人は寄りつかない', () {
          l.troops += g.rng.range(5, 12);
          l.merit += 5;
          return '麓には侍屋敷が並び、城は一つの砦になった。';
        }),
      ], after: next);
    }),

    SceneDef('l_nengu', 20, 84, (g) => 1.5, _keep, (g, next) {
      final l = g.l;
      g.ask('年貢の増徴', '主家から、年貢を一割増やせとの達しが来た。領内の村々は、去年の不作からまだ立ち直っていない。', [
        Choice.h('達しの通りに取り立てる', '主君は喜ぶ。村の恨みは残る', () {
          _fav(g, 6);
          l.gold += 5;
          g.j(-3);
          if (g.rng.chance(.2)) {
            l.hp -= 15;
            l.troops = (l.troops * .85).floor();
            g.setFlag('ikki_crushed');
            g.mark('年貢の取り立てで一揆を招き、鎮めた');
            return '村々が蓆旗を掲げた。一揆は鎮めたが、こちらも無傷ではなかった。';
          }
          return '年貢は納められた。村の目は、冷たかった。';
        }),
        Choice.h('差額を自腹で埋める（銭20貫）', '村は守れる。蔵は痩せる', () {
          if (!_pay(g, 20)) {
            _fav(g, -5);
            return '自腹を切ろうにも銭が足りず、納めが遅れて叱責を受けた。';
          }
          _fav(g, 3);
          l.net += 4;
          l.fame += 4;
          g.setFlag('benevolent');
          g.mark('年貢の増徴を、自腹で肩代わりした');
          return '村の長たちが、黙って深く頭を下げた。';
        }),
        Choice.h('減免を願い出る', '筋は通る。主君の機嫌しだいだ', () {
          if (g.rng.chance(.35 + l.mi / 300)) {
            _fav(g, 2);
            l.fame += 5;
            l.net += 2;
            return '願いは聞き届けられ、領内の増徴は見送られた。';
          }
          _fav(g, -8);
          return '「民に甘い」と一喝された。';
        }),
      ], after: next);
    }),

    SceneDef('l_chisui', 20, 84, (g) => 1.2, _keep, (g, next) {
      final l = g.l;
      g.ask('暴れ川', '領内を流れる川が、毎年のように田を呑む。古老は、堤を築けば三代は安泰だと言う。', [
        Choice.h('大堤を築く（銭25貫）', '長い普請になる。成れば田が増える', () {
          if (!_pay(g, 25)) return '銭が足りず、普請は始められなかった。';
          l.fame += 8;
          l.merit += 10;
          l.net += 3;
          g.setFlag('chisui');
          g.mark('暴れ川に堤を築いた');
          return '三年がかりの普請の末、川は堤の内に収まった。';
        }),
        Choice.h('村々に任せる', '銭はかからない。川はまた暴れる', () {
          if (g.rng.chance(.5)) {
            l.gold = l.gold >= 8 ? l.gold - 8 : 0;
            g.j(-2);
            return '秋の大水で、また田が流された。';
          }
          return '今年は、川がおとなしかった。';
        }),
        Choice.h('川の神を祀る（銭3貫）', '心は鎮まる。川が鎮まるかはわからない', () {
          l.gold = l.gold >= 3 ? l.gold - 3 : 0;
          g.j(2);
          l.net += 1;
          return '河原に社を建て、村人と共に祈った。';
        }),
      ], after: next);
    }),

    SceneDef('l_fief_kenchi', 22, 84, (g) => 1.2, _keep, (g, next) {
      final l = g.l;
      g.ask('知行地の検地', '領内の田畑を測り直せば、隠し田が出てくるはずだ。だが、それを見逃してきたのは代々の地侍たちだ。', [
        Choice.h('竿を入れて測り直す', '蔵は潤う。地侍は面白くない', () {
          l.gold += g.rng.range(10, 20);
          l.merit += 6;
          g.setFlag('kenchi_own');
          if (g.rng.chance(.25)) {
            l.troops = (l.troops * .8).floor();
            g.j(-4);
            return '隠し田は暴いた。だが地侍の何人かが、兵を連れて去っていった。';
          }
          g.mark('自らの知行地に竿を入れた');
          return '帳面の田は、思っていたより三割も多かった。';
        }),
        Choice.h('地侍と話をつける', '取り分は少ない。恨みも少ない', () {
          l.gold += 5;
          l.net += 3;
          return '酒を酌み交わし、半分ずつで手を打った。';
        }),
        Choice.h('古い帳面のままにする', '何も変わらない', () {
          g.j(1);
          return '昔からのやり方を、変えずにおいた。';
        }),
      ], after: next);
    }),

    SceneDef('l_new_retainer', 20, 84, (g) => 1.5, _keep, (g, next) {
      final l = g.l;
      final name = _man(g);
      g.ask('牢人の売り込み', '他家を退いた$nameという男が、召し抱えてほしいと門を叩いた。弁は立つが、前の主家を出た訳は語らない。', [
        Choice.h('高禄で召し抱える（銭15貫）', '頼れる家臣になるかもしれない', () {
          if (!_pay(g, 15)) return '払える禄がなく、$nameは去っていった。';
          if (g.rng.chance(.7)) {
            g.meet('家臣', name, 60);
            l.merit += 8;
            l.troops += g.rng.range(5, 10);
            g.setFlag('good_retainer');
            g.mark('牢人の$nameを召し抱えた');
            return '$nameは、古くからの家臣のように働いた。';
          }
          _fav(g, -5);
          g.setFlag('spy_retainer');
          return '$nameは他家の間者だった。気づいたときには、城の絵図が持ち出されていた。';
        }),
        Choice.h('軍師として傍に置く', '知恵が借りられる。古株は嫌がる', () {
          g.meet('軍師', name, 55);
          l.chi = clampInt(l.chi + 2, 0, 99);
          l.net = l.net >= 1 ? l.net - 1 : 0;
          g.setFlag('gunshi');
          g.mark('$nameを軍師として傍に置いた');
          return '$nameの献策は、ときに古株の顔をしかめさせた。';
        }),
        Choice.h('断る', '危うい者は入れない', () => '素性の知れぬ者は、城に入れなかった。'),
      ], after: next);
    }),

    SceneDef('l_young_blunder', 20, 84, (g) => 1.2, _keep, (g, next) {
      final name = _man(g);
      g.ask('若侍の失態', '目をかけていた若い家臣の$nameが、主家の使者に無礼を働いた。使者は顔を赤くして帰っていった。', [
        Choice.h('腹を切らせて詫びる', '家の面目は立つ。若い命が一つ消える', () {
          _fav(g, 5);
          g.j(-8);
          g.setFlag('harsh_master');
          g.mark('失態を犯した若侍$nameに腹を切らせた');
          return '$nameは、一言も恨みを言わずに逝った。';
        }),
        Choice.h('自ら頭を下げに行く', '若侍は救える。主君には落ち度と映る', () {
          _fav(g, -6);
          g.meet('家臣', name, 80);
          g.setFlag('saved_retainer');
          g.mark('失態を犯した若侍$nameを庇った');
          return '使者の前で手をついた。$nameは、その夜泣いていたという。';
        }),
        Choice.h('蟄居させて様子を見る', 'ほとぼりが冷めるのを待つ', () {
          _fav(g, -2);
          return '$nameを屋敷に閉じ込め、噂が消えるのを待った。';
        }),
      ], after: next);
    }),

    SceneDef('l_elder_advice', 25, 84, (g) => 1.2, _keep, (g, next) {
      final l = g.l;
      final name = _man(g);
      g.ask('老臣の諫言', '先代から仕える老臣の$nameが、膝を詰めて言った。「近ごろは、耳に心地よい言葉ばかりお聞きになる」', [
        Choice.h('諫言を容れる', '耳は痛い。家は締まる', () {
          l.chi = clampInt(l.chi + 1, 0, 99);
          l.merit += 3;
          l.net += 2;
          g.meet('老臣', name, 70);
          g.setFlag('heeded_elder');
          return '$nameの言葉を、一つずつ書き留めた。';
        }),
        Choice.h('退けて隠居させる', '小言はなくなる。家中は口をつぐむ', () {
          g.j(2);
          l.net = l.net >= 2 ? l.net - 2 : 0;
          g.setFlag('silenced_elder');
          return '$nameは隠居した。評定は、静かになった。';
        }),
      ], after: next);
    }),

    SceneDef(
      'l_hostage_child',
      25,
      70,
      (g) => 1.5,
      (g) => _castle(g) && g.l.kids >= 1,
      (g, next) {
        final n = _kid(g);
        g.ask('人質の差し出し', '主家が、忠誠の証として子を一人差し出せと求めてきた。行き先は、主家の城の奥深くだ。', [
          Choice.h('$nを差し出す', '主家の信は厚くなる。子とは離れて暮らす', () {
            _fav(g, 12);
            g.j(-10);
            g.meet('人質の子', n, 60);
            g.setFlag('hostage_child');
            g.mark('子の$nを主家へ人質に出した');
            return '$nは振り返らずに輿へ乗った。泣いたのは、見送るほうだった。';
          }),
          Choice.h('病を理由に断る', '子は手元に残る。主家は疑いの目を向ける', () {
            _fav(g, -12);
            g.setFlag('refused_hostage');
            if (g.l.fav < 20 && g.rng.chance(.06)) {
              g.die('人質を拒んで謀反を疑われ、腹を切らされた', 'seppuku');
              return '使者が二度目に来たとき、携えていたのは白装束だった。';
            }
            return '使者は黙って帰った。主家の目は、それきり冷たくなった。';
          }),
        ], after: next);
      },
    ),

    SceneDef('l_favorite', 20, 84, (g) => 1.5, _castle, (g, next) {
      final l = g.l;
      final name = _man(g);
      g.ask('主君の寵臣', '主君の側に、近ごろ取り立てられた$nameがいる。あなたの献策は、その者の口を通さねば主君に届かなくなった。', [
        Choice.h('寵臣に取り入る（銭10貫）', '道は通る。誇りは少し削れる', () {
          if (!_pay(g, 10)) {
            _fav(g, -3);
            return '手土産も用意できず、取り次ぎは後回しにされた。';
          }
          _fav(g, 6);
          g.j(-3);
          g.meet('寵臣', name, 40);
          return '$nameは上機嫌で、あなたの献策を主君に取り次いだ。';
        }),
        Choice.h('主君に直に訴える', '筋が通れば寵臣は退く。通らなければ…', () {
          if (g.rng.chance(.35 + l.mi / 300 + l.chi / 400)) {
            _fav(g, 8);
            g.meet('寵臣', name, 10);
            g.setFlag('beat_favorite');
            g.mark('主君の寵臣$nameを退けた');
            return '主君は$nameを遠ざけた。$nameは、去り際にこちらを睨んだ。';
          }
          if (g.rng.chance(.12)) {
            g.die('主君の寵臣に讒言され、腹を切らされた', 'seppuku');
            return '訴えは、$nameの口から主君へ、違う話になって届いた。';
          }
          _fav(g, -15);
          g.meet('寵臣', name, 0);
          g.setFlag('favorite_enemy');
          return '主君は、$nameの言い分を信じた。';
        }),
        Choice.h('黙って務めを果たす', '波風は立たない。主君は遠くなる', () {
          _fav(g, -4);
          l.merit += 4;
          return '献策はやめ、目の前の務めだけを果たした。';
        }),
      ], after: next);
    }),

    SceneDef('l_transfer', 25, 75, (g) => 1, _keep, (g, next) {
      final l = g.l;
      g.ask('国替えの命', '主家から、遠い新領への国替えを命じられた。石高は増えるが、慣れ親しんだ城と家臣の半ばは置いていくことになる。', [
        Choice.h('命に従う', '石高は増える。根は失う', () {
          l.gold += 15;
          l.troops = (l.troops * .6).floor();
          _fav(g, 8);
          l.net = l.net >= 3 ? l.net - 3 : 0;
          g.setFlag('kunigae');
          g.mark('主命により、遠国へ国替えとなった');
          return '見知らぬ城で、見知らぬ百姓たちが頭を下げた。';
        }),
        Choice.h('旧領に留まりたいと願う', '情は守れる。主君は不満を抱く', () {
          _fav(g, -10);
          l.net += 2;
          return '国替えは沙汰止みとなった。主君の声は、どこか冷たかった。';
        }),
        Choice.h('家臣を連れて移ると条件を出す', '家中は結束する。主君との駆け引きになる', () {
          if (g.rng.chance(.5 + l.mi / 300)) {
            _fav(g, 2);
            l.merit += 3;
            l.gold += 10;
            g.setFlag('kunigae');
            return '条件は呑まれた。家臣たちは、一人残らずついて来た。';
          }
          _fav(g, -6);
          return '「主に条件をつけるか」と叱責された。';
        }),
      ], after: next);
    }),

    SceneDef('l_border', 20, 75, (g) => 1.5, _keep, (g, next) {
      final l = g.l;
      final name = _man(g);
      g.ask(
        '国境の小競り合い',
        '隣国との境で、百姓同士の水争いが刃傷沙汰になった。隣国の城主$nameが、兵を出して境に陣を張っている。',
        [
          Choice.h('兵を率いて押し返す', '武名は上がる。血は流れる', () {
            final r = g.battle('main');
            if (g.l.dead == null) g.mark('国境の争いに兵を率いた');
            return r;
          }),
          Choice.h('$nameと談判する', '収まれば双方の顔が立つ', () {
            if (g.rng.chance(.4 + (l.chi + l.mi) / 300)) {
              l.net += 4;
              l.fame += 3;
              g.meet('隣国の城主', name, 45);
              return '境の川で向き合い、水の分け方を取り決めた。$nameとは、妙に気が合った。';
            }
            _fav(g, -5);
            g.meet('隣国の城主', name, 10);
            return '談判は物別れに終わり、弱腰と侮られた。';
          }),
          Choice.h('主家の裁きを仰ぐ', '自分の手は汚れない。弱腰とも見られる', () {
            _fav(g, 2);
            l.fame = l.fame >= 2 ? l.fame - 2 : 0;
            return '主家の使者が来て、境を引き直していった。';
          }),
        ],
        after: next,
      );
    }),

    SceneDef('l_lure', 20, 84, (g) => 1.2, _keep, (g, next) {
      final l = g.l;
      final e = _rival(g);
      final who = e == null ? '隣国の大名' : '${e.name}家';
      g.ask('敵からの密書', '$whoから、密かに書状が届いた。寝返れば、いまの倍の所領を約束するという。', [
        Choice.h('書状を主君に差し出す', '忠義は示せる。敵の恨みを買う', () {
          _fav(g, 10);
          l.merit += 3;
          g.mark('敵の誘いの書状を、主君に差し出した');
          return '主君は書状を読み、黙ってあなたの肩を叩いた。';
        }),
        Choice.h('返事をせず、手元に置く', 'いざというときの保険。見つかれば命取り', () {
          g.setFlag('secret_letter');
          if (g.rng.chance(.15)) {
            if (g.rng.chance(.4)) {
              g.die('敵と通じたと疑われ、腹を切らされた', 'seppuku');
              return '文箱の底の書状が、目付の手に渡った。';
            }
            _fav(g, -20);
            return '書状が見つかった。申し開きはしたが、疑いは晴れない。';
          }
          return '書状は、文箱の底にしまい込んだ。';
        }),
        if (e != null)
          Choice.h('誘いに乗る', '倍の所領。裏切り者の名がつく', () {
            if (g.rng.chance(.15)) {
              g.die('寝返りの途上で、主家の追手に討たれた', 'senshi');
              return '国境の峠で、追手に追いつかれた。';
            }
            l.lord = e.name;
            l.fav = 25;
            l.gold += 20;
            l.fame = l.fame >= 5 ? l.fame - 5 : 0;
            g.setFlag('turncoat');
            g.mark('主家を見限り、${e.name}家に寝返った');
            return '城ごと${e.name}家に降った。約束の所領は、半分ほどだった。';
          }),
      ], after: next);
    }),

    SceneDef(
      'l_heir_edu',
      35,
      75,
      (g) => 1.5,
      (g) => _castle(g) && g.l.kids >= 2,
      (g, next) {
        final h1 = g.rng.pick(kHeirNames);
        final h2 = g.rng.pick(kHeirNames.where((n) => n != h1).toList());
        g.ask('嫡男の器', '嫡男の$h1は心優しいが、武芸も学問も振るわない。家臣たちは、利発な次男の$h2を推す声を上げ始めた。', [
          Choice.h('$h1に継がせる', '筋目は守れる。家の行く末は案じられる', () {
            g.meet('嫡男', h1, 70);
            g.setFlag('heir');
            g.j(2);
            g.mark('心優しい嫡男$h1を跡継ぎと定めた');
            return '$h1は、${g.l.female ? '母' : '父'}の決めたことに涙ぐんだ。';
          }),
          Choice.h('$h2を立て、嫡男を廃する', '家は強くなる。兄弟に溝が残る', () {
            g.meet('嫡男', h2, 55);
            g.setFlag('heir');
            g.setFlag('disinherit');
            g.j(-5);
            g.mark('嫡男を廃し、次男の$h2を跡継ぎとした');
            return '$h1は寺へ入った。兄弟が口をきくことは、もうなかった。';
          }),
          Choice.h('二人を厳しく鍛え直す（銭10貫）', '答えを先に延ばす', () {
            g.l.gold = g.l.gold >= 10 ? g.l.gold - 10 : 0;
            g.meet('嫡男', h1, 60);
            return '名のある師を招き、二人を朝から晩まで鍛えさせた。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'l_daughter',
      35,
      75,
      (g) => 1.5,
      (g) => _castle(g) && g.l.kids >= 1,
      (g, next) {
        final l = g.l;
        final hime = g.rng.pick(kHimeNames);
        g.ask('娘の縁組', '年頃になった娘の$himeに、主家の重臣から縁組の話が来た。相手は娘より二十も年上の後添えだ。', [
          Choice.h('縁組を受ける', '家の後ろ盾は厚くなる。娘の涙は見ないふり', () {
            _fav(g, 6);
            l.net += 5;
            g.j(-6);
            g.meet('娘', hime, 40);
            g.mark('娘の$himeを、主家の重臣に嫁がせた');
            return '$himeは、輿の中で一度も顔を上げなかった。';
          }),
          Choice.h('娘の想う相手に嫁がせる', '娘は笑う。重臣の顔は潰れる', () {
            _fav(g, -6);
            g.j(6);
            g.meet('娘', hime, 85);
            g.setFlag('love_match');
            return '$himeは、小さな家の若侍に嫁いでいった。よく笑う娘になった。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'l_inlaw_enemy',
      20,
      75,
      (g) => 1.2,
      (g) => _castle(g) && g.l.married,
      (g, next) {
        final l = g.l;
        final sp = l.people['伴侶'];
        final who = sp?.name ?? (l.female ? '夫' : '妻');
        if (l.female) {
          g.ask('実家との手切れ', 'あなたの実家が、嫁ぎ先の主家と手切れになった。奥では、あなたを間者のように見る目がある。', [
            Choice.h('実家と縁を切る', '嫁ぎ先での居場所は守れる。親兄弟とは敵になる', () {
              _fav(g, 8);
              g.j(-12);
              g.setFlag('cut_family');
              g.mark('敵となった実家と、縁を切った');
              return '実家からの文を、読まずに火にくべた。';
            }),
            Choice.h('$whoに実家との仲立ちを申し出る', '和睦が成れば大功。成らなければ板挟み', () {
              if (g.rng.chance(.3 + l.mi / 300)) {
                l.merit += 15;
                _fav(g, 8);
                l.fame += 5;
                g.mark('実家と嫁ぎ先の和睦を取り持った');
                return '二つの家の間を文で行き来し、和睦をまとめ上げた。';
              }
              _fav(g, -6);
              g.j(-6);
              return '仲立ちは実らず、どちらの家からも疑われた。';
            }),
          ], after: next);
          return;
        }
        g.ask('妻の実家', '$whoの実家が、主家と手切れになった。家中には、奥方を疑いの目で見る者がいる。', [
          Choice.h('$whoを実家へ帰す', '主家への忠は示せる。夫婦の縁は切れる', () {
            l.married = false;
            l.people.remove('伴侶');
            _fav(g, 8);
            g.j(-15);
            g.setFlag('divorced');
            g.mark('敵となった実家へ、妻の$whoを帰した');
            return '$whoは、最後に一度だけ振り返った。';
          }),
          Choice.h('$whoをかばい通す', '夫婦の絆は深まる。主家の疑いは晴れない', () {
            if (sp != null) sp.bond = clampInt(sp.bond + 20, 0, 100);
            _fav(g, -10);
            g.setFlag('kept_wife');
            g.mark('敵方の出の妻$whoを、かばい通した');
            return '「わしの妻だ」と言い切った。$whoは、袖で顔を覆った。';
          }),
          Choice.h('$whoに仲立ちを頼む', '和睦が成れば大功。成らなければ板挟み', () {
            if (g.rng.chance(.3 + l.mi / 300)) {
              l.merit += 15;
              _fav(g, 8);
              l.fame += 5;
              if (sp != null) sp.bond = clampInt(sp.bond + 10, 0, 100);
              g.mark('妻の実家と主家の和睦を取り持った');
              return '$whoの文が、二つの家を結び直した。';
            }
            _fav(g, -6);
            g.j(-6);
            return '仲立ちは実らず、$whoは板挟みに苦しんだ。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'l_ambition',
      25,
      70,
      (g) => 1 + (g.l.fav < 35 ? .8 : 0),
      (g) => _keep(g) && g.l.rank >= 6,
      (g, next) {
        final l = g.l;
        g.ask('腹心の囁き', '主君の失政が続き、家中の目が自然とあなたに集まるようになった。腹心が、兵を密かに養っておくべきだと囁く。', [
          Choice.h('密かに兵を養う（銭15貫）', '機が来たときに備えられる。露見すれば…', () {
            if (!_pay(g, 15)) return '養う銭がなく、話はそれきりになった。';
            l.troops += g.rng.range(15, 30);
            _fav(g, -8);
            g.setFlag('ambition');
            if (g.rng.chance(.1)) {
              if (g.rng.chance(.4)) {
                g.die('密かに兵を養ったことが露見し、腹を切らされた', 'seppuku');
                return '山中の砦に、主家の目付が踏み込んだ。';
              }
              _fav(g, -20);
              return '兵の動きが主家に漏れた。釈明に追われた。';
            }
            g.mark('主家に隠れて、兵を養い始めた');
            return '山あいの村に、名もない兵たちが集められた。';
          }),
          Choice.h('腹心を叱りつける', '忠義は守れる。腹心は去るかもしれない', () {
            _fav(g, 4);
            l.net = l.net >= 1 ? l.net - 1 : 0;
            g.setFlag('loyal_heart');
            return '「二度と口にするな」。腹心は、黙って頭を下げた。';
          }),
          Choice.h('主君に諫言する', '主君が変われば家は持ち直す。変わらなければ睨まれる', () {
            if (g.rng.chance(.3 + l.chi / 300)) {
              _fav(g, 8);
              l.fame += 4;
              return '主君は長く黙り込み、やがて政を改めると言った。';
            }
            _fav(g, -10);
            return '主君は顔色を変え、席を立った。';
          }),
        ], after: next);
      },
    ),

    SceneDef('l_hyoro', 20, 84, (g) => 1.2, _keep, (g, next) {
      final l = g.l;
      g.ask('兵糧の蓄え', '境目の城を預かる身として、蔵の米をどうするか決めねばならない。米の値が上がっており、売れば大きな銭になる。', [
        Choice.h('米を売って銭に換える', '蔵は軽くなる。囲まれれば持たない', () {
          l.gold += g.rng.range(15, 25);
          if (g.rng.chance(.15)) {
            if (g.rng.chance(.3)) {
              g.die('兵糧の尽きた城で敵に囲まれ、飢えて死んだ', 'ue');
              return '秋、敵の大軍が城を囲んだ。蔵は、とうに空だった。';
            }
            l.hp -= 25;
            _fav(g, -10);
            return '敵に囲まれ、空の蔵を前に城を明け渡した。';
          }
          return '米は高値で売れた。蔵には、風が吹き抜けている。';
        }),
        Choice.h('蔵を満たしておく（銭10貫）', '銭は出ていく。いざというときに持ちこたえる', () {
          l.gold = l.gold >= 10 ? l.gold - 10 : 0;
          g.setFlag('stocked');
          if (g.rng.chance(.15)) {
            l.fame += 8;
            l.merit += 10;
            g.mark('蓄えた兵糧で、長い籠城を耐え抜いた');
            return '秋、敵に囲まれた。蔵の米で冬を越し、敵は去った。';
          }
          return '蔵は米俵で埋まった。何も起きなければ、それでよい。';
        }),
      ], after: next);
    }),

    // ==================================================================
    // 大名（位8）
    // ==================================================================
    SceneDef('l_bunkokuho', 20, 84, (g) => 1.2, _daimyo, (g, next) {
      g.ask('掟を定める', '家中の争いごとが絶えない。家臣たちは、裁きの拠り所となる掟を定めてほしいと願い出た。', [
        Choice.h('細かな掟を定める', '家中は引き締まる。不満もくすぶる', () {
          _grow(g, g.rng.range(2, 5));
          g.j(-2);
          g.setFlag('bunkokuho');
          g.mark('分国法を定めた');
          return '掟は何十箇条にも及んだ。家臣たちは、それを写して持ち帰った。';
        }),
        Choice.h('喧嘩両成敗だけを定める', '争いは減る。理不尽も生まれる', () {
          _grow(g, 2);
          g.l.net = g.l.net >= 1 ? g.l.net - 1 : 0;
          g.setFlag('bunkokuho');
          return '理由を問わず、刀を抜いた者は双方罰する。争いは目に見えて減った。';
        }),
        Choice.h('慣わしに任せる', '家臣の顔は立つ。争いは続く', () {
          if (g.rng.chance(.4)) {
            _cut(g, .95);
            return '所領争いが斬り合いになり、家中が割れた。';
          }
          return 'これまで通り、古い慣わしで裁いた。';
        }),
      ], after: next);
    }),

    SceneDef('l_rakuichi', 20, 84, (g) => 1.2, _daimyo, (g, next) {
      g.ask('座と市', '城下の座の商人たちが、新しく来た商人を締め出している。座を廃し、誰でも商えるようにせよと進言する者がいる。', [
        Choice.h('座を廃して楽市とする', '町は伸びる。座の後ろ盾の寺社は怒る', () {
          _grow(g, g.rng.range(3, 6));
          g.l.gold += 10;
          g.setFlag('rakuichi');
          g.mark('城下を楽市とした');
          if (g.rng.chance(.2)) {
            g.j(-3);
            return '城下は賑わった。座を抱える寺社からは、強い抗議が来た。';
          }
          return '諸国から商人が集まり、城下は見違えるほど賑わった。';
        }),
        Choice.h('座を守る', '冥加金は入る。町は伸び悩む', () {
          g.l.gold += g.rng.range(10, 18);
          return '座の商人たちは、礼の銭を欠かさず納めた。';
        }),
      ], after: next);
    }),

    SceneDef('l_realm_kenchi', 25, 84, (g) => 1.2, _daimyo, (g, next) {
      g.ask(
        '国中の検地',
        '国中の田畑を一律の竿で測り直せば、隠し田も国人の取り分も明らかになる。国人たちはそれを、首に縄をかけられることだと受け取るだろう。',
        [
          Choice.h('一斉に竿を入れる', '国の力は大きく増す。一揆が起きるかもしれない', () {
            if (g.rng.chance(.3)) {
              _cut(g, .88);
              g.j(-5);
              g.setFlag('kenchi_ikki');
              return '国人一揆が起きた。鎮めはしたが、多くを失った。';
            }
            _grow(g, g.rng.range(5, 8));
            g.setFlag('realm_kenchi');
            g.mark('国中に竿を入れ、検地を行った');
            return '帳面の上で、国は一回り大きくなった。';
          }),
          Choice.h('国人ごとに差し出させる', '穏やかに進む。隠し田は残る', () {
            _grow(g, g.rng.range(1, 3));
            return '国人たちは、それぞれの帳面を差し出した。数字は、どれも控えめだった。';
          }),
          Choice.h('見送る', '国人は安堵する', () {
            g.l.net += 2;
            return '検地は見送った。国人たちは、胸をなで下ろした。';
          }),
        ],
        after: next,
      );
    }),

    SceneDef('l_mine', 20, 84, (g) => 1, _daimyo, (g, next) {
      final l = g.l;
      g.ask('金山', '領内の山で金の鉱脈が見つかったと、山師が知らせてきた。掘るには人も銭も要る。', [
        Choice.h('山師に任せて掘らせる（銭30貫）', '当たれば蔵が溢れる。外れれば銭は土の中', () {
          if (!_pay(g, 30)) return '銭が足りず、山には手がつけられなかった。';
          if (g.rng.chance(.55 + l.un / 400)) {
            l.gold += g.rng.range(60, 100);
            _grow(g, 3);
            g.setFlag('gold_mine');
            g.mark('領内に金山を開いた');
            return '坑道の奥で、岩が黄金色に光った。';
          }
          return '掘っても掘っても、出てくるのは石ばかりだった。';
        }),
        Choice.h('秘して手をつけない', '他国に狙われずに済む。宝は眠ったまま', () {
          g.setFlag('hidden_mine');
          g.j(1);
          return '山師には口止めの銭を渡し、山はそのままにした。';
        }),
      ], after: next);
    }),

    SceneDef('l_nanban_port', 20, 84, (g) => 1, _daimyo, (g, next) {
      final l = g.l;
      g.ask('南蛮船の寄港', '南蛮の船が、領内の湊に入りたいと申し出てきた。鉄砲や硝石を積んでいるが、宣教師も乗っている。', [
        Choice.h('交易も布教も許す', '鉄砲と銭が手に入る。寺社や家臣は眉をひそめる', () {
          l.gold += 20;
          l.gun = true;
          _grow(g, 3);
          g.setFlag('kirishitan_ok');
          g.meet('宣教師', '南蛮の宣教師', 50);
          g.mark('南蛮船に湊を開き、布教を許した');
          if (g.rng.chance(.2)) {
            g.j(-3);
            return '湊には南蛮寺が建った。古い寺の僧たちは、門を閉ざした。';
          }
          return '湊には見たこともない品が並び、鐘の音が響くようになった。';
        }),
        Choice.h('交易だけを許す', '品は得られる。船は来なくなるかもしれない', () {
          if (g.rng.chance(.5)) {
            l.gold += 15;
            l.gun = true;
            return '南蛮の商人は、渋い顔で鉄砲を売っていった。';
          }
          return '布教を許さぬと知ると、船は帆を上げて去った。';
        }),
        Choice.h('湊を閉ざす', '国の静けさは守られる', () {
          g.j(1);
          return '沖の船は、しばらく留まったのち、水平線に消えた。';
        }),
      ], after: next);
    }),

    SceneDef('l_ikko', 20, 84, (g) => 1.2, _daimyo, (g, next) {
      g.ask('門徒の立て籠もり', '領内の一向門徒が、年貢を拒んで寺に立て籠もった。門徒は村々に広がり、家臣の中にも信徒がいる。', [
        Choice.h('兵を差し向けて攻め落とす', '一揆は根絶やしにできる。血は長く残る', () {
          g.j(-6);
          g.setFlag('crushed_ikko');
          if (g.rng.chance(.03)) {
            g.die('一向門徒の放った刺客に討たれた', 'ansatsu');
            return '戦のあと、念仏を唱える男が、行列に飛び込んできた。';
          }
          if (g.rng.chance(.3)) {
            _cut(g, .85);
            return '門徒は死を恐れずに戦い、味方の損害は大きかった。';
          }
          _cut(g, .95);
          g.l.fame += 5;
          g.mark('一向一揆を攻め滅ぼした');
          return '寺は焼け落ちた。煙は三日のあいだ消えなかった。';
        }),
        Choice.h('寺と和を結ぶ', '国は静まる。寺の力は残る', () {
          g.l.fame = g.l.fame >= 2 ? g.l.fame - 2 : 0;
          g.l.net += 3;
          g.setFlag('ikko_peace');
          return '年貢を減らす代わりに、門徒は寺を出た。';
        }),
        Choice.h('指導者だけを捕らえる', '早く収まる。殉教者を生むかもしれない', () {
          if (g.rng.chance(.5 + g.l.chi / 300)) {
            _grow(g, 1);
            return '坊官を捕らえると、門徒たちは散っていった。';
          }
          _cut(g, .9);
          return '捕らえた坊官は殉教者と仰がれ、一揆はかえって広がった。';
        }),
      ], after: next);
    }),

    SceneDef('l_temple_land', 20, 84, (g) => 1, _daimyo, (g, next) {
      g.ask(
        '大寺の寺領',
        '領内の大寺が、広い寺領と僧兵を抱え、守護の手は入れさせぬと言い立てている。家臣は、寺領を召し上げれば兵も蔵も潤うと言う。',
        [
          Choice.h('寺領を召し上げる', '国は強まる。仏罰を恐れる者も出る', () {
            _grow(g, g.rng.range(3, 6));
            g.l.gold += 15;
            g.j(-3);
            g.setFlag('seized_temple');
            g.mark('大寺の寺領を召し上げた');
            return '僧兵は解かれ、寺には本堂だけが残された。';
          }),
          Choice.h('寄進して味方につける（銭20貫）', '祈りと人心が得られる', () {
            if (!_pay(g, 20)) return '寄進する銭が足りず、寺とは睨み合いが続いた。';
            g.l.fame += 5;
            g.l.net += 3;
            g.j(3);
            g.setFlag('temple_patron');
            return '寺は、あなたの武運を祈る祈祷を欠かさなくなった。';
          }),
        ],
        after: next,
      );
    }),

    SceneDef('l_break_alliance', 20, 84, (g) => 1.2, _daimyo, (g, next) {
      final e = _rival(g);
      if (e == null) {
        next();
        return;
      }
      g.ask('盟約の破り時', '長く盟を結んできた${e.name}家が、代替わりで揺れている。いま背後を突けば、国を丸ごと奪える。', [
        Choice.h('盟約を破って攻め込む', '国は広がる。裏切りの名は消えない', () {
          final me = _me(g);
          g.setFlag('oath_breaker');
          g.l.fame = g.l.fame >= 5 ? g.l.fame - 5 : 0;
          if (g.rng.chance(
            clampD(me.power / (me.power + e.power) * 1.3, .2, .85),
          )) {
            final gain = e.power * .4;
            me.power += gain;
            e.power = e.power * .6 < 3 ? 3 : e.power * .6;
            g.meet('宿敵', '${e.name}家の遺児', 0);
            g.mark('盟約を破り、${e.name}家を攻めた');
            return '${e.name}家の城を次々と落とした。落ち延びた遺児が、あなたの名を呪っているという。';
          }
          _cut(g, .85);
          return '${e.name}家は一つにまとまり、攻め手を押し返した。';
        }),
        Choice.h('盟約を守る', '信義の名は残る。好機は去る', () {
          g.l.fame += 6;
          g.l.net += 3;
          g.setFlag('kept_oath');
          return '${e.name}家の若い当主から、丁重な礼状が届いた。';
        }),
      ], after: next);
    }),

    SceneDef('l_hostage_fate', 20, 84, (g) => 1, _daimyo, (g, next) {
      final name = g.rng.pick(kHeirNames);
      g.ask('人質の処遇', '盟を破った隣国の当主の子、$nameが、人質としてこの城にいる。家臣たちは、見せしめに斬るべきだと言う。', [
        Choice.h('斬る', '家臣の溜飲は下がる。恨みは深く残る', () {
          _grow(g, 1);
          g.l.fame = g.l.fame >= 3 ? g.l.fame - 3 : 0;
          g.j(-8);
          g.setFlag('killed_hostage');
          g.meet('宿敵', '$nameの父', 0);
          g.mark('人質の$nameを斬った');
          return '$nameは、最後まで泣かなかった。';
        }),
        Choice.h('親元へ送り返す', '甘いと言われる。器の大きさとも言われる', () {
          g.l.fame += 8;
          g.l.net += 3;
          g.setFlag('returned_hostage');
          return '$nameを輿に乗せ、国境まで送らせた。';
        }),
        Choice.h('手元で育てる', '家臣になるか、仇を育てるか', () {
          g.meet('人質の若君', name, 50);
          g.setFlag('raised_hostage');
          g.mark('人質の$nameを、我が子同然に育てた');
          return '$nameは、あなたの子らと一緒に手習いを始めた。';
        }),
      ], after: next);
    }),

    SceneDef('l_surrendered', 20, 84, (g) => 1.2, _daimyo, (g, next) {
      final name = _man(g);
      g.ask('降将', '降伏した敵の侍大将、$nameが、縄を打たれて庭に引き据えられた。命乞いはしない、と言う。', [
        Choice.h('縄を解いて召し抱える', '良い家臣になるかもしれない。寝首をかくかもしれない', () {
          if (g.rng.chance(.75)) {
            _grow(g, 2);
            g.meet('降将', name, 60);
            g.mark('降った敵将$nameを召し抱えた');
            return '$nameは、その日から誰よりも働いた。';
          }
          if (g.rng.chance(.3)) {
            g.die('召し抱えた降将に、寝所で討たれた', 'ansatsu');
            return '$nameの目の奥の火は、消えていなかった。';
          }
          _cut(g, .95);
          return '$nameは、兵を連れて夜のうちに逃げた。';
        }),
        Choice.h('首を刎ねる', '後の憂いはない。家中は主の苛烈さを知る', () {
          g.l.fame += 2;
          g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
          g.j(-3);
          return '$nameの首は、城門に晒された。';
        }),
        Choice.h('国へ帰す', '仁の名が上がる', () {
          g.l.fame += 6;
          return '$nameは、一度だけ深く頭を下げて去った。';
        }),
      ], after: next);
    }),

    SceneDef('l_meijo', 25, 84, (g) => 1.2, _daimyo, (g, next) {
      g.ask('名城の普請', '天下に聞こえる城を築こうと、縄張りの絵図が広げられた。石垣は高く、天守は五重。費えは国が傾くほどだ。', [
        Choice.h('五重の天守を築く（銭60貫）', '威は天下に轟く。蔵は空になる', () {
          if (!_pay(g, 60)) return '銭が足りず、絵図は巻かれたまま蔵にしまわれた。';
          _grow(g, g.rng.range(5, 8));
          g.l.fame += 15;
          g.setFlag('meijo');
          g.mark('天下に聞こえる名城を築いた');
          return '白い天守が、遠い国からも見えた。';
        }),
        Choice.h('堅固な平城にとどめる（銭25貫）', '見栄えより守り', () {
          if (!_pay(g, 25)) return '銭が足りず、普請は見送られた。';
          _grow(g, 3);
          return '高さはないが、堀は深く、どこからも攻めにくい城になった。';
        }),
        Choice.h('いまの城で足りる', '蔵は守れる', () => '城は、いまのままで十分だと答えた。'),
      ], after: next);
    }),

    SceneDef('l_heinou', 25, 84, (g) => 1, _daimyo, (g, next) {
      g.ask(
        '兵と百姓',
        '田植えと稲刈りの頃になると、兵が村へ帰ってしまい、戦が続けられない。兵を村から切り離し、城下に住まわせる策が上がっている。',
        [
          Choice.h('兵を城下に集める（銭30貫）', '一年中戦える。村の力は落ちる', () {
            if (!_pay(g, 30)) return '兵を養う銭が足りなかった。';
            _grow(g, g.rng.range(4, 7));
            g.setFlag('heinou');
            g.mark('兵を村から切り離し、城下に集めた');
            return '城下には長屋が並び、槍を担いだ兵が毎朝調練に出るようになった。';
          }),
          Choice.h('昔のままにする', '村は落ち着く。戦は季節に縛られる', () {
            g.j(1);
            return '兵は、これまで通り田と戦を行き来する。';
          }),
        ],
        after: next,
      );
    }),

    SceneDef('l_teppo', 20, 84, (g) => 1.2, _daimyo, (g, next) {
      final l = g.l;
      g.ask('鉄砲の商い', '堺の商人が、鉄砲を百挺まとめて売りたいと言ってきた。値は張るが、弓の何倍もの兵を倒せるという。', [
        Choice.h('百挺買い入れ、鉄砲隊を組む（銭40貫）', '戦の形が変わる。蔵は軽くなる', () {
          if (!_pay(g, 40)) return '銭が足りず、商人は他国へ回っていった。';
          l.gun = true;
          _grow(g, g.rng.range(4, 7));
          g.setFlag('teppo_tai');
          g.mark('鉄砲隊を組んだ');
          return '射場から、雷のような音が絶えなくなった。';
        }),
        Choice.h('十挺だけ買って試す（銭8貫）', '使い道は見えてくる', () {
          if (!_pay(g, 8)) return '十挺を買う銭も惜しかった。';
          l.gun = true;
          _grow(g, 1);
          return '試し撃ちの音に、馬が驚いて跳ねた。';
        }),
        Choice.h('弓と槍で足りる', '銭は残る。時代に遅れるかもしれない', () => '商人には、茶だけ出して帰ってもらった。'),
      ], after: next);
    }),

    SceneDef('l_kanni', 20, 84, (g) => 1, _daimyo, (g, next) {
      final l = g.l;
      g.ask(
        '官位の内意',
        '朝廷の使いが、献金と引き換えに官位を授けたいと申し出てきた。名ばかりの官位でも、他の大名を従わせる理由にはなる。',
        [
          Choice.h('献金して官位を受ける（銭40貫）', '名分が手に入る', () {
            if (!_pay(g, 40)) return '献金する銭が足りず、使いは帰っていった。';
            l.fame += 15;
            _grow(g, 2);
            g.setFlag('kanni');
            g.mark('朝廷に献金し、官位を賜った');
            return '口宣案が届いた。家臣たちは、新しい呼び名で平伏した。';
          }),
          Choice.h('内裏の修理を申し出る（銭60貫）', '名分も、都の信望も得る', () {
            if (!_pay(g, 60)) return '銭が足りず、申し出は果たせなかった。';
            l.fame += 25;
            l.net += 5;
            _grow(g, 3);
            g.setFlag('kanni');
            g.setFlag('dairi');
            g.mark('内裏の修理を請け負い、官位を賜った');
            return '崩れかけた築地塀が直り、都の人々があなたの名を口にした。';
          }),
          Choice.h('断る', '名より実を取る', () => '官位で米は増えぬ、と使いを帰した。'),
        ],
        after: next,
      );
    }),

    SceneDef('l_shogun', 20, 84, (g) => 1, _daimyo, (g, next) {
      final l = g.l;
      g.ask('将軍家の御内書', '京を追われた将軍家から、上洛して将軍家を助けよとの書状が届いた。', [
        Choice.h('兵を率いて上洛する', '天下に名乗りを上げる。周りの大名は警戒する', () {
          if (g.rng.chance(clampD(.4 + g.share, .3, .85))) {
            l.fame += 20;
            _grow(g, 3);
            g.setFlag('joraku');
            g.mark('将軍家を奉じて上洛した');
            return '都の大路を、軍勢を率いて進んだ。';
          }
          _cut(g, .85);
          return '上洛の途上で周りの大名に阻まれ、兵を返した。';
        }),
        Choice.h('銭を送るにとどめる（銭20貫）', '義理は果たせる', () {
          if (!_pay(g, 20)) return '送る銭もなく、返事だけを出した。';
          l.fame += 5;
          return '将軍家から、丁重な礼状が届いた。';
        }),
        Choice.h('捨て置く', '関わらずに済む', () => '書状は、文箱にしまい込んだ。'),
      ], after: next);
    }),

    SceneDef(
      'l_successor',
      40,
      84,
      (g) => 1.5,
      (g) => _daimyo(g) && g.l.kids >= 2,
      (g, next) {
        final h1 = g.rng.pick(kHeirNames);
        final h2 = g.rng.pick(kHeirNames.where((n) => n != h1).toList());
        g.ask('世継ぎ', '家臣たちが、世継ぎを定めてほしいと願い出た。嫡子の$h1は温和で、庶子の$h2は戦上手だ。', [
          Choice.h('$h1を世継ぎに定める', '筋目は守れる。家は穏やかに続く', () {
            g.meet('嫡男', h1, 70);
            g.setFlag('heir');
            g.l.net += 2;
            g.mark('嫡子の$h1を世継ぎと定めた');
            return '$h1を世継ぎと披露した。家臣たちは、ほっとした顔をした。';
          }),
          Choice.h('戦上手の$h2を立てる', '家は強くなる。家中が割れるかもしれない', () {
            g.meet('嫡男', h2, 55);
            g.setFlag('heir');
            g.setFlag('disinherit');
            _grow(g, 1);
            g.mark('庶子の$h2を世継ぎに立てた');
            if (g.rng.chance(.2)) {
              _cut(g, .9);
              return '$h1を担ぐ重臣たちが、城を去った。';
            }
            return '$h2は、父の期待に応えると誓った。';
          }),
        ], after: next);
      },
    ),

    SceneDef('l_brother_revolt', 20, 75, (g) => 1, _daimyo, (g, next) {
      final name = g.rng.pick(kGivenM);
      g.ask('弟の挙兵', '弟の$nameが、不満を抱く重臣たちに担がれて兵を挙げた。幼い日、ともに野を駆けた弟だ。', [
        Choice.h('自ら兵を率いて討つ', '家は一つにまとまる。血を分けた者を斬ることになる', () {
          if (g.rng.chance(.7)) {
            _cut(g, .92);
            g.j(-15);
            g.setFlag('killed_brother');
            g.mark('謀反した弟の$nameを討った');
            return '$nameの首桶を、長いあいだ開けられなかった。';
          }
          _cut(g, .8);
          if (g.rng.chance(.1)) {
            g.die('謀反した弟の放った刺客に討たれた', 'ansatsu');
            return '陣中に紛れ込んだ$nameの手の者が、背後から迫った。';
          }
          return '戦は長引き、国は大きく傷ついた。';
        }),
        Choice.h('弟を許し、重臣だけを罰する', '情はつながる。火種は残る', () {
          _cut(g, .95);
          g.setFlag('forgave_brother');
          if (g.rng.chance(.12)) {
            g.die('許した弟の手の者に、寝所で刺された', 'ansatsu');
            return '許したはずの夜に、襖が音もなく開いた。';
          }
          g.meet('弟', name, 40);
          g.mark('謀反した弟の$nameを許した');
          return '$nameは泣いて詫びた。その涙が本物かは、わからない。';
        }),
        Choice.h('国を分けて与える', '戦は避けられる。国は小さくなる', () {
          _cut(g, .8);
          g.meet('弟', name, 60);
          g.j(2);
          return '国の半ばを$nameに与えた。兄弟の戦は、起きずに済んだ。';
        }),
      ], after: next);
    }),

    SceneDef(
      'l_insei',
      50,
      84,
      (g) => 1.2,
      (g) => _daimyo(g) && g.l.kids >= 1,
      (g, next) {
        g.ask('院政', '家督を譲れという声が、家中にそれとなく広がっている。だが、まだ若い跡継ぎに国を任せきるのは心もとない。', [
          Choice.h('家督を譲り、後ろで政を見る', '跡継ぎは育つ。二つの声は家臣を迷わせる', () {
            g.setFlag('insei');
            g.setFlag('retired');
            g.l.troops = 0;
            g.j(4);
            g.mark('家督を譲り、隠居の身で政を見た');
            if (g.rng.chance(.25)) {
              _cut(g, .9);
              return '新しい当主と隠居の命が食い違い、家臣たちは右往左往した。';
            }
            return '隠居所から、ときおり短い指図の文を送った。';
          }),
          Choice.h('生涯、当主の座にある', '国は一つの声で動く。跡継ぎは育たない', () {
            g.setFlag('never_retire');
            _grow(g, 1);
            return '「${g.l.female ? 'わらわ' : 'わし'}の目が黒いうちは」と、家督の話を退けた。';
          }),
        ], after: next);
      },
    ),

    SceneDef(
      'l_sokushitsu',
      20,
      70,
      (g) => 1,
      (g) => _daimyo(g) && !g.l.female,
      (g, next) {
        final l = g.l;
        final name = '${g.rng.pick(kSurnames)}家の${g.rng.pick(kGivenF)}';
        final sp = l.people['伴侶'];
        g.ask('側室の話', '家臣が、$nameを側室にと勧めてきた。娘の父は、境目の要所を押さえる国人だ。', [
          Choice.h('側室に迎える', '国人は味方になる。奥は波立つ', () {
            g.meet('側室', name, 55);
            _grow(g, 2);
            g.j(4);
            if (sp != null) sp.bond = clampInt(sp.bond - 15, 0, 100);
            if (g.rng.chance(.4)) l.kids++;
            g.mark('$nameを側室に迎えた');
            return '$nameが奥に入った。${sp == null ? '' : '${sp.name}は、何も言わなかった。'}';
          }),
          Choice.h('断る', '奥は穏やか。国人は離れるかもしれない', () {
            if (sp != null) sp.bond = clampInt(sp.bond + 5, 0, 100);
            if (g.rng.chance(.3)) {
              _cut(g, .96);
              return '話を断ると、国人は隣国へ誼を通じ始めた。';
            }
            return '話は、穏やかに立ち消えた。';
          }),
        ], after: next);
      },
    ),

    SceneDef('l_meibutsu', 25, 84, (g) => 1, _daimyo, (g, next) {
      final l = g.l;
      g.ask('名物の茶入れ', '天下に名高い茶入れが、売りに出されたという。一国にも代えがたいと言われる名物だ。', [
        Choice.h('大枚をはたいて手に入れる（銭50貫）', '茶の湯の席で一目置かれる', () {
          if (!_pay(g, 50)) return '銭が足りず、名物は他家の手に渡った。';
          l.fame += 12;
          l.net += 4;
          g.setFlag('meibutsu');
          g.mark('天下の名物を手に入れた');
          return '掌に収まるほどの茶入れが、国より重く感じられた。';
        }),
        Choice.h('手に入れて功臣に与える（銭50貫）', '土地の代わりに誉れを与える。家臣は奮い立つ', () {
          if (!_pay(g, 50)) return '銭が足りず、名物は他家の手に渡った。';
          _grow(g, g.rng.range(3, 5));
          l.net += 3;
          g.setFlag('meibutsu_gift');
          return '名物を賜った家臣は、城一つ貰うより喜んだ。';
        }),
        Choice.h('茶器に国は賭けぬ', '蔵は守れる', () => '土くれ一つに国の銭は出せぬ、と笑った。'),
      ], after: next);
    }),

    SceneDef('l_honne', 30, 84, (g) => 1.2, _daimyo, (g, next) {
      final l = g.l;
      final name = _man(g);
      g.ask('誰も本音を言わない', '評定で何を言っても、家臣たちは「ご尤も」と頭を下げるばかりになった。誰も、本音を言わない。', [
        Choice.h('身分を問わず、異を唱える者を求める', '耳の痛い言葉が戻る', () {
          g.meet('軍師', name, 60);
          l.chi = clampInt(l.chi + 2, 0, 99);
          l.net += 3;
          _grow(g, 1);
          g.setFlag('seek_truth');
          g.mark('身分を問わず異見を求め、$nameを得た');
          return '名もない足軽上がりの$nameが、真っ向から策に異を唱えた。久しぶりに、胸がすいた。';
        }),
        Choice.h('一人、忍びで城下を歩く', '民の声が聞ける。危うさもある', () {
          if (g.rng.chance(.05)) {
            g.die('忍び歩きの夜、刺客に襲われた', 'ansatsu');
            return '路地の暗がりから、白刃が伸びた。';
          }
          g.j(6);
          l.fame += 3;
          g.setFlag('incognito');
          return '茶屋の婆が、殿様の悪口を楽しそうに話していた。';
        }),
        Choice.h('それでよい、と思う', '国は滞りなく回る。心は冷えていく', () {
          g.j(-6);
          g.setFlag('lonely_lord');
          return '静かな評定の間で、自分の声だけが響いていた。';
        }),
      ], after: next);
    }),

    SceneDef('l_old_friend', 30, 84, (g) => 1.2, _daimyo, (g, next) {
      final l = g.l;
      final p = l.people['幼なじみ'] ?? l.people['好敵手'];
      final name = p?.name ?? _man(g);
      g.ask('旧友の内通', '若い頃から苦楽を共にした$nameが、敵方と通じていたことが分かった。証の書状が、目の前にある。', [
        Choice.h('斬る', '国の掟は守られる。友は二度と戻らない', () {
          g.j(-15);
          _grow(g, 1);
          if (p != null) p.bond = 0;
          g.setFlag('killed_friend');
          g.mark('内通した旧友$nameを斬った');
          return '$nameは、斬られる前に一度だけ笑った。';
        }),
        Choice.h('書状を焼き、何も見なかったことにする', '友は救える。裏切りは繰り返されるかもしれない', () {
          if (g.rng.chance(.25)) {
            if (g.rng.chance(.4)) {
              g.die('見逃した旧友に、寝首をかかれた', 'ansatsu');
              return '焼いたはずの書状の続きが、夜半に届いた。';
            }
            _cut(g, .85);
            return '$nameは敵方へ走り、城を一つ持ち去った。';
          }
          if (p != null) p.bond = clampInt(p.bond + 20, 0, 100);
          g.j(3);
          g.setFlag('spared_friend');
          return '書状の灰を、黙って庭に撒いた。';
        }),
        Choice.h('二人きりで問いただす', '本心が聞ける。刃が出るかもしれない', () {
          if (g.rng.chance(.5)) {
            if (p != null) p.bond = clampInt(p.bond + 10, 0, 100);
            g.setFlag('reconciled_friend');
            g.mark('内通した旧友$nameと、膝を突き合わせて語った');
            return '$nameは、家族を人質に取られていたと泣いた。';
          }
          if (g.rng.chance(.15)) {
            g.die('問いただした旧友に、刺された', 'ansatsu');
            return '$nameの袖から、短刀が滑り出た。';
          }
          g.j(-8);
          return '$nameは何も答えず、その夜のうちに姿を消した。';
        }),
      ], after: next);
    }),

    SceneDef('l_lord_illness', 40, 84, (g) => 1.2, (g) => _daimyo(g), (
      g,
      next,
    ) {
      final l = g.l;
      g.ask('主の病', '胸を病み、近ごろは咳に血が混じる。病が知れれば、家臣も隣国も動き出すだろう。', [
        Choice.h('病を隠して政務を続ける', '国は揺れない。体は削られる', () {
          l.hp -= 20;
          g.setFlag('hid_illness');
          if (g.rng.chance(.12)) {
            g.die('病を隠したまま政務を続け、倒れた', 'byo');
            return '評定の席で、ふいに目の前が暗くなった。';
          }
          return '白粉で顔色を隠し、何事もない顔で評定に出た。';
        }),
        Choice.h('公にして養生する', '体は戻る。隣国がつけ込む', () {
          _heal(l, 30);
          _cut(g, .9);
          return '湯治の間に、隣国が境の城をいくつか奪った。';
        }),
        Choice.h('名医を探させる（銭20貫）', '銭はかかる。良い医者に会えれば', () {
          if (!_pay(g, 20)) {
            l.hp -= 10;
            return '銭が足りず、名医は招けなかった。';
          }
          _heal(l, 25);
          return '都から来た医師の薬で、咳は少し収まった。';
        }),
      ], after: next);
    }),

    // ==================================================================
    // 天下に手が届く者（位8・勢力が大きい）
    // ==================================================================
    SceneDef('l_tenka_last', 20, 84, (g) => 2.5, (g) => _near(g, .35), (
      g,
      next,
    ) {
      final e = _rival(g, strongest: true);
      if (e == null) {
        next();
        return;
      }
      g.ask('最後の大敵', '天下に残る大きな敵は、${e.name}家だけになった。これを下せば、もはや逆らう者はいない。', [
        Choice.h('全軍で攻め寄せる', '一気に決まる。敗れれば全てが崩れる', () {
          final me = _me(g);
          if (g.rng.chance(
            clampD(me.power / (me.power + e.power) * 1.1, .3, .9),
          )) {
            final gain = e.power * .5;
            me.power += gain;
            e.power = e.power * .5 < 3 ? 3 : e.power * .5;
            g.l.fame += 15;
            g.mark('天下分け目の戦で、${e.name}家を破った');
            return '野を埋めた${e.name}家の旗が、一日で崩れた。';
          }
          _cut(g, .8);
          g.l.fame = g.l.fame >= 5 ? g.l.fame - 5 : 0;
          return '${e.name}家の陣は堅く、退かざるを得なかった。';
        }),
        Choice.h('囲んで降伏を待つ', '時はかかる。血は流れない', () {
          _grow(g, 2);
          e.power = e.power * .85 < 3 ? 3 : e.power * .85;
          if (g.age >= 50 && g.rng.chance(.06)) {
            g.die('天下を前にした長陣の陣中で、病に倒れた', 'byo');
            return '長陣の冬、陣中で熱を出し、そのまま起き上がれなかった。';
          }
          return '城を幾重にも囲み、月日が敵の力を削っていった。';
        }),
        Choice.h('所領を安堵して臣従させる', '敵は味方になる。火種も抱え込む', () {
          _grow(g, e.power * .3);
          e.power = e.power * .7 < 3 ? 3 : e.power * .7;
          g.l.fame += 5;
          g.setFlag('tenka_peace');
          g.mark('${e.name}家を戦わずに従えた');
          return '${e.name}家の当主が、あなたの前で平伏した。目は笑っていなかった。';
        }),
      ], after: next);
    }),

    SceneDef('l_title', 20, 84, (g) => 2, (g) => _near(g, .3), (g, next) {
      final l = g.l;
      g.ask('朝廷の内意', '朝廷から、望むなら最高の位を授けたいとの内意が伝えられた。武家の棟梁となるか、公家の頂に立つか。', [
        Choice.h('征夷大将軍を望む', '武家を束ねる名分。家柄を問う声もある', () {
          l.fame += 20;
          _grow(g, 3);
          g.setFlag('shogun_title');
          g.mark('征夷大将軍に任じられた');
          return '将軍宣下の勅使が、城の大広間に入ってきた。';
        }),
        Choice.h('関白を望む', '公家の頂から天下に号令する', () {
          l.fame += 20;
          l.net += 4;
          _grow(g, 2);
          g.setFlag('kanpaku');
          g.mark('関白に任じられた');
          return '都に上り、公家たちの居並ぶ中で関白の座に就いた。';
        }),
        Choice.h('位は受けず、実を取る', '名に縛られない。名分は得られない', () {
          _grow(g, 1);
          g.setFlag('no_title');
          return '「位で天下は治まらぬ」と、内意を丁重に辞した。';
        }),
      ], after: next);
    }),

    SceneDef('l_tenka_fushin', 20, 84, (g) => 2, (g) => _near(g, .3), (
      g,
      next,
    ) {
      g.ask('天下の普請', '従う大名たちに、城や堀の普請を割り当てる時が来た。普請は大名たちの蔵を削り、逆らう力を奪う。', [
        Choice.h('重い普請を課す', '大名は弱る。不満は溜まる', () {
          g.setFlag('tenka_fushin');
          if (g.rng.chance(.2)) {
            _cut(g, .9);
            return '普請に耐えかねた大名が、兵を挙げた。';
          }
          _grow(g, g.rng.range(4, 7));
          g.mark('諸大名に天下普請を課した');
          return '諸国の大名が石を曳き、巨大な城が瞬く間に立ち上がった。';
        }),
        Choice.h('軽い普請にとどめる', '恨みは少ない。大名の力も残る', () {
          _grow(g, 2);
          g.l.net += 3;
          return '大名たちは、ほっとした顔で国へ帰った。';
        }),
      ], after: next);
    }),

    SceneDef('l_move_lords', 20, 84, (g) => 2, (g) => _near(g, .35), (g, next) {
      final name = '${g.rng.pick(kSurnames)}家の当主';
      g.ask('大名の国替え', '味方についた大名の中に、古い本領で力を蓄えすぎた$nameがいる。遠国へ移せば、その牙は抜ける。', [
        Choice.h('遠国へ移す', '牙は抜ける。拒まれれば戦になる', () {
          if (g.rng.chance(.25)) {
            _cut(g, .85);
            g.meet('宿敵', name, 5);
            return '$nameは国替えを拒み、城に籠もって兵を挙げた。';
          }
          _grow(g, 4);
          g.setFlag('moved_lords');
          g.mark('力をつけた大名を、遠国へ移した');
          return '$nameは、黙って遠国へ移っていった。';
        }),
        Choice.h('加増して取り込む', '味方は固まる。力はさらに増す', () {
          _grow(g, 1);
          g.l.net += 4;
          g.meet('股肱の大名', name, 60);
          return '$nameは加増の沙汰に平伏し、忠誠を誓った。';
        }),
      ], after: next);
    }),

    SceneDef('l_overseas', 30, 84, (g) => 2, (g) => _near(g, .3), (g, next) {
      final l = g.l;
      g.ask('海の向こう', '天下の目処が立つと、海の向こうの大国が目に入るようになった。家臣の多くは、それを口に出さずに案じている。', [
        Choice.h('渡海の支度を命じる', '名は海の彼方まで轟く。国は疲れ果てる', () {
          _cut(g, .85);
          l.fame += 15;
          g.setFlag('kaigai');
          g.mark('海の向こうへ兵を出す支度を命じた');
          return '湊という湊で、大船の普請が始まった。';
        }),
        Choice.h('交易で富を得る', '蔵は満ちる。武名は増えない', () {
          l.gold += 30;
          _grow(g, 2);
          g.setFlag('kaigai_trade');
          return '朱印を押した船が、南の海へ漕ぎ出していった。';
        }),
        Choice.h('夢は夢のままにしておく', '国は休める。胸の火は燻る', () {
          l.net += 3;
          g.j(-2);
          return '地図の海の向こうを、指でそっとなぞった。';
        }),
      ], after: next);
    }),

    SceneDef('l_young_heir', 50, 84, (g) => 2, (g) => _near(g, .3), (g, next) {
      final name = g.rng.pick(kHeirNames);
      g.ask('幼い世継ぎ', '世継ぎの$nameは、まだ幼い。自分が死ねば、従う大名たちが幼い主を盛り立てるとは限らない。', [
        Choice.h('有力な大名たちに誓紙を書かせる', '形は整う。誓いが守られるかは別だ', () {
          g.meet('幼い世継ぎ', name, 80);
          g.l.net += 3;
          g.setFlag('oath_council');
          g.mark('諸大名に、幼い$nameへの忠誠を誓わせた');
          return '血判の押された誓紙が、何枚も積み上がった。';
        }),
        Choice.h('危うい者を今のうちに除く', '世継ぎの道は開ける。恨みが残る', () {
          g.meet('幼い世継ぎ', name, 70);
          _cut(g, .9);
          g.l.fame = g.l.fame >= 5 ? g.l.fame - 5 : 0;
          g.setFlag('purge_for_heir');
          if (g.rng.chance(.05)) {
            g.die('世継ぎのための粛清に追い詰められた者に、討たれた', 'ansatsu');
            return '除こうとした者が、先に動いた。';
          }
          return '幾人かの大名が、改易され、あるいは腹を切った。';
        }),
        Choice.h('力ある者に後を託す', '天下は保たれる。家は脇に退く', () {
          g.meet('幼い世継ぎ', name, 60);
          g.l.net += 5;
          g.j(-5);
          g.setFlag('tenka_to_other');
          return '最も力のある者を枕元に呼び、天下を頼むと頭を下げた。';
        }),
      ], after: next);
    }),

    SceneDef('l_suspicion', 55, 84, (g) => 2, (g) => _near(g, .3), (g, next) {
      g.ask('猜疑', '夜ごと、誰かに寝首をかかれる夢を見る。重臣の誰が裏切っても、おかしくないと思えてくる。', [
        Choice.h('疑わしい者を罰する', '不安は消える。忠臣も消える', () {
          _cut(g, .9);
          g.j(-5);
          g.setFlag('paranoid');
          if (g.rng.chance(.08)) {
            g.die('追い詰められた重臣に討たれた', 'ansatsu');
            return '罰せられると悟った重臣が、先に刃を向けた。';
          }
          g.mark('老いて猜疑に駆られ、重臣を罰した');
          return '評定の席が、一つ、また一つと空いていった。';
        }),
        Choice.h('己の心の弱さを恥じる', '家臣は安らぐ。夢は続く', () {
          g.j(3);
          g.l.chi = clampInt(g.l.chi + 1, 0, 99);
          return '夜明けに起きて、写経をするようになった。';
        }),
        Choice.h('目付を置いて家中を見張らせる（銭20貫）', '目は行き届く。家中は息を潜める', () {
          if (!_pay(g, 20)) return '目付を置く銭も惜しかった。';
          g.setFlag('metsuke');
          g.l.net = g.l.net >= 2 ? g.l.net - 2 : 0;
          return '誰が誰と会ったか、毎晩知らせが届くようになった。';
        }),
      ], after: next);
    }),

    SceneDef('l_summit', 30, 84, (g) => 2, (g) => _near(g, .35), (g, next) {
      final l = g.l;
      final p = l.people['幼なじみ'];
      g.ask('頂の孤独', '天下まで、あと一歩のところに来た。共に戦った者たちの多くは、もうこの世にいない。', [
        Choice.h('戦友たちの墓に参る', '心が少し軽くなる', () {
          g.j(5);
          g.setFlag('visited_graves');
          g.mark('天下を前に、戦友たちの墓に参った');
          return '一つ一つの墓に、酒を注いで回った。';
        }),
        Choice.h(p == null ? '昔の知り人を呼び寄せる' : '${p.name}を呼び寄せる', '昔の自分に会える', () {
          g.j(8);
          l.net += 2;
          if (p != null) {
            p.bond = clampInt(p.bond + 15, 0, 100);
            return '${p.name}は、昔と同じ呼び方であなたを呼んだ。';
          }
          return '若い頃の話をしているあいだだけ、天下のことを忘れた。';
        }),
        Choice.h('振り返らず、前だけを見る', '歩みは速まる。心は凍る', () {
          _grow(g, 2);
          g.j(-5);
          g.setFlag('no_looking_back');
          return '振り返れば足が止まる。そう言い聞かせた。';
        }),
      ], after: next);
    }),
  ];
}
