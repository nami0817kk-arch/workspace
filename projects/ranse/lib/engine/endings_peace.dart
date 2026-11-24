import 'endings_catalog.dart';
import 'game.dart';
import 'history_lines.dart';
import 'life.dart';
import 'peace.dart';

/// 手書きの最期: 泰平の世で長く生きた人（2026-11-24。人生が亡くなるまで続くようになったため）。
///
/// 一六一六年（大坂の陣のあと）からの世で、天寿か病で亡くなった人の受け皿を道ごとに一本ずつ（細かさ2）と、
/// 泰平の岐路（`peace.dart` の `pc_`）の旗で出る最期。幼くして亡くなる道には無い
/// （生まれは一五六八年までなので、一六〇一年からの世に子どもはいない）。
/// 一六〇一〜一六一五年に亡くなった人には、「乱世を生き抜いた」最期（kinds に era を持つもの）が
/// 候補に入る（`ending.dart` の `eraEndingFits`）。
///
/// 同じ日に足した分（id に `_hei_` が入る）: 戦を知らない者の世（一六三六年から）の受け皿、
/// 天寿・病のほかの死に方（災い・行方知れず・飢え・切腹や処刑・暗殺）の受け皿、大坂の陣・島原・追腹・禁教・
/// 越訴・敵討ち・かぶき者など泰平の岐路の死因で出る最期、泰平の岐路と暮らし（`pc_`・`pl_`）の旗で出る最期、
/// 長く生きた人だけの幻の最期。**受け皿（細かさ3まで）の文には、江戸・幕府・徳川を書かない**
/// （歴史が変わった世でも出るため。徳川の世の言葉は、史実の世の岐路の旗か死因で出る最期にだけ）。
/// 一六一六年からの世に亡くなった人には、戦の世の言葉の既存の最期より、ここの最期が先に出る
/// （`ending.dart` の `yieldsToPeace`）。

/// 泰平の世（戦の絶えた世）で亡くなったか。今川の世は乱世が続くので入れない。
bool _taihei(Game g) => g.year >= 1616 && worldLine(g) != 'imagawa';
bool _f(Game g, String f) => g.hasFlag(f);
bool _dead(Game g, String s) => (g.l.dead ?? '').contains(s);
bool _p(Game g, String s) => g.l.path.any((e) => e.contains(s));

/// 戦の絶えた世で亡くなったか（`peaceTime`。史実の世は一六〇一年から。今川の世には無い）。
bool _peace(Game g) => peaceTime(g);

/// 戦を知らない者の世（一六三六年から）で亡くなったか。
bool _late(Game g) => _taihei(g) && g.year >= 1636;
bool _real(Game g) => worldLine(g) == 'real';

