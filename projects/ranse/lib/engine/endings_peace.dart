import 'endings_catalog.dart';
import 'game.dart';
import 'history_lines.dart';

/// 手書きの最期: 泰平の世で長く生きた人（2026-11-24。人生が亡くなるまで続くようになったため）。
///
/// 一六一六年（大坂の陣のあと）からの世で、天寿か病で亡くなった人の受け皿を道ごとに一本ずつ（細かさ2）と、
/// 泰平の岐路（`peace.dart` の `pc_`）の旗で出る最期。幼くして亡くなる道には無い
/// （生まれは一五六八年までなので、一六〇一年からの世に子どもはいない）。
/// 一六〇一〜一六一五年に亡くなった人には、「乱世を生き抜いた」最期（kinds に era を持つもの）が
/// 候補に入る（`ending.dart` の `eraEndingFits`）。

/// 泰平の世（戦の絶えた世）で亡くなったか。今川の世は乱世が続くので入れない。
bool _taihei(Game g) => g.year >= 1616 && worldLine(g) != 'imagawa';
bool _f(Game g, String f) => g.hasFlag(f);
bool _dead(Game g, String s) => (g.l.dead ?? '').contains(s);

const _calm = {'tenju', 'byo'};

final kPeaceEndings = <EndingDef>[
  // ---------------- 村の暮らし ----------------
  EndingDef(
    id: 'v_taihei',
    way: 'village',
    kinds: _calm,
    tier: Tier.common,
    title: '戦のない村で老いた人',
    text:
        '{年}年（{元号}）、{国}の村で、{名}は{歳}歳の生涯を閉じた。若い日には、陣触れの太鼓に怯え、焼かれる村をいくつも見た。'
        'いま、村の若い者は槍の持ち方も知らない。それで良いのだと、{名}は最後まで言っていた。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 'v_taihei_kikin',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '飢えの年に蓄えを分けた人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。寛永の飢えの年、蓄えを村の者と分け合ったことを、村は忘れなかった。'
        '野辺送りには、組の家の者がみな鍬を置いて並んだ。戦のない世にも、人は飢える。'
        'だが、分け合えば越せる冬もあるのだと、{名}は身をもって示した。',
    cond: (g) => _taihei(g) && _f(g, 'pc_kikin_gave'),
    spec: 6,
  ),
  EndingDef(
    id: 'v_taihei_kakure',
    way: 'village',
    kinds: _calm,
    tier: Tier.rare,
    title: '納戸の祈りを遺した人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。寺の帳面には、熱心な檀家として名が載っている。'
        'だが納戸の奥では、異国の祈りの言葉が、口伝えに次の代へ受け継がれていた。意味はもう、誰にも分からない。'
        'それでもその言葉は、{名}の死ののちも、長く唱えられ続けた。',
    cond: (g) => _taihei(g) && _f(g, 'pc_kakure_passed'),
    spec: 8,
  ),

  // ---------------- 商いの道 ----------------
  EndingDef(
    id: 'm_taihei',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.common,
    title: '算盤の世を見届けた商人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で息を引き取った。若い日は、戦のたびに荷を隠し、街道の関銭に泣いた。'
        'いまは、刀を差した者が、払いを待ってくれと頭を下げに来る。'
        '「長生きは、してみるものだ」。それが、帳場での最後の軽口だった。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 'm_taihei_edo',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '江戸に暖簾を掛けた商人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。葦の原だった江戸に、間口の狭い出店を出した日から、長い歳月が過ぎていた。'
        '店はいまや、通りの角を占めている。'
        '臨終の床で{名}は、江戸から届いたばかりの売り上げの帳面を、最後まで手放さなかった。',
    cond: (g) => _taihei(g) && _f(g, 'pc_edo_shop'),
    spec: 6,
  ),

  // ---------------- 仏門 ----------------
  EndingDef(
    id: 'p_taihei',
    way: 'priest',
    kinds: _calm,
    tier: Tier.common,
    title: '畳の上の死者を送り続けた人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で静かに逝った。若い日に弔ったのは、戦場に捨てられた名も知れぬ亡骸ばかりだった。'
        '老いてからは、畳の上で家の者に囲まれて逝く者を送ることが増えた。'
        '経は同じでも、読む声はずいぶん穏やかになった。そう言って、{名}は笑っていたという。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 'p_taihei_danka',
    way: 'priest',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '村の帳面に最後に載った人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。寺請の世になってから、村で生まれる子も、嫁ぐ娘も、逝く年寄りも、みな{名}の筆で帳面に記されてきた。'
        'その帳面の新しい行に、若い者が{名}の名を書き入れた。'
        '葬いの日、村じゅうの者が、堂に入りきれずに庭まで並んだ。',
    cond: (g) => _taihei(g) && _f(g, 'pc_danka_dera'),
    spec: 6,
  ),

  // ---------------- 忍び・流れ者・野盗 ----------------
  EndingDef(
    id: 's_taihei',
    way: 'shadow',
    kinds: _calm,
    tier: Tier.common,
    title: '闇の要らぬ世に老いた者',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。街道には関所が立ち、村ごとに人の名が帳面に載る世になっていた。'
        '闇にまぎれて生きた者の居場所は、もうどこにもない。'
        'それでも{名}は、昔のことを誰にも語らぬまま、最後まで逃げおおせた。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 's_taihei_kusuri',
    way: 'shadow',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '薬売りとして逝った忍び',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。火薬を練った手で腹薬を丸め、行李を背負って村々を歩いた後半生だった。'
        '村の者は、{名}をただの気のいい薬売りだと思っていた。'
        '葬いの日、行李の底から、錆びた苦無が一本だけ出てきた。',
    cond: (g) => _taihei(g) && _f(g, 'pc_kusuri'),
    spec: 6,
  ),

  // ---------------- 足軽・侍 ----------------
  EndingDef(
    id: 'b_taihei',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.common,
    title: '戦場を知る最後の一人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。まわりで本物の戦場を知る者は、とうに{名}ひとりになっていた。'
        '若い者は、その昔語りを、半ば作り話だと思って聞いていた。{名}は怒りもせず、「それでよい」と言った。'
        '古い槍は、最後まで手入れが行き届いていた。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 'b_taihei_osaka',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.rare,
    title: '大坂の落人として老いた男',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。燃える大坂の城を背に落ち延びてから、名を変え、素性を隠して生きてきた。'
        '村の者は、無口な年寄りの背の刀傷を、熊にやられた跡だと聞かされていた。'
        '最期の床で{名}は、うわごとに、とうに無い城の名を呼んだ。',
    cond: (g) => _taihei(g) && _f(g, 'pc_osaka_survivor'),
    spec: 8,
  ),
  EndingDef(
    id: 'b_osaka_ronin',
    way: 'samurai',
    kinds: {'senshi'},
    tier: Tier.uncommon,
    title: '最後の戦場に槍を置いた牢人',
    text:
        '{年}年、大坂。{歳}歳の{名}は、豊臣方の牢人として、押し寄せる軍勢のなかに斬り込んだ。'
        '長い牢人暮らしのあいだ、槍の置き場所をずっと探していた。それが、ここだった。'
        '戦の世は、{名}たちの死とともに終わった。',
    cond: (g) => _dead(g, '豊臣方の牢人として討死'),
    spec: 8,
  ),

  // ---------------- 城主・家老 ----------------
  EndingDef(
    id: 'j_taihei',
    way: 'castle',
    kinds: _calm,
    tier: Tier.common,
    title: '兵を率いた野が田になるのを見た人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。若い日に兵を率いた野は、いまは一面の田になっている。'
        '城の縄張りも、国境の物見も、もう誰も{名}に尋ねない。尋ねられるのは、年貢の帳尻と、普請の掛かりばかりだった。'
        'それを泰平と呼ぶのだと、{名}は知っていた。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 'j_taihei_ikkoku',
    way: 'castle',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '自らの手で城を壊した人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。一つの国に城は一つと定められた年、預かった城を自らの手で壊した。'
        '石垣の跡には、いま桑が植わっている。'
        '{名}は年に一度、その畑の端に立ち、櫓のあった空をしばらく見上げていたという。',
    cond: (g) =>
        _taihei(g) &&
        g.l.maxRank < 8 &&
        (_f(g, 'pc_ikkoku_obeyed') || _f(g, 'pc_ikkoku_farewell')),
    spec: 6,
  ),

  // ---------------- 大名・下剋上 ----------------
  EndingDef(
    id: 'd_taihei',
    way: 'daimyo',
    kinds: _calm,
    tier: Tier.common,
    title: '家を潰さずに済んだ話ばかりした国主',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。国を奪い合った世を知る大名は、もう幾人も残っていなかった。'
        '若い国主たちは、{名}に合戦の話をせがんだ。'
        '{名}が語ったのは、戦に勝った話ではなく、家を潰さずに済んだ話ばかりだった。',
    cond: (g) => _taihei(g) && g.l.rank >= 8,
    spec: 2,
  ),

  // ---------------- 天下人 ----------------
  EndingDef(
    id: 't_taihei',
    way: 'tenka',
    kinds: {'victory'},
    tier: Tier.rare,
    title: '関ヶ原ののちに天下を取った者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、天下の過半をその手に収めた。関ヶ原ののちも戦をやめなかった、最後の一人だった。'
        '諸国の大名が、次々と誓いの書状を差し出してくる。'
        '戦の世を終わらせたのは、徳川でも豊臣でもなく、{名}になった。',
    cond: (g) => g.year >= 1601 && worldLine(g) == 'real',
    spec: 3,
  ),

  // ---------------- 女の道 ----------------
  EndingDef(
    id: 'f_taihei',
    way: 'woman',
    kinds: _calm,
    tier: Tier.common,
    title: '落城を知らぬ娘たちを見送った女',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で静かに逝った。若い日には、嫁ぐことも、仕えることも、家と家との戦の続きだった。'
        'いまの娘たちは、落城の夜の逃げ道を教わらずに育つ。'
        'それを物足りなく思う自分がおかしくて、{名}はよく一人で笑っていた。',
    cond: _taihei,
    spec: 2,
  ),
  EndingDef(
    id: 'f_taihei_edo',
    way: 'woman',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '江戸の屋敷で国元を思い続けた奥方',
    text:
        '{年}年、{名}は{歳}歳で、江戸の屋敷で息を引き取った。幕府への証として国元を離れてから、長い歳月が過ぎていた。'
        '枕元には、国元から届いた文が、年ごとに束ねて積まれていた。'
        '最期に{名}は、国元の庭の柿は今年も実ったかと尋ねたという。',
    cond: (g) =>
        _taihei(g) &&
        (_f(g, 'pc_edo_okugata') ||
            _f(g, 'pc_edo_tsukiai') ||
            _f(g, 'pc_edo_fumi')),
    spec: 6,
  ),
  EndingDef(
    id: 'f_taihei_ooku',
    way: 'woman',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '鈴の錠の内で老いた女',
    text:
        '{年}年、{名}は{歳}歳で世を去った。江戸の城の奥御殿に上がってから、鈴の付いた錠の外へ出ることは、ほとんどなかった。'
        '奥の廊下の数も、女たちの名も、掟の一条一条も、すべて覚えていた。'
        '{名}の部屋の灯が消えた夜、長い廊下は、いつもより少し静かだった。',
    cond: (g) => _taihei(g) && _f(g, 'pc_ooku') && g.l.lord == '松平',
    spec: 7,
  ),
];
