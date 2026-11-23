import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 伏線の回収 その3（2026-11-23）。能力で起きる岐路（`tal_`、幼少期の `tal_c_` も）と
/// 寺社の願掛け（`ps_wish_*`）で立てた旗が、何年もあとに返ってくる岐路。
/// どれも一生に一度。旗を持つ人にだけ出るので、重みは `echoes_more.dart` と同じくらいにしてある。
/// id・新しい旗は `e3_` で始める。

int _c(int v) => clampInt(v, 0, 100);
int _s(int v) => clampInt(v, 0, 99);
void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;
void _down(Game g, int n) => g.l.net = g.l.net >= n ? g.l.net - n : 0;
void _fameDown(Game g, int n) => g.l.fame = g.l.fame >= n ? g.l.fame - n : 0;

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

/// 主家に仕える侍（戦える人。奥で仕える女性は除く）。
bool _samurai(Game g) => _retainer(g) && g.canFight;

/// 身分のない暮らし（仏門・野の道を除く）。
bool _commoner(Game g) => g.l.rank == 0 && g.active && !_monk(g) && !_outlaw(g);

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

/// 歩んだ道に、この言葉を含む一行があるか（同じ旗が違う場面で立つときの見分け）。
bool _walked(Game g, String word) => g.l.path.any((p) => p.contains(word));

