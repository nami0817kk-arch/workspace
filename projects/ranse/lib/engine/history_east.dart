import 'childhood.dart';
import 'game.dart';
import 'rng.dart';

/// 東国（相模・越後・甲斐・信濃・陸奥・出羽・常陸・会津・駿河・三河）の史実の岐路。
///
/// id は `h_e_` で始める（`isHistoryScene` が `h_` で史実の岐路と見なす）。
/// 合戦はその家に仕える者に、暮らしに届く史実はその国の身分の低い者に出る。

int _yr(Game g, int a) => g.l.startYear + a;
bool _at(Game g, int a, int y) => _yr(g, a) == y;
bool _span(Game g, int a, int from, int to) =>
    _yr(g, a) >= from && _yr(g, a) <= to;
bool _lordIs(Game g, List<String> ns) => ns.contains(g.l.lord);
bool _inRegion(Game g, List<String> rs) => rs.contains(g.l.region);
bool _alive(Game g, String n) => g.fa[n]?.alive ?? false;
bool _soldier(Game g) =>
    g.l.rank >= 1 &&
    g.l.rank < 8 &&
    g.l.lord != null &&
    _alive(g, g.l.lord!) &&
    g.canFight &&
    g.active;
bool _priest(Game g) => g.hasFlag('priesthood');

/// 秀吉が天下を取った世（史実どおりか、関ヶ原だけが変わった世）。
bool _hideyoshiWorld(Game g) =>
    !g.hasFlag('history_okehazama') &&
    !g.hasFlag('history_honnoji') &&
    !g.hasFlag('history_yamazaki');
int _c(int v) => clampInt(v, 0, 100);

void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;

void _pay(Game g, int n) => g.l.gold = g.l.gold >= n ? g.l.gold - n : 0;

/// [lord] に仕える。[drop] なら寝返りとして位を一つ下げる。
void _join(Game g, String lord, {int fav = 25, bool drop = false}) {
  final l = g.l;
  final changed = l.lord != lord;
  l.lord = lord;
  if (drop && changed) l.rank -= 1;
  if (l.rank < 1) l.rank = 1;
  if (l.rank > l.maxRank) l.maxRank = l.rank;
  if (changed) l.fav = fav;
  l.ronin = false;
}

