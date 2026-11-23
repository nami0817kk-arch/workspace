import 'childhood.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 泰平の世の岐路（2026-11-24、ユーザー「キャラが死ぬまでは続けたい」）。id・旗は `pc_`。
///
/// 人生は一六〇一年を越えても、亡くなるまで（または天下統一まで）続く。関ヶ原のあとの世に、
/// 戦国を生きた人がどう身を置くかの岐路を置く。どれも**一六〇一年からだけ**出る（[kPeaceFrom]）。
///
/// - 徳川の世（史実どおりの世）を前提にした岐路は [kPeaceEdoScenes]。歴史が変わった世では出ない
///   （`history_lines.dart` の `kSkipScenes` に入れてある）。江戸の町を前提にしたもの（[kPeaceEdoTownScenes]）は、
///   小田原で北条が残った世（家康が江戸に入らない）でも出ない。
/// - 年の決まった岐路（幕府が開かれた年の高札・大坂の陣・一国一城令・禁教・島原・寛永の飢饉）は [kPeaceHistoryScenes]。
///   史実の岐路と同じく、その年に条件が合えば必ず出る（`isHistoryScene`）。
/// - 前の段の旗で筋が分かれる: 関ヶ原の東西（歩んだ道の文）・牢人（`l.ronin`）・キリシタン（`kirishitan`）・
///   仕える家（豊臣＝内部の名は織田／徳川＝松平）・初陣（`first_battle`）と、この中の旗
///   （大坂に入った `pc_osaka_in` → 夏の陣、隠れて守る `pc_kakure` → 絵踏み → 祈りを伝える、
///   朱印の船 `pc_shuin` → 海の禁、御殿に上がる `pc_ooku` → 奥の掟）。筋の表は [kPeaceRoots]。
/// - 泰平の世（[peaceTime]）には、家どうしの合戦の岐路（[kWarSceneIds] と `bt_`）は出ず、
///   「戦に備える」は「武芸を錬り、務めに備える」に替わる（`adult.dart`）。

/// 泰平の岐路が出はじめる年。
const kPeaceFrom = 1601;

/// 世界線ごとの、戦の絶える年（この年から [peaceTime]）。今川の世は乱世が続くので無い。
const kPeaceStart = {'real': 1601, 'nobunaga': 1601, 'west': 1602, 'akechi': 1605};

/// 家どうしの戦が絶えた世か（大名どうしの合戦・小競り合いが起きない）。
bool peaceTime(Game g) {
  final y = kPeaceStart[worldLine(g)];
  return y != null && g.year >= y;
}

/// 泰平の世には出さない、戦の岐路（出陣・初陣・陣中・乱取り・籠城・国境の小競り合い ほか）。
const kWarSceneIds = {
  'battle',
  'first_battle',
  'last_battle',
  'siege',
  'a_randori',
  'al_ekiri',
  'al_teppo',
  'al_kubi',
  'bd_os_foes',
  'cl_karita',
  'cl_rojo_bi',
  'dm_engun',
  'dm_choryaku',
  'e2_book_war',
  'e3_wrote_book',
  'e4_river',
  'fa_uijin',
  'l_border',
  'l_lure',
  'sh_o_jingari',
  'tal_low_jinpu',
  'tf_f_randori',
  'tf_f_jinpu',
  'tm_kubi',
};

bool sceneSkippedInPeace(Game g, String id) =>
    (kWarSceneIds.contains(id) || id.startsWith('bt_')) && peaceTime(g);

/// 年の決まった泰平の岐路（その年に条件が合えば必ず出る）。
const kPeaceHistoryScenes = {
  'pc_kaifu',
  'pc_osaka_ronin',
  'pc_osaka_jin',
  'pc_osaka_toyotomi',
  'pc_osaka_natsu',
  'pc_ikkoku',
  'pc_kinkyo',
  'pc_shimabara',
  'pc_kikin',
};

/// 徳川の世を前提にした泰平の岐路（歴史が変わった世では出ない）。
const kPeaceEdoScenes = {
  'pc_kaifu',
  'pc_meshihanachi',
  'pc_osaka_ronin',
  'pc_osaka_jin',
  'pc_osaka_toyotomi',
  'pc_osaka_natsu',
  'pc_ikkoku',
  'pc_junshi',
  'pc_sankin',
  'pc_shimabara',
  'pc_kinkyo',
  'pc_fumie',
  'pc_kakure_inori',
  'pc_edo_shop',
  'pc_shuin',
  'pc_kaikin',
  'pc_gonin',
  'pc_terauke',
  'pc_shinobi_end',
  'pc_sekisho',
  'pc_edo_yashiki',
  'pc_ooku',
  'pc_ooku_okite',
  'pc_jiin',
  'pc_fushin',
};

/// 江戸の町・江戸の屋敷を前提にした岐路（小田原で北条が残った世でも出ない）。
const kPeaceEdoTownScenes = {
  'pc_sankin',
  'pc_edo_shop',
  'pc_edo_yashiki',
  'pc_ooku',
  'pc_ooku_okite',
  'pc_fushin',
};

/// どの世でも、戦が絶えれば出る泰平の岐路。
const kPeaceAnyLineScenes = {
  'pc_ronin_life',
  'pc_young_gap',
  'pc_oboegaki',
  'pc_bugei',
  'pc_daimyo_kashi',
  'pc_shinden',
  'pc_kikin',
  'pc_hatago',
};

/// 泰平の岐路の id（テストが使う）。
const kPeaceSceneIds = {...kPeaceEdoScenes, ...kPeaceAnyLineScenes};

/// 筋: 前の段の旗がなければ出ない岐路（id → 要る旗）。
const kPeaceRoots = {
  'pc_osaka_natsu': 'pc_osaka_in',
  'pc_fumie': 'pc_kakure',
  'pc_kakure_inori': 'pc_kakure',
  'pc_kinkyo': 'kirishitan',
  'pc_kaikin': 'pc_shuin',
  'pc_ooku_okite': 'pc_ooku',
};

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
bool _p(Game g, String s) => g.l.path.any((e) => e.contains(s));

/// 一六〇一年からの、戦の絶えた世（どの世界線でも）。
bool _peace(Game g) => g.year >= kPeaceFrom && peaceTime(g);

/// 一六〇一年からの、徳川の世。
bool _edo(Game g) => g.year >= kPeaceFrom && worldLine(g) == 'real';
bool _yr(Game g, int a, int b) => g.year >= a && g.year <= b;

bool _lordAlive(Game g) => g.l.lord != null && (g.fa[g.l.lord]?.alive ?? false);
bool _monk(Game g) => g.hasFlag('priesthood');

/// 主家に仕える、戦える男の侍（位1〜7。隠居でない）。
bool _samurai(Game g) =>
    !g.l.female &&
    g.l.rank >= 1 &&
    g.l.rank <= 7 &&
    _lordAlive(g) &&
    g.canFight &&
    g.active &&
    !_monk(g);

/// 身分のない牢人（男）。
bool _ronin(Game g) =>
    !g.l.female &&
    g.l.rank == 0 &&
    g.l.ronin &&
    !_monk(g) &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('way_outlaw') &&
    !g.hasFlag('retired');

bool _merchant(Game g) =>
    g.l.rank == 0 && g.hasFlag('way_merchant') && !_monk(g);
bool _outlaw(Game g) => g.l.rank == 0 && g.hasFlag('way_outlaw') && !_monk(g);
bool _ninja(Game g) =>
    g.l.rank == 0 &&
    !_monk(g) &&
    !g.hasFlag('way_merchant') &&
    (g.l.cls.id == 'ninja' || g.hasFlag('nukenin'));

/// 村の百姓・浜の者（身分なし。商い・野・仏門でない）。
bool _villager(Game g) =>
    g.l.rank == 0 &&
    (g.l.cls.id == 'farmer' || g.l.cls.id == 'fisher') &&
    !g.l.ronin &&
    !_monk(g) &&
    !g.hasFlag('way_merchant') &&
    !g.hasFlag('way_outlaw');

/// 町や村に暮らす、身分のない人（牢人・野の道・仏門を除く）。
bool _commoner(Game g) =>
    g.l.rank == 0 && !g.l.ronin && !_monk(g) && !g.hasFlag('way_outlaw');

bool _west(Game g) => _p(g, '関ヶ原で西軍に加わり');
bool _east(Game g) => _p(g, '関ヶ原で東軍に加わった');
bool _toyotomi(Game g) => g.l.lord == '織田';

double _w(Game g) => 40;