List<SceneDef> buildEchoTalentScenes() => [
  // ------------------------------------------------------------------
  // 御前試合で家老の息子を打ち負かした（tal_karo_grudge）→ 家老の讒言。
  SceneDef(
    'e3_karo_grudge',
    22,
    60,
    (g) => 6,
    (g) => g.hasFlag('tal_karo_grudge') && _retainer(g),
    (g, next) {
      g.ask('家老の讒言', '御前試合であなたに打ち負かされた家老の息子は、あの日の恥を忘れていなかった。近ごろ父の家老が、「あの者は驕っております」と殿の耳に吹き込んでいるという。', [
        Choice.h('殿の前で身の潔白を述べる', '筋は通る。家老を相手にしては分が悪い', () {
          if (g.rng.chance(.35 + g.l.fav / 250)) {
            g.l.fav = _c(g.l.fav + 5);
            return '殿は黙って聞き、「その方の働きは見ておる」とだけ言った。';
          }
          g.l.fav = _c(g.l.fav - 8);
          return '言葉を尽くすほど、殿の目は冷たくなった。家老が、隅で薄く笑っていた。';
        }),
        Choice.h('家老の不始末を調べ上げて訴え出る', '家老を退けられるかもしれない。しくじれば、腹を切らされることもある', () {
          if (g.rng.chance(.4 + g.l.chi / 300)) {
            g.l.merit += 15;
            g.l.fav = _c(g.l.fav + 8);
            g.l.fame += 4;
            g.setFlag('e3_karo_fell');
            g.mark('御前試合以来の恨みを抱く家老の不始末を暴き、役から退かせた');
            return '家老が知行の米を横に流していた証を、殿の前に並べた。家老は隠居を命じられた。';
          }
          if (g.rng.chance(.08)) {
            g.die('恨みを抱く家老を訴え出てしくじり、讒言の罪を着せられて腹を切らされた', 'seppuku');
            return '証は、いつの間にかすり替えられていた。';
          }
          g.l.fav = _c(g.l.fav - 12);
          g.j(-4);
          return '証が足りなかった。「同じ家中の者を訴えるとは」と、殿は顔をしかめた。';
        }),
        Choice.h('家老の屋敷を訪ね、息子に頭を下げる', '恨みは和らぐかもしれない。家中では折れたと見られる', () {
          if (g.rng.chance(.55)) {
            g.l.net += 4;
            g.j(2);
            g.setFlag('e3_karo_peace');
            g.mark('御前試合で打ち負かした家老の息子と、盃を交わして和解した');
            return '息子は長いこと黙っていたが、やがて「あの一本は見事だった」と言った。';
          }
          _fameDown(g, 2);
          return '門前で待たされたまま、日が暮れた。家中に笑い話として広まった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 殿の寵を受けて同輩に妬まれた（tal_envied）→ 背を預けられない／濡れ衣。
  SceneDef(
    'e3_envied',
    22,
    60,
    (g) => 6,
    (g) => g.hasFlag('tal_envied') && _retainer(g),
    (g, next) {
      if (g.canFight) {
        g.ask('同輩の目', '殿の側近くに召されてから、同輩たちの目が冷たい。次の戦で、あなたの組の脇を固めるはずの同輩が、どうも当てにならないという噂だ。', [
          Choice.h('殿に陣の組み替えを願い出る', '背中は守られる。殿の寵を笠に着たと言われる', () {
            g.l.fav = _c(g.l.fav - 2);
            _down(g, 3);
            return '組み替えは許された。同輩たちの陰口は、かえって増えた。';
          }),
          Choice.h('同輩の陣を訪ね、酒を酌み交わす', '心が解ければ背を預けられる。解けなければ、戦場で一人になる', () {
            if (g.rng.chance(.5 + g.l.mi / 300)) {
              g.l.net += 5;
              g.j(3);
              g.setFlag('e3_envied_eased');
              g.mark('妬みを向けていた同輩と酒を酌み交わし、戦場で背を預け合った');
              return '夜更けまで飲んだ。翌朝の戦で、同輩の槍はあなたの脇を離れなかった。';
            }
            g.l.hp -= 15;
            return '盃は交わしたが、心は解けていなかった。戦場で脇が崩れ、手傷を負った。';
          }),
          Choice.h('構わず先駆けて、手柄で黙らせる', '手柄は大きい。脇が崩れれば、敵中に取り残される', () {
            if (g.rng.chance(.04)) {
              g.die('同輩の妬みで脇を固める兵が動かず、敵中に取り残されて討たれた', 'senshi');
              return '振り返ると、味方の旗が遠かった。';
            }
            g.l.merit += 20;
            g.l.fame += 4;
            g.l.hp -= 8;
            return '敵の旗を奪って戻った。同輩たちは、もう何も言わなかった。';
          }),
        ], after: next);
        return;
      }
      g.ask('奥の濡れ衣', '殿への取り次ぎを任されてから、奥の女中たちの目が冷たい。ある朝、奥方さまの櫛が失せ、それがあなたの部屋の近くで見つかったという。', [
        Choice.h('奥方さまに身の潔白を申し上げる', '信じてもらえるかは、日ごろの覚えしだい', () {
          if (g.rng.chance(.45 + g.l.fav / 200)) {
            g.l.fav = _c(g.l.fav + 4);
            return '奥方さまは「そなたがするはずがない」と言った。噂は止んだ。';
          }
          g.l.fav = _c(g.l.fav - 10);
          return '奥方さまは何も言わなかった。それきり、取り次ぎに呼ばれることが減った。';
        }),
        Choice.h('自ら櫛の行方を調べる', '真相が知れるかもしれない。奥に波風が立つ', () {
          if (g.rng.chance(.4 + g.l.chi / 250)) {
            g.l.fav = _c(g.l.fav + 6);
            g.l.fame += 2;
            g.setFlag('e3_envied_cleared');
            g.mark('奥で濡れ衣を着せられかけ、自ら調べて晴らした');
            return '櫛を置いた女中が見つかった。妬みからだったと、泣いて詫びた。';
          }
          _down(g, 3);
          return '誰が置いたのかは分からなかった。奥の空気が、いっそう重くなった。';
        }),
        Choice.h('取り次ぎの役を退く', '妬みはおさまる。殿の覚えは薄れる', () {
          g.l.fav = _c(g.l.fav - 8);
          g.l.net += 3;
          return '役を退くと、女中たちの態度が嘘のように和らいだ。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 殿の寵を受けた（tal_favorite）→ 殿が老い、若殿の側近に疎まれる。
  SceneDef(
    'e3_favorite',
    28,
    65,
    (g) => 5,
    (g) => g.hasFlag('tal_favorite') && _retainer(g),
    (g, next) {
      g.ask('代替わりの気配', 'あなたを側近くに置いた殿も、年を取った。家中では、若殿の代を見越して人が動きはじめている。先代の寵を受けた者を、若殿の側近は快く思っていない。', [
        Choice.h('若殿にも変わらぬ心で仕える', '時はかかる。認められれば、二代に仕える身になる', () {
          if (g.rng.chance(.5 + g.l.mi / 300)) {
            g.l.fav = _c(g.l.fav + 5);
            g.l.net += 3;
            g.setFlag('e3_two_lords');
            g.mark('殿の寵を受けた身で、若殿にも変わらぬ心で仕えた');
            return 'ある日、若殿が「父上がその方を頼みにした訳が分かった」と言った。';
          }
          g.l.fav = _c(g.l.fav - 6);
          return '若殿の側近は、あなたの言葉をことごとく遮った。';
        }),
        Choice.h('役を返上して、目立たぬ務めに移る', '静かに勤められる。家中での重みは手放す', () {
          g.l.fav = _c(g.l.fav - 5);
          g.j(4);
          return '殿は寂しそうに頷いた。肩の荷が下りた。';
        }),
        Choice.h('殿の寵を頼みに、若殿の側近と張り合う', '殿の在るうちは強い。代が替われば、ただでは済まない', () {
          if (g.rng.chance(.05)) {
            g.die('先代の寵を頼みに若殿の側近と張り合い、代替わりののち腹を切らされた', 'seppuku');
            return '殿が倒れたのは、その冬のことだった。';
          }
          g.l.fav = _c(g.l.fav + 6);
          g.l.merit += 8;
          g.j(-3);
          return 'いまは殿が後ろにいる。若殿の側近の目が、日ごとに鋭くなる。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 賭場で証文に指を押した（tal_gamble_debt）→ 取り立てが来る。
  SceneDef(
    'e3_gamble_debt',
    18,
    65,
    (g) => 6,
    (g) => g.hasFlag('tal_gamble_debt') && g.active && !_monk(g),
    (g, next) {
      g.ask('賭場の取り立て', 'あの夜の賭場で指を押した証文を手に、胴元の手下が戸口に立った。「利が利を生みましてな。今日こそ、耳を揃えていただきます」', [
        Choice.h('家財を売って返す', '借りはなくなる。暮らしは苦しくなる', () {
          _pay(g, 15);
          g.j(-3);
          g.setFlag('e3_debt_paid');
          g.mark('賭場で背負った借りを、家財を売って返し終えた');
          return '鍋も着物も売った。手下は証文を破って帰っていった。';
        }),
        if (g.canFight)
          Choice.h('胴元の頼む荒事を一つ引き受け、帳消しにする', '借りは消える。危うい橋を渡ることになる', () {
            if (g.rng.chance(.05)) {
              g.die('賭場の借りを帳消しにするため胴元の荒事を引き受け、斬り合いで命を落とした', 'sai');
              return '相手は、聞いていたより多かった。';
            }
            if (g.rng.chance(.55)) {
              g.j(-4);
              g.setFlag('e3_debt_job');
              return '借りは消えた。誰にも言えない夜が、一つ増えた。';
            }
            g.l.hp -= 12;
            if (_retainer(g)) g.l.fav = _c(g.l.fav - 5);
            return '話がこじれ、手傷を負って逃げ帰った。妙な噂が立った。';
          }),
        Choice.h('高利の証文だと役人に訴え出る', '筋が通れば借りは軽くなる。胴元に恨まれる', () {
          if (g.rng.chance(.4 + g.l.chi / 250)) {
            _pay(g, 5);
            g.l.chi = _s(g.l.chi + 1);
            return '役人は証文を読み、利の分を棒引きにさせた。元の銭だけを返した。';
          }
          g.l.hp -= 10;
          _pay(g, 8);
          return '訴えは取り上げられなかった。帰り道、胴元の手下に囲まれて打たれた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 兵法の書を著した（tal_wrote_book）→ 写しが広まり、敵方も読んでいる。
  SceneDef(
    'e3_wrote_book',
    30,
    80,
    (g) => 6,
    (g) => g.hasFlag('tal_wrote_book') && g.active,
    (g, next) {
      if (_samurai(g)) {
        g.ask('敵の陣立て', '${_house(g)}家の陣で、敵の陣立てを見て息をのんだ。あなたが昔著した兵法の書の、そのままの形だ。写しが広まり、敵の大将も読んでいたらしい。', [
          Choice.h('書いた者だけが知る弱みを突く策を献じる', '当たれば大手柄。敵が書の先まで読んでいれば、外れる', () {
            if (g.rng.chance(.55 + g.l.chi / 300)) {
              g.l.merit += 25;
              g.l.fav = _c(g.l.fav + 8);
              g.l.fame += 6;
              g.setFlag('e3_book_turned');
              g.mark('敵が自ら著した兵法書どおりの陣を敷き、その弱みを突いて破った');
              return '書には、わざと書かなかった一手があった。敵の陣は、その一手で崩れた。';
            }
            g.l.fav = _c(g.l.fav - 4);
            return '敵の大将は、書の先まで読んでいた。策は空を切った。';
          }),
          Choice.h('黙って下知に従う', '何も起きない。書のことは胸にしまう', () {
            return '口をつぐんで持ち場についた。妙な心持ちのまま、戦は終わった。';
          }),
        ], after: next);
        return;
      }
      g.ask('兵法書の写し', '昔著した兵法の書の写しが、諸国に広まっているという。今日も、写しを懐にした若い武者が門を叩いた。「この書を著したお方に、ひと目お会いしたくて」', [
        Choice.h('若者を迎え、書の講釈をする', '教える相手ができる。書の名がさらに広まる', () {
          g.l.fame += 5;
          g.l.net += 3;
          g.j(4);
          g.setFlag('e3_book_lecture');
          g.mark('著した兵法書の写しを携えて来た若者たちに、講釈をした');
          return '若者は、書の余白に細かく書き込みをしていた。夜更けまで、問いが尽きなかった。';
        }),
        Choice.h('若者は帰し、書を書き改める', '書は深まる。若者はがっかりする', () {
          g.l.chi = _s(g.l.chi + 2);
          g.j(2);
          return '写しを読み返すと、若い頃の思い込みが目についた。筆をとり直した。';
        }),
        Choice.h('写しが争いの種になると憂え、集めて焼かせる', '書は世から消えていく。惜しむ者もいる', () {
          _fameDown(g, 3);
          _pay(g, 4);
          g.j(-2);
          g.setFlag('e3_book_burned');
          g.mark('諸国に広まった自らの兵法書の写しを、集めて焼かせた');
          return '銭を払って写しを買い集め、庭で焼いた。煙が細く立ちのぼった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 帳尻の不正を申し上げた（tal_exposed_fraud）→ 暴かれた者の恨み。
  SceneDef(
    'e3_exposed_fraud',
    22,
    65,
    (g) => 6,
    (g) => g.hasFlag('tal_exposed_fraud') && _retainer(g),
    (g, next) {
      if (g.l.female && !g.canFight) {
        g.ask('暇を出された女中', '昔、あなたが申し上げて暇を出された台所の女中が、子の手を引いて城下で物乞いをしていると聞いた。', [
          Choice.h('人をやって、米と銭を届ける', '銭は減る。恨みは和らぐかもしれない', () {
            _pay(g, 4);
            g.j(3);
            g.setFlag('e3_fraud_mercy');
            g.mark('昔ごまかしを申し上げて暇を出された女中に、ひそかに米と銭を届けた');
            return '使いの者が戻って、「女中は泣いておりました」と言った。';
          }),
          Choice.h('町の店に、働き口を口利きする', '銭はかからない。奥の者には甘いと言われる', () {
            g.l.net += 2;
            g.l.fav = _c(g.l.fav - 2);
            return '女中は、町の味噌屋で働きはじめたという。';
          }),
          Choice.h('自業自得と取り合わない', '何も変わらない。噂は奥にも届く', () {
            g.j(-3);
            return '女中の噂は、いつの間にか聞かなくなった。';
          }),
        ], after: next);
        return;
      }
      g.ask('代官の息子', 'あなたの訴えで役を解かれた代官の息子が、元服して同じ${_house(g)}家に仕えるようになった。父が落ちぶれたのは、あなたのせいだと思っているらしい。', [
        Choice.h('息子を呼び、父の帳面を見せて話す', '分かり合えるかもしれない。恨みをかえって深めるかもしれない', () {
          if (g.rng.chance(.5 + g.l.mi / 300)) {
            g.l.net += 4;
            g.j(3);
            g.setFlag('e3_fraud_son_reconciled');
            g.mark('不正を訴えた代官の息子に父の帳面を見せ、恨みを解いた');
            return '息子は帳面をめくる手を止め、長いこと黙っていた。帰り際、深く頭を下げた。';
          }
          _down(g, 2);
          return '「父を辱めるおつもりか」と、息子は帳面を払いのけて出ていった。';
        }),
        Choice.h('息子の働きを殿に推す', '恨みは和らぐ。推した者の不始末は、自分にはね返る', () {
          if (g.rng.chance(.65)) {
            g.l.fav = _c(g.l.fav + 3);
            g.l.net += 3;
            return '息子はよく働いた。父とは違う、と家中で言われるようになった。';
          }
          g.l.fav = _c(g.l.fav - 5);
          return '息子は役目で大きなしくじりをした。推したあなたも、殿に叱られた。';
        }),
        Choice.h('取り合わず、夜道には供を連れる', '身は守れる。恨みは残ったままだ', () {
          if (g.rng.chance(.03)) {
            g.die('不正を訴えた代官の息子に恨まれ、夜道で斬られた', 'ansatsu');
            return '供の者が提灯を落とした、その一瞬だった。';
          }
          _down(g, 1);
          return '息子とは、廊下ですれ違っても目を合わせなかった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 分け前をもらって黙った（tal_bribe）→ 帳面の洗い直しで露見の危うさ。
  SceneDef(
    'e3_bribe',
    21,
    65,
    (g) => 6,
    (g) => g.hasFlag('tal_bribe') && _retainer(g),
    (g, next) {
      final f = g.l.female && !g.canFight;
      final who = f ? 'あの台所の女中' : 'あの代官';
      g.ask('帳面の洗い直し', '新しく${f ? '奥の掛かりを預かる老女' : '勘定方の奉行'}が来て、昔の帳面を一冊ずつ洗い直しているという。あなたが分け前をもらって目をつぶった、$whoの帳面も、その中にある。', [
        Choice.h('自ら申し出て、受け取った銭を返す', '罪は軽くなるかもしれない。主君の覚えは落ちる', () {
          _pay(g, 10);
          g.l.fav = _c(g.l.fav - 10);
          g.j(3);
          g.setFlag('e3_bribe_confessed');
          g.mark('昔、黙る代わりに受け取った銭を、自ら申し出て返した');
          return '叱責は受けたが、罪には問われなかった。眠れぬ夜が終わった。';
        }),
        Choice.h('帳面を抜き取って焼く', '露見しなければ何も起きない。露見すれば、命で償うことになる', () {
          if (g.rng.chance(.25)) {
            if (g.rng.chance(.2)) {
              g.die('黙る代わりに受け取った銭を隠すため帳面を焼いたことが露見し、腹を切らされた', 'seppuku');
              return '帳面の写しが、もう一冊あった。';
            }
            g.l.fav = _c(g.l.fav - 20);
            if (g.l.rank > 1) g.l.rank -= 1;
            g.j(-5);
            return '帳面を焼いたことが知れた。役を取り上げられ、身分を一つ落とされた。';
          }
          g.j(-4);
          g.setFlag('e3_bribe_hidden');
          return '帳面は灰になった。洗い直しは、何事もなく終わった。';
        }),
        Choice.h('$whoにすべてを負わせる', '自分は助かるかもしれない。後ろめたさは一生残る', () {
          if (g.rng.chance(.6)) {
            g.j(-8);
            return '$whoが捕らえられた。あなたの名は、最後まで出なかった。';
          }
          g.l.fav = _c(g.l.fav - 12);
          return '$whoが、取り調べですべてを話した。あなたの名も出た。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 検地を差配した（tal_kenchi）→ 凶作の年、その村々が訪ねてくる。
  SceneDef(
    'e3_kenchi',
    28,
    75,
    (g) => 6,
    (g) => g.hasFlag('tal_kenchi') && g.active && !_monk(g),
    (g, next) {
      final r = _retainer(g);
      g.ask('検地の村', '凶作の年。あなたが検地を差配した村々の長が、連れ立って訪ねてきた。「検地の帳面どおりの年貢では、この冬を越せませぬ」${r ? '' : '。いまは役を離れたあなたにも、すがる思いで来たという。'}', [
        Choice.h(
          r ? '殿に年貢の減免を願い出る' : '代官に掛け合う',
          r ? '村は息をつける。殿は検地の手柄を惜しむ' : '話が通じれば村は救われる。今の身では軽く扱われるかもしれない',
          () {
            if (g.rng.chance(r ? .4 + g.l.fav / 250 : .45)) {
              g.l.net += 5;
              g.l.fame += 3;
              g.setFlag('e3_kenchi_relief');
              g.mark('自ら差配した検地の村々のため、凶作の年に年貢を軽くさせた');
              return 'その年の年貢は、わずかに下げられた。村の長たちが、何度も頭を下げた。';
            }
            if (r) g.l.fav = _c(g.l.fav - 6);
            g.j(-2);
            return r ? '「帳面を改めたのはその方であろう」と、殿は取り合わなかった。' : '代官は、昔の検地役の言うことなど聞かなかった。';
          },
        ),
        Choice.h('自分の蔵の米を村に貸す', '蓄えは減る。村の者は恩を忘れない', () {
          _pay(g, 8);
          g.l.net += 5;
          g.j(3);
          return '米俵を荷車に積んで、村々へ送った。';
        }),
        Choice.h(
          r ? '帳面どおりに取り立てる' : '今の身では何もできぬと断る',
          r ? '主家の蔵は満ちる。村の恨みは、いつか形になる' : '身は煩わされない。村の者は肩を落とす',
          () {
            if (r) {
              g.l.fav = _c(g.l.fav + 5);
              g.j(-4);
              if (g.rng.chance(.3)) {
                g.l.hp -= 10;
                return '年貢は残らず納められた。村を見回りに出た日、どこからか石が飛んできた。';
              }
              return '年貢は残らず納められた。村々の家から、煙が上がらなくなった。';
            }
            g.j(-3);
            return '村の長たちは、黙って帰っていった。';
          },
        ),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 出城の縄張り・暴れ川の堤（tal_fushin）→ その城が攻められる／その堤が大水に耐える。
  SceneDef(
    'e3_fushin',
    24,
    75,
    (g) => 6,
    (g) =>
        g.hasFlag('tal_fushin') &&
        (_walked(g, '出城の縄張り')
            ? _samurai(g)
            : _commoner(g) && !_merchant(g)),
    (g, next) {
      if (_walked(g, '出城の縄張り')) {
        g.ask('縄張りした城', '敵の大軍が、あなたが縄張りをした出城に押し寄せた。籠もる兵を率いるよう命じられた。幾重もの堀の筋は、すべて頭の中にある。', [
          Choice.h('堀ごとに兵を退きながら、敵を引き込む', '城の工夫が生きれば大手柄。最後の堀まで破られれば、逃げ場はない', () {
            if (g.rng.chance(.04)) {
              g.die('自ら縄張りした出城に籠もり、最後の堀で討たれた', 'senshi');
              return '最後の堀に、敵の梯子が掛かった。';
            }
            g.l.merit += 25;
            g.l.fav = _c(g.l.fav + 6);
            g.l.fame += 6;
            g.l.hp -= 6;
            g.setFlag('e3_fort_held');
            g.mark('自ら縄張りをした出城に籠もり、敵の大軍を退けた');
            return '堀を一つ越えるたびに、敵は横矢を浴びた。ひと月ののち、敵は囲みを解いた。';
          }),
          Choice.h('本城に援けを請い、門を固く閉ざす', '堅実だ。援けが来るまで持ちこたえられるかしだい', () {
            if (g.rng.chance(.6)) {
              g.l.merit += 10;
              return '援けの兵が来るまで、門は破られなかった。';
            }
            g.l.fav = _c(g.l.fav - 5);
            g.l.hp -= 10;
            return '外の堀を破られ、二の丸まで退いた。辛うじて城は持ちこたえた。';
          }),
        ], after: next);
        return;
      }
      g.ask('堤の工夫', '大雨が幾日も続いた。あなたが工夫した堤の切れ目から水が逃げ、村の田は無事だった。ところが川下の村では、田がすっかり流されたという。川下の村の者が、堤の工夫を教えてほしいと頼みに来た。', [
        Choice.h('川下の村へ出向いて、堤づくりを教える', '人の役に立つ。家を何日も空ける', () {
          g.l.net += 5;
          g.l.fame += 4;
          g.j(3);
          g.setFlag('e3_levee_taught');
          g.mark('自ら工夫した堤のつくりを、川下の村にも教えた');
          return '川下の村の者と、泥だらけになって土を盛った。';
        }),
        Choice.h('工夫は村のものとして、明かさない', '村の田は守れる。川下の恨みを買う', () {
          g.l.gold += 3;
          g.j(-3);
          _down(g, 1);
          return '川下の村の者は、肩を落として帰っていった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 慕い寄る兵を引き受けた（tal_beloved_captain）→ 負け戦のしんがりで、兵が命を張る。
  SceneDef(
    'e3_captain',
    25,
    65,
    (g) => 6,
    (g) => g.hasFlag('tal_beloved_captain') && _samurai(g),
    (g, next) {
      g.ask('しんがり', '戦は負けだった。${_house(g)}家の軍が崩れ、退き口のしんがりをあなたの組が任された。慕って集まった兵たちが、「お頭の行くところへ」と槍を揃えている。', [
        Choice.h('兵とともに踏みとどまり、追っ手を食い止める', '味方は逃げ延びる。最後まで残れば、命の保証はない', () {
          if (g.rng.chance(.05)) {
            g.die('慕って集まった兵とともにしんがりを務め、追っ手を食い止めて討たれた', 'senshi');
            return '兵たちは、最後まであなたのそばを離れなかった。';
          }
          g.l.merit += 25;
          g.l.fav = _c(g.l.fav + 10);
          g.l.fame += 8;
          g.l.hp -= 12;
          g.l.troops = g.l.troops >= 5 ? g.l.troops - 5 : 0;
          g.setFlag('e3_rearguard');
          g.mark('負け戦でしんがりを務め、慕い寄った兵とともに追っ手を食い止めた');
          return '日が暮れるまで、追っ手を一歩も通さなかった。帰り着いた兵は、出たときより少なかった。';
        }),
        Choice.h('兵を先に逃がし、わずかな手勢で残る', '兵は生き延びる。自分の身は危うい', () {
          if (g.rng.chance(.05)) {
            g.die('慕い寄った兵を先に逃がし、自らしんがりに残って討たれた', 'senshi');
            return '兵たちの背が遠ざかるのを見届けて、槍を握り直した。';
          }
          g.l.fame += 6;
          g.l.net += 5;
          g.l.hp -= 15;
          g.mark('負け戦で慕い寄った兵を先に逃がし、自らしんがりに残って生き延びた');
          return '傷だらけで陣に戻ると、兵たちが泣きながら駆け寄ってきた。';
        }),
        Choice.h('兵の言葉を容れて、隊ごと退く', '兵も自分も無事だ。主君の覚えは落ちる', () {
          g.l.fav = _c(g.l.fav - 6);
          return '隊を崩さずに退いた。しんがりの役を果たさなかったと、陰で言われた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 慕う者を束ねた（tal_followers）→ 人を集めて何か企んでいると疑われる。
  SceneDef(
    'e3_followers',
    23,
    75,
    (g) => 6,
    (g) =>
        g.hasFlag('tal_followers') && g.active && !_monk(g) && g.l.rank < 8,
    (g, next) {
      final r = _retainer(g);
      final who = r ? '殿の側近' : '代官';
      g.ask('集まる者への疑い', '$whoが、あなたが人を集めて何事か企んでいると疑っているという。慕って集まった仲間たちは、「われらが証を立てます」と言ってきかない。', [
        Choice.h('仲間を連れて、堂々と申し開きに出る', '疑いは晴れるかもしれない。数を見せれば、かえって恐れられる', () {
          if (g.rng.chance(.5 + g.l.mi / 300)) {
            g.l.fame += 4;
            g.l.net += 3;
            g.setFlag('e3_followers_cleared');
            g.mark('慕って集まった仲間を連れて申し開きに出て、企みの疑いを晴らした');
            return '仲間の一人ひとりが、あなたとの縁を語った。$whoは、しまいに苦笑して疑いを解いた。';
          }
          if (r) g.l.fav = _c(g.l.fav - 10);
          g.l.hp -= 6;
          return '人数を見た$whoは、かえって顔色を変えた。仲間の何人かが、しばらく留め置かれた。';
        }),
        Choice.h('仲間の集まりを、しばらく解く', '疑いはおさまる。仲間は寂しがる', () {
          _down(g, 3);
          g.j(-2);
          return '「時が来たら、また」と言って、仲間たちを帰した。';
        }),
        Choice.h('疑う者に贈り物をして黙らせる', '銭はかかる。弱みを握られる', () {
          _pay(g, 6);
          if (r) g.l.fav = _c(g.l.fav + 2);
          return '贈り物は受け取られた。疑いの話は、それきり聞かなくなった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 別働隊の夜襲で本陣を焼いた（tal_night_raid）→ 討たれた敵将の子が仇を名乗る。
  SceneDef(
    'e3_night_raid',
    28,
    70,
    (g) => 5,
    (g) =>
        g.hasFlag('tal_night_raid') && g.active && g.canFight && !_monk(g),
    (g, next) {
      final rival = _newName(g, female: false);
      g.ask('仇の名乗り', '若い武者が、門前で名乗りを上げた。「$rivalと申す。父は、あの夜襲で本陣を焼かれ、討たれた。父の仇、尋常に勝負されよ」', [
        Choice.h('立ち合いに応じる', '決着はつく。若い者の刃は、恨みのぶんだけ鋭い', () {
          if (g.rng.chance(.05)) {
            g.die('夜襲で討った敵将の子に仇と名乗られ、立ち合いで斬られた', 'sai');
            return '若者の踏み込みは、思ったより深かった。';
          }
          g.l.fame += 6;
          g.l.hp -= 10;
          g.j(-3);
          g.mark('夜襲で討った敵将の子に仇と名乗られ、立ち合って退けた');
          return '若者の刀を叩き落とした。命は取らなかった。若者は、地に伏して泣いた。';
        }),
        Choice.h('戦の習いを説き、仇討ちを思いとどまらせる', '分かってくれれば恨みは解ける。分からなければ、また来る', () {
          if (g.rng.chance(.45 + g.l.mi / 300)) {
            g.meet('仇の子', rival, 45);
            g.l.net += 3;
            g.j(3);
            g.setFlag('e3_raid_son_peace');
            g.mark('夜襲で討った敵将の子に戦の習いを説き、仇討ちを思いとどまらせた');
            return '父の最期の様子を話すと、$rivalはじっと聞いていた。やがて刀を納めた。';
          }
          g.j(-3);
          return '$rivalは唇を噛んで去った。「また来る」という声が残った。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 使者として婚姻の約定を取りつけた（tal_alliance）→ その縁が揺らぐ。
  SceneDef(
    'e3_alliance',
    26,
    70,
    (g) => 6,
    (g) => g.hasFlag('tal_alliance') && _retainer(g),
    (g, next) {
      g.ask('揺らぐ縁', 'あなたが使者に立って結んだ婚姻の縁が、揺らいでいる。向こうの家に嫁いだ姫から、ひそかに文が届いた。「両家のあいだに、よからぬ噂が立っております」', [
        Choice.h('再び使者に立って、両家の間を取りなす', '縁が保たれれば大きな手柄。こじれれば、使者の身が危うい', () {
          if (g.rng.chance(.03)) {
            g.die('自ら結んだ縁を取りなす使者に立ち、向こうの城下で討たれた', 'ansatsu');
            return '城下の宿に、夜更けに人の気配がした。';
          }
          if (g.rng.chance(.5 + g.l.mi / 300)) {
            g.l.merit += 20;
            g.l.fav = _c(g.l.fav + 8);
            g.l.fame += 4;
            g.setFlag('e3_alliance_kept');
            g.mark('自ら結んだ両家の縁が揺らいだとき、再び使者に立って取りなした');
            return '向こうの主は「その方が来るなら」と席についた。噂は、讒言の類と知れた。';
          }
          g.l.fav = _c(g.l.fav - 5);
          return '話は物別れに終わった。帰りの道中、姫の顔が浮かんで離れなかった。';
        }),
        Choice.h('姫の文を殿に見せ、備えを進言する', '不意は突かれない。縁は切れやすくなる', () {
          g.l.merit += 10;
          g.l.fav = _c(g.l.fav + 4);
          _down(g, 2);
          return '境の城に兵が入った。向こうの家も、同じように兵を入れたという。';
        }),
        Choice.h('姫に返書を送り、内々に噂の出所を探る', '静かに確かめられる。姫の身が危うくなるかもしれない', () {
          if (g.rng.chance(.55)) {
            g.l.chi = _s(g.l.chi + 1);
            g.l.merit += 8;
            return '噂の出所は、縁組を快く思わぬ向こうの重臣だった。殿にだけ、そっと伝えた。';
          }
          g.j(-4);
          return '姫からの文は、それきり途絶えた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 町割りをして市を開いた（tal_machiwari）→ 栄えた町と、古い座の訴え。
  SceneDef(
    'e3_machiwari',
    26,
    80,
    (g) => 6,
    (g) =>
        g.hasFlag('tal_machiwari') &&
        g.active &&
        (_retainer(g) || _merchant(g)),
    (g, next) {
      final r = _retainer(g);
      g.ask('町の行く末', 'あなたが町割りを引いた町が、すっかり大きくなった。市の立つ日には、遠国の商人まで集まる。ところが、古くからの座の者たちが「新しい市に商いを奪われた」と訴え出た。', [
        Choice.h('市を守り、誰でも商える掟を続けさせる', '町はますます栄える。座の者の恨みは深まる', () {
          g.l.fame += 5;
          if (r) {
            g.l.merit += 10;
          } else {
            g.l.gold += 10;
          }
          _down(g, 2);
          g.setFlag('e3_market_kept');
          g.mark('自ら町割りをした町で、座の者の訴えを退けて市を守った');
          return '市の日はそのままになった。座の者の目は冷たいが、町はにぎわい続けた。';
        }),
        Choice.h('座の者に市の一角を任せ、折り合わせる', '揉め事は収まる。にぎわいは少し落ちる', () {
          g.l.net += 5;
          g.j(2);
          return '座の者にも、市の一角に店を出させた。双方が渋々頷いた。';
        }),
        Choice.h('座の者の礼物を受け、座の掟を戻す', '懐は潤う。町の者はがっかりする', () {
          g.l.gold += 15;
          g.j(-4);
          _fameDown(g, 3);
          return '市の日は減らされた。遠国の商人は、ほかの町へ流れていった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 槍の指南役を務めた（tal_shinan）→ 教えた若侍が一人前になって頼ってくる。
  SceneDef(
    'e3_shinan',
    30,
    75,
    (g) => 6,
    (g) =>
        g.hasFlag('tal_shinan') &&
        g.active &&
        !_monk(g) &&
        (_retainer(g) ||
            (g.l.rank == 0 && g.canFight && !_outlaw(g) && !_merchant(g))),
    (g, next) {
      final known = g.l.people['槍の弟子'];
      final student = known?.name ?? _newName(g, female: false);
      if (_retainer(g)) {
        g.ask('槍の弟子', '昔、槍を教えた若侍の$studentが、いまは一隊を預かる身になった。その$studentが、役目のしくじりで殿の勘気をこうむった。「師匠、どうかお取りなしを」', [
          Choice.h('殿に取りなす', '弟子は救われるかもしれない。殿の機嫌を損ねるおそれもある', () {
            if (g.rng.chance(.45 + g.l.fav / 250)) {
              g.meet('槍の弟子', student, 70);
              g.l.net += 4;
              g.setFlag('e3_pupil_saved');
              g.mark('昔槍を教えた$studentが殿の勘気をこうむったとき、取りなして救った');
              return '殿は「その方の弟子なら」と許した。$studentは、昔のように深く頭を下げた。';
            }
            g.l.fav = _c(g.l.fav - 6);
            return '「弟子かわいさか」と、殿は取り合わなかった。';
          }),
          Choice.h('師として叱り、自ら詫びに行かせる', '筋は通る。弟子が折れるかは分からない', () {
            if (g.rng.chance(.6)) {
              g.meet('槍の弟子', student, 60);
              g.l.net += 2;
              return '$studentは殿の前で額を床につけた。勘気は解けた。';
            }
            g.j(-3);
            return '$studentは詫びに行かず、家を去った。行方は知れない。';
          }),
          Choice.h('関わらない', '自分の身は守れる。弟子は師を恨むかもしれない', () {
            g.j(-3);
            return '$studentは、それきり顔を見せなくなった。';
          }),
        ], after: next);
        return;
      }
      final other = _nearOther(g);
      if (other == null) {
        g.ask('槍の弟子', '昔、槍を教えた若侍の$studentが訪ねてきた。いまは一隊を預かる身だという。「師匠に教わった槍で、生き延びてまいりました」', [
          Choice.h('酒を出して、昔語りをする', '心が温まる。何も変わらない', () {
            g.meet('槍の弟子', student, 65);
            g.j(5);
            return '庭に出て、二人で槍を構えてみた。弟子の槍は、師の槍より速かった。';
          }),
          Choice.h('稽古をつけてやる', '腕がなまらずに済む。体は少しこたえる', () {
            g.l.bu = _s(g.l.bu + 1);
            g.l.hp -= 3;
            return '日が暮れるまで、槍を合わせた。';
          }),
        ], after: next);
        return;
      }
      final h = houseName(g, other);
      g.ask('槍の弟子', '昔、槍を教えた若侍の$studentが訪ねてきた。いまは$h家で一隊を預かる身だという。「師匠ほどのお方が、埋もれていてはなりません。当家にお迎えしたい」', [
        Choice.h('弟子の口添えで仕える', 'ふたたび主家を持つ身になる。戦に出ることになる', () {
          _join(g, other);
          g.meet('槍の弟子', student, 70);
          g.setFlag('e3_pupil_brought_back');
          g.mark('昔槍を教えた$studentの口添えで、$h家に仕えた');
          return '$h家の門をくぐると、若侍たちが「師匠の師匠だ」とささやき合った。';
        }),
        Choice.h('礼を言って断る', '今の暮らしは変わらない。弟子は少し寂しがる', () {
          g.meet('槍の弟子', student, 55);
          g.j(2);
          return '$studentは、何度も振り返りながら帰っていった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 祭りの子ども相撲で勝った（tal_c_sumo_win）→ 力自慢として召し出される。
  SceneDef(
    'e3_c_sumo',
    17,
    40,
    (g) => 6,
    (g) =>
        g.hasFlag('tal_c_sumo_win') &&
        !g.l.female &&
        g.active &&
        !_monk(g) &&
        g.l.rank < 8 &&
        (_retainer(g) || _strongest(g) != null),
    (g, next) {
      final mine = _retainer(g);
      final lordKey = mine ? g.l.lord! : _strongest(g)!;
      final h = houseName(g, lordKey);
      g.ask('力自慢', '$h家の殿が相撲を好み、国中の力自慢を集めているという。「祭りの相撲で年上の子を投げ飛ばした、あの子が大きくなった」と、あなたの名が挙がった。', [
        Choice.h('土俵に上がる', '勝てば目に留まる。相手は名うての力士だ', () {
          if (g.rng.chance(.45 + g.l.bu / 250)) {
            g.l.fame += 6;
            g.setFlag('e3_sumo_called');
            final canJoin = !mine &&
                g.l.rank == 0 &&
                !_outlaw(g) &&
                !_merchant(g);
            if (mine) {
              g.l.fav = _c(g.l.fav + 8);
              g.l.merit += 8;
            } else if (canJoin) {
              _join(g, lordKey);
              g.mark('相撲の力を見込まれ、$h家に召し抱えられた');
              return '名うての力士を寄り切った。殿は膝を打ち、その場で召し抱えると言った。';
            } else {
              g.l.gold += 10;
            }
            g.mark('力自慢として$h家の相撲に召し出され、勝ち名乗りを受けた');
            return '名うての力士を寄り切った。殿が膝を打って、褒美を取らせた。';
          }
          g.l.hp -= 10;
          g.l.fame += 1;
          return '力は互角だったが、最後に投げられて肩を痛めた。殿は「惜しい」と言った。';
        }),
        Choice.h('子どもの頃の話だと辞退する', '何も起きない。殿は少し残念がる', () {
          if (mine) g.l.fav = _c(g.l.fav - 2);
          return '「子どもの相撲と大人の相撲は違います」と、頭を下げた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 白い鹿に導かれた（tal_c_white_deer）→ ふたたび白い鹿を見る。
  SceneDef(
    'e3_c_white_deer',
    18,
    70,
    (g) => 5,
    (g) => g.hasFlag('tal_c_white_deer') && g.active,
    (g, next) {
      g.ask('ふたたび白い鹿', '山道で、白い鹿を見た。幼い日、道に迷ったあなたを導いた、あの鹿によく似ている。連れの者が、そっと弓に矢をつがえた。', [
        Choice.h('連れの弓を押さえて止める', '鹿は去っていく。連れは不満げだ', () {
          g.l.un = _s(g.l.un + 3);
          g.j(4);
          g.setFlag('e3_deer_spared');
          g.mark('白い鹿をふたたび見て、射ようとする連れを止めた');
          return '鹿はしばらくこちらを見ていたが、やがて木立の奥へ消えた。';
        }),
        Choice.h('鹿のあとをついていく', '幼い日のように、何かに出会うかもしれない', () {
          if (g.rng.chance(.5 + g.l.un / 300)) {
            g.l.un = _s(g.l.un + 2);
            g.l.fame += 3;
            g.j(5);
            g.setFlag('e3_deer_shrine');
            g.mark('白い鹿のあとを追い、山奥の荒れた祠を見つけて祀り直した');
            return '鹿が立ち止まった先に、苔むした祠があった。里の者と、祠を祀り直した。';
          }
          g.l.hp -= 6;
          return '鹿は霧の中に消えた。帰り道で足をくじいた。';
        }),
        Choice.h('射るに任せる', '白い獣は高く売れる。罰が当たるという者もいる', () {
          g.l.gold += 12;
          g.l.un = _s(g.l.un - 6);
          g.j(-4);
          return '矢は鹿を射抜いた。その夜から、妙に寝つきが悪くなった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 暴れ馬から幼い子を救った（tal_c_horse）→ その子が大人になって訪ねてくる。
  SceneDef(
    'e3_c_horse',
    22,
    55,
    (g) => 5,
    (g) => g.hasFlag('tal_c_horse') && g.active,
    (g, next) {
      final name = _newName(g, female: false);
      g.ask('あの日の子', '見知らぬ男が、立派な馬を引いて訪ねてきた。「$nameと申します。幼い日、暴れ馬の前で立ちすくんでいたのが、わたしです」。いまは馬を商っているという。', [
        Choice.h('馬を贈られて、ありがたく受ける', '良い馬が手に入る。返す恩が残る', () {
          g.l.fame += 3;
          g.j(3);
          if (_samurai(g)) g.l.merit += 5;
          g.meet('馬喰の縁', name, 55);
          g.setFlag('e3_horse_gift');
          g.mark('幼い日に暴れ馬から救った子が、大人になって馬を贈りに来た');
          return '馬は、あなたが手綱を取るとおとなしく首を下げた。';
        }),
        Choice.h('馬は受けず、酒を酌み交わす', '恩の貸し借りはなくなる。気持ちよく別れられる', () {
          g.j(5);
          g.l.net += 2;
          return '$nameは、あの日の馬の話を何度もした。';
        }),
        Choice.h('馬の商いに銭を出して、手を組む', '儲かれば暮らしが変わる。商いは水もの', () {
          if (g.l.gold < 8) {
            g.meet('馬喰の縁', name, 50);
            return '出せる銭がなかった。$nameは「またいつか」と笑って帰った。';
          }
          g.l.gold -= 8;
          g.meet('馬喰の縁', name, 60);
          if (g.rng.chance(.55 + g.l.sei / 400)) {
            g.l.gold += 20;
            g.l.net += 2;
            return '馬は、良い値で売れた。$nameは律儀に、分け前を届けてきた。';
          }
          g.j(-3);
          return '買い付けた馬が、病で何頭も倒れた。$nameは、何度も頭を下げた。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------------
  // 寺社で願を掛けた（ps_wish_home / ps_wish_rise）→ 年を経て、願ほどき・お礼参り。
  SceneDef(
    'e3_wish',
    32,
    85,
    (g) => 5,
    (g) =>
        (g.hasFlag('ps_wish_home') || g.hasFlag('ps_wish_rise')) && g.active,
    (g, next) {
      if (g.hasFlag('ps_wish_home')) {
        final sp = g.l.married ? g.l.people['伴侶']?.name : null;
        final fam = sp != null ? '$spも家の者も' : '家の者も';
        g.ask('お礼参り', '若い頃、寺社で家の者の無事を願った。あれから年を重ね、$famみな息災だ。そろそろ、お礼参りをせねばと思う。', [
          Choice.h('家の者を連れて、お礼参りに出かける', '心が満ちる。長い道のりは体にこたえる', () {
            g.j(6);
            g.l.hp -= 3;
            final s = g.l.people['伴侶'];
            if (s != null && g.l.married) s.bond = _c(s.bond + 5);
            g.setFlag('e3_wish_thanks');
            g.mark('若い日に家の者の無事を願った寺社へ、家の者とお礼参りをした');
            return '境内の大きな木は、昔のままだった。家の者と並んで、手を合わせた。';
          }),
          Choice.h('奉納の品を届けさせる', '銭はかかる。足を運ばずに済む', () {
            _pay(g, 4);
            g.l.un = _s(g.l.un + 1);
            return '使いの者に、奉納の品を持たせた。';
          }),
          Choice.h('願が叶ったのは己の働きと笑う', '何も変わらない。罰が当たると言う者もいる', () {
            g.l.un = _s(g.l.un - 2);
            return '家の者は、少し困ったような顔をした。';
          }),
        ], after: next);
        return;
      }
      final risen = g.l.maxRank >= 3 || g.l.gold >= 40;
      g.ask('願ほどき', '若い頃、寺社に寄進して身の栄えを願った。${risen ? 'あれから、身は確かに栄えた。' : '願は、まだ叶ったとは言えない。'}社の者が訪ねてきて、「願ほどきの寄進を」と言う。', [
        Choice.h('大きく寄進して、願ほどきをする', '銭は出ていく。神仏への借りはなくなる', () {
          _pay(g, 10);
          g.l.un = _s(g.l.un + 3);
          g.l.fame += 3;
          g.j(3);
          g.setFlag('e3_wish_released');
          g.mark('若い日に身の栄えを願った寺社に、大きく寄進して願ほどきをした');
          return '社の帳面に、あなたの名が大きく記された。';
        }),
        Choice.h('寄進はせず、手を合わせに行くだけにする', '銭は減らない。社の者はいい顔をしない', () {
          g.j(2);
          return '賽銭だけを投げ、長いこと手を合わせた。';
        }),
        Choice.h(
          risen ? '栄えたのは己の働きと追い返す' : '叶わぬ願に払う銭はないと追い返す',
          '銭は守れる。罰が当たると言う者もいる',
          () {
            g.l.un = _s(g.l.un - 3);
            g.j(-2);
            return '社の者は、黙って帰っていった。';
          },
        ),
      ], after: next);
    },
  ),
];