/// 嫁いだ娘が、いまも生きている。
bool _wedDaughter(Game g) =>
    g.l.children.any((k) => k.female && k.fate == KidFate.wed);

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

  // ---------------- 戦を知らない者の世（一六三六年から）の受け皿 ----------------
  EndingDef(
    id: 'v_hei_late',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '戦を知らぬ村の最年長',
    text:
        '{年}年（{元号}）、{国}の村で、{名}は{歳}歳で息を引き取った。村には、戦を見たことのある者がもう一人もいない。'
        '{名}が語る焼け働きの夜の話を、子らは鬼の昔話と同じ顔で聞いた。'
        '怖がりもせず笑って聞く顔を見るのが、{名}の晩年の楽しみだった。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 'm_hei_late',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '関銭を知らぬ手代に店を任せた商人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。店の若い手代は、荷を奪われる怖さも、道ごとに取られた関銭も知らない。'
        '知っているのは、相場と掛けの取り立てだけだ。'
        '「それで足りる世になった」。帳場を譲った日、{名}はそう言って、古い脇差を蔵の奥にしまった。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 'p_hei_late',
    way: 'priest',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '古い過去帳を最後まで繰った人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で静かに逝った。寺に持ち込まれる供養は、いつしか畳の上で逝った者のものばかりになった。'
        '討たれた者の名を記した古い過去帳を開く者は、もう{名}のほかにいない。'
        '最期の朝も、{名}はその帳を一枚だけ繰って、経を上げた。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 's_hei_late',
    way: 'shadow',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '偽りの名のまま葬られた者',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。{名}の昔を知る者は、追う側にも追われる側にも、もう誰も残っていなかった。'
        '村の帳面には、ありふれた名と生業が載っている。'
        '偽りの名のまま葬られることを、{名}は少しも気にしていなかったという。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 'b_hei_late',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '昔語りを軍記と比べられた古強者',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で息を引き取った。若い侍たちは、戦を軍記の読み物でしか知らない。'
        '{名}の昔語りは、本と違うと言ってよく直された。{名}は笑って「本のほうが正しかろう」と答え、それきり黙った。'
        '遺された槍の柄には、手の形にすり減った跡があった。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 'j_hei_late',
    way: 'castle',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '絵図の城しか知らぬ者に囲まれた重臣',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。家中の若い者は、城攻めも籠城も、絵図の上でしか知らない。'
        '評定で問われるのは、蔵の米と借銀の話ばかりになった。'
        '「戦よりよほど難しい」。そうこぼしながら、{名}は最後まで帳面に目を通していた。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 'd_hei_late',
    way: 'daimyo',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '戦を知らぬ世継ぎに国を渡した国主',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。跡を継ぐ者は、一度も鎧を着て野に立ったことがない。それを頼りなく思った日もあった。'
        'だが、国を奪われる怖さを知らずに治められるなら、それに越したことはない。'
        'そう思えるようになって、{名}は目を閉じた。',
    cond: _late,
    spec: 3,
  ),
  EndingDef(
    id: 'f_hei_late',
    way: 'woman',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '懐剣の使い道を訊かれた女',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で静かに逝った。嫁入り道具の懐剣を、いまの若い娘たちは飾りだと思っている。'
        '何に使うものかと訊かれて、{名}は答えに詰まった。'
        '答えずに済む世になったのだと気づき、その夜は長いこと、古い懐剣を磨いていたという。',
    cond: _late,
    spec: 3,
  ),

  // ---------------- 乱世を知る最後の者たち（長く生きた人だけの最期） ----------------
  EndingDef(
    id: 'b_hei_last',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.phantom,
    title: '乱世を知る最後の一人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で世を去った。長篠も、本能寺も、関ヶ原も、{名}が生きたあいだの出来事だった。'
        'その頃を覚えている者は、国じゅうを探しても、もう幾人も残っていない。'
        '土地の領主は使いをよこし、昔の戦の話を書き留めさせた。筆を執った若侍は、聞きながら幾度も手を止めたという。',
    cond: (g) =>
        _taihei(g) && g.year >= 1640 && g.age >= 78 && _f(g, 'first_battle'),
    spec: 9,
  ),
  EndingDef(
    id: 'b_hei_mago',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.rare,
    title: '戦を知らぬ孫に槍を譲った古強者',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で息を引き取った。亡くなる前の年、{名}は古い槍を孫に譲った。'
        '孫は、柄の傷の一つ一つのいわれを聞きたがった。'
        '{名}は半分だけ話し、残りは「知らずに済むなら、それがよい」と笑った。槍はいま、床の間に飾られている。',
    cond: (g) => _late(g) && g.l.kids > 0 && _f(g, 'first_battle'),
    spec: 7,
  ),
  EndingDef(
    id: 'v_hei_last',
    way: 'village',
    kinds: _calm,
    tier: Tier.phantom,
    title: '焼かれた村を覚えている最後の人',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で息を引き取った。村が焼かれた夜を覚えている者は、もう{名}しかいなかった。'
        '村の子らは、親と同じ家で生まれ、同じ田で育っていく。誰もさらわれず、誰も槍を持たされない。'
        'それがどれほど稀なことかを知っているのも、{名}ひとりだった。',
    cond: (g) => _taihei(g) && g.year >= 1640 && g.age >= 78,
    spec: 9,
  ),
  EndingDef(
    id: 'f_hei_last',
    way: 'woman',
    kinds: _calm,
    tier: Tier.phantom,
    title: '乱世の奥を知る最後の女',
    text:
        '{年}年（{元号}）、{名}は{歳}歳で静かに逝った。夫や子の帰りを、討死の知らせに怯えながら待つ。'
        'そういう暮らしがあったことを知る女は、もう{名}のほかに幾人もいない。'
        '若い女たちに昔を訊かれると、{名}は決まって「いまのほうが、ずっと良い」とだけ答えた。その一言の重さを量れる者も、もういなかった。',
    cond: (g) => _taihei(g) && g.year >= 1640 && g.age >= 78,
    spec: 9,
  ),

  // ---------------- 災い（戦の絶えた世の受け皿） ----------------
  EndingDef(
    id: 'v_hei_sai',
    way: 'village',
    kinds: {'sai'},
    tier: Tier.common,
    title: '戦のない年に災いに呑まれた人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、思いがけぬ災いに命を落とした。'
        '軍勢に村を焼かれる心配のなくなった世にも、水と火と山は、人の都合を聞いてはくれない。'
        '村の者は総出で{名}を弔い、次の日にはもう、壊れた畦を直しにかかった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'm_hei_sai',
    way: 'merchant',
    kinds: {'sai'},
    tier: Tier.common,
    title: '暖簾を残して災いに消えた商人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、災いに呑まれて命を落とした。荷を奪う者の減った世でも、火と水だけは防ぎようがない。'
        '店の者は泣きながら帳面を調べ、掛けの残りを一つずつ片付けた。'
        '暖簾は、次の月にはもう掛け直されていた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'p_hei_sai',
    way: 'priest',
    kinds: {'sai'},
    tier: Tier.common,
    title: 'うろ覚えの経で送られた人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、思いがけぬ災いのなかで命を終えた。人の死を数えきれぬほど送ってきた身に、自分の番は不意に来た。'
        '村の者は、{名}がいつも唱えていた経を、うろ覚えのまま皆で唱えた。'
        '途中で何度も、誰かが節を間違えた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'b_hei_sai',
    way: 'samurai',
    kinds: {'sai'},
    tier: Tier.common,
    title: '覚悟と違う死に方をした侍',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、災いに遭って命を落とした。刀を抜くこともない、あっけない最期だった。'
        '若い日に覚悟していた死に方とは、まるで違う。'
        'それでも、人を斬らずに済む世の死に方だと、朋輩は墓の前で言い合った。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'j_hei_sai',
    way: 'castle',
    kinds: {'sai'},
    tier: Tier.common,
    title: '災いの帳面に一行で載った重臣',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、不意の災いで世を去った。城を預かる身には、敵よりも火事と大水のほうが恐ろしい世になっていた。'
        '{名}の死は帳面に一行で記され、役目はその日のうちに次の者へ引き継がれた。'
        '家は、何事もなく続いた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'f_hei_sai',
    way: 'woman',
    kinds: {'sai'},
    tier: Tier.common,
    title: '書きかけの文を残した女',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、思いがけぬ災いに呑まれた。攻め寄せる軍勢を恐れずに眠れる世になっても、火と水は昔のままだった。'
        'あとには、畳んだままの小袖と、書きかけの文が残った。'
        '宛名の主は、その文を長く手放さなかったという。',
    cond: _peace,
    spec: 2,
  ),

  // ---------------- 行方知れず（戦の絶えた世の受け皿） ----------------
  EndingDef(
    id: 'v_hei_yukue',
    way: 'village',
    kinds: {'yukue'},
    tier: Tier.common,
    title: '帳面に名だけ残した人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、ふいに村から姿を消した。村の帳面には、いまも{名}の名が残っている。'
        '消すに消せず、村の役の者は毎年、同じ名を書き写した。'
        '戦にさらわれる者のいない世で、人がいなくなる訳を、村の誰も思いつけなかった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'm_hei_yukue',
    way: 'merchant',
    kinds: {'yukue'},
    tier: Tier.common,
    title: '良い品を見つけたまま戻らぬ商人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、商いの旅に出たまま戻らなかった。街道が静かになり、山賊の噂も減った世のことだ。'
        '店では、{名}の座る場所を空けたまま、帳面を付け続けた。'
        '旅先からの最後の文には、良い品を見つけたとだけ書いてあった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'p_hei_yukue',
    way: 'priest',
    kinds: {'yukue'},
    tier: Tier.common,
    title: '円座を残して消えた人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、寺を出たきり戻らなかった。行き先を尋ねた者には、ただ山のほうを指したという。'
        '寺では、{名}の座っていた円座を片付けずにおいた。'
        'いまも朝の勤めの前に、誰かがそこの埃を払っている。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 's_hei_yukue',
    way: 'shadow',
    kinds: {'yukue'},
    tier: Tier.common,
    title: '改めの世に足取りを消した者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、誰にも告げずに姿を消した。'
        '関所が立ち、宿ごとに人を改める世で、足取りを残さずに消えるのは容易なことではない。{名}は、それをやってのけた。'
        '生きているのか死んだのか、確かめられた者はいない。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'b_hei_yukue',
    way: 'samurai',
    kinds: {'yukue'},
    tier: Tier.common,
    title: '刀を置いて消えた侍',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、ある朝、ふいに姿を消した。刀と具足は、きちんと並べて置いてあった。'
        '戦のない世に、己の使い道を見つけられなかったのだろうと、朋輩は噂した。'
        '届けを書く者は、「欠け落ち」の字を、長いこと書きあぐねた。',
    cond: _peace,
    spec: 2,
  ),

  // ---------------- 飢え（戦の絶えた世の受け皿） ----------------
  EndingDef(
    id: 'v_hei_ue',
    way: 'village',
    kinds: {'ue'},
    tier: Tier.common,
    title: '種籾に手を付けなかった人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、実りのない年に力尽きた。兵に米を奪われることのない世にも、冷たい夏と長雨は来る。'
        '年貢を納めた蔵の前を通るたび、{名}は黙って目を伏せた。'
        '最後の種籾には、とうとう手を付けなかった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'm_hei_ue',
    way: 'merchant',
    kinds: {'ue'},
    tier: Tier.common,
    title: '大福帳だけを枕元に残した商人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、食うものも尽きて世を去った。算盤の世は、しくじった者に冷たい。'
        '店をたたんで裏店に移ってからは、昔の得意先の前を避けて歩いた。'
        '枕元には、もう使うあてのない大福帳が、一冊だけ残っていた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'p_hei_ue',
    way: 'priest',
    kinds: {'ue'},
    tier: Tier.common,
    title: '己の椀を最後にした人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、飢えの年に痩せ衰えて逝った。寺に届いた施しの米は、門前に並ぶ者たちへ先に回した。'
        '己の椀は、いつも最後だった。'
        '「先に倒れてどうする」と叱った村の者が、亡骸を背負って山門をくぐった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 's_hei_ue',
    way: 'shadow',
    kinds: {'ue'},
    tier: Tier.common,
    title: '治まった世に居場所をなくした者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、道ばたの辻堂で飢えて死んだ。帳面に名のない者には、村の施しも回ってこない。'
        '乱れた世なら、紛れ込む場所はいくらでもあった。'
        '静かに治まった世は、{名}のような者から先に、居場所を奪っていった。',
    cond: _peace,
    spec: 2,
  ),

  // ---------------- 切腹や処刑（戦の絶えた世の受け皿） ----------------
  EndingDef(
    id: 'b_hei_seppuku',
    way: 'samurai',
    kinds: {'seppuku'},
    tier: Tier.common,
    title: '書付の世に裁かれた侍',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、裁きを受けて命を終えた。'
        '戦の世なら、槍一本の働きで帳消しになったかもしれない落ち度だった。いまは、書付と作法がすべてを決める。'
        '{名}は最後の朝、いつもどおりに髭を当たり、迎えの者を待った。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'j_hei_seppuku',
    way: 'castle',
    kinds: {'seppuku'},
    tier: Tier.common,
    title: '家の咎を負って果てた重臣',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、咎を一身に負って果てた。誰かが責めを負わねば、家そのものが潰されかねない世になっていた。'
        '{名}は言い訳を一つもせず、後のことだけを細かに書き残した。'
        'その書付のおかげで、家は残った。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'd_hei_seppuku',
    way: 'daimyo',
    kinds: {'seppuku'},
    tier: Tier.common,
    title: '法度の前に果てた国主',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、上の裁きによって命を絶たれた。国を切り取った腕も、公儀の法度の前では何の役にも立たなかった。'
        '城を出る朝、{名}は門の前で一度だけ振り返った。'
        'その目に何が映っていたのかを、供の者は誰にも語らなかった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'f_hei_seppuku',
    way: 'woman',
    kinds: {'seppuku'},
    tier: Tier.common,
    title: '白い小袖で裁きを受けた女',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、裁きを受けて命を終えた。戦のない世にも、家の体面と法度は、人の命より重く扱われた。'
        '{名}は取り乱さず、髪を整え、白い小袖に着替えた。'
        'その落ち着きぶりを、立ち会った者は長く忘れなかった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'v_hei_seppuku',
    way: 'village',
    kinds: {'seppuku'},
    tier: Tier.common,
    title: '竹矢来の外に村が並んだ人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、仕置きを受けて命を落とした。高札の文字は、読めぬ者にも容赦なく当てはめられる。'
        '刑場の竹矢来の外には、村の者が黙って並んだ。'
        '誰も声を上げなかったが、その夜、{名}の家の戸口には、握り飯がいくつも置かれていた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 's_hei_seppuku',
    way: 'shadow',
    kinds: {'seppuku'},
    tier: Tier.common,
    title: '逃げ場のない世に捕らえられた者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、捕らえられて仕置きを受けた。乱世なら、国境を一つ越えれば追手は止まった。'
        'いまは、どの国へ逃げても同じ触れが回っている。'
        '縄を打たれた{名}は、捕り方の手際を、妙に感心した顔で眺めていたという。',
    cond: _peace,
    spec: 2,
  ),

  // ---------------- 暗殺（戦の絶えた世の受け皿） ----------------
  EndingDef(
    id: 'b_hei_ansatsu',
    way: 'samurai',
    kinds: {'ansatsu'},
    tier: Tier.common,
    title: '傷の数まで帳面に記された侍',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、何者かの刃に倒れた。戦のない世にも、遺恨と喧嘩は残っている。'
        '届けを受けた役人は、刻限と場所と傷の数を、細かに帳面に記した。'
        '戦場での死なら、誰も数えなかったことばかりだった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'j_hei_ansatsu',
    way: 'castle',
    kinds: {'ansatsu'},
    tier: Tier.common,
    title: '頓死と記された重臣',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、闇のなかで命を奪われた。合戦のなくなった家中では、争いは評定の裏と夜道で片が付く。'
        '下手人は挙がらず、家の記録には「頓死」とだけ書かれた。'
        '誰が得をしたのかは、家中の者ならみな知っていた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'd_hei_ansatsu',
    way: 'daimyo',
    kinds: {'ansatsu'},
    tier: Tier.common,
    title: '病死と届けられた国主',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、不意に命を奪われた。上へは、病による急な死と届けられた。'
        'まことの次第が知れれば、家が取り潰されかねない。'
        '{名}の死の訳は、家の者たちの手で、固く封じられた。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 'm_hei_ansatsu',
    way: 'merchant',
    kinds: {'ansatsu'},
    tier: Tier.common,
    title: '算盤の恨みに倒れた商人',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、夜道で刃に倒れた。懐の銭は、そのままだった。'
        '物取りではなく、商いの恨みだろうと、町の者は囁き合った。'
        '算盤で人を泣かせることもできる世になったのだと、{名}は知っていたはずだった。',
    cond: _peace,
    spec: 2,
  ),
  EndingDef(
    id: 's_hei_ansatsu',
    way: 'shadow',
    kinds: {'ansatsu'},
    tier: Tier.common,
    title: '昔の因縁に追いつかれた者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、人知れず刃に倒れた。昔の因縁が、長い歳月をかけて追いついたらしい。'
        '堅い世になるほど、古い貸し借りを覚えている者は執念深い。'
        '亡骸は、名もなき行き倒れとして、村はずれに葬られた。',
    cond: _peace,
    spec: 2,
  ),

  // ---------------- 泰平の世の戦（大坂の陣・島原） ----------------
  EndingDef(
    id: 'b_hei_osaka_east',
    way: 'samurai',
    kinds: {'senshi'},
    tier: Tier.uncommon,
    title: '最後の戦で先手に倒れた侍',
    text:
        '{年}年、大坂。{歳}歳の{名}は、徳川方として城に取りつき、討たれた。これが最後の戦になると、陣中の誰もが知っていた。'
        '手柄を立てる折は、もう二度と来ない。'
        'そう思って踏み出した一歩が、{名}の最後の一歩になった。',
    cond: (g) => _dead(g, '徳川方として討死'),
    spec: 8,
  ),
  EndingDef(
    id: 'b_hei_osaka_toyotomi',
    way: 'samurai',
    kinds: {'senshi'},
    tier: Tier.rare,
    title: '主家とともに果てた豊臣の臣',
    text:
        '{年}年、大坂。{歳}歳の{名}は、豊臣の家臣として、城門の内で討死した。降る道も、刀を置く道もあった。'
        'それでも{名}は、禄を食んだ家の最後を見届けるほうを選んだ。'
        '城が燃え落ちたとき、太閤の築いた世も、ともに灰になった。',
    cond: (g) => _dead(g, '豊臣の家臣として討死'),
    spec: 8,
  ),
  EndingDef(
    id: 'b_hei_osaka_kizu',
    way: 'samurai',
    kinds: {'senshi'},
    tier: Tier.rare,
    title: '落ち延びた先で息絶えた牢人',
    text:
        '{年}年、{歳}歳の{名}は、大坂の城を落ち延びたのち、傷がもとで息絶えた。'
        '川筋の葦の陰で、燃える天守の明かりを、最後まで見ていたという。'
        '名を変えて生き直す道もあったはずだった。だが傷は、それを待ってはくれなかった。',
    cond: (g) => _dead(g, '夏の陣の傷がもとで'),
    spec: 8,
  ),
  EndingDef(
    id: 'j_hei_osaka',
    way: 'castle',
    kinds: {'senshi'},
    tier: Tier.rare,
    title: '最後の大戦に散った将',
    text:
        '{年}年、大坂。{歳}歳の{名}は、天下の最後の大戦で命を落とした。かつては自らも兵を率いた身である。'
        '攻める側も守る側も、これで戦の世が終わると知っていた。'
        '{名}の名は、敵味方の討死を記した長い帳面の、中ほどに載っている。',
    cond: (g) => _dead(g, '大坂'),
    spec: 8,
  ),
  EndingDef(
    id: 'b_hei_shimabara',
    way: 'samurai',
    kinds: {'senshi'},
    tier: Tier.rare,
    title: '久方ぶりの戦場に斃れた古強者',
    text:
        '{年}年、島原。{歳}歳の{名}は、原の古城の石垣に取りつき、討たれた。'
        'まわりの若い侍にとっては初めての戦で、{名}にとっては久方ぶりの戦場だった。戦を知る者の務めとして、誰よりも先に立った。'
        '戦を知らぬ者たちが、その亡骸を担いで下がった。',
    cond: (g) => _dead(g, '島原の一揆攻めで討死'),
    spec: 8,
  ),
  EndingDef(
    id: 'j_hei_shimabara',
    way: 'castle',
    kinds: {'senshi'},
    tier: Tier.rare,
    title: '原の古城の石垣で果てた老将',
    text:
        '{年}年、島原。{歳}歳の{名}は、原の古城を攻める陣で命を落とした。戦を知らぬ者ばかりの軍勢のなかで、{名}の白髪は目立った。'
        '城方は鍬や鎌まで手に取り、死を恐れなかった。'
        'これは昔の戦とは違うと、{名}は最後に悟ったかもしれない。',
    cond: (g) => _dead(g, '島原の一揆攻めで討死'),
    spec: 8,
  ),

  // ---------------- 追腹・禁教・越訴・磔（泰平の岐路の死） ----------------
  EndingDef(
    id: 'b_hei_oibara',
    way: 'samurai',
    kinds: {'seppuku'},
    tier: Tier.uncommon,
    title: '殿の墓へ向いて腹を切った侍',
    text:
        '{年}年、{歳}歳の{名}は、亡き殿の後を追って腹を切った。戦場で殿の馬前に死ぬ折は、ついに来なかった。'
        '戦のない世に残された忠義の示し方は、もうこれしかないと、{名}は思い定めた。'
        '菩提寺の庭の白い布は、殿の墓のほうを向いて敷かれていた。',
    cond: (g) => _dead(g, '追腹を切った'),
    spec: 7,
  ),
  EndingDef(
    id: 'j_hei_oibara',
    way: 'castle',
    kinds: {'seppuku'},
    tier: Tier.uncommon,
    title: '主君の墓の脇に眠る重臣',
    text:
        '{年}年、{歳}歳の{名}は、亡き主君の後を追い、追腹を切った。長い歳月、同じ家の浮き沈みをともにした主従だった。'
        '「あちらでも、お供がおらねば困られよう」。'
        'そう言い残した{名}の墓は、主君の墓のすぐ脇に、一回り小さく建っている。',
    cond: (g) => _dead(g, '追腹を切った'),
    spec: 7,
  ),
  EndingDef(
    id: 'f_hei_junkyo',
    way: 'woman',
    kinds: {'seppuku'},
    tier: Tier.rare,
    title: '祈りの言葉とともに果てた女',
    text:
        '{年}年、{歳}歳の{名}は、教えを棄てずに刑場へ引かれた。棄てると一言いえば、家に帰れた。役人は幾度もそう勧めた。'
        '{名}は首を横に振り、最後まで祈りの言葉を口にしていた。'
        'その言葉の意味を、見物の者は誰も知らなかった。',
    cond: (g) => _dead(g, '信者として'),
    spec: 8,
  ),
  EndingDef(
    id: 'b_hei_junkyo',
    way: 'samurai',
    kinds: {'seppuku'},
    tier: Tier.rare,
    title: '縄を打たれても背を伸ばしていた信者',
    text:
        '{年}年、{歳}歳の{名}は、信者として刑場に果てた。主家への奉公と、天の主への信心とは、{名}の胸の内では少しも食い違っていなかった。'
        '食い違うと決めたのは、世のほうだった。'
        '刀を取り上げられ、縄を打たれても、{名}は背筋を伸ばしていた。',
    cond: (g) => _dead(g, '信者として'),
    spec: 8,
  ),
  EndingDef(
    id: 'j_hei_junkyo',
    way: 'castle',
    kinds: {'seppuku'},
    tier: Tier.rare,
    title: '禄より教えを選んだ重臣',
    text:
        '{年}年、{歳}歳の{名}は、禁じられた教えを棄てず、裁きを受けた。城を預かったほどの身である。棄てたと届けるだけで、家も禄も守れた。'
        '{名}は、家の後のことを記した書付だけを残し、自らは教えのほうを選んだ。'
        '祈りの数珠は、土の下へ持っていった。',
    cond: (g) => _dead(g, '信者として'),
    spec: 8,
  ),
  EndingDef(
    id: 'v_hei_junkyo',
    way: 'village',
    kinds: {'seppuku'},
    tier: Tier.rare,
    title: '村に小さな灯を残した信者',
    text:
        '{年}年、{歳}歳の{名}は、信者として命を絶たれた。村の者は、{名}がいつ異国の教えに帰依したのかも、よく知らなかった。'
        'ただ、分け隔てなく人の世話を焼く者だったことは、誰もが覚えている。'
        'その夜、村の幾軒かで、戸を閉ざして小さな灯がともされた。',
    cond: (g) => _dead(g, '信者として'),
    spec: 8,
  ),
  EndingDef(
    id: 'v_hei_osso',
    way: 'village',
    kinds: {'seppuku'},
    tier: Tier.rare,
    title: '村を救って祠に祀られた頭取',
    text:
        '{年}年、{歳}歳の{名}は、村の年貢を減らすよう上の役所へ直に訴え、頭取として仕置きを受けた。訴えは取り上げられ、村は冬を越した。'
        '法度を破った者は罰し、願いの中身は聞き届ける。それが、この世の裁きだった。'
        '村はずれの小さな祠に、{名}の名が祀られている。',
    cond: (g) => _dead(g, '越訴し、頭取として'),
    spec: 8,
  ),
  EndingDef(
    id: 's_hei_kurayaburi',
    way: 'shadow',
    kinds: {'seppuku'},
    tier: Tier.uncommon,
    title: '技を盗みに使い切った忍び',
    text:
        '{年}年、{歳}歳の{名}は、大店の蔵を破って捕らえられ、磔になった。城の奥へ忍び入るための技も、戦のない世では、ただの盗みの腕でしかない。'
        '捕り方の提灯に囲まれたとき、{名}は屋根の上で、少し笑ったという。'
        '久しぶりに、技を使い切った夜だった。',
    cond: (g) => _dead(g, '忍びの技で蔵を破り'),
    spec: 8,
  ),
  EndingDef(
    id: 's_hei_sekisho',
    way: 'shadow',
    kinds: {'seppuku'},
    tier: Tier.uncommon,
    title: '抜け道を歩き続けた流れ者',
    text:
        '{年}年、{歳}歳の{名}は、関所破りの咎で磔になった。山の抜け道なら、土地の者より詳しかった。'
        '国境に柵のなかった頃から、そうして歩いてきたのだ。道は昔のままでも、通ってはならぬ世に変わっていた。'
        '{名}は、それを最後まで呑み込めなかった。',
    cond: (g) => _dead(g, '関所破りの咎で'),
    spec: 8,
  ),

  // ---------------- 敵討ち・かぶき者・用心棒・大火・飢饉（泰平の岐路の死） ----------------
  EndingDef(
    id: 'b_hei_kaeriuchi',
    way: 'samurai',
    kinds: {'ansatsu'},
    tier: Tier.rare,
    title: '敵討ちの旅の果てに倒れた侍',
    text:
        '{年}年、{歳}歳の{名}は、弟の敵を追う旅の果てに立ち合い、返り討ちに遭った。届けを出して国を出てから、長い旅だった。'
        '敵もまた、逃げ疲れていた。踏み込んだ足が砂利に滑らなければ、どちらが倒れていたかは分からない。'
        '敵討ちの届けの帳面は、そこで閉じられた。',
    cond: (g) => _dead(g, '返り討ちに遭った'),
    spec: 8,
  ),
  EndingDef(
    id: 'b_hei_kabuki',
    way: 'samurai',
    kinds: {'ansatsu'},
    tier: Tier.uncommon,
    title: '飾りの刀に斬られた侍',
    text:
        '{年}年、{歳}歳の{名}は、辻でかぶき者の喧嘩に巻き込まれ、斬られた。戦に遅れて生まれ、暴れる場所のない若い者たちだった。'
        '戦の世を見てきた{名}には、その長い刀が、ただの飾りに見えた。'
        'その油断を、後ろの一人が斬った。',
    cond: (g) => _dead(g, 'かぶき者の喧嘩に巻き込まれ'),
    spec: 7,
  ),
  EndingDef(
    id: 'b_hei_yojinbo',
    way: 'samurai',
    kinds: {'ansatsu'},
    tier: Tier.uncommon,
    title: '日銭で腕を売った牢人',
    text:
        '{年}年、{歳}歳の{名}は、用心棒に雇われた先の揉め事で、刃に倒れた。主を失った侍の腕は、賭場と商家が日銭で買う。'
        '槍一筋で禄を取った日々は、遠い昔になっていた。'
        '亡骸を引き取りに来た者は、いなかった。',
    cond: (g) => _dead(g, '用心棒に雇われ'),
    spec: 7,
  ),
  EndingDef(
    id: 'm_hei_kaji',
    way: 'merchant',
    kinds: {'sai'},
    tier: Tier.uncommon,
    title: '証文を抱えて煙に巻かれた商人',
    text:
        '{年}年、{歳}歳の{名}は、大火の夜、蔵へ荷を取りに戻って煙に巻かれた。乱世の火をくぐり抜けた身が、町の火事で命を落とした。'
        '焼け跡から、{名}が抱えていた帳箱が見つかった。'
        '中の証文は、一枚も焦げていなかった。',
    cond: (g) => _dead(g, '蔵へ荷を取りに戻り'),
    spec: 8,
  ),
  EndingDef(
    id: 'v_hei_wakachi',
    way: 'village',
    kinds: {'ue'},
    tier: Tier.rare,
    title: '最後の一握りを隣の子に渡した人',
    text:
        '{年}年、寛永の飢えの年。{歳}歳の{名}は、蓄えを村の者に分け尽くして力尽きた。最後の一握りは、隣の家の子に渡した。'
        '春になって、その子は生きていた。'
        '村では、{名}の田を皆で代わる代わる耕し、最初の刈り穂を墓に供えた。',
    cond: (g) => _dead(g, '蓄えを分け尽くして'),
    spec: 8,
  ),

  // ---------------- 足軽・侍（泰平の暮らし） ----------------
  EndingDef(
    id: 'b_hei_kanjo',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '算盤侍と笑われた勘定方',
    text:
        '{年}年、{名}は{歳}歳で世を去った。槍を置いて勘定方に移った日、朋輩は「算盤侍」と笑った。'
        'それから長い歳月、{名}は蔵米の出入りを、一俵の狂いもなく帳面に合わせ続けた。'
        '笑った者たちの家の借銀を、黙って繰り延べてやったのも{名}だった。',
    cond: (g) => _peace(g) && _f(g, 'pl_kanjo'),
    spec: 6,
  ),
  EndingDef(
    id: 'b_hei_dojo',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '人を討つ技を型に変えた師範',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。人を討つために覚えた技を、{名}は道場で、身を修める型に作り替えて教えた。'
        '弟子たちは、型の一つ一つがどんな場で生まれたのかを知らない。知らぬまま、朝ごとに木刀を振っている。'
        'それが{名}の望みだった。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pl_dojo_jitsu') ||
            _f(g, 'pl_dojo_kata') ||
            _f(g, 'pl_dojo_open') ||
            _f(g, 'pc_dojo')),
    spec: 6,
  ),
  EndingDef(
    id: 'b_hei_tenarai',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '覚えたての字で送られた牢人',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。主家を離れてからは、裏店で町の子らに読み書きを教えて暮らした。'
        '子らは{名}を「お師匠さま」と呼び、刀を差していた頃のことは知らない。'
        '弔いには、筆を覚えた子らが、覚えたての字で名を書いた紙を持って集まった。',
    cond: (g) => _peace(g) && _f(g, 'pc_ronin_tenarai'),
    spec: 7,
  ),
  EndingDef(
    id: 'b_hei_west',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.rare,
    title: '西軍の昔をようやく語れた男',
    text:
        '{年}年、{名}は{歳}歳で世を去った。関ヶ原で敗れた側にいたことを、{名}は長いあいだ、誰にも語らなかった。語れば障りのある世だった。'
        '年の離れた若い者に訊かれて初めて口を開いたとき、聞き手にはもう、東も西もただの昔話でしかなかった。'
        '{名}は拍子抜けして、それから声を上げて笑った。',
    cond: (g) => _taihei(g) && _p(g, '関ヶ原で西軍に加わり、敗れて'),
    spec: 7,
  ),
  EndingDef(
    id: 'b_hei_kataki',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '敵の背を見て刀を収めた侍',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。弟の敵を見つけながら、刀を収めて帰った男である。臆したと言う者もいた。{名}は言い訳をしなかった。'
        'やつれた敵の背を見たあの日、斬るべきものはもう何も残っていなかった。'
        '晩年に一度だけ、{名}はそう語ったという。',
    cond: (g) => _peace(g) && _f(g, 'pl_kataki_spared'),
    spec: 7,
  ),
  EndingDef(
    id: 'b_hei_bugu',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '具足を寺に納めて逝った侍',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。古い具足は、とうに寺へ納めてあった。'
        '敵も味方もなく、あの頃に死んだ者すべての供養を頼んでのことだ。'
        '具足櫃のあった床の間には、花でも活けておけと言い残した。',
    cond: (g) => _peace(g) && _f(g, 'pl_bugu_tera'),
    spec: 7,
  ),
  EndingDef(
    id: 'b_hei_katoku',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.common,
    title: '跡目の届けを済ませて逝った侍',
    text:
        '{年}年、{名}は{歳}歳で世を去った。跡目の届けは、とうに済ませてある。'
        '家を継ぐ者が戦で次々に欠けた世を知る身には、書付一枚で家が続くことが、いまだに不思議だった。'
        '枕元に座る跡継ぎの顔を確かめて、{名}は安んじて目を閉じた。',
    cond: (g) => _peace(g) && _f(g, 'pl_katoku_done') && g.l.kids > 0,
    spec: 5,
  ),
  EndingDef(
    id: 'b_hei_kikigaki',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.rare,
    title: '軍記の語らぬ戦を語り残した侍',
    text:
        '{年}年、{名}は{歳}歳で世を去った。軍記は、勝った者の手柄しか語らない。'
        '{名}は、泥と飢えと、逃げ惑う百姓のことを、ありのままに語り残した。聞いて顔を曇らせる者も多かった。'
        'その書付を、いまも時おり、誰かが読みに来る。',
    cond: (g) => _peace(g) && (_f(g, 'pl_kikigaki') || _f(g, 'pc_oboe_grim')),
    spec: 8,
  ),

  // ---------------- 城主・家老（泰平の暮らし） ----------------
  EndingDef(
    id: 'j_hei_rusui',
    way: 'castle',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '盃で家を守った留守居役',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。留守居役として、他家の同役と盃を交わし、噂を拾い、家に降りかかる火の粉を払い続けた。'
        '槍を振るうより、よほど骨の折れる務めだった。'
        '{名}の弔いには、諸家の留守居から、ずらりと香典が届いた。',
    cond: (g) => _peace(g) && _f(g, 'pl_rusui'),
    spec: 6,
  ),
  EndingDef(
    id: 'j_hei_fushin',
    way: 'castle',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '江戸の石垣に石を残した城主',
    text:
        '{年}年、{名}は{歳}歳で世を去った。江戸の城の石垣には、{名}の手勢が運び、積んだ石がいまも並んでいる。蔵を空にするほどの普請だった。'
        '城を落とすことばかり考えた若い日もあった。'
        'だが後の世に残ったのは、積んだほうの石だった。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pc_fushin_loyal') ||
            _f(g, 'pc_fushin_hands') ||
            _f(g, 'pc_fushin_built') ||
            _f(g, 'pc_fushin_thrift')),
    spec: 6,
  ),
  EndingDef(
    id: 'j_hei_kakun',
    way: 'castle',
    kinds: _calm,
    tier: Tier.uncommon,
    title: 'しくじりを家訓に書き残した重臣',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。書き上げた家訓には、勝ち戦の話が一つも出てこない。'
        '書いてあるのは、借銀の戒めと、人の使い方と、己のしくじりばかりである。'
        '家の者はそれを、年の初めごとに、皆の前で読み上げることになった。',
    cond: (g) =>
        _peace(g) && (_f(g, 'pl_kakun_shippai') || _f(g, 'pl_kakun_jitsu')),
    spec: 6,
  ),
  EndingDef(
    id: 'j_hei_east',
    way: 'castle',
    kinds: _calm,
    tier: Tier.common,
    title: '関ヶ原の朝の迷いを語らなかった城主',
    text:
        '{年}年、{名}は{歳}歳で世を去った。関ヶ原で、勝った側についた。その一日の選びが、家のその後をすべて決めた。'
        'あの朝、霧のなかで迷ったことを、{名}は誰にも話さなかった。'
        '話さぬまま、選び損ねた家々が消えていくのを、長い歳月、黙って見てきた。',
    cond: (g) => _taihei(g) && _real(g) && _p(g, '関ヶ原で東軍に加わった'),
    spec: 5,
  ),

  // ---------------- 大名（泰平の暮らし） ----------------
  EndingDef(
    id: 'd_hei_ikkoku',
    way: 'daimyo',
    kinds: _calm,
    tier: Tier.rare,
    title: '支城の石を堤に積ませた国主',
    text:
        '{年}年、{名}は{歳}歳で世を去った。一つの国に城は一つと触れが出た年、{名}は、幾度も攻め手を退けた支城を、自らの命で壊させた。'
        '石垣の石は、川の堤に積み直された。'
        '攻め手を防ぐはずだった石が、いまは大水から田を守っている。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pc_ikkoku_obeyed') || _f(g, 'pc_ikkoku_farewell')),
    spec: 6,
  ),

  // ---------------- 商いの道（泰平の暮らし） ----------------
  EndingDef(
    id: 'm_hei_kaisen',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '風向きを尋ねて逝った廻船の商人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。遠国の品を船に積み、海賊の出なくなった海を、季節ごとに行き来させた。'
        '臨終の床でも、{名}は風向きを尋ねた。'
        '船が港に入ったと聞いて、うなずき、それきり目を開けなかった。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pl_funamochi') ||
            _f(g, 'pl_kaisen_momen') ||
            _f(g, 'pl_kaisen_kome') ||
            _f(g, 'pc_kaisen')),
    spec: 6,
  ),
  EndingDef(
    id: 'm_hei_yakeato',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.rare,
    title: '焼け跡で取り立てを待った商人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。大火のあと、{名}は掛けの取り立てを待ち、焼け出された得意先が立ち直るのを助けた。'
        '損な商いだと笑う者もいた。'
        '弔いの日、店の前の通りは、あの焼け跡から立ち直った者たちで埋まった。',
    cond: (g) => _peace(g) && _f(g, 'pl_saiken_trust'),
    spec: 7,
  ),
  EndingDef(
    id: 'm_hei_kura',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '大名に利息を払わせた商人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。大名家の米と銀を扱う身になってから、刀を差した者たちが、{名}の店の座敷で頭を下げるようになった。'
        '若い日には、同じ刀に怯えて荷を隠したものだった。'
        '{名}は誰にも威張らず、利息だけはきちんと取った。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pc_kuramoto') ||
            _f(g, 'pc_daimyo_kashi') ||
            _f(g, 'pc_osaka_kura')),
    spec: 6,
  ),

  // ---------------- 村の暮らし（泰平の暮らし） ----------------
  EndingDef(
    id: 'v_hei_shinden',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '拓いた田を焼かれずに済んだ百姓',
    text:
        '{年}年、{名}は{歳}歳で世を去った。藪と石ばかりだった土地は、いま、見渡すかぎりの田になっている。'
        '拓いた田は、戦で焼かれることも、踏み荒らされることもなかった。'
        '最初の実りを手に乗せた日の重さを、{名}は生涯の自慢にしていた。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pl_shinden_kawa') ||
            _f(g, 'pl_shinden_yama') ||
            _f(g, 'pl_shinden_own') ||
            _f(g, 'pl_shinden_furuta') ||
            _f(g, 'pc_shinden_mura')),
    spec: 6,
  ),
  EndingDef(
    id: 'v_hei_yosui',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '当たり前になった水を引いた人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。村に水を引く普請があったのは、もうずいぶん前のことになる。'
        'いまでは、用水のなかった頃を知る者のほうが少ない。水は当たり前の顔をして田を流れている。'
        'それでよいのだと、{名}は堰の音を聞きながら言っていた。',
    cond: (g) => _peace(g) && _f(g, 'pl_yosui'),
    spec: 6,
  ),
  EndingDef(
    id: 'v_hei_ko',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '旅の話の尽きなかった代参の人',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。講の旅で、生まれて初めて、遠い国の道を歩いた。'
        '戦の世なら、村を出るのは、逃げるときか連れて行かれるときだけだった。道中の話は、何度語っても種が尽きなかった。'
        '村の者は、次に旅立つ者に、{名}の笠を持たせた。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pl_ko_daisan') ||
            _f(g, 'pl_ko_kenbutsu') ||
            _f(g, 'pl_ko_tane')),
    spec: 6,
  ),
  EndingDef(
    id: 'v_hei_yakunin',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '帳面の世の村役人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。村の役を引き受けてからは、年貢の割り付けも、水の番も、寄合の揉め事も、みな{名}のところへ持ち込まれた。'
        '槍を持った者に頭を下げた昔より、帳面を持った者に頭を下げるいまのほうが、まだ話は通じる。'
        'そう言って、{名}はよく笑っていた。',
    cond: (g) => _peace(g) && _f(g, 'pl_yakunin'),
    spec: 6,
  ),
  EndingDef(
    id: 'v_hei_hatago',
    way: 'village',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '旅人を見送り続けた街道の女',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。街道の端で、旅の者に茶と飯を出し続けた。'
        '軍勢ではなく、参詣の講や、商人や、飛脚の通る道だった。「道中ご無事で」と見送った客は数えきれない。'
        '{名}の野辺送りの日、宿場の者は街道に出て、同じ言葉をかけた。',
    cond: (g) =>
        _peace(g) &&
        g.l.female &&
        (_f(g, 'pc_hatago') || _f(g, 'pc_chamise')),
    spec: 6,
  ),

  // ---------------- 仏門（泰平の暮らし） ----------------
  EndingDef(
    id: 'p_hei_gakuryo',
    way: 'priest',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '書き込みだらけの経本を遺した人',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。戦のない世の寺は、学びの場になった。'
        '{名}は宗の学びに打ち込み、老いても若い者と机を並べた。薙刀を取る僧兵の時代は、とうに終わっている。'
        '書き込みで真っ黒になった{名}の経本は、弟子たちが形見に分け合った。',
    cond: (g) => _peace(g) && (_f(g, 'pl_gakuryo') || _f(g, 'pc_gakuryo')),
    spec: 6,
  ),
  EndingDef(
    id: 'p_hei_tomurai',
    way: 'priest',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '布施を問わずに弔った人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。布施を出せぬ家の葬いも、{名}は同じ経で、同じ長さだけ弔った。'
        '乱世には、弔われぬまま野に朽ちた者を、あまりに多く見た。'
        '畳の上で逝ける世になったのなら、送るほうも手は抜けない。それが口癖だった。',
    cond: (g) =>
        _peace(g) && (_f(g, 'pl_tomurai_free') || _f(g, 'pl_tomurai_ko')),
    spec: 6,
  ),
  EndingDef(
    id: 'p_hei_moto',
    way: 'priest',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '討った者の名を唱え続けた元侍の僧',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。若い日は槍を取り、人を討った身である。'
        '髪を下ろしてからは、討った者の名を唱える朝の勤めを、最後まで欠かさなかった。'
        '「あの者らも、畳の上で死にたかったろう」。それが、{名}の最後の言葉だった。',
    cond: (g) => _taihei(g) && !g.l.female && _f(g, 'first_battle'),
    spec: 5,
  ),

  // ---------------- 忍び・流れ者・野盗（泰平の暮らし） ----------------
  EndingDef(
    id: 's_hei_banshi',
    way: 'shadow',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '何事もない夜を数えた番士',
    text:
        '{年}年、{名}は{歳}歳で世を去った。江戸の城の番士として、門と塀と夜の庭を見回る歳月だった。忍び入る者は、ついに一人も現れなかった。'
        '塀のどこが越えやすいかを誰より知りながら、何事もない夜を数えて老いた。'
        'それを{名}は、悪くない務めだと言っていた。',
    cond: (g) => _peace(g) && _f(g, 'pc_banshi'),
    spec: 7,
  ),
  EndingDef(
    id: 's_hei_katagi',
    way: 'shadow',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '帳面に名を載せて逝った者',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。流れる暮らしをやめ、帳面に名を載せてからは、同じ土地で、同じ顔ぶれと歳を重ねた。'
        '朝に戸を開けると、挨拶を返してくれる者がいる。それだけのことに慣れるまで、{名}は幾年もかかった。'
        '弔いは、近所の者が出した。',
    cond: (g) =>
        _peace(g) &&
        (_f(g, 'pl_katagi') || _f(g, 'pc_settled') || _f(g, 'pc_teraotoko')),
    spec: 6,
  ),
  EndingDef(
    id: 's_hei_waza',
    way: 'shadow',
    kinds: _calm,
    tier: Tier.rare,
    title: '使わぬ技を伝えた忍び',
    text:
        '{年}年、{名}は{歳}歳で世を去った。使う当てのない技を、{名}は次の代に残した。火の扱い、薬草の見分け、音を立てぬ歩き方。'
        '若い者たちはそれを、芸事のように習った。'
        '「使わずに済むのが、いちばんの上手だ」。{名}の教えは、いつもその一言で締めくくられていた。',
    cond: (g) =>
        _peace(g) && (_f(g, 'pl_waza_tsutae') || _f(g, 'pl_waza_mamori')),
    spec: 7,
  ),

  // ---------------- 女の道（泰平の暮らし） ----------------
  EndingDef(
    id: 'f_hei_wed',
    way: 'woman',
    kinds: _calm,
    tier: Tier.common,
    title: '嫁いだ娘の里であり続けた母',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。嫁いだ娘は、盆と正月には顔を見せた。'
        '敵になるかもしれぬ家へ、人質のように送り出したのではない。家の格と人柄を見て決めた縁だった。'
        '娘の文箱には、母からの文が、嫁いだ年から一通も欠けずにしまってある。',
    cond: (g) => _peace(g) && _f(g, 'pl_engumi_kaku') && _wedDaughter(g),
    spec: 5,
  ),
  EndingDef(
    id: 'f_hei_shinan',
    way: 'woman',
    kinds: _calm,
    tier: Tier.common,
    title: '行儀見習いの娘たちを送り出した女',
    text:
        '{年}年、{名}は{歳}歳で世を去った。奥へ行儀見習いに上がってくる娘たちに、立ち居振る舞いを教える歳月だった。'
        '人質でも、家の浮沈を背負うのでもなく、嫁入りの箔を付けに来る娘たちである。'
        '宿下がりした娘たちは、嫁ぎ先から折々に文をよこした。{名}はそれを、一通ずつ束ねて取っておいた。',
    cond: (g) => _peace(g) && _f(g, 'pl_oku_shinan'),
    spec: 4,
  ),
  EndingDef(
    id: 'f_hei_enkiri',
    way: 'woman',
    kinds: _calm,
    tier: Tier.common,
    title: '戸を叩けば開けてくれた女',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。夫から逃れてきた若い嫁を、{名}は見捨てなかった。'
        '戦の世には、女の行き先は家が決めた。戦が絶えても、それはあまり変わらない。'
        'それでも、戸を叩けば開けてくれる女が一人いると、近所の嫁たちは知っていた。弔いには、あの日の嫁も来ていた。',
    cond: (g) => _peace(g) && _f(g, 'pl_enkiri_helped'),
    spec: 4,
  ),
  EndingDef(
    id: 'f_hei_rusu',
    way: 'woman',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '勤めの留守を守り抜いた妻',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。夫が遠い勤めで家を空けるあいだ、機を織り、帳面を付け、家を回した。'
        '戦の留守なら、帰らぬ覚悟も要った。勤めの留守は、ただ長いだけである。'
        '戻ってきた夫が驚くほど、家の借銭は減っていた。',
    cond: (g) => _peace(g) && (_f(g, 'pl_rusu_hata') || _f(g, 'pl_rusu_cho')),
    spec: 5,
  ),
  EndingDef(
    id: 'f_hei_hoko',
    way: 'woman',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '御殿へ上げた娘を誇った母',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。御殿奉公に上がった娘は、見違えるほどの行儀を身に付けて宿下がりしてきた。'
        '畳の縁を踏まぬ歩き方を見て、{名}は笑い、少し寂しくもなった。'
        '人質に取られるのではなく、磨かれるために娘を出せる世を、{名}はありがたいと思っていた。',
    cond: (g) => _peace(g) && _f(g, 'pl_musume_hoko'),
    spec: 6,
  ),
  EndingDef(
    id: 'f_hei_kakure',
    way: 'woman',
    kinds: _calm,
    tier: Tier.rare,
    title: '納戸で祈り続けた女',
    text:
        '{年}年、{名}は{歳}歳で世を去った。寺の帳面には、檀家として名が載っている。'
        'だが夜ごと、納戸の奥で、禁じられた祈りを捧げ続けた。棄てたふりをして守るという道を、誰が責められよう。'
        '{名}の数珠は、仏のものと、もう一つ、帯の内側にあった。',
    cond: (g) => _peace(g) && _f(g, 'pc_kakure') && !_f(g, 'pc_confessor'),
    spec: 7,
  ),
  EndingDef(
    id: 'f_hei_haikai',
    way: 'woman',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '季節を詠むために季節を眺めた女',
    text:
        '{年}年、{名}は{歳}歳で世を去った。俳諧の座に連なり、句を詠むのが晩年の楽しみだった。'
        '乱世には、辞世のほかに歌を詠む暇など、なかなか持てなかった。'
        '季節を詠むためだけに、季節を眺めていられる。それが、{名}の泰平だった。',
    cond: (g) =>
        _peace(g) && (_f(g, 'pl_haikai_nyushu') || _f(g, 'pl_haikai_hokku')),
    spec: 5,
  ),

  // ---------------- 乱世を知る者の泰平（誰にでも起きる岐路の旗） ----------------
  EndingDef(
    id: 'b_hei_foe',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.common,
    title: 'かつての敵と盃を交わした侍',
    text:
        '{年}年、{名}は{歳}歳で世を去った。晩年の飲み仲間は、若い日に同じ戦場の向こう側にいた男だった。'
        'どちらの槍が先に逃げたかで、二人は盃を手に、幾度も言い争った。'
        '弔いの席で、その男は誰よりも長く、棺のそばに座っていた。',
    cond: (g) => _peace(g) && _f(g, 'pl_foe_sake'),
    spec: 5,
  ),
  EndingDef(
    id: 'b_hei_ando',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.common,
    title: '枕元の刀を片付けた侍',
    text:
        '{年}年、{名}は{歳}歳で静かに逝った。夜討ちに備えて枕元に刀を置く癖が、長いこと抜けなかった。'
        'ある年、それを納戸にしまった。物音で跳ね起きずに朝まで眠れるようになったのは、それからである。'
        '最期の夜も、{名}は深く眠ったまま、目を覚まさなかった。',
    cond: (g) => _peace(g) && _f(g, 'pl_ando'),
    spec: 4,
  ),
  EndingDef(
    id: 'b_hei_ronin',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.common,
    title: '仕官の口を待ち続けた牢人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。主家を離れてから、仕官の口はついに掛からなかった。戦がなければ、槍の腕を買う家もない。'
        'それでも{名}は、毎朝、刀の手入れだけは欠かさなかった。'
        '長屋の者は、その音で朝が来たのを知ったという。',
    cond: (g) => _peace(g) && _f(g, 'pc_ronin') && g.l.ronin,
    spec: 5,
  ),
  EndingDef(
    id: 'b_hei_saishikan',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '牢人から帰り咲いた侍',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。牢人の身から、もう一度召し抱えられた。禄は多くなく、役目も地味だった。'
        'それでも、帰る屋敷と仕える家があることの重さを、{名}は誰よりも知っていた。'
        '勤めを休んだ日は、ついに一日もなかったという。',
    cond: (g) => _peace(g) && _f(g, 'pl_saishikan_done'),
    spec: 6,
  ),
  EndingDef(
    id: 'b_hei_turned',
    way: 'samurai',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '太閤の恩を忘れたと言われ続けた侍',
    text:
        '{年}年、{名}は{歳}歳で世を去った。大坂の城を出て徳川に降ったあの日から、「太閤の恩を忘れた」という囁きは、ついに消えなかった。'
        '{名}は一度も言い返さなかった。家を残し、家の者を食わせた。'
        'それが己の選んだ忠義だと、胸の内で思い定めていた。',
    cond: (g) => _peace(g) && _f(g, 'pc_osaka_turned'),
    spec: 7,
  ),
  EndingDef(
    id: 'j_hei_young',
    way: 'castle',
    kinds: _calm,
    tier: Tier.common,
    title: '若い者に煙たがられた古参',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。戦を知らぬ若い者に、戦場の作法を叩き込もうとして、ずいぶん煙たがられた。'
        '使う折のない作法だと、{名}にも分かっていた。それでも、伝えずに済ますことはできなかった。'
        '弔いの日、若い者たちは、教わったとおりの作法で{名}を送った。',
    cond: (g) => _peace(g) && _f(g, 'pc_young_strict'),
    spec: 5,
  ),
  EndingDef(
    id: 'v_hei_ando',
    way: 'village',
    kinds: _calm,
    tier: Tier.common,
    title: '心張り棒を一本にして眠った人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。夜ごと戸に心張り棒を二本掛け、逃げるための荷をまとめて寝るのが、長い習いだった。'
        'ある年から、荷を解き、棒を一本にした。何も起こらぬ夜が、幾年も続いたからである。'
        'その静けさに慣れたころ、{名}の番が来た。',
    cond: (g) => _peace(g) && _f(g, 'pl_ando'),
    spec: 4,
  ),
  EndingDef(
    id: 'p_hei_kazoe',
    way: 'priest',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '死んだ者の名を数え続けた人',
    text:
        '{年}年、{名}は{歳}歳で世を去った。眠れぬ夜ごとに、乱世で死んだ者たちの名を数えるのが習いだった。'
        '身内、朋輩、名も知らぬまま弔った者。数は年ごとに増えこそすれ、減ることはない。'
        '最期の夜、数え終える前に、{名}は静かに眠りに落ちた。',
    cond: (g) => _peace(g) && _f(g, 'pl_kazoe'),
    spec: 6,
  ),
  EndingDef(
    id: 'm_hei_shibai',
    way: 'merchant',
    kinds: _calm,
    tier: Tier.uncommon,
    title: '桟敷で泰平を知った商人',
    text:
        '{年}年、{名}は{歳}歳で息を引き取った。商いの合間に、芝居町へ足を運ぶのを楽しみにしていた。'
        '舞台の上では、斬られた者が、幕のあとで起き上がる。それを笑って見ていられる世が来たのだと、{名}は桟敷で思ったという。'
        '贔屓の役者から、弔いに花が届いた。',
    cond: (g) => _peace(g) && _f(g, 'pl_shibai_hiiki'),
    spec: 5,
  ),

  // ---------------- 天下人（戦の絶えた世に天下を取った者） ----------------
  EndingDef(
    id: 't_hei_late',
    way: 'tenka',
    kinds: {'victory'},
    tier: Tier.phantom,
    title: '定まった天下を覆した者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、天下の過半をその手に収めた。大坂の城が落ち、誰もが戦の世は終わったと信じたあとのことである。'
        '定まったはずの天下を、{名}はただ一人、もう一度ひっくり返した。'
        '泰平は、{名}の名のもとに、初めからやり直されることになった。',
    cond: (g) => g.year >= 1616 && _real(g),
    spec: 5,
  ),
  EndingDef(
    id: 't_hei_line',
    way: 'tenka',
    kinds: {'victory'},
    tier: Tier.rare,
    title: '静まった世をもう一度束ねた者',
    text:
        '{年}年（{元号}）、{歳}歳の{名}は、天下の過半をその手に収めた。戦は絶えたと、誰もが思い始めた矢先だった。'
        'ようやく訪れた静けさを破ったのは{名}であり、それを前よりも固く結び直したのも{名}だった。'
        'この世の泰平は、{名}から数えられることになる。',
    cond: (g) => _peace(g) && !_real(g),
    spec: 4,
  ),
];