List<SceneDef> buildPeaceScenes() => [
  // =====================================================================
  // 誰にでも: 新しい世の始まり
  // =====================================================================
  SceneDef(
    'pc_kaifu',
    15,
    84,
    (g) => 30,
    (g) => _edo(g) && g.year == 1603,
    (g, next) {
      final l = g.l;
      final String who;
      if (_monk(g)) {
        who = '寺の門前にも、同じ高札が立った。弔う者の絶えなかった歳月が、終わるのかもしれない。';
      } else if (_ronin(g) || _west(g)) {
        who = '関ヶ原で敗れた側の者には、苦い知らせだ。槍一筋で身を立てる道は、いよいよ細くなる。';
      } else if (l.rank >= 8) {
        who = 'これからは、国の境を刀で引き直すことはできない。将軍の顔色をうかがいながら、家を保つ世になる。';
      } else if (l.rank >= 1) {
        who = '家中では、これで戦は終わりだと言う者と、まだ大坂に豊臣がいると言う者とが、半々だ。';
      } else if (_merchant(g)) {
        who = '市では、もう荷を隠さずに運べるぞと、商人たちが早くも算盤をはじいている。';
      } else if (_outlaw(g)) {
        who = '街道の取り締まりは、これから厳しくなるだろう。乱れた世を頼りに生きてきた者には、息の詰まる話だ。';
      } else {
        who = '村の寄り合いでは、年寄りたちが首をかしげている。戦のない世など、誰も見たことがないのだ。';
      }
      g.ask(
        '新しい世',
        '辻に高札が立った。徳川家康が征夷大将軍に任じられ、幕府を開いたという。$who',
        [
          Choice.h('戦のない世を信じて、暮らしを立て直す', '備えを解けば、暮らしは楽になる。世がまた乱れれば、丸腰だ', () {
            g.j(5);
            l.gold += g.rng.range(2, 6);
            g.setFlag('pc_believed');
            g.mark('幕府が開かれた年、戦のない世を信じて暮らしを立て直した');
            return '隠していた蓄えを掘り出し、家の傷んだ所を直した。夜、物音で飛び起きることが、少しずつ減っていった。';
          }),
          Choice.h('まだ信じず、備えを解かない', '用心に越したことはない。張りつめた日々は、なお続く', () {
            g.j(-2);
            l.bu = _c(l.bu + 1);
            g.setFlag('pc_doubted');
            return '天下が定まったと聞くのは、これが初めてではない。逃げ道と隠し場所は、そのままにしておいた。';
          }),
          Choice.h('世の移りを、人に聞いて回る', '耳を澄ませば、新しい世での身の置き所が見えてくる', () {
            l.net = _c(l.net + 4);
            l.chi = _c(l.chi + 1);
            g.setFlag('pc_listened');
            return '旅の者や出入りの商人から、将軍の膝元に生まれた新しい町の話を幾度も聞いた。世の重心が、東へ移りつつあった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // 侍
  // =====================================================================

  // ---- 召し放ち（主家の減封） ----
  SceneDef(
    'pc_meshihanachi',
    18,
    70,
    _w,
    (g) =>
        _edo(g) &&
        _yr(g, 1601, 1640) &&
        _samurai(g) &&
        g.l.rank <= 5 &&
        g.l.lord != '松平',
    (g, next) {
      final l = g.l;
      final house = houseName(g, l.lord);
      g.ask(
        '召し放ち',
        '$house家が、幕府から領地を削られた。家中の禄は軒並み減らされ、暇を出される者も出るという。'
            '${_west(g) ? '関ヶ原で西についた者の名は、真っ先に書き出されているらしい。' : ''}',
        [
          Choice.h('禄を減らされても家に残る', '暮らしは苦しくなる。それでも主家は主家だ', () {
            _pay(g, 10 + l.rank * 4);
            l.fav = _c100(l.fav + 10);
            g.j(-4);
            g.setFlag('pc_stayed_poor');
            g.mark('禄を減らされても、$house家に残った');
            return '屋敷を引き払い、長屋に移った。それでも、朝の登城は欠かさなかった。';
          }),
          Choice.h('暇を乞い、牢人となる', '新しい仕官の口は、もう多くはない', () {
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.fav = 0;
            l.ronin = true;
            g.j(-8);
            g.setFlag('pc_ronin');
            g.mark('主家の減封で暇を乞い、牢人となった');
            return '刀と具足を背に、城下を出た。戦のない世に、槍一筋の男の行く先は少ない。';
          }),
          Choice.h('刀を置き、村に土着する', '侍の身分は捨てる。田は裏切らない', () {
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.fav = 0;
            l.gold += 8;
            g.j(2);
            g.setFlag('pc_dochaku');
            g.mark('刀を置き、村に土着した');
            return '知行地だった村に、百姓として住み着いた。村の者は、まだ「旦那さま」と呼ぶ。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 牢人暮らし ----
  SceneDef(
    'pc_ronin_life',
    18,
    75,
    _w,
    (g) => _peace(g) && _ronin(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '牢人暮らし',
        '仕官の口は、どこにもない。どの家も人を減らしている。'
            '${_west(g) ? '関ヶ原で敗れた側の名は、門前で告げただけで首を振られる。' : ''}'
            '裏長屋の家賃の払いが、また迫ってきた。',
        [
          Choice.h('傘を張り、内職で食いつなぐ', '侍の手には馴染まぬ仕事だが、飢えはしない', () {
            l.gold += g.rng.range(4, 8);
            g.j(-3);
            g.setFlag('pc_ronin_naishoku');
            g.mark('牢人として、傘張りで食いつないだ');
            return '指先が糊で固くなった。刀の柄を握る日は、少しずつ減っていった。';
          }),
          Choice.h('町の子らに読み書きを教える', '知恵があれば、師匠と呼ばれて暮らせる', () {
            if (l.chi >= 45) {
              l.gold += g.rng.range(5, 10);
              l.net = _c(l.net + 6);
              g.j(4);
              g.setFlag('pc_ronin_tenarai');
              g.mark('牢人として、町の子らに読み書きを教えた');
              return '長屋の一間に、子どもたちの声が満ちた。「お師匠さま」と呼ばれるのは、悪くなかった。';
            }
            g.j(-2);
            return '教えるほどの学はなかった。三月で、子どもは一人も来なくなった。';
          }),
          Choice.h('腕を頼りに、用心棒の口を探す', '銭にはなる。刃傷沙汰に巻き込まれることもある', () {
            if (g.rng.chance(.04)) {
              g.die('牢人の身で用心棒に雇われ、喧嘩の刃に倒れた', 'ansatsu');
              return '賭場の揉め事で、後ろから斬られた。';
            }
            l.gold += g.rng.range(8, 16);
            l.bu = _c(l.bu + 1);
            g.setFlag('pc_ronin_yojinbo');
            g.mark('牢人として、商家の用心棒を務めた');
            return '大店の蔵の前に、夜ごと座った。戦場の夜に比べれば、静かなものだった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 大坂の陣（牢人） ----
  SceneDef(
    'pc_osaka_ronin',
    18,
    80,
    (g) => 30,
    (g) => _edo(g) && g.year == 1614 && _ronin(g) && g.canFight,
    (g, next) {
      final l = g.l;
      final west = _west(g);
      g.ask(
        '大坂へ',
        '大坂の城が、牢人を集めている。金銀を惜しまず、名のある者には一手の将を任せるという。'
            '${west ? '関ヶ原で敗れてからの歳月が、胸の底で動いた。あの日の借りを返す時が、来たのかもしれない。' : '一方で、城を囲む徳川の陣でも、腕の立つ者を陣借りさせているらしい。'}',
        [
          Choice.h('大坂城へ馳せ参じる', '最後の戦場だ。勝ち目は薄いが、槍の置き場所はここしかない', () {
            if (g.rng.chance(.06)) {
              g.die('大坂冬の陣で、豊臣方の牢人として討死した', 'senshi');
              return '出丸の柵際で、鉄砲の玉に倒れた。';
            }
            l.gold += 20;
            l.merit += 10;
            l.fame += 6;
            g.j(8);
            g.setFlag('pc_osaka_in');
            g.mark('牢人として、大坂城に馳せ参じた');
            return '支度の金を受け取り、久しぶりに具足を着けた。冬の戦は和議で終わったが、堀は埋められた。城に残る者と去る者が、分かれ始めた。';
          }),
          Choice.h('徳川の陣に、陣借りを願い出る', '勝つ側につく。手柄があれば、仕官の道が開くかもしれない', () {
            l.merit += 6;
            g.setFlag('pc_osaka_east');
            if ((g.fa['松平']?.alive ?? false) && g.rng.chance(.3)) {
              l.rank = 1;
              l.maxRank = l.maxRank > 1 ? l.maxRank : 1;
              l.lord = '松平';
              l.fav = 25;
              l.ronin = false;
              g.mark('大坂の陣で徳川方に陣借りし、召し抱えられた');
              return '城を囲む陣の端で、働きが目に留まった。長い牢人暮らしが、終わった。';
            }
            g.mark('大坂の陣で、徳川方に陣借りした');
            return '城を囲む陣の端で冬を越した。和議が成り、陣は解かれた。召し抱えの声は、掛からなかった。';
          }),
          Choice.h('どちらにも行かない', '戦はもう懲りた。長屋で冬を越す', () {
            g.j(-2);
            g.setFlag('pc_osaka_stayed');
            return '西へ急ぐ牢人たちを、戸口から見送った。隣の部屋は、その日から空いたままになった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 大坂夏の陣（城に入った牢人） ----
  SceneDef(
    'pc_osaka_natsu',
    18,
    81,
    (g) => 30,
    (g) => _edo(g) && g.year == 1615 && g.hasFlag('pc_osaka_in') && _ronin(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '夏の陣',
        '和議は破れた。堀を失った大坂城に、徳川の大軍がふたたび迫っている。'
            '城を出る者は、もう誰も止めない。残る者は、城の外で戦うしかない。',
        [
          Choice.h('城に残り、野に打って出る', '生きて帰れる戦ではない。それでも、ここが死に場所だ', () {
            if (g.rng.chance(.55)) {
              g.die('大坂夏の陣で、豊臣方の牢人として討死した', 'senshi');
              return '天王寺の野で、押し寄せる軍勢のなかに斬り込んだ。';
            }
            l.fame += 15;
            l.hp -= g.rng.range(15, 30);
            g.setFlag('pc_osaka_survivor');
            g.mark('大坂夏の陣を戦い、落ち延びた');
            if (l.hp <= 0) {
              g.die('大坂夏の陣の傷がもとで死んだ', 'senshi');
              return '燃える城を背に落ち延びたが、傷は深かった。';
            }
            return '燃える天守を背に、川筋を落ち延びた。落人狩りの目を逃れ、名を変えて生きることになった。';
          }),
          Choice.h('夜のうちに城を抜ける', '命は拾える。「逃げた」という声は、一生ついて回る', () {
            l.fame -= 5;
            g.j(-6);
            g.setFlag('pc_osaka_left');
            g.mark('夏の陣の前に、大坂城を抜けた');
            return '堀の跡を越えて、闇のなかを歩いた。数日ののち、城の方角の空が赤く染まるのを見た。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 大坂の陣（徳川方の家臣） ----
  SceneDef(
    'pc_osaka_jin',
    16,
    80,
    (g) => 30,
    (g) => _edo(g) && g.year == 1614 && _samurai(g) && !_toyotomi(g),
    (g, next) {
      final l = g.l;
      final house = houseName(g, l.lord);
      g.ask(
        '大坂の陣',
        '大坂攻めの陣触れが、$house家にも届いた。${g.age >= 50 ? '関ヶ原からもう長い。具足の紐は、すっかり硬くなっている。' : '家中の若い者は、初めての戦に浮き足立っている。'}'
            '${_west(g) ? 'かつて西についた身には、ここで働きを見せるほかに、疑いを晴らす道はない。' : ''}',
        [
          Choice.h('先手を願い出る', '最後の戦で名を上げる。城方の牢人は、死に物狂いだ', () {
            if (g.rng.chance(.08)) {
              g.die('大坂の陣で、徳川方として討死した', 'senshi');
              return '出丸に取りついたところを、鉄砲で撃ちすくめられた。';
            }
            l.merit += 22;
            l.fame += 8;
            l.fav = _c100(l.fav + 8);
            g.setFlag('pc_osaka_sakite');
            g.mark('大坂の陣で、$house家の先手を務めた');
            return '城方の鉄砲に幾人も倒れたが、持ち場は崩さなかった。これが、生涯で最後の戦になった。';
          }),
          Choice.h('持ち場を守り、陣を固める', '大きな手柄はない。大きな怪我もない', () {
            l.merit += 8;
            l.fav = _c100(l.fav + 3);
            g.mark('大坂の陣に、$house家の兵として加わった');
            return '城を遠巻きにして冬を越し、次の夏に天守の燃える煙を見た。戦の世の終わりを、陣中で知った。';
          }),
          Choice.h('病と称して国元に残る', '命は惜しい。家中の目は冷たくなる', () {
            l.fav = _c100(l.fav - 12);
            l.fame -= 4;
            g.setFlag('pc_osaka_absent');
            return '留守の城で、勝ち戦の知らせを聞いた。戻ってきた者たちの土産話に、加わる席はなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 大坂の陣（豊臣の家臣） ----
  SceneDef(
    'pc_osaka_toyotomi',
    16,
    80,
    (g) => 30,
    (g) => _edo(g) && g.year == 1614 && _samurai(g) && _toyotomi(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '大坂城の評定',
        '徳川と手切れになった。大坂の城には牢人があふれ、古くからの家臣の声は、日ごとに小さくなっていく。'
            '城に残るか、去るか。決めるなら、堀の水があるうちだ。',
        [
          Choice.h('豊臣の家臣として、城に籠もる', '主家と運命をともにする。城が落ちれば、命はない', () {
            if (g.rng.chance(.35)) {
              g.die('大坂の陣で、豊臣の家臣として討死した', 'senshi');
              return '城門の内で、最後まで槍を振るった。';
            }
            l.fame += 12;
            l.fav = _c100(l.fav + 15);
            g.setFlag('pc_osaka_loyal');
            g.mark('豊臣の家臣として、大坂城に籠もった');
            return '冬の戦を生き延びた。だが堀は埋められ、城は裸になった。次の夏が、最後になるだろう。';
          }),
          Choice.h('城を出て、徳川に降る', '家は残せる。「太閤の恩を忘れた」と言われ続ける', () {
            l.lord = '松平';
            l.rank = l.rank - 1 < 1 ? 1 : l.rank - 1;
            l.fav = 15;
            l.troops = (l.troops * .5).floor();
            l.fame -= 8;
            g.j(-8);
            g.setFlag('pc_osaka_turned');
            g.mark('大坂城を出て、徳川に降った');
            return '夜明け前、わずかな供と城門を出た。振り返ると、天守の金の鯱が、朝日に光っていた。';
          }),
          Choice.h('刀を置き、町人にまぎれる', '侍をやめる。戦にも、どちらの家にも関わらない', () {
            l.rank = 0;
            l.lord = null;
            l.troops = 0;
            l.fav = 0;
            g.setFlag('pc_osaka_townsman');
            g.mark('大坂の陣を前に、刀を置いた');
            return '髷を結い直し、船場の裏店に身を隠した。城から聞こえる鬨の声を、布団をかぶって聞いた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 一国一城令 ----
  SceneDef(
    'pc_ikkoku',
    20,
    84,
    (g) => 30,
    (g) =>
        _edo(g) &&
        g.year == 1615 &&
        !g.l.female &&
        g.l.rank >= 5 &&
        g.l.rank <= 8 &&
        _lordAlive(g) &&
        g.active,
    (g, next) {
      final l = g.l;
      final lord = l.rank >= 8;
      g.ask(
        '城を壊せ',
        lord
            ? '幕府から触れが届いた。一つの国に、城は一つ。本城のほかは、すべて壊せという。先祖が築き、家臣たちが命がけで守ってきた支城の名が、書付に並んでいる。'
            : '一つの国に、城は一つ。幕府の触れを受けて、殿から命が下った。あなたの預かる城を、壊せという。石垣を積んだ日のことも、籠城の夜のことも、まだ覚えている。',
        [
          Choice.h('すぐに壊しにかかる', '疑いは招かない。城とともに、一つの時代が終わる', () {
            l.fav = _c100(l.fav + 8);
            g.j(-6);
            g.setFlag('pc_ikkoku_obeyed');
            g.mark(lord ? '一国一城の触れに従い、支城を壊した' : '一国一城の触れに従い、預かった城を壊した');
            return '櫓が引き倒され、堀が埋められていった。人足たちの掛け声を、最後まで立って聞いた。';
          }),
          Choice.h('櫓だけ壊し、石垣は残す', '形だけ従う。目付に見とがめられれば、ただでは済まない', () {
            if (g.rng.chance(.15)) {
              l.fav = _c100(l.fav - 20);
              l.fame -= 6;
              _pay(g, 30);
              g.setFlag('pc_ikkoku_caught');
              g.mark('城の石垣を残したのを咎められた');
              return '見回りの目付が、残した石垣を書き留めていった。詫びの使者と、多くの銭が要った。';
            }
            g.j(3);
            g.setFlag('pc_kept_wall');
            g.mark('一国一城の触れのあとも、城の石垣を残した');
            return '草に埋もれた石垣は、誰の目にも留まらなかった。いつかまた要る日が来る、と思った。その日は、来なかった。';
          }),
          Choice.h('最後の一夜を、櫓で明かしてから壊す', '命には従う。別れだけは、自分の流儀で告げる', () {
            g.j(2);
            l.net = _c(l.net + 3);
            g.setFlag('pc_ikkoku_farewell');
            g.mark('壊す城の櫓で、最後の一夜を明かした');
            return '古くからの家臣たちと、櫓で酒を酌んだ。夜が明けると、自ら最初の槌を入れた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 戦を知らない若い世代 ----
  SceneDef(
    'pc_young_gap',
    45,
    84,
    _w,
    (g) =>
        _peace(g) &&
        g.year >= 1616 &&
        !g.l.female &&
        g.hasFlag('first_battle') &&
        !_monk(g) &&
        (g.l.rank >= 1 || g.l.maxRank >= 2),
    (g, next) {
      final l = g.l;
      g.ask(
        '戦を知らぬ者たち',
        '家中の若い者が、槍の稽古を怠けて書物と算盤ばかりいじっている。'
            '「戦など、もう起きませぬ。これからは勘定の世です」。その顔には、傷ひとつない。',
        [
          Choice.h('戦場の作法を、厳しく叩き込む', '煙たがられる。それでも、伝えねばならぬことがある', () {
            l.net = _c(l.net - 4);
            l.fame += 3;
            g.setFlag('pc_young_strict');
            g.mark('戦を知らぬ若い者に、戦場の作法を叩き込んだ');
            return '「古い」と陰で言われているのは知っていた。それでも、首の守り方だけは覚えさせた。';
          }),
          Choice.h('黙って、算盤を習いに行く', '時代は変わった。老いた身が、頭を下げて学ぶ', () {
            l.sei = _c(l.sei + 3);
            l.net = _c(l.net + 5);
            g.j(2);
            g.setFlag('pc_young_learned');
            g.mark('若い者に頭を下げ、算盤を習った');
            return '太い指で珠をはじいた。若い者は驚き、やがて、戦の話を聞きたがるようになった。';
          }),
          Choice.h('好きにさせておく', '戦がないのは、良いことだ。それを知らぬのも', () {
            g.j(1);
            return '縁側から、稽古場の静けさを眺めた。あの静けさのために、戦ってきたのだった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 覚書（昔語りを書き留める） ----
  SceneDef(
    'pc_oboegaki',
    55,
    84,
    _w,
    (g) =>
        _peace(g) &&
        g.year >= 1620 &&
        !g.l.female &&
        g.hasFlag('first_battle') &&
        !_monk(g) &&
        _lordAlive(g) &&
        g.l.rank >= 1 &&
        g.l.rank <= 7,
    (g, next) {
      final l = g.l;
      final west = _west(g);
      final east = _east(g);
      g.ask(
        '覚書',
        '若い殿が、家の戦の記録を残したいという。戦場を知る者は、もう数えるほどしかいない。書役が筆を構えて、あなたの前に座った。'
            '${west ? '関ヶ原でどちらにいたかを、ここで語るかどうか。' : (east ? '関ヶ原の朝の霧から、語ることになる。' : '')}',
        [
          Choice.h(
            'ありのままに語る',
            west ? '負けた側の話も、包まず話す。家中の目が変わるかもしれない' : '手柄も、しくじりも、逃げた日のことも',
            () {
              if (west && g.rng.chance(.3)) {
                l.fav = _c100(l.fav - 8);
                g.setFlag('pc_oboe_true');
                g.mark('覚書に、西軍にいた日のことをありのままに語った');
                return '書役の筆が、一度止まった。その段は、あとで墨で消されたと聞いた。';
              }
              l.fame += 6;
              g.j(3);
              g.setFlag('pc_oboe_true');
              g.mark('家の覚書に、戦の日々をありのままに語った');
              return '三日かけて語った。書役は、何度も筆を止めて聞き返した。紙の上に、あの日々が残った。';
            },
          ),
          Choice.h('手柄を大きく語る', '名は上がる。同じ戦場にいた者が聞けば、笑うだろう', () {
            l.fame += 10;
            l.fav = _c100(l.fav + 4);
            g.setFlag('pc_oboe_boast');
            g.mark('家の覚書に、手柄を大きく語った');
            return '取った首は、語るたびに増えた。確かめられる者は、もうこの世にいなかった。';
          }),
          Choice.h('戦のむごさだけを語る', '手柄話を待つ殿は、顔を曇らせる', () {
            l.fav = _c100(l.fav - 3);
            g.j(4);
            g.setFlag('pc_oboe_grim');
            g.mark('家の覚書に、戦のむごさを語り残した');
            return '焼けた村と、飢えた城の話をした。書役は黙って、最後まで書き取った。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 殉死 ----
  SceneDef(
    'pc_junshi',
    40,
    80,
    (g) => 12,
    (g) =>
        _edo(g) &&
        _yr(g, 1607, 1650) &&
        _samurai(g) &&
        g.l.rank >= 3 &&
        g.l.fav >= 60,
    (g, next) {
      final l = g.l;
      final house = houseName(g, l.lord);
      g.ask(
        '追腹',
        '長く仕えた$house家の殿が、世を去った。戦場で死に場所を得られなくなった世で、主の後を追って腹を切る者が、忠義の鑑と讃えられている。'
            '殿に目をかけられたあなたを、家中の者が黙って見ている。',
        [
          Choice.h('殿の後を追う', '忠義は語り継がれる。命は、ここまでになる', () {
            g.mark('亡き殿の後を追った');
            g.die('亡き主君の後を追い、追腹を切った', 'seppuku');
            return '菩提寺の庭に、白い布が敷かれた。';
          }),
          Choice.h('生きて、若殿に仕える', '務めはまだある。「追わなかった」と囁く者も出る', () {
            l.fame -= 4;
            l.fav = _c100(l.fav - 10);
            l.merit += 8;
            g.setFlag('pc_no_junshi');
            g.mark('亡き殿の後を追わず、若殿に仕え続けた');
            return '囁きは聞こえていた。だが幼い殿のそばには、戦を知る者が一人は要った。';
          }),
          Choice.h('家督を譲り、殿の菩提を弔って暮らす', '城を下がり、墓守として余生を送る', () {
            g.setFlag('retired');
            g.setFlag('pc_bodai');
            g.j(2);
            g.mark('城を下がり、亡き殿の菩提を弔って暮らした');
            return '菩提寺の門前に小さな家を借り、毎朝、墓の苔を払った。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 参勤交代の供 ----
  SceneDef(
    'pc_sankin',
    18,
    75,
    _w,
    (g) =>
        _edo(g) &&
        g.year >= 1635 &&
        _samurai(g) &&
        g.l.rank <= 6 &&
        g.l.lord != '松平',
    (g, next) {
      final l = g.l;
      final house = houseName(g, l.lord);
      g.ask(
        '参勤の供',
        '$house家の殿が、江戸へ上る年になった。行列の供揃えに、あなたの名も挙がっている。'
            '道中は長く、江戸の屋敷詰めは一年に及ぶ。国元の家は、そのあいだ留守になる。',
        [
          Choice.h('行列の供をして、江戸へ上る', '掛かりは嵩む。それでも、天下の町をこの目で見られる', () {
            _pay(g, 12);
            l.fav = _c100(l.fav + 8);
            l.net = _c(l.net + 5);
            l.chi = _c(l.chi + 1);
            g.j(4);
            g.setFlag('pc_edo_seen');
            g.mark('殿の参勤の供をして、江戸へ上った');
            return '槍を立てて街道を歩いた。戦の行軍と違い、宿場ごとに人が道の端にひざまずいた。江戸の町の大きさには、声も出なかった。';
          }),
          Choice.h('国元の留守を預かる', '地味な務めだ。家の者とは離れずに済む', () {
            l.merit += 5;
            l.fav = _c100(l.fav + 3);
            g.j(2);
            g.setFlag('pc_rusu');
            return '殿のいない城は静かだった。年貢の帳面と、堤の見回りで一年が過ぎた。';
          }),
          Choice.h('江戸の屋敷詰めを、長く願い出る', '殿のそばで覚えは得られる。国元の家族とは、年単位で会えなくなる', () {
            l.fav = _c100(l.fav + 14);
            l.merit += 10;
            g.j(-5);
            g.setFlag('pc_edozume');
            g.mark('江戸の屋敷詰めを長く務めた');
            return '江戸の屋敷の長屋に、国元からの文が年に幾度か届いた。子の字が、届くたびに上手くなっていた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 島原 ----
  SceneDef(
    'pc_shimabara',
    16,
    84,
    (g) => 30,
    (g) =>
        _edo(g) &&
        g.year == 1638 &&
        _samurai(g) &&
        const {'島津', '龍造寺', '大友', '毛利', '松平'}.contains(g.l.lord),
    (g, next) {
      final l = g.l;
      final house = houseName(g, l.lord);
      final kiri = g.hasFlag('kirishitan');
      g.ask(
        '原城',
        '島原の一揆を討てという命が、$house家にも下った。原の古城を、諸家の大軍が囲んでいる。'
            '家中のほとんどは、これが初めての戦だ。${kiri ? '城のなかから、かつて自分も口にした祈りの声が、風に乗って聞こえてくる。' : '城のなかから、聞き慣れない祈りの歌が聞こえてくる。'}',
        [
          Choice.h('総攻めの先頭に立つ', '久方ぶりの戦場で名を上げる。城方は、死を恐れていない', () {
            if (g.rng.chance(.1)) {
              g.die('島原の一揆攻めで討死した', 'senshi');
              return '石垣に取りついたところへ、上から石と熱湯が降ってきた。';
            }
            l.merit += 20;
            l.fame += 6;
            g.j(-6);
            g.setFlag('pc_hara_first');
            g.mark('島原の原城攻めで、先頭に立った');
            return '城は落ちた。手柄は帳面に記された。だが、斬った相手が鍬を握る手をしていたことは、誰にも話さなかった。';
          }),
          Choice.h('若い者を後ろで束ねる', '戦を知る者の務めだ。手柄は若い者に譲る', () {
            l.merit += 10;
            l.fav = _c100(l.fav + 6);
            l.net = _c(l.net + 4);
            g.setFlag('pc_hara_led');
            g.mark('島原の陣で、戦を知らぬ若い者を束ねた');
            return '震える若侍の兜の緒を、一人ずつ締め直してやった。全員を、生きて国へ連れ帰った。';
          }),
          Choice.h(
            kiri ? '矢文で、降るよう呼びかける' : '逃げてきた女や子を、見逃す',
            '情けは、軍法に触れる。見つかれば、咎めを受ける',
            () {
              if (g.rng.chance(.2)) {
                l.fav = _c100(l.fav - 15);
                l.fame -= 5;
                g.setFlag('pc_hara_mercy');
                g.mark('島原の陣で情けをかけ、咎めを受けた');
                return '目付に見とがめられた。「一揆に通じたか」と問い詰められ、謹慎を命じられた。';
              }
              g.j(4);
              g.setFlag('pc_hara_mercy');
              g.mark('島原の陣で、人知れず情けをかけた');
              return '夜の闇にまぎれて、幾人かが浜のほうへ消えていった。振り返らずに行け、とだけ言った。';
            },
          ),
        ],
        after: next,
      );
    },
  ),

  // ---- 武芸が見世物になる ----
  SceneDef(
    'pc_bugei',
    25,
    75,
    _w,
    (g) =>
        _peace(g) &&
        g.year >= 1616 &&
        !g.l.female &&
        g.l.bu >= 60 &&
        !_monk(g) &&
        g.l.rank <= 4 &&
        g.active,
    (g, next) {
      final l = g.l;
      g.ask(
        '見世物の槍',
        '盛り場の興行師が訪ねてきた。「旦那の腕前、戦場で腐らせるには惜しい。小屋で見せりゃあ、人が集まりますぜ」。'
            '人を突くために磨いた技に、木戸銭を払う世になった。',
        [
          Choice.h('小屋に出て、技を見せる', '銭にはなる。「武士の技を売った」と言う者もいる', () {
            l.gold += g.rng.range(15, 30);
            l.fame += 4;
            l.fav = _c100(l.fav - 5);
            g.setFlag('pc_misemono');
            g.mark('盛り場の小屋で、槍の技を見世物にした');
            return '藁束を突くたびに、見物から歓声が上がった。戦場では、誰も声など上げなかった。';
          }),
          Choice.h('道場を開き、型として教える', '人を殺す技を、身を修める道として残す', () {
            l.gold += g.rng.range(4, 10);
            l.net = _c(l.net + 6);
            g.j(3);
            g.setFlag('pc_dojo');
            if (!l.people.containsKey('弟子')) {
              g.meet('弟子', g.rng.pick(['新之丞', '源三郎', '伊織', '主水']), 45);
            }
            g.mark('道場を開き、戦場の技を型として教えた');
            return '町人の子まで、木刀を握りに来た。「戦で使う日は来ぬ」と言い聞かせて、教えた。';
          }),
          Choice.h('きっぱりと断る', '技は見せるものではない。暮らしは変わらない', () {
            g.j(1);
            return '興行師は肩をすくめて帰った。その夜、久しぶりに槍の手入れをした。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 手伝い普請 ----
  SceneDef(
    'pc_fushin',
    20,
    80,
    _w,
    (g) =>
        _edo(g) &&
        _yr(g, 1604, 1640) &&
        !g.l.female &&
        g.l.rank >= 5 &&
        g.l.rank <= 8 &&
        _lordAlive(g) &&
        g.active &&
        g.l.lord != '松平',
    (g, next) {
      final l = g.l;
      final lord = l.rank >= 8;
      final f = g.fa[l.lord]!;
      g.ask(
        '手伝い普請',
        lord
            ? '幕府から、江戸の城の石垣普請を手伝えという命が届いた。石も、人足も、船も、すべて家の持ち出しになる。戦の代わりに、普請で家の力を削ぐつもりらしい。'
            : '殿が幕府から命じられた江戸の城の石垣普請で、あなたが丁場を預かることになった。石を伊豆から船で運び、隣の丁場の家と出来を競わされる。',
        [
          Choice.h('銭も人も惜しまず出す', '幕府の覚えは良くなる。蔵は空になる', () {
            _pay(g, lord ? 80 : 25);
            if (lord) f.power = (f.power * .95).clamp(3, 140).toDouble();
            l.fav = _c100(l.fav + 10);
            l.fame += 6;
            g.setFlag('pc_fushin_loyal');
            g.mark('江戸の城の石垣普請に、惜しまず力を出した');
            return '積み上がった石垣の角に、家の刻印を打たせた。城が続くかぎり、その印は残る。';
          }),
          Choice.h('掛かりを切り詰めて務める', '蔵は守れる。出来が悪ければ、やり直しを命じられる', () {
            if (g.rng.chance(.3)) {
              _pay(g, lord ? 60 : 20);
              l.fame -= 5;
              g.setFlag('pc_fushin_redo');
              return '大雨のあと、積んだ石垣が孕んだ。積み直しを命じられ、結局は倍の掛かりになった。';
            }
            _pay(g, lord ? 40 : 12);
            g.setFlag('pc_fushin_thrift');
            g.mark('江戸の城の石垣普請を、切り詰めて務め上げた');
            return '隣の丁場ほど見栄えはしなかったが、検分は通った。';
          }),
          Choice.h('人足たちと寝起きをともにして働く', '身は削れる。現場の者は、ついてくる', () {
            _pay(g, lord ? 50 : 15);
            l.hp -= g.rng.range(4, 10);
            l.net = _c(l.net + 8);
            l.sei = _c(l.sei + 2);
            g.setFlag('pc_fushin_hands');
            g.mark('江戸の城の石垣普請で、人足とともに働いた');
            return '石を曳く掛け声に、自分の声も混ぜた。戦場で兵を率いたときと、同じ腹の据え方だった。';
          }),
          // 普請上手（特性。`trait_scenes2.dart`）は、石の組み方を自分で指図できる。
          if (g.has('builder'))
            Choice.h('石の組み方を、自ら図に引いて指図する', '無駄な石も人手も減らせる。出来の責めは、すべて自分に掛かる', () {
              _pay(g, lord ? 30 : 8);
              l.fav = _c100(l.fav + 8);
              l.fame += 8;
              l.sei = _c(l.sei + 2);
              g.setFlag('pc_fushin_built');
              g.mark('江戸の城の石垣を、自ら石組みを指図して積み上げた');
              return '角石の据え方から裏の栗石の厚みまで、自分で決めた。検分の役人は水準を当て、何も言わずに次の丁場へ行った。隣の丁場の家が、石工を借りに来た。';
            }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // キリシタン
  // =====================================================================

  // ---- 禁教 ----
  SceneDef(
    'pc_kinkyo',
    15,
    84,
    (g) => 30,
    (g) => _edo(g) && g.year == 1613 && g.hasFlag('kirishitan'),
    (g, next) {
      final l = g.l;
      g.ask(
        '禁教の触れ',
        'デウスの教えを棄てよという触れが、国じゅうに回った。南蛮寺は壊され、伴天連は追われている。'
            '役人が、信者の名を一人ずつ帳面に書き出している。',
        [
          Choice.h('教えを棄てると申し出る', '身は安んじる。胸の内は、誰にも見えない', () {
            g.j(-8);
            g.setFlag('pc_korobi');
            g.mark('禁教の触れに従い、教えを棄てた');
            return '役人の前で、棄てると言った。その夜、首から外したものを、どこにしまうか決められなかった。';
          }),
          Choice.h('棄てたふりをして、隠れて守る', '見つかれば、命はない。家の者にも、危うさが及ぶ', () {
            g.j(-3);
            g.setFlag('pc_kakure');
            g.mark('教えを棄てたふりをして、隠れて信仰を守った');
            return '仏壇の奥に、小さな像を隠した。祈りの言葉は、声に出さずに唱えるようになった。';
          }),
          Choice.h('信者であると名乗り出る', '教えには背かない。刑場か、国の外か', () {
            if (g.rng.chance(.4)) {
              g.die('教えを棄てず、信者として刑場に果てた', 'seppuku');
              return '縄を打たれて、刑場へ引かれた。最後まで、祈りの言葉を口にしていた。';
            }
            l.gold = (l.gold * .3).floor();
            l.net = _c(l.net - 10);
            g.j(4);
            g.setFlag('pc_confessor');
            g.setFlag('pc_kakure');
            g.mark('信者と名乗り出て、家も財も失った');
            return '家を取り上げられ、所払いになった。それでも、命までは取られなかった。流れ着いた先の浦で、同じ祈りを知る者たちに出会った。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 絵踏み ----
  SceneDef(
    'pc_fumie',
    15,
    84,
    _w,
    (g) => _edo(g) && g.year >= 1629 && g.hasFlag('pc_kakure'),
    (g, next) {
      final l = g.l;
      g.ask(
        '絵踏み',
        '役人が、聖なる御方の像を刻んだ板を、土の上に置いた。村の者が一人ずつ呼ばれ、その上を踏んでいく。'
            '踏めない者は、信者と見なされる。あなたの名が、呼ばれた。',
        [
          Choice.h('踏む', '命はつながる。足の裏の冷たさは、消えない', () {
            g.j(-8);
            g.setFlag('pc_fumi');
            g.mark('絵踏みで、御像を踏んだ');
            return '踏んだ。役人は、帳面に印を付けた。家に帰って、その足を長いこと洗った。';
          }),
          Choice.h('踏まない', '教えには背かない。その場で縄を打たれる', () {
            if (g.rng.chance(.6)) {
              g.die('絵踏みを拒み、信者として処刑された', 'seppuku');
              return '板の前で膝をつき、手を合わせた。役人が、縄を持って近づいてきた。';
            }
            l.gold = (l.gold * .5).floor();
            g.j(-4);
            g.setFlag('pc_fumi_refused');
            g.mark('絵踏みを拒み、牢に入れられた');
            return '牢に入れられ、棄てるまで責められた。村の者の嘆願で、命だけは助けられた。';
          }),
          Choice.h('病と称して、その日をやり過ごす', '知恵で逃れる。疑いの目は、次の年も向けられる', () {
            if (l.chi + l.mi >= 100 || g.rng.chance(.5)) {
              g.setFlag('pc_fumi_dodged');
              g.mark('絵踏みの日を、病と称してやり過ごした');
              return '名主が、うまく口添えをしてくれた。帳面には、踏んだ者として名が載った。';
            }
            g.j(-8);
            g.setFlag('pc_fumi');
            g.mark('絵踏みで、御像を踏んだ');
            return '役人は、床まで板を運ばせた。寝たまま、足を載せるほかなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 隠れた祈りを伝えるか ----
  SceneDef(
    'pc_kakure_inori',
    50,
    84,
    _w,
    (g) =>
        _edo(g) &&
        g.year >= 1639 &&
        g.hasFlag('pc_kakure') &&
        g.hasFlag('scene:pc_fumie'),
    (g, next) {
      final l = g.l;
      g.ask(
        '納戸の祈り',
        '南蛮の船は、もう来ない。伴天連も、一人残らずいなくなった。祈りの言葉を覚えているのは、この村では、あなたと幾人かの年寄りだけになった。'
            '${l.kids > 0 ? '子や孫に、伝えるかどうか。' : '村の若い者に、伝えるかどうか。'}伝えれば、その者たちも、同じ危うさを背負うことになる。',
        [
          Choice.h('祈りの言葉を、口伝えに教える', '教えは残る。見つかれば、一族が絶える', () {
            g.j(5);
            g.setFlag('pc_kakure_passed');
            g.mark('隠れた祈りを、次の代に口伝えで残した');
            return '納戸の闇のなかで、ひと言ずつ教えた。意味の分からない異国の言葉を、幼い声が繰り返した。';
          }),
          Choice.h('自分の代で終わらせる', '子らは、安んじて暮らせる。祈りは、ともに土に還る', () {
            g.j(-3);
            g.setFlag('pc_kakure_ended');
            g.mark('隠れた祈りを、自分の代で終わらせると決めた');
            return '像を布に包み、裏山の椿の根元に埋めた。場所は、誰にも告げなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // 商人
  // =====================================================================

  // ---- 江戸に店を出す ----
  SceneDef(
    'pc_edo_shop',
    18,
    70,
    _w,
    (g) => _edo(g) && _yr(g, 1603, 1645) && _merchant(g) && g.l.gold >= 30,
    (g, next) {
      final l = g.l;
      g.ask(
        '新しい町',
        '江戸という東の町が、とてつもない速さで大きくなっているという。諸国の大名が屋敷を構え、普請の人足があふれ、物はいくらあっても足りない。'
            '上方の商人たちが、次々と出店を出し始めた。',
        [
          Choice.h('江戸に出店を出す', '当たれば大きい。遠い店は、目が届かない', () {
            _pay(g, 25);
            if (g.rng.chance(.65) || l.sei >= 60) {
              l.gold += g.rng.range(40, 80);
              l.fame += 5;
              g.setFlag('pc_edo_shop');
              g.mark('江戸に出店を出し、当てた');
              return '日本橋の近くに間口の狭い店を借りた。品は、着くそばから売れていった。';
            }
            g.j(-5);
            g.setFlag('pc_edo_shop_failed');
            g.mark('江戸に出店を出したが、うまくいかなかった');
            return '任せた手代が、売り上げを持って消えた。江戸は、人も銭も呑み込む町だった。';
          }),
          Choice.h('大坂の蔵屋敷に出入りを願う', '大名の米を扱う。堅い商いだが、掛け売りが溜まる', () {
            l.gold += g.rng.range(15, 30);
            l.net = _c(l.net + 6);
            g.setFlag('pc_osaka_kura');
            g.mark('大坂の蔵屋敷に出入りする商人となった');
            return '諸国の米が川舟で運び込まれ、蔵の前に山と積まれた。米の値を読む目が、何よりの元手になった。';
          }),
          Choice.h('いまの町で、手堅く続ける', '大儲けはない。顔の見える客がいる', () {
            l.gold += g.rng.range(4, 8);
            g.j(2);
            return '店先に水を打ち、いつもの客を待った。流行りに乗らないのも、商いの一つだ。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 朱印の船 ----
  SceneDef(
    'pc_shuin',
    20,
    70,
    _w,
    (g) => _edo(g) && _yr(g, 1604, 1632) && _merchant(g) && g.l.gold >= 50,
    (g, next) {
      final l = g.l;
      g.ask(
        '朱印の船',
        '幕府の朱印状を受けた船が、長崎から安南や暹羅へ出るという。銀を積んで行き、生糸や鹿皮、砂糖を積んで帰る。'
            '船主が、荷に銀を出す者を募っている。',
        [
          Choice.h('まとまった銀を出す', '無事に戻れば、幾倍にもなる。海は、船ごと呑むこともある', () {
            _pay(g, 40);
            g.setFlag('pc_shuin');
            if (g.rng.chance(.7)) {
              l.gold += g.rng.range(90, 160);
              l.fame += 6;
              g.mark('朱印の船に銀を出し、大きな利を得た');
              return '一年ののち、船は砂糖と生糸を山と積んで戻った。蔵に、嗅いだことのない異国の香りが満ちた。';
            }
            g.j(-6);
            g.mark('朱印の船に銀を出したが、船は戻らなかった');
            return '船は、南の海で消息を絶った。嵐か、海賊か。知る者はいなかった。';
          }),
          Choice.h('少しだけ出して、様子を見る', '損は小さい。儲けも小さい', () {
            _pay(g, 12);
            g.setFlag('pc_shuin');
            l.gold += g.rng.chance(.7) ? g.rng.range(20, 40) : 0;
            g.mark('朱印の船の荷に、少しだけ銀を出した');
            return '帰ってきた船の荷のうち、小さな行李ひとつ分が、自分の取り分だった。';
          }),
          Choice.h('海の商いには手を出さない', '見えない海の向こうに、銭は預けない', () {
            return '船出を見送る人々の後ろで、算盤だけはじいてみた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 海の禁 ----
  SceneDef(
    'pc_kaikin',
    25,
    80,
    _w,
    (g) => _edo(g) && g.year >= 1635 && _merchant(g) && g.hasFlag('pc_shuin'),
    (g, next) {
      final l = g.l;
      g.ask(
        '閉じた海',
        '海の外へ出ることも、帰ることも禁じられた。朱印の船は、もう出ない。安南の町に残った者たちは、二度と帰れないという。'
            '海の商いで張った店を、どう畳み、どう繋ぐか。',
        [
          Choice.h('長崎の唐物を扱う商いに替える', '窓は一つだけ残った。そこに食い込めば、まだ商える', () {
            if (l.sei >= 55 || g.rng.chance(.5)) {
              l.gold += g.rng.range(30, 60);
              g.setFlag('pc_nagasaki_trade');
              g.mark('海が閉じたのち、長崎の唐物の商いに替えた');
              return '入札の仲間に加えてもらうまでに、多くの付け届けが要った。それでも、糸は切れなかった。';
            }
            _pay(g, 20);
            g.j(-4);
            return '長崎の仲間は、よそ者を入れなかった。付け届けだけが、消えていった。';
          }),
          Choice.h('国の内を回る廻船に乗り換える', '北の昆布や米を、西へ運ぶ。地味だが、海は海だ', () {
            l.gold += g.rng.range(20, 40);
            g.j(2);
            g.setFlag('pc_kaisen');
            g.mark('海が閉じたのち、国の内を回る廻船の商いに替えた');
            return '船は、岸に沿って北と西を行き来した。外海の青さを知る水主たちは、少し物足りなそうだった。';
          }),
          Choice.h('海の向こうに残った者へ、最後の文を託す', '商いにはならない。心残りは、一つ減る', () {
            _pay(g, 8);
            g.j(3);
            g.setFlag('pc_last_letter');
            g.mark('海の向こうに残った者へ、最後の文を託した');
            return '阿蘭陀の船に託した文が届いたかどうか、知るすべはなかった。返事は、来なかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 大名貸し ----
  SceneDef(
    'pc_daimyo_kashi',
    25,
    80,
    _w,
    (g) => _peace(g) && g.year >= 1616 && _merchant(g) && g.l.gold >= 80,
    (g, next) {
      final l = g.l;
      g.ask(
        '大名貸し',
        'さる大名家の勘定方が、人目を忍んで訪ねてきた。江戸の屋敷の掛かりと普請の手伝いで、蔵が空だという。'
            '「来年の年貢米を形に、用立ててもらえまいか」。刀を差した者が、算盤を持つ者に頭を下げる世になった。',
        [
          Choice.h('まとまった銀を貸す', '利は大きい。相手は大名だ。踏み倒されても、訴える先がない', () {
            _pay(g, 60);
            if (g.rng.chance(.3)) {
              g.j(-8);
              g.setFlag('pc_kashi_lost');
              g.mark('大名に貸した銀を、踏み倒された');
              return '「お家の大事につき、返済はしばらく待て」。その「しばらく」は、終わらなかった。';
            }
            l.gold += g.rng.range(90, 140);
            l.fame += 6;
            g.setFlag('pc_daimyo_kashi');
            g.mark('大名に銀を貸し、名字と刀を許された');
            return '利息は米で届いた。礼として、名字を名乗り刀を差すことを許された。差す用は、なかった。';
          }),
          Choice.h('蔵元として、年貢米を預かる形にする', '貸すのではなく、米を売る役を引き受ける。儲けは薄いが、取りはぐれない', () {
            l.gold += g.rng.range(15, 30);
            l.net = _c(l.net + 5);
            g.setFlag('pc_kuramoto');
            g.mark('大名家の年貢米を預かる蔵元となった');
            return '米俵が蔵に入るたびに、帳面に筆を入れた。大名の台所は、こうして商人の手の内に入っていった。';
          }),
          Choice.h('丁重に断る', '武家と銭の貸し借りはしない。恨みは、少し買う', () {
            l.net = _c(l.net - 2);
            return '勘定方は、何も言わずに帰った。翌月、同じ家が隣町の両替商から借りたと聞いた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // 村と町
  // =====================================================================

  // ---- 五人組 ----
  SceneDef(
    'pc_gonin',
    18,
    75,
    _w,
    (g) => _edo(g) && g.year >= 1605 && _villager(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '五人組',
        '村の家が五軒ずつ組にされ、年貢も咎も、組で負うことになった。組の一軒が、今年の年貢を納められないという。'
            'その家の亭主は、長く患っている。不足は、残りの家にかぶさる。',
        [
          Choice.h('自分の蔵から、不足を出してやる', '懐は痛む。あの家は、恩を忘れないだろう', () {
            _pay(g, 8);
            l.net = _c(l.net + 8);
            g.j(2);
            g.setFlag('pc_gonin_helped');
            g.mark('五人組の家の年貢の不足を、肩代わりした');
            return '俵を担いで、黙ってその家の土間に置いた。翌年の田植えには、その家の子らが真っ先に手伝いに来た。';
          }),
          Choice.h('組の皆で、少しずつ出し合う', '決まりどおりだ。誰の恩にも、恨みにもならない', () {
            _pay(g, 3);
            l.net = _c(l.net + 3);
            g.setFlag('pc_gonin_shared');
            return '寄り合いで升を回し、皆が同じだけ出した。誰も礼を言わず、誰も文句を言わなかった。';
          }),
          Choice.h('名主に訴え、その家の田を手放させる', '負い目は消える。村の目は、冷たくなる', () {
            l.gold += 6;
            l.net = _c(l.net - 8);
            g.j(-3);
            g.setFlag('pc_gonin_reported');
            g.mark('年貢を納められぬ組の家を、名主に訴えた');
            return 'その家は田を手放し、小作に落ちた。空いた田の一枚は、あなたの家に回ってきた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 新田の村 ----
  SceneDef(
    'pc_shinden',
    18,
    65,
    _w,
    (g) => _peace(g) && g.year >= 1610 && _villager(g) && g.l.cls.id == 'farmer',
    (g, next) {
      final l = g.l;
      g.ask(
        '新田の村',
        '戦に取られていた人手と銭が、川と野に向かい始めた。領主が大きな用水を引き、荒れ野に新しい村を立てるという。'
            '移り住む者には、数年のあいだ年貢を免じる触れが出た。',
        [
          Choice.h('家を挙げて、新田の村へ移る', '田は広くなる。水が来るまでの数年は、食うや食わずだ', () {
            _pay(g, 10);
            l.hp -= g.rng.range(4, 10);
            if (g.rng.chance(.7)) {
              l.gold += g.rng.range(20, 40);
              g.j(5);
              g.setFlag('pc_shinden_mura');
              g.mark('新田の村へ移り、一から田を拓いた');
              return '三年目の秋、用水がようやく田に届いた。見渡すかぎりの稲穂は、どれも自分の家のものだった。';
            }
            g.j(-5);
            g.setFlag('pc_shinden_failed');
            g.mark('新田の村へ移ったが、水が届かなかった');
            return '用水は、村の手前で砂に吸われて消えた。元の村に、頭を下げて戻った。';
          }),
          Choice.h('用水普請の人足に出て、日銭を稼ぐ', '田は増えない。銭は確かに入る', () {
            l.gold += g.rng.range(8, 14);
            l.hp -= g.rng.range(2, 6);
            g.setFlag('pc_yosui_ninsoku');
            return '鍬の代わりに畚を担いだ。掘った水路に水が走った日は、人足も百姓も一緒になって声を上げた。';
          }),
          Choice.h('先祖の田を守って動かない', '狭くとも、土を知り尽くした田だ', () {
            g.j(1);
            return '隣の家は、荷車に鍋釜を積んで出ていった。空いた畦の草を、黙って刈った。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 寺請 ----
  SceneDef(
    'pc_terauke',
    18,
    84,
    _w,
    (g) =>
        _edo(g) &&
        g.year >= 1635 &&
        _commoner(g) &&
        !g.hasFlag('kirishitan'),
    (g, next) {
      final l = g.l;
      g.ask(
        '寺請',
        'どの家も、どこかの寺の檀家であると証を立てよ、という触れが出た。キリシタンでない証だという。'
            '旅に出るにも、奉公に出るにも、嫁に行くにも、寺の判が要る。',
        [
          Choice.h('先祖の墓のある寺の檀家になる', '筋は通る。盆暮れの付け届けは、欠かせなくなる', () {
            _pay(g, 3);
            l.net = _c(l.net + 3);
            g.setFlag('pc_danka');
            g.mark('寺請の触れで、先祖の寺の檀家となった');
            return '住持が、家の者の名と歳を帳面に書き入れた。生まれるのも死ぬのも、これからは寺の帳面の上のことになる。';
          }),
          Choice.h('付け届けの軽い、小さな寺を選ぶ', '懐は助かる。「先祖を粗末にした」と親類が言う', () {
            l.net = _c(l.net - 4);
            l.gold += 2;
            g.setFlag('pc_danka_small');
            return '村はずれの小さな寺の和尚は、判を押しながら、布施の額を何も言わなかった。';
          }),
          Choice.h('判を預かる寺の世話役を買って出る', '手間は掛かる。村の出入りが、すべて耳に入る', () {
            l.net = _c(l.net + 6);
            l.sei = _c(l.sei + 2);
            g.setFlag('pc_tera_sewayaku');
            g.mark('寺請の世話役として、村の出入りをまとめた');
            return '誰が生まれ、誰が嫁ぎ、誰が村を出たか。寺の帳面を繰れば、村のすべてが分かるようになった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 寛永の飢饉 ----
  SceneDef(
    'pc_kikin',
    15,
    84,
    (g) => 30,
    (g) =>
        g.year == 1642 && peaceTime(g) && _commoner(g) && !_merchant(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '飢えの年',
        '雨と冷えと虫が、幾年も続いた。牛は疫病で倒れ、田を起こす力もない。村の蔵は底が見え、道には村を捨てた者が行き倒れている。'
            '戦のない世にも、人は飢えて死ぬ。',
        [
          Choice.h('蓄えを、村の者と分け合う', '皆で冬を越せるかもしれない。共倒れになるかもしれない', () {
            if (l.gold < 6 && g.rng.chance(.08)) {
              g.die('寛永の飢饉で、蓄えを分け尽くして力尽きた', 'ue');
              return '最後の一握りを、隣の子に渡した。';
            }
            _pay(g, 10);
            l.hp -= g.rng.range(4, 10);
            l.net = _c(l.net + 10);
            g.setFlag('pc_kikin_gave');
            g.mark('寛永の飢饉で、蓄えを村の者と分け合った');
            return '粥は、日ごとに薄くなった。それでも春まで、組の家から死人を出さなかった。';
          }),
          Choice.h('家の者の分だけを、固く守る', '家は守れる。戸を叩く音に、耳をふさぐことになる', () {
            l.hp -= g.rng.range(2, 6);
            l.net = _c(l.net - 8);
            g.j(-6);
            g.setFlag('pc_kikin_kept');
            return '夜ごと、戸を叩く音がした。開けなかった。春になって、その音がしなくなった。';
          }),
          Choice.h('領主の蔵を開けるよう、願い出る', '聞き届けられれば、村が救われる。強訴と取られれば、咎めを受ける', () {
            if (g.rng.chance(.05)) {
              g.die('飢饉の年に蔵を開けよと願い出て、頭取として処刑された', 'seppuku');
              return '願いは、徒党と見なされた。';
            }
            if (l.mi + l.sei >= 90 || g.rng.chance(.5)) {
              l.fame += 8;
              l.net = _c(l.net + 12);
              g.setFlag('pc_kikin_plea');
              g.mark('寛永の飢饉で、蔵を開けるよう願い出て聞き届けられた');
              return '代官は長いこと黙っていたが、やがて蔵の鍵を持ってこさせた。お救いの米が、村に配られた。';
            }
            l.hp -= g.rng.range(4, 8);
            g.j(-4);
            return '願いは退けられた。代官所の門前で、三日座り込んだが、門は開かなかった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 宿場の旅籠 ----
  SceneDef(
    'pc_hatago',
    20,
    70,
    _w,
    (g) =>
        _peace(g) &&
        g.year >= 1605 &&
        g.l.female &&
        g.l.rank == 0 &&
        !_monk(g) &&
        !g.hasFlag('way_outlaw') &&
        !g.hasFlag('retired'),
    (g, next) {
      final l = g.l;
      g.ask(
        '街道の宿',
        '街道が整えられ、一里ごとに塚が築かれた。兵の代わりに、商人と参詣の旅人が行き来するようになり、村は宿場に指図された。'
            '旅人を泊める家が、足りないという。',
        [
          Choice.h('家を直して、旅籠を開く', '元手は要る。戦のない世の街道は、人が絶えない', () {
            _pay(g, 12);
            if (g.rng.chance(.75)) {
              l.gold += g.rng.range(20, 40);
              l.net = _c(l.net + 6);
              g.j(4);
              g.setFlag('pc_hatago');
              g.mark('街道の宿場で、旅籠の女あるじとなった');
              return '諸国の言葉が、囲炉裏端で混ざり合った。客の話を聞いているだけで、遠くへ旅をした気になった。';
            }
            g.j(-3);
            return '本陣の近くの大きな宿に、客をみな取られた。一年で、看板を下ろした。';
          }),
          Choice.h('軒先で、茶と団子を売る', '小さな商いだ。元手はほとんど要らない', () {
            l.gold += g.rng.range(6, 12);
            l.net = _c(l.net + 3);
            g.setFlag('pc_chamise');
            g.mark('街道の端で、茶店を営んだ');
            return '床几を二つ出しただけの店に、毎日、誰かが腰を下ろした。';
          }),
          Choice.h('これまでどおりの暮らしを続ける', '人の出入りは、わずらわしい', () {
            g.j(1);
            return '家の前を、見知らぬ人が毎日通るようになった。垣根を、少し高くした。';
          }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // 忍び・流れ者
  // =====================================================================

  // ---- 忍びの仕事がなくなる ----
  SceneDef(
    'pc_shinobi_end',
    18,
    75,
    _w,
    (g) => _edo(g) && g.year >= 1603 && _ninja(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '用のない技',
        '戦がなくなり、忍びを雇う家がなくなった。城に忍び入る用も、敵陣に火を放つ用も、もうない。'
            '里の者は、江戸へ出て城の門番になるか、鍬を握るか、道を外れるかを選び始めている。',
        [
          Choice.h('江戸へ出て、城の番士に抱えられる', '禄はもらえる。技を使う日は、まず来ない', () {
            l.gold += g.rng.range(10, 20);
            g.j(-2);
            g.setFlag('pc_banshi');
            g.mark('忍びの技を置き、江戸の城の番士となった');
            return '御門の脇に、一日じゅう立った。闇を走った足は、同じ石畳の上で少しずつ鈍っていった。';
          }),
          Choice.h('技を頼りに、盗みで食う', '腕があれば、蔵は破れる。捕まれば、磔だ', () {
            if (g.rng.chance(.07)) {
              g.die('忍びの技で蔵を破り、捕らえられて磔になった', 'seppuku');
              return '大店の蔵の屋根で、捕り方の提灯に囲まれた。';
            }
            l.gold += g.rng.range(25, 50);
            g.j(-3);
            g.setFlag('way_outlaw');
            g.setFlag('pc_nusutto');
            g.mark('忍びの技を、盗みに使うようになった');
            return '錠前は、戦国の城より町の蔵のほうがよほど甘かった。';
          }),
          Choice.h('里に残り、薬を作って売り歩く', '忍びの薬草の知恵は、泰平の世でも銭になる', () {
            l.gold += g.rng.range(8, 16);
            l.net = _c(l.net + 5);
            g.j(3);
            g.setFlag('pc_kusuri');
            g.mark('忍びの里で、薬を作って売り歩いた');
            return '火薬を練った手で、腹薬を丸めた。行商の荷を背負えば、どの関所も怪しまずに通した。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 関所と人別 ----
  SceneDef(
    'pc_sekisho',
    18,
    75,
    _w,
    (g) => _edo(g) && g.year >= 1616 && _outlaw(g) && !_ninja(g),
    (g, next) {
      final l = g.l;
      g.ask(
        '関所',
        '街道に関所が置かれ、村ごとに人の名が帳面に載せられるようになった。帳面に名のない者は、どの宿場でも怪しまれる。'
            '手形のないあなたに、この先の峠の関は越えられない。',
        [
          Choice.h('夜の山を抜けて、関を破る', '道は知っている。見つかれば、命はない', () {
            if (g.rng.chance(.06)) {
              g.die('関所破りの咎で、磔になった', 'seppuku');
              return '尾根の藪で、見張りの犬に吠えられた。';
            }
            l.un = _c(l.un + 1);
            g.setFlag('pc_seki_yaburi');
            g.mark('夜の山を抜けて、関所を破った');
            return '獣道を這って、夜明け前に峠の向こうへ下りた。こんな道を知る者も、もう少なくなった。';
          }),
          Choice.h('宿場の人足として、腰を落ち着ける', '流れる暮らしは終わる。帳面に、名が載る', () {
            l.gold += g.rng.range(6, 12);
            g.j(2);
            g.setFlag('pc_settled');
            g.mark('宿場の人足として、帳面に名を載せた');
            return '問屋場で荷を担ぎ、駕籠を舁いた。名を聞かれて、久しぶりに生まれた村の名を口にした。';
          }),
          Choice.h('寺に頼み込み、寺男として置いてもらう', '飯と寝床は得られる。寺の判が、身の証になる', () {
            l.net = _c(l.net + 4);
            g.j(3);
            g.setFlag('pc_teraotoko');
            g.mark('寺男となり、寺の判で身の証を得た');
            return '朝は庭を掃き、夕は鐘を撞いた。和尚は、昔のことを一度も尋ねなかった。';
          }),
          // 国言葉に通じる（特性。`trait_scenes4.dart`）は、土地の者の顔で関を通れる。
          if (g.has('dialects'))
            Choice.h('土地の言葉で、近くの村の者として関を通る', '言葉に訛りがなければ、よそ者とは見られない。手形がないことに変わりはない', () {
              l.un = _c(l.un + 1);
              l.net = _c(l.net + 2);
              g.setFlag('pc_seki_kotoba');
              g.mark('土地の言葉をそっくり真似て、手形もなしに関所を通った');
              return '番士に、土地の訛りで、今年の柿の出来をこぼしてみせた。番士は、同じ訛りで相づちを打ち、手形のことは聞きもしなかった。';
            }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // 女性
  // =====================================================================

  // ---- 江戸の屋敷 ----
  SceneDef(
    'pc_edo_yashiki',
    18,
    75,
    _w,
    (g) =>
        _edo(g) &&
        g.year >= 1622 &&
        g.l.female &&
        g.l.married &&
        g.l.rank >= 5 &&
        g.l.rank <= 8 &&
        g.l.lord != '松平' &&
        !g.hasFlag('retired'),
    (g, next) {
      final l = g.l;
      final hostage = g.hasFlag('hostage');
      g.ask(
        '江戸の屋敷',
        '大名と重臣の妻子は、江戸の屋敷に住まうことになった。幕府への証である。国元を離れれば、いつ戻れるかは分からない。'
            '${hostage ? '若い日に人質として他家で暮らした歳月が、また繰り返されるのかと思った。' : '生まれ育った国の山が、遠ざかっていく。'}',
        [
          Choice.h('屋敷の奥を、自ら取り仕切る', '務めは重い。江戸の屋敷は、家のもう一つの城になる', () {
            l.merit += 10;
            l.sei = _c(l.sei + 2);
            g.j(-2);
            g.setFlag('pc_edo_okugata');
            g.mark('江戸の屋敷の奥を取り仕切った');
            return '国元から来た女中たちに、江戸の水と言葉を覚えさせた。屋敷の門の内だけが、小さな国元だった。';
          }),
          Choice.h('他家の奥方たちと、付き合いを広げる', '気は張る。屋敷の塀の外の噂が、家を助けることもある', () {
            l.net = _c(l.net + 10);
            l.mi = _c(l.mi + 1);
            g.setFlag('pc_edo_tsukiai');
            g.mark('江戸で、諸家の奥方との付き合いを広げた');
            return '香合わせの席で交わされるひと言が、ときに老中の屋敷の空気を伝えた。夫への文に、それを書き添えた。';
          }),
          Choice.h('国元へ、文を書き続ける', '心は国元に置いたままだ。江戸の暮らしには、なじめない', () {
            g.j(-4);
            l.chi = _c(l.chi + 1);
            g.setFlag('pc_edo_fumi');
            g.mark('江戸の屋敷から、国元へ文を書き続けた');
            return '庭の柿は実ったか、堤は切れなかったか。尋ねてばかりの文に、返事はいつもひと月遅れで届いた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 御殿に上がる ----
  SceneDef(
    'pc_ooku',
    16,
    45,
    _w,
    (g) =>
        _edo(g) &&
        g.year >= 1618 &&
        g.l.female &&
        !g.l.married &&
        g.l.rank >= 2 &&
        g.l.rank <= 6 &&
        _lordAlive(g) &&
        (g.fa['松平']?.alive ?? false) &&
        !_monk(g) &&
        !g.hasFlag('retired'),
    (g, next) {
      final l = g.l;
      final tokugawa = l.lord == '松平';
      g.ask(
        '江戸の御殿',
        tokugawa
            ? '江戸の城の奥御殿へ移れ、という話が来た。将軍家の奥は、表の役人も立ち入れぬ女だけの城だという。一度上がれば、容易には下がれない。'
            : '江戸の城の奥御殿で、作法の確かな女を求めているという。奥方さまが、あなたを推すと言い出した。将軍家の奥は、一度上がれば、容易には下がれない。',
        [
          Choice.h('御殿に上がる', '栄えある奉公だ。親の死に目にも、会えぬかもしれない', () {
            l.lord = '松平';
            l.fav = _c100(l.fav < 30 ? 30 : l.fav);
            l.merit += 12;
            l.fame += 6;
            g.j(-2);
            g.setFlag('pc_ooku');
            g.mark('江戸の城の奥御殿に上がった');
            return '長い廊下の先で、鈴の付いた錠が下りた。その内側が、これからの世界のすべてになった。';
          }),
          Choice.h('いまの奉公先に残る', '慣れた奥で、慣れた務めを続ける', () {
            l.fav = _c100(l.fav + 4);
            g.j(1);
            return '話は、別の女に回った。江戸から届くその女の文は、年ごとに短くなった。';
          }),
        ],
        after: next,
      );
    },
  ),

  // ---- 奥の掟 ----
  SceneDef(
    'pc_ooku_okite',
    18,
    70,
    _w,
    (g) =>
        _edo(g) &&
        g.year >= 1623 &&
        g.l.female &&
        g.hasFlag('pc_ooku') &&
        g.l.lord == '松平' &&
        g.l.rank >= 1 &&
        g.l.rank <= 7 &&
        !g.hasFlag('retired'),
    (g, next) {
      final l = g.l;
      g.ask(
        '奥の掟',
        '将軍の乳母から上りつめた御局が、奥の掟を次々と定めている。門の出入り、文のやり取り、灯を消す刻限まで。'
            '古くからの女中たちは、陰で眉をひそめている。あなたは、どちらの側にも顔が利く。',
        [
          Choice.h('掟を守らせる側に回る', '御局の覚えはめでたくなる。朋輩からは、煙たがられる', () {
            l.merit += 15;
            l.fav = _c100(l.fav + 10);
            l.net = _c(l.net - 5);
            g.setFlag('pc_ooku_strict');
            g.mark('奥御殿で、掟を守らせる役に就いた');
            return '夜ごと、長い廊下を見回った。錠の鈴の音で、誰の部屋の戸が開いたかが分かるようになった。';
          }),
          Choice.h('古参と新参のあいだを取り持つ', '骨は折れる。どちらからも、頼られるようになる', () {
            if (l.mi >= 50 || g.rng.chance(.5)) {
              l.net = _c(l.net + 8);
              l.merit += 8;
              g.setFlag('pc_ooku_bridge');
              g.mark('奥御殿で、古参と新参のあいだを取り持った');
              return '掟の厳しさを古参に説き、古参の言い分を上へ伝えた。奥の空気が、少しだけ和らいだ。';
            }
            l.fav = _c100(l.fav - 6);
            return 'どちらにも良い顔をする、と両方から言われた。';
          }),
          Choice.h('目立たぬよう、務めだけを果たす', '波風は立たない。取り立てもない', () {
            g.j(1);
            return '掟がいくつ増えても、朝の務めは同じだった。廊下を拭き、灯を入れ、鈴の音を聞いた。';
          }),
        ],
        after: next,
      );
    },
  ),

  // =====================================================================
  // 仏門
  // =====================================================================

  // ---- 寺の法度 ----
  SceneDef(
    'pc_jiin',
    20,
    84,
    _w,
    (g) => _edo(g) && g.year >= 1615 && _monk(g) && !g.hasFlag('retired'),
    (g, next) {
      final l = g.l;
      final f = l.female;
      g.ask(
        '寺の法度',
        '幕府が、寺々に法度を下した。どの寺も本山の下に連なり、学問に励み、徒党を組むなという。'
            '僧兵が山を下り、門徒が城を囲んだ世は終わった。${f ? '庵' : '寺'}は、お上の帳面の一行になる。',
        [
          Choice.h('本山の末として、届けを出す', '寺は安んじる。本山への上納が、毎年の務めになる', () {
            _pay(g, 4);
            l.fame += 3;
            g.setFlag('pc_matsuji');
            g.mark('寺の法度に従い、本山の末として届けを出した');
            return '届けの紙に、${f ? '庵' : '寺'}の名と宗旨を書いた。数百年の由緒が、数行に収まった。';
          }),
          Choice.h('学問に打ち込み、経の講釈で名を上げる', '戦のない世の僧は、学で立つ。若い僧が、集まってくるかもしれない', () {
            l.chi = _c(l.chi + 3);
            if (l.chi >= 60) {
              l.fame += 8;
              l.net = _c(l.net + 5);
              g.setFlag('pc_gakuryo');
              g.mark('泰平の世に、経の講釈で名を上げた');
              return '講釈の日には、本堂に入りきれぬほどの人が集まった。刀を差した者も、算盤を提げた者も、同じ畳に座った。';
            }
            return '夜ごと灯の下で経を繰った。名は上がらなかったが、読めなかった字が読めるようになった。';
          }),
          Choice.h('檀家の葬いと法事を、丁寧に務める', '地味な務めだ。寺請の世では、寺は村の要になる', () {
            l.net = _c(l.net + 8);
            l.gold += g.rng.range(4, 8);
            g.j(2);
            g.setFlag('pc_danka_dera');
            g.mark('檀家の葬いと法事を、丁寧に務め続けた');
            return '戦で死ぬ者は、いなくなった。畳の上で死ぬ者を、一人ずつ送った。それが、泰平の世の経だった。';
          }),
        ],
        after: next,
      );
    },
  ),
];