List<SceneDef> buildHistoryEastScenes() {
  return [
    // ================= 相模 =================
    SceneDef(
      'h_e_kawagoe',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '北条',
      (g, next) {
        g.ask(
          '河越夜戦',
          '武蔵の河越城を、関東の諸将の大軍が半年も囲んでいる。城を守るのは「地黄八幡」の北条綱成。氏康は夜討ちで囲みを破ると決めた。',
          [
            Choice.h('白い布を肩に、夜の敵陣へ斬り込む', '名を上げる好機。闇の中では敵も味方も見えにくい', () {
              if (g.rng.chance(.1)) {
                g.die('河越の夜戦で、闇の中に討死した', 'senshi');
                return '松明の向こうから、槍が突き出された。';
              }
              g.l.merit += 18;
              g.l.fame += 10;
              g.l.fav = _c(g.l.fav + 8);
              g.mark('河越の夜戦で、北条の奇襲に加わった');
              return '油断した大軍は崩れた。夜明けには、関東の勢いが北条に傾いていた。';
            }),
            Choice.h('城の綱成に、夜討ちの合図を届ける', '危うい使いだ。成れば手柄は大きい', () {
              if (g.rng.chance(.12)) {
                g.die('河越の囲みを抜けようとして、見つかって討たれた', 'senshi');
                return '堀の手前で、見張りに見つかった。';
              }
              g.l.merit += 14;
              g.l.net += 2;
              g.mark('河越の囲みを抜け、城の北条綱成に夜討ちの合図を届けた');
              return '囲みをすり抜け、城に合図を届けた。城の兵も打って出た。';
            }),
            Choice.h('後詰めに控える', '堅実だ。手柄は小さい', () {
              g.l.merit += 4;
              return '遠くで鬨の声が上がり、やがて静まった。北条の大勝だった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1546),
    ),

    SceneDef(
      'h_e_meyasu',
      15,
      84,
      (g) => 20,
      (g) =>
          _inRegion(g, ['相模']) &&
          g.l.rank == 0 &&
          !_priest(g) &&
          !g.hasFlag('way_outlaw') &&
          g.active,
      (g, next) {
        g.ask(
          '氏康の民政',
          '北条氏康が、村々にかけていた雑多な役をやめ、年貢を改めるという。代官の非道があれば、百姓でもじかに訴え出てよいとのお触れだ。',
          [
            Choice.h('代官の取り立てを訴え出る', '正しければ聞き届けられる。代官に恨まれるかもしれない', () {
              if (g.rng.chance(.7)) {
                g.l.gold += 4;
                g.l.net += 2;
                g.j(5);
                g.mark('北条の訴えの制で、代官の非道を訴え出た');
                return '訴えは取り上げられた。代官は替えられ、村の年貢は軽くなった。';
              }
              g.l.hp -= 10;
              return '訴えは届いたが、代官の手の者に夜道で殴られた。';
            }),
            Choice.h('新しい年貢を黙って納める', '騒ぎは起こさない。暮らしは少し楽になる', () {
              g.l.gold += 2;
              return '取り立ては前より軽くなった。小田原の殿様は、話のわかる人らしい。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1550, 1555),
    ),

    SceneDef(
      'h_e_odawara_1561',
      15,
      84,
      (g) => 20,
      (g) =>
          _inRegion(g, ['相模']) && g.l.rank <= 1 && g.l.lord != '上杉' && g.active,
      (g, next) {
        g.ask(
          '越後勢、小田原へ',
          '越後の長尾景虎（のちの上杉謙信）が関東の諸将を従え、十万ともいわれる大軍で小田原を囲んだ。氏康は城に籠もり、城下は焼き払われるという。',
          [
            Choice.h('家財を背負って城に逃げ込む', '堅い城の中なら命は守れる。家は焼かれる', () {
              _pay(g, 3);
              g.mark('長尾景虎の小田原攻めを、城の中でしのいだ');
              return '城は落ちなかった。やがて越後勢は囲みを解き、鎌倉へ去っていった。';
            }),
            Choice.h('山に隠れて家を見張る', '家を守れるかもしれない。乱取りの兵に出くわせば終わりだ', () {
              if (g.rng.chance(.12)) {
                g.die('小田原攻めの乱取りの兵に、山中で見つかって殺された', 'senshi');
                return '藪をかき分ける足音が、すぐそこまで来た。';
              }
              g.l.gold += 2;
              return '兵は通り過ぎた。焼け残った家の柱を、ぼんやりと撫でた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1561),
    ),

    SceneDef(
      'h_e_ishigakiyama',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['相模']) && g.l.rank == 0 && g.active,
      (g, next) {
        g.ask(
          '一夜城',
          '天下の大軍が小田原を囲んで三月。ある朝、向かいの石垣山に、白壁の城が忽然と現れた。陣の周りでは商人が市を開き、遊女や茶人まで来ているという。',
          [
            Choice.h('上方の陣に物を売りに行く', '大きな儲けになる。北条の世が戻れば咎められる', () {
              g.l.gold += 10;
              g.setFlag('sold_to_hideyoshi');
              g.mark('小田原の陣で、上方の大軍に物を売った');
              return '米も草鞋も飛ぶように売れた。北条の城は、もう長くはもたないと思った。';
            }),
            Choice.h('城の身内に、ひそかに米を届ける', '情けは通る。見つかれば命はない', () {
              if (g.rng.chance(.15)) {
                g.die('小田原の囲みの中へ米を運ぼうとして、捕らえられ斬られた', 'seppuku');
                return '夜の堀端で、見回りの兵に捕まった。';
              }
              g.l.net += 3;
              g.j(4);
              g.mark('小田原の籠城の中へ、ひそかに米を届けた');
              return '堀の抜け道から米を渡した。身内は、黙って手を握った。';
            }),
            Choice.h('戸を閉めて戦が終わるのを待つ', '何も得ないが、何も失わない', () {
              return '七月、城は開かれた。百年続いた北条の世が終わった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1590),
    ),

    // ================= 越後 =================
    SceneDef(
      'h_e_tsurugaoka',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '上杉',
      (g, next) {
        g.ask(
          '鶴岡八幡宮',
          '小田原を囲んだ帰り、景虎は鎌倉の鶴岡八幡宮で上杉の名と関東管領の職を継いだ。社前に並ぶ関東の諸将の中で、ひとりの将が下馬の礼をとらなかった。',
          [
            Choice.h('無礼な将を、その場で咎める', '主の面目は立つ。関東の諸将に恨まれる', () {
              g.l.fav = _c(g.l.fav + 10);
              g.l.net -= 2;
              g.mark('鶴岡八幡宮で、上杉謙信の関東管領就任の場に立ち会った');
              return '景虎は扇でその将の顔を打った。関東の諸将の心は、少しずつ離れていった。';
            }),
            Choice.h('黙って式を見届ける', '波風は立てない', () {
              g.l.merit += 4;
              g.mark('鶴岡八幡宮で、上杉謙信の関東管領就任を見届けた');
              return '若宮大路に、越後の旗がはためいていた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1561),
    ),

    SceneDef(
      'h_e_aoso',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['越後']) && g.l.rank == 0 && !_priest(g) && g.active,
      (g, next) {
        g.ask(
          '青苧',
          '越後の山で採れる青苧（からむし）は、京で上等の布になる。直江津の湊から船で運ばれ、長尾家の大きな財になっている。',
          [
            Choice.h('青苧を育てて売る', '手間はかかる。上方の値に左右される', () {
              g.l.gold += 6;
              g.l.hp -= 5;
              g.mark('越後の青苧を育て、上方へ売った');
              return '刈って、剥いで、干した。湊の商人は、いい値で買っていった。';
            }),
            Choice.h('直江津の湊で荷を担ぐ', '銭はすぐに入る。上方の噂も聞ける', () {
              g.l.gold += 3;
              g.l.net += 2;
              return '船乗りたちから、京の都の話を聞いた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1550, 1577),
    ),

    SceneDef(
      'h_e_otate',
      15,
      84,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '上杉',
      (g, next) {
        g.ask('御館の乱', '謙信が跡継ぎを定めぬまま倒れた。甥の景勝と、北条から来た養子の景虎が、家督を争って越後を二つに割った。', [
          Choice.h('春日山の景勝につく', '城も金蔵も景勝が押さえた。勢いはこちらにある', () {
            final r = g.battle('main');
            if (g.l.dead == null) {
              g.l.fav = _c(g.l.fav + 10);
              g.mark('御館の乱で、上杉景勝についた');
              return '$r 翌年の春、景虎は鮫ヶ尾城で自害した。';
            }
            return r;
          }),
          Choice.h('御館の景虎につく', '北条の後ろ盾がある。助けが来なければ終わりだ', () {
            if (g.rng.chance(.25)) {
              g.die('御館の乱で景虎方として戦い、敗れて討たれた', 'senshi');
              return '雪に阻まれ、北条の援軍は来なかった。';
            }
            g.l.rank = 0;
            g.l.lord = null;
            g.l.ronin = true;
            g.mark('御館の乱で景虎について敗れ、越後を去った');
            return '景虎は自害した。景虎方の者は越後を追われた。';
          }),
          Choice.h('どちらにもつかず屋敷に籠もる', '命は守れる。勝った側に疑われる', () {
            g.l.fav = _c(g.l.fav - 15);
            return '戦が終わったとき、景勝の家臣たちの目は冷たかった。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1578),
    ),

    SceneDef(
      'h_e_otate_town',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['越後']) && g.l.rank == 0 && g.active,
      (g, next) {
        g.ask(
          '御館の焼け跡',
          '上杉の跡目争いで、府中の御館が焼け落ちた。景虎の幼い子まで討たれたという。焼け跡には、逃げ遅れた町の者が座り込んでいる。',
          [
            Choice.h('焼け出された者を家に泊める', '人の情けは返ってくる。食い扶持は減る', () {
              _pay(g, 3);
              g.l.net += 3;
              g.j(3);
              g.mark('御館の乱で焼け出された者を、家に泊めた');
              return '狭い家で、知らない家族と冬を越した。';
            }),
            Choice.h('焼け跡で金目の物を拾う', '銭にはなる。見つかれば罰を受ける', () {
              if (g.rng.chance(.25)) {
                g.l.hp -= 15;
                return '拾っているところを、景勝方の兵に見つかって打たれた。';
              }
              g.l.gold += 5;
              g.j(-3);
              return '焦げた銅銭を、袋いっぱいに拾った。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1579),
    ),

    // ================= 甲斐 =================
    SceneDef(
      'h_e_kinzan',
      15,
      60,
      (g) => 20,
      (g) =>
          _inRegion(g, ['甲斐']) &&
          g.l.rank == 0 &&
          !g.l.female &&
          !_priest(g) &&
          g.active,
      (g, next) {
        g.ask('黒川金山', '甲斐の山奥の金山で、金掘衆が人を集めている。掘った金は甲州金となり、武田の軍資金になるという。', [
          Choice.h('金掘衆に加わる', '稼ぎはいい。坑道は崩れることがある', () {
            if (g.rng.chance(.06)) {
              g.die('黒川金山の坑道が崩れ、生き埋めになった', 'sai');
              return '頭の上で、岩のきしむ音がした。';
            }
            g.l.gold += 10;
            g.l.hp -= 10;
            g.setFlag('kanahori');
            g.mark('黒川金山で金を掘った');
            return '暗い穴の中で、何年も岩を砕いた。手の中の砂金は、驚くほど重かった。';
          }),
          Choice.h('村で田を守る', '暮らしは変わらない', () => '山へ向かう男たちの背中を見送った。'),
        ], after: next);
      },
      ageOk: (g, a) => _span(g, a, 1550, 1575),
    ),

    SceneDef(
      'h_e_mimase',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['武田', '北条']),
      (g, next) {
        final takeda = g.l.lord == '武田';
        final foe = takeda ? '北条' : '武田';
        g.ask(
          '三増峠',
          takeda
              ? '小田原城を囲んだ信玄は、四日で兵を返した。甲斐への帰り道、三増峠で北条の兵が待ち伏せている。'
              : '小田原から引き揚げる武田勢を、三増峠で待ち伏せる。氏照・氏邦の兵が、山の上に潜んでいる。',
          [
            Choice.h(
              takeda ? '峠の上の敵へ駆け上がる' : '峠を下る武田勢に襲いかかる',
              '名を上げる好機。山の戦は乱れやすい',
              () {
                final r = g.battle('van', enemy: foe);
                if (g.l.dead == null) g.mark('三増峠の戦いで、先陣を駆けた');
                return r;
              },
            ),
            Choice.h(
              '荷駄を守る',
              '命は守りやすい。手柄は小さい',
              () => g.battle('rear', enemy: foe),
            ),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1569),
    ),

    SceneDef(
      'h_e_erinji',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['甲斐']) && (g.l.rank == 0 || _priest(g)) && g.active,
      (g, next) {
        g.ask(
          '恵林寺',
          '武田が滅び、織田の兵が甲斐に入った。信玄の菩提寺・恵林寺が、敵を匿った咎で囲まれた。山門に積まれた柴に、火がかけられようとしている。',
          [
            Choice.h('寺の者を一人でも連れ出す', '救える命がある。火の中に入ることになる', () {
              if (g.rng.chance(.2)) {
                g.die('恵林寺の焼き討ちで、寺の者を助けようとして炎に巻かれた', 'sai');
                return '煙の中で、出口を見失った。';
              }
              g.l.hp -= 15;
              g.l.net += 3;
              g.mark('恵林寺の焼き討ちの日、寺の者を炎の中から連れ出した');
              return '若い僧を一人、背負って逃げた。山門の上から「心頭滅却すれば火も自ずから涼し」と聞こえた。';
            }),
            Choice.h('遠くから手を合わせる', '身は守れる。炎は忘れられない', () {
              g.j(-6);
              return '快川和尚と百人余りの僧が、山門の上で炎に包まれたという。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1582),
    ),

    SceneDef(
      'h_e_tensho_jingo',
      15,
      70,
      (g) => 20,
      (g) =>
          _inRegion(g, ['甲斐', '信濃']) &&
          g.l.lord != '武田' &&
          g.l.rank < 8 &&
          (g.l.rank <= 1 || g.l.ronin || g.l.lord == '織田') &&
          g.canFight &&
          !_priest(g) &&
          !g.hasFlag('history_honnoji') &&
          g.active,
      (g, next) {
        final ok = <Choice>[
          if (_alive(g, '松平'))
            Choice.h('徳川家康の誘いに応じる', '武田の旧臣を厚く迎えているという。辛抱強い主だ', () {
              _join(g, '松平');
              g.l.merit += 6;
              g.mark('天正壬午の乱で、徳川家康に仕えた');
              return '武田の旧臣たちと共に、徳川に誓紙を出した。家康は甲斐を手に入れた。';
            }),
          if (_alive(g, '北条'))
            Choice.h('北条の大軍に加わる', '数はこちらが多い。勝てるとは限らない', () {
              _join(g, '北条');
              final r = g.battle('main', enemy: _alive(g, '松平') ? '松平' : null);
              if (g.l.dead == null) g.mark('天正壬午の乱で、北条に加わった');
              return '$r やがて北条と徳川は和を結び、甲斐は徳川のものになった。';
            }),
          Choice.h('どこにもつかず村を守る', '命は守れる。出世の機は逃す', () {
            return '徳川と北条の兵が、甲斐の野で何十日もにらみ合った。';
          }),
        ];
        g.ask(
          '天正壬午の乱',
          '本能寺の変で信長が倒れ、主のいなくなった甲斐と信濃に、徳川・北条・上杉が兵を入れた。武田の旧臣たちは、どこにつくかを迫られている。',
          ok,
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1582),
    ),

    // ================= 信濃 =================
    SceneDef(
      'h_e_uedahara',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '武田',
      (g, next) {
        g.ask(
          '上田原',
          '信濃の村上義清を攻める。雪の残る上田原で、村上勢が猛然と打ちかかってきた。先陣の板垣信方の隊が、押し返されている。',
          [
            Choice.h('板垣の隊を助けに駆ける', '主の重臣を救えるかもしれない。敵は勢いづいている', () {
              if (g.rng.chance(.2)) {
                g.die('上田原の戦いで、板垣信方と共に討死した', 'senshi');
                return '村上勢の槍衾に、飲み込まれた。';
              }
              g.l.merit += 12;
              g.l.hp -= 15;
              g.mark('上田原で、武田の大敗の中を生き延びた');
              return '板垣も甘利も討たれた。晴信まで手傷を負う大敗だった。';
            }),
            Choice.h('晴信の本陣を固める', '主を守る。負け戦でも咎められない', () {
              g.l.fav = _c(g.l.fav + 6);
              return '本陣は崩れなかった。だが晴信は、なかなか兵を引こうとしなかった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1548),
    ),

    SceneDef(
      'h_e_katsurao',
      15,
      70,
      (g) => 20,
      (g) =>
          _inRegion(g, ['信濃']) &&
          g.l.rank <= 1 &&
          g.l.lord != '武田' &&
          !_priest(g) &&
          g.active,
      (g, next) {
        g.ask(
          '葛尾城',
          '武田に攻められ、村上義清の葛尾城が落ちた。義清は越後の長尾景虎を頼って落ちていくという。村の若い者の中にも、ついて行く者がいる。',
          [
            if (g.canFight && _alive(g, '上杉'))
              Choice.h('義清について越後へ行く', '故郷を捨てる。越後の若い殿は戦に強いという', () {
                _join(g, '上杉', fav: 20);
                g.mark('村上義清について、越後へ落ちていった');
                return '雪の峠を越えた。春日山の若い殿は、義清を温かく迎えた。';
              })
            else
              Choice.h('寺に逃げ込み、戦をやり過ごす', '命は守れる。村の田は荒れる', () {
                _pay(g, 2);
                return '寺の床下で、何日も息をひそめた。';
              }),
            Choice.h('村に残り、武田の世で生きる', '暮らしは守れる。新しい主の年貢は重いかもしれない', () {
              return '武田の代官が来た。村の暮らしは、思ったほどは変わらなかった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1553),
    ),

    SceneDef(
      'h_e_ueda',
      15,
      84,
      (g) => 20,
      (g) =>
          _inRegion(g, ['信濃']) && g.l.rank <= 1 && g.l.lord != '松平' && g.active,
      (g, next) {
        g.ask('上田合戦', '真田昌幸の上田城に、徳川の大軍が攻め寄せる。昌幸は城下の町人や百姓にまで、戦に加われと触れを出したという。', [
          if (g.canFight)
            Choice.h('城下で敵を待ち伏せる', '真田の策に乗る。町は戦場になる', () {
              if (g.rng.chance(.1)) {
                g.die('上田合戦で、城下の辻に立ち討死した', 'senshi');
                return '徳川の兵が、どっと辻になだれ込んできた。';
              }
              g.l.merit += 6;
              g.l.fame += 6;
              g.mark('上田合戦で、真田昌幸の城下の戦いに加わった');
              return '城下に引き込んだ徳川勢に、四方から石と矢を浴びせた。逃げる敵は神川で溺れた。';
            })
          else
            Choice.h('城の兵に握り飯を運ぶ', '戦を陰で支える。町は戦場になる', () {
              g.l.net += 2;
              g.mark('上田合戦で、真田の兵に握り飯を運んだ');
              return '握り飯を運ぶ道すがら、徳川勢が城下で崩れていくのを見た。';
            }),
          Choice.h('山へ逃げて戦をやり過ごす', '命は守れる。町の者に何か言われるかもしれない', () {
            return '山の上から、徳川の大軍が崩れていくのを見た。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1585),
    ),

    // ================= 陸奥 =================
    SceneDef(
      'h_e_tenbun',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '伊達',
      (g, next) {
        g.ask(
          '天文の乱',
          '伊達の当主・稙宗が、子の晴宗に捕らえられた。救い出された稙宗と晴宗が争い、奥羽の家々が二つに割れて戦っている。',
          [
            Choice.h('嫡男・晴宗につく', '若い力につく。先代に弓を引くことになる', () {
              final r = g.battle('main');
              if (g.l.dead == null) {
                g.l.fav = _c(g.l.fav + 8);
                g.mark('伊達の天文の乱で、晴宗についた');
                return '$r 長い戦の末、晴宗が家督を握った。';
              }
              return r;
            }),
            Choice.h('父・稙宗につく', '筋は通る。負ければ立場を失う', () {
              final r = g.battle('main');
              if (g.l.dead == null) {
                g.l.fav = _c(g.l.fav - 15);
                g.l.rank = g.l.rank > 1 ? g.l.rank - 1 : 1;
                g.mark('伊達の天文の乱で、稙宗について敗れた');
                return '$r 稙宗は隠居に追い込まれ、稙宗方の者は冷や飯を食わされた。';
              }
              return r;
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1542, 1547),
    ),

    SceneDef(
      'h_e_hitotoribashi',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['伊達', '佐竹', '蘆名']),
      (g, next) {
        final date = g.l.lord == '伊達';
        g.ask(
          '人取橋',
          date
              ? '佐竹と蘆名の連合軍三万が、伊達を押しつぶしにかかる。味方は七千ほど。老将・鬼庭左月が殿に立つという。'
              : '佐竹と蘆名の連合軍は三万。若い伊達政宗を、人取橋の手前まで追い詰めた。',
          date
              ? [
                  Choice.h('鬼庭左月と共に殿に立つ', '主を逃がす盾になる。生きて帰れる者は少ない', () {
                    if (g.rng.chance(.3)) {
                      g.die('人取橋で、鬼庭左月と共に殿を務めて討死した', 'senshi');
                      return '老将の背中を見ながら、敵の波に飲まれた。';
                    }
                    g.l.merit += 25;
                    g.l.fame += 15;
                    g.l.fav = _c(g.l.fav + 15);
                    g.mark('人取橋で殿を務め、政宗を逃がして生き延びた');
                    return '左月は討たれた。だが日が暮れるまで、橋は破られなかった。';
                  }),
                  Choice.h('政宗の旗本で戦う', '主のそばで戦う。手柄はほどほど', () {
                    final r = g.battle('main', enemy: '佐竹');
                    if (g.l.dead == null) {
                      return '$r ほどなく、連合軍は国元の騒ぎで引き揚げていった。';
                    }
                    return r;
                  }),
                ]
              : [
                  Choice.h('伊達の本陣へ攻め込む', '政宗の首が見える。伊達勢は死に物狂いだ', () {
                    final r = g.battle('van', enemy: '伊達');
                    if (g.l.dead == null) g.mark('人取橋で、伊達政宗をあと一歩まで追い詰めた');
                    return r;
                  }),
                  Choice.h(
                    '後ろで構える',
                    '命は守れる',
                    () => g.battle('rear', enemy: '伊達'),
                  ),
                ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1585),
    ),

    SceneDef(
      'h_e_shiroshozoku',
      15,
      84,
      (g) => 20,
      (g) =>
          g.l.lord == '伊達' &&
          g.l.rank >= 2 &&
          g.l.rank < 8 &&
          g.canFight &&
          g.active,
      (g, next) {
        g.ask(
          '死に装束',
          '小田原に参陣せよとの秀吉の命に、政宗は遅れに遅れた。いまから小田原へ向かうという。供は少ない。生きて帰れるかはわからない。',
          [
            Choice.h('政宗の供をして小田原へ行く', '主と命を共にする。天下人を間近に見られる', () {
              if (g.rng.chance(.05)) {
                g.die('政宗の供をして小田原へ向かう途中、山道で病に倒れた', 'byo');
                return '急ぎの旅が、体にこたえた。';
              }
              g.l.fav = _c(g.l.fav + 15);
              g.l.net += 3;
              g.mark('白い死に装束の伊達政宗に供をし、秀吉の前に出た');
              return '髪を切り、白装束で現れた政宗の首筋を、秀吉は杖で軽く叩き、「もう少し遅ければ、ここが危うかったぞ」と言ったという。';
            }),
            Choice.h('国元に残って城を守る', '留守を預かる。何かあれば国が危うい', () {
              g.l.merit += 4;
              return '小田原から、政宗は許されたと知らせが来た。会津は取り上げられたという。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1590),
    ),

    SceneDef(
      'h_e_kasai_osaki',
      15,
      70,
      (g) => 20,
      (g) =>
          _inRegion(g, ['陸奥']) &&
          g.l.rank == 0 &&
          !g.l.female &&
          !_priest(g) &&
          g.active,
      (g, next) {
        g.ask(
          '葛西大崎一揆',
          '秀吉の仕置で葛西と大崎の家が取り潰され、上方から来た新しい領主の家来たちが村で乱暴を働いている。旧臣と百姓が、一揆を起こそうと誘いに来た。',
          [
            Choice.h('一揆に加わる', '黙ってはいられない。天下の軍勢を敵に回す', () {
              if (g.rng.chance(.3)) {
                g.die('葛西大崎一揆に加わり、伊達の兵に撫で斬りにされた', 'senshi');
                return '一揆は、伊達と蒲生の兵に囲まれた。';
              }
              g.l.hp -= 20;
              g.setFlag('ikki');
              g.mark('葛西大崎一揆に加わり、生き延びた');
              return '一揆は鎮められた。名を変え、山あいの村にひそんだ。';
            }),
            Choice.h('関わらず村に籠もる', '命は守れる。一揆の仲間には恨まれる', () {
              g.j(-3);
              return 'やがて一揆は鎮められた。首謀の者は、ことごとく斬られたという。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1590) || _at(g, a, 1591),
    ),

    // ================= 出羽 =================
    SceneDef(
      'h_e_mogami_ran',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '最上',
      (g, next) {
        g.ask('最上の家督', '最上の当主・義光と、隠居した父の義守が争い始めた。父には伊達の後ろ盾がある。家中が二つに割れている。', [
          Choice.h('義光につく', '若い当主につく。伊達の兵を相手にする', () {
            final r = g.battle('main');
            if (g.l.dead == null) {
              g.l.fav = _c(g.l.fav + 10);
              g.mark('最上の家督争いで、最上義光についた');
              return '$r 和睦が成り、義光は最上の主の座を守った。';
            }
            return r;
          }),
          Choice.h('義守につく', '伊達がついている。勝てば重く用いられる', () {
            g.l.fav = _c(g.l.fav - 20);
            g.j(-4);
            return '和睦が成り、義光が家を握った。義守方だった者は、肩身が狭くなった。';
          }),
        ], after: next);
      },
      ageOk: (g, a) => _at(g, a, 1574),
    ),

    SceneDef(
      'h_e_hasedo',
      15,
      84,
      (g) => 20,
      (g) =>
          _hideyoshiWorld(g) &&
          ((_soldier(g) && _lordIs(g, ['最上', '上杉'])) ||
              (_inRegion(g, ['出羽']) && g.l.rank == 0 && g.active)),
      (g, next) {
        if (_soldier(g) && _lordIs(g, ['最上', '上杉'])) {
          final mogami = g.l.lord == '最上';
          final foe = mogami ? '上杉' : '最上';
          g.ask(
            '長谷堂城',
            mogami
                ? '上杉の直江兼続が二万の兵で出羽へ攻め込んだ。長谷堂城は千ほどで守る。ここを抜かれれば山形が危うい。'
                : '直江兼続に従い、最上の長谷堂城を囲む。小城だが、守りは固い。',
            [
              Choice.h(
                mogami ? '長谷堂城に籠もって守る' : '長谷堂城へ攻めかかる',
                '激しい戦になる。名を上げる好機だ',
                () {
                  final r = g.battle(mogami ? 'main' : 'van', enemy: foe);
                  if (g.l.dead == null) {
                    g.mark('長谷堂城の戦いで、最上と上杉の戦に加わった');
                    return '$r やがて関ヶ原の知らせが届き、上杉勢は兵を引いた。';
                  }
                  return r;
                },
              ),
              Choice.h(
                '後詰めにまわる',
                '命は守りやすい',
                () => g.battle('rear', enemy: foe),
              ),
            ],
            after: next,
          );
          return;
        }
        g.ask(
          '長谷堂の戦',
          '上杉の大軍が出羽に攻め込み、村々に火を放ちながら山形へ迫っている。最上の兵は少なく、山形の殿様は百姓にも助けを求めているという。',
          [
            Choice.h('最上の城へ兵糧を運ぶ', '村を守る戦に手を貸す。道中は危うい', () {
              if (g.rng.chance(.08)) {
                g.die('長谷堂の戦の折、兵糧を運ぶ途中で上杉の兵に討たれた', 'senshi');
                return '山道で、上杉の物見に見つかった。';
              }
              g.l.net += 2;
              g.mark('長谷堂の戦で、最上の城へ兵糧を運んだ');
              return '城の兵は、米俵を見て歓声を上げた。やがて、上杉勢は引き揚げていった。';
            }),
            Choice.h('家族を連れて山へ逃げる', '命は守れる', () {
              _pay(g, 3);
              return '戻ると、村の半分が焼けていた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1600),
    ),

    SceneDef(
      'h_e_haguro',
      15,
      84,
      (g) => 20,
      // 月山・湯殿山は女人禁制だったので、男だけに出す。
      (g) => _inRegion(g, ['出羽']) && g.l.rank <= 1 && g.active && !g.l.female,
      (g, next) {
        g.ask(
          '出羽三山',
          '羽黒山・月山・湯殿山の出羽三山に、関東や越後からも白装束の参詣者がやって来る。山伏が道案内の者を探している。',
          [
            Choice.h('参詣者の道案内をする', '銭になる。山は険しい', () {
              if (g.rng.chance(.03)) {
                g.die('月山の吹雪の中で、参詣者を案内しているうちに道を失った', 'yukue');
                return '吹雪が、すべてを白く塗りつぶした。';
              }
              g.l.gold += 4;
              g.l.net += 2;
              g.mark('出羽三山で、参詣者の道案内をした');
              return '遠い国の話を聞きながら、山道を何度も往き来した。';
            }),
            Choice.h('自分も三山に詣でる', '心が洗われる。暮らしの足しにはならない', () {
              g.j(6);
              _heal(g, 5);
              return '月山の頂で、雲の海を見下ろした。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1545, 1595),
    ),

    // ================= 常陸 =================
    SceneDef(
      'h_e_oni_yoshishige',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && g.l.lord == '佐竹',
      (g, next) {
        g.ask(
          '鬼義重',
          '佐竹の当主・義重は、一太刀で七人を斬り伏せたと噂され、「鬼義重」と恐れられている。その義重が、北条との戦で自ら先頭に立つという。',
          [
            Choice.h('義重の馬のすぐ後ろを駆ける', '鬼の背中を追う。命の保証はない', () {
              final r = g.battle('van', enemy: '北条');
              if (g.l.dead == null) {
                g.l.fav = _c(g.l.fav + 8);
                g.meet('鬼の主', '佐竹義重', 40);
                g.mark('「鬼義重」佐竹義重の馬の後ろを駆けた');
              }
              return r;
            }),
            Choice.h('隊列を守って進む', '堅実だ', () => g.battle('main', enemy: '北条')),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1567, 1583),
    ),

    SceneDef(
      'h_e_numajiri',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['佐竹', '北条']),
      (g, next) {
        final foe = g.l.lord == '佐竹' ? '北条' : '佐竹';
        g.ask(
          '沼尻の対陣',
          '下野の沼尻で、佐竹と北条の大軍が沼をはさんで向かい合った。どちらも動かぬまま、もう三月になる。陣中には飽きと病が広がっている。',
          [
            Choice.h('夜陰に乗じて敵陣を探りに出る', '手柄になる。見つかれば終わりだ', () {
              if (g.rng.chance(.12)) {
                g.die('沼尻の対陣で、$foeの陣を探りに出て討たれた', 'senshi');
                return '沼の葦の中で、$foeの物見と鉢合わせた。';
              }
              g.l.merit += 10;
              g.mark('沼尻の対陣で、夜の物見に出た');
              return '敵陣の様子を持ち帰った。だが、大将たちは動かなかった。';
            }),
            Choice.h('陣中で静かに過ごす', '命は守れる。体はなまる', () {
              if (g.rng.chance(.08)) {
                g.die('沼尻の長い対陣のさなか、陣中の病で死んだ', 'byo');
                return '沼の湿気が、体を蝕んだ。';
              }
              return '夏の終わりに和睦が成り、両軍は引き揚げた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1584),
    ),

    SceneDef(
      'h_e_mito',
      15,
      84,
      (g) => 20,
      (g) =>
          _hideyoshiWorld(g) &&
          _inRegion(g, ['常陸']) &&
          g.l.rank <= 1 &&
          g.active,
      (g, next) {
        g.ask('水戸の城下', '佐竹義宣が水戸城を奪い、太田から本拠を移すという。新しい城下に町を割り、商人や職人を集めている。', [
          Choice.h('水戸の新しい町に移る', '新しい町には商いの種がある。古い縁は遠くなる', () {
            g.l.gold += 6;
            g.l.net -= 1;
            g.setFlag('moved_mito');
            g.mark('佐竹の新しい城下、水戸に移り住んだ');
            return '木の香りのする新しい町で、暮らしを始めた。';
          }),
          Choice.h('慣れた土地に留まる', '縁は守れる', () => '水戸へ向かう荷車の列を、見送った。'),
        ], after: next);
      },
      ageOk: (g, a) => _span(g, a, 1590, 1592),
    ),

    // ================= 会津 =================
    SceneDef(
      'h_e_ashina_heir',
      15,
      84,
      (g) => 20,
      (g) => g.l.lord == '蘆名' && g.l.rank >= 1 && g.l.rank < 8 && g.active,
      (g, next) {
        g.ask(
          '蘆名の跡目',
          '当主の盛隆が近習に斬られ、跡を継いだ幼子も病で死んだ。次の当主に、伊達政宗の弟・小次郎を迎えるか、佐竹義重の子・義広を迎えるかで、家中が割れている。',
          [
            Choice.h('伊達の小次郎を推す', '隣の伊達と結べる。佐竹方の家臣に恨まれる', () {
              g.l.fav = _c(g.l.fav - 10);
              g.l.net += 2;
              g.setFlag('ashina_date_side');
              return '評定は佐竹の義広に決まった。伊達を推した者たちは、家中で居場所を失っていった。';
            }),
            Choice.h('佐竹の義広を推す', '佐竹の後ろ盾を得る。伊達を敵に回す', () {
              g.l.fav = _c(g.l.fav + 10);
              g.mark('蘆名の跡目に、佐竹の義広を推した');
              return '義広が蘆名の主となった。伊達政宗は、それを許さなかった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1586, 1587),
    ),

    SceneDef(
      'h_e_suriagehara',
      15,
      70,
      (g) => 20,
      (g) => _soldier(g) && _lordIs(g, ['蘆名', '伊達']),
      (g, next) {
        final ashina = g.l.lord == '蘆名';
        g.ask(
          '摺上原',
          ashina
              ? '磐梯山の麓、摺上原で伊達の大軍とぶつかる。味方の猪苗代盛国はすでに伊達に寝返った。風向きも悪い。'
              : '磐梯山の麓、摺上原で蘆名と決戦に及ぶ。風が変われば、こちらの勝ちだと政宗は言う。',
          ashina
              ? [
                  Choice.h('義広の旗のもと最後まで戦う', '蘆名の誇りは守れる。負け戦になる', () {
                    if (g.rng.chance(.25)) {
                      g.die('摺上原で、蘆名のために戦って討死した', 'senshi');
                      return '日橋川へ追い落とされ、冷たい水に沈んだ。';
                    }
                    g.l.rank = 0;
                    g.l.lord = null;
                    g.l.ronin = true;
                    g.mark('摺上原で蘆名のために戦い、主家を失った');
                    return '蘆名は敗れた。義広は常陸へ落ち、蘆名の家は滅んだ。';
                  }),
                  if (_alive(g, '伊達'))
                    Choice.h('伊達に降る', '命と家は守れる。主を見捨てることになる', () {
                      _join(g, '伊達', fav: 15, drop: true);
                      g.j(-8);
                      g.mark('摺上原の前に、蘆名を見限って伊達に降った');
                      return '伊達の陣に降った。黒川の城には、まもなく伊達の旗が立った。';
                    }),
                ]
              : [
                  Choice.h('先陣で蘆名に斬り込む', '名を上げる好機だ', () {
                    final r = g.battle('van', enemy: '蘆名');
                    if (g.l.dead == null) g.mark('摺上原で、伊達の先陣を駆けた');
                    return r;
                  }),
                  Choice.h(
                    '政宗の本陣に控える',
                    'ほどほどの手柄',
                    () => g.battle('main', enemy: '蘆名'),
                  ),
                ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1589),
    ),

    SceneDef(
      'h_e_gamo',
      15,
      84,
      (g) => 20,
      (g) =>
          _hideyoshiWorld(g) &&
          _inRegion(g, ['会津']) &&
          g.l.rank <= 1 &&
          g.active,
      (g, next) {
        g.ask(
          '蒲生氏郷',
          '会津に、伊勢の松坂から蒲生氏郷が新しい殿様としてやって来た。黒川の名を若松と改め、市を開き、近江から職人を呼んで漆の器を作らせているという。',
          [
            Choice.h('塗師の弟子になる', '手に職がつく。修業は長い', () {
              g.l.chi = _c(g.l.chi + 2);
              g.l.gold += 3;
              g.setFlag('urushi');
              g.mark('蒲生氏郷が呼んだ職人に、会津の漆塗りを習った');
              return '朱と黒の漆を、何度も何度も塗り重ねた。';
            }),
            Choice.h('若松の市で商いを始める', '新しい城下には客が多い。上方の商人は手強い', () {
              g.l.gold += 6;
              g.l.net += 2;
              return '近江の商人たちから、算盤の使い方を覚えた。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1590, 1594),
    ),

    // ================= 駿河 =================
    SceneDef(
      'h_e_jukeini',
      15,
      84,
      (g) => 20,
      (g) => _inRegion(g, ['駿河']) && g.l.rank <= 2 && g.active,
      (g, next) {
        g.ask(
          '尼御台',
          '隣の村との境の争いが、駿府の今川館に持ち込まれた。裁くのは、今川の掟「仮名目録」に通じた尼御台・寿桂尼だという。',
          [
            Choice.h('古い証文を揃えて堂々と訴える', '理があれば通る。掟は厳しい', () {
              if (g.rng.chance(.65)) {
                g.l.gold += 5;
                g.j(4);
                g.mark('駿府で、寿桂尼の裁きを受けた');
                return '尼御台は証文を静かに読み、「帰」の印を押した書状を下した。境はこちらのものになった。';
              }
              _pay(g, 3);
              return '掟の上では、相手に理があった。尼御台の目は、少しも揺れなかった。';
            }),
            Choice.h('相手と話をつけて内々に収める', '大事にはならない。少し損をする', () {
              _pay(g, 2);
              g.l.net += 2;
              return '酒を酌み交わし、境に杭を打ち直した。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _span(g, a, 1545, 1567),
    ),

    SceneDef(
      'h_e_sunpu_1568',
      15,
      84,
      (g) => 20,
      (g) =>
          !g.hasFlag('history_okehazama') &&
          ((_inRegion(g, ['駿河']) && g.l.rank <= 1 && g.active) ||
              (g.l.lord == '今川' && g.l.rank >= 1 && g.l.rank < 8 && g.active)),
      (g, next) {
        final vassal = g.l.lord == '今川' && g.l.rank >= 1;
        g.ask(
          '駿府落ち',
          '師走、武田信玄が駿河へ攻め込んだ。今川の重臣たちは次々と寝返り、氏真は駿府を捨てて掛川へ逃れた。今川館に火の手が上がっている。',
          vassal
              ? [
                  Choice.h('氏真に従い掛川へ落ちる', '主を見捨てない。今川の先は暗い', () {
                    if (g.rng.chance(.08)) {
                      g.die('駿府落ちの道中、追手に討たれた', 'senshi');
                      return '大井川の手前で、武田の追手に追いつかれた。';
                    }
                    g.l.fav = _c(g.l.fav + 20);
                    g.mark('駿府を追われた今川氏真に従い、掛川へ落ちた');
                    return '輿もない落ち延びだった。氏真の奥方は、徒歩で掛川へ向かったという。';
                  }),
                  if (_alive(g, '武田'))
                    Choice.h('武田に寝返る', '勝つ側につく。裏切り者と呼ばれる', () {
                      _join(g, '武田', fav: 15, drop: true);
                      g.j(-6);
                      g.mark('武田の駿河攻めに、今川を見限って寝返った');
                      return '武田の陣に降った。信玄は、黙って頷いた。';
                    }),
                ]
              : [
                  Choice.h('燃える館から書物や器を運び出す', '値打ちのある物が残るかもしれない。火の粉は熱い', () {
                    if (g.rng.chance(.06)) {
                      g.die('焼け落ちる今川館で、梁の下敷きになった', 'sai');
                      return '頭の上で、太い梁が音を立てて折れた。';
                    }
                    g.l.gold += 5;
                    g.mark('焼け落ちる今川館から、都ぶりの器を運び出した');
                    return '京から来た歌書や茶碗を抱えて逃げた。「東の京」と呼ばれた駿府が燃えていた。';
                  }),
                  Choice.h('家族を連れて山へ逃げる', '命は守れる', () {
                    _pay(g, 2);
                    return '山の上から、駿府の町が燃えるのを見た。';
                  }),
                ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1568),
    ),

    SceneDef(
      'h_e_edo',
      15,
      84,
      (g) => 20,
      (g) =>
          !g.hasFlag('history_honnoji') &&
          g.active &&
          ((g.l.lord == '松平' && g.l.rank >= 1 && g.l.rank < 8) ||
              (_inRegion(g, ['駿河', '三河']) && g.l.rank == 0)),
      (g, next) {
        final vassal = g.l.lord == '松平' && g.l.rank >= 1;
        g.ask(
          '江戸へ',
          vassal
              ? '北条が滅び、秀吉は家康に関東へ移れと命じた。三河も駿河も手放し、湿地ばかりの江戸に城を構えるという。家中には不満の声もある。'
              : '徳川の殿様が、関東の江戸へ移られるという。家来衆だけでなく、町の商人や職人もついて行く者がいる。',
          vassal
              ? [
                  Choice.h('主に従い江戸へ移る', '新しい土地を一から拓く。苦労は多い', () {
                    g.l.fav = _c(g.l.fav + 10);
                    g.l.merit += 6;
                    g.setFlag('edo_move');
                    g.mark('家康の関東移封に従い、江戸へ移った');
                    return '八朔の日、家康は江戸に入った。葦の茂る入江を、皆で埋め立てていった。';
                  }),
                  Choice.h('故郷に残りたいと願い出る', '故郷は守れる。主の不興を買う', () {
                    g.l.fav = _c(g.l.fav - 15);
                    g.j(3);
                    return '許しは出たが、家康の目は冷たかった。';
                  }),
                ]
              : [
                  Choice.h('徳川について江戸へ移る', '新しい町には仕事がある。故郷は遠くなる', () {
                    g.l.gold += 5;
                    g.l.net -= 1;
                    g.setFlag('edo_move');
                    g.mark('徳川について、まだ何もない江戸へ移った');
                    return '江戸は葦原ばかりだった。だが、毎日どこかで槌の音がした。';
                  }),
                  Choice.h('故郷に残る', '慣れた暮らしを守る。新しい殿様の顔はわからない', () {
                    return '徳川の旗が去り、豊臣の大名が新しい主としてやって来た。';
                  }),
                ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1590),
    ),

    // ================= 三河 =================
    SceneDef(
      'h_e_okazaki',
      15,
      84,
      (g) => 20,
      (g) =>
          !g.hasFlag('history_okehazama') &&
          _inRegion(g, ['三河']) &&
          g.l.rank <= 1 &&
          g.active,
      (g, next) {
        g.ask(
          '岡崎の若殿',
          '桶狭間で義元が討たれ、今川の兵が岡崎城から逃げ去った。十年あまり人質として過ごした松平の若殿・元康が、岡崎へ帰ってきた。大樹寺で腹を切りかけたが、和尚に止められたという。',
          [
            Choice.h('城の門前で若殿を迎える', '三河の者の心は一つになる。若殿の行く末はまだわからない', () {
              g.l.net += 2;
              g.j(5);
              g.setFlag('welcomed_motoyasu');
              g.mark('岡崎へ帰った若き日の徳川家康を、門前で迎えた');
              return '若殿の旗には「厭離穢土 欣求浄土」と書かれていた。';
            }),
            Choice.h('今川の仕返しを恐れて家に籠もる', '用心に越したことはない', () => '戸の隙間から、行列を見送った。'),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1560),
    ),

    SceneDef(
      'h_e_mikawa_ikko',
      15,
      84,
      (g) => 20,
      (g) =>
          (_inRegion(g, ['三河']) || g.l.lord == '松平') &&
          g.l.rank < 8 &&
          !g.hasFlag('history_okehazama') &&
          g.active,
      (g, next) {
        final serving = g.l.lord == '松平' && g.l.rank >= 1;
        final vassal = serving && g.canFight && _alive(g, '松平');
        g.ask(
          '三河一向一揆',
          vassal
              ? '三河の一向宗の寺々が、松平に背いて一揆を起こした。家中にも門徒は多く、昨日までの朋輩が一揆の側で槍を構えている。'
              : '三河の一向宗の寺々が、松平の殿様に背いて立ち上がった。寺の門徒衆が、村を回って加勢を求めている。',
          [
            Choice.h(
              vassal ? '家康のもとで一揆と戦う' : '一揆に加わらず、殿様に味方する',
              '主への忠は示せる。同じ三河の者と争うことになる',
              () {
                if (vassal) {
                  final r = g.battle('main');
                  if (g.l.dead == null) {
                    g.l.fav = _c(g.l.fav + 10);
                    g.mark('三河一向一揆で、家康のもとで戦った');
                    return '$r 半年の戦の末、一揆は和を請うた。';
                  }
                  return r;
                }
                g.l.net -= 1;
                return '門徒の隣人とは、口をきかなくなった。翌年、一揆は鎮まった。';
              },
            ),
            Choice.h('門徒として一揆に加わる', '信心を貫く。主に弓を引くことになる', () {
              if (g.rng.chance(.15)) {
                g.die('三河一向一揆に加わり、松平の兵に討たれた', 'senshi');
                return '寺の土塀の前で、松平の兵に討たれた。';
              }
              g.setFlag('ikko');
              if (serving) {
                g.l.rank = 0;
                g.l.lord = null;
                g.l.ronin = true;
                g.mark('三河一向一揆で門徒につき、松平家を出奔した');
                return '一揆は敗れた。主に背いた身として、三河を去った。';
              }
              g.l.hp -= 10;
              g.mark('三河一向一揆に、門徒として加わった');
              return '一揆は敗れた。寺は壊され、門徒は散り散りになった。';
            }),
          ],
          after: next,
        );
      },
      ageOk: (g, a) => _at(g, a, 1563),
    ),
  ];
}
