import 'game.dart';

/// 遺されたもの（2026-11-23）。
///
/// 一生の終わりに「人々が覚えていたこと」を一行ずつ返す。才能（`tal_`）・暮らしと嗜み（`ps_`）・
/// 女性の暮らし（`wl_`）・縁（`bd_`）・国（`rg_`）・戦（`bt_`）・寺（`tm_`）・家族（`fa_`）・
/// 幼少期の旗と、縁のある人（`l.people`）・子の数から作る。
///
/// - 各行の文は、その旗を立てる岐路の文（選択肢・結果・`mark()`）を読んで書いた。旗が同じでも
///   中身が二通りあるもの（縄張りか堤か・形見が刀か書か・検地の厳しさ）は、歩んだ道（`l.path`）の文字で見分ける。
/// - 重み（[Remembrance.weight]）の高い順に最大5行。同じ組（[Remembrance.group]）からは一番重い一行だけ。
/// - 15歳前に亡くなった子には、子ども向けの行（[Remembrance.child]）だけを出す。
/// - 文に数字は入れない。常体の語り。既存の `mark()`・`die()`・最期の文とは別に持つ（変えない）。
class Remembrance {
  Remembrance(
    this.id,
    this.weight,
    this.when,
    this.say, {
    this.child = false,
    this.group,
  });

  final String id;
  final double weight;
  final bool Function(Game g) when;
  final String Function(Game g) say;

  /// 子ども（15歳前の死）にも出す行。
  final bool child;

  /// 同じ組からは一番重い一行だけを出す。
  final String? group;
}

/// 1つの人生に出す行の上限。
const kRemembranceMax = 5;

// ---------------------------------------------------------------- 補助

bool Function(Game) _f(String flag) => (g) => g.hasFlag(flag);
String Function(Game) _t(String s) => (_) => s;
bool _p(Game g, String s) => g.l.path.any((e) => e.contains(s));
int _fc(Game g, String id) => g.l.focus[id] ?? 0;
String? _who(Game g, String role) => g.l.people[role]?.name;

/// いまも夫婦でいる連れ合いの名。
String? _spouse(Game g) => g.l.married ? _who(g, '伴侶') : null;

/// 亡くなった師の名（`bd_ms_name:<名>`）。
String? _master(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('bd_ms_name:')) return f.substring(11);
  }
  return null;
}

/// 「師の◯◯」。名が分からなければ「師」。
String _msOf(Game g) {
  final n = _master(g);
  return n == null ? '師' : '師の$n';
}

/// 「幼なじみの◯◯」。名が分からなければ「幼なじみ」。
String _osOf(Game g) {
  final n = _who(g, '幼なじみ');
  return n == null ? '幼なじみ' : '幼なじみの$n';
}

/// 「好敵手の◯◯」。名が分からなければ「好敵手」。
String _rvOf(Game g) {
  final n = _who(g, '好敵手');
  return n == null ? '好敵手' : '好敵手の$n';
}

/// 「連れ合いの◯◯」。いまも夫婦でなければ「連れ合い」。
String _spOf(Game g) {
  final n = _spouse(g);
  return n == null ? '連れ合い' : '連れ合いの$n';
}

/// 子守をした弟妹の名（`cf_sib_name:<名>`）。分からなければ「弟妹」。
String _sib(Game g) {
  for (final f in g.l.flags) {
    if (f.startsWith('cf_sib_name:')) return f.substring(12);
  }
  return '弟妹';
}

/// 旗ひとつで決まる、文の変わらない行。
Remembrance _r(
  String flag,
  double w,
  String text, {
  bool child = false,
  String? group,
}) => Remembrance(flag, w, _f(flag), _t(text), child: child, group: group);

// ---------------------------------------------------------------- 行の表

final List<Remembrance> kRemembrances = [
  // ================================================================ 幼い日
  _r('tera_diligent', 2,'寺の手習いでは、いつも一番前に座り、和尚に筋がよいと目をかけられていた。',
      child: true, group: 'tera'),
  _r('tera_friends', 2.5, '寺の手習いで、仲間と机を並べ、筆の持ち方を教え合っていた。',
      child: true, group: 'tera'),
  Remembrance('focus_tera', 1.5, (g) => _fc(g, 'tera') >= 3,
      _t('硯を抱えて寺の手習いへ通う姿を、近所の者はよく見かけた。'),
      child: true, group: 'tera'),
  _r('sword_lessons', 2.5, '冬の朝も休まず剣の稽古に通い、指南役を一度だけうなずかせた。',
      child: true, group: 'dojo'),
  Remembrance('focus_dojo', 2, (g) => _fc(g, 'dojo') >= 2,
      _t('道場の荒稽古に、泣き言ひとつ言わずに通い続けた。'),
      child: true, group: 'dojo'),
  Remembrance('focus_abacus', 1.5, (g) => _fc(g, 'abacus') >= 2,
      _t('算盤をはじかせれば、店の大人にも引けを取らなかった。'),
      child: true),
  Remembrance('focus_manners', 1.5, (g) => _fc(g, 'manners') >= 2,
      _t('行儀見習いに上がった先で、立ち居振る舞いの美しさを褒められた。'),
      child: true),
  Remembrance('focus_friend', 1, (g) => _fc(g, 'friend') >= 4,
      _t('いつも友に囲まれて、日が暮れるまで遊んでいた。'),
      child: true, group: 'friends'),
  Remembrance('child_osananajimi', 2, (g) => g.isChild && _who(g, '幼なじみ') != null,
      (g) => '${_osOf(g)}とは、いつも一緒だった。',
      child: true, group: 'os'),
  _r('saw_battle', 2, '幼い日、戦をその目で見て、人が人を殺すさまを胸に焼き付けた。', child: true),
  _r('met_nobunaga', 4, '尾張の若殿・吉法師と野で遊んだことがある、と語り草になった。',
      child: true, group: 'cameo'),
  _r('saw_nobunaga', 1.5, '尾張の野で、若き日の吉法師の姿を見たことがあった。',
      child: true, group: 'cameo'),
  _r('met_kenshin', 4, '越後の寺で、のちの上杉謙信と言葉を交わしたことがあった。',
      child: true, group: 'cameo'),
  _r('dog', 1.5, '拾ってきた子犬のシロが、どこへ行くにもついて回っていた。', child: true),
  _r('beat_bushi_kid', 2, '木刀を向けてきた侍の子を、逆に打ち負かして泣かせた。', child: true),
  _r('honest_child', 1.5, '店番の折、多すぎた釣り銭を正直に返し、その客を常連にした。', child: true),
  _r('tomboy', 1.5, '縫い物よりも、兄に混じって木刀を振るほうを好んだ。', child: true),
  _r('nun_teacher', 1.5, '旅の尼が地面に枝で書いてくれた字を、宝のように覚えていた。', child: true),
  _r('nursed_mother', 2, '母が床に伏したとき、付きっきりで額の手ぬぐいを替え続けた。', child: true),
  _r('kind_sibling', 1, '大事な木彫りの馬を壊した兄を、黙って許してやった。', child: true),
  _r('saw_nengu', 1.5, '年貢を取り立てられる父の背中を、物陰から見ていた。', child: true),
  _r('family_head', 3, '父亡きあと、幼い身で母と家を支えた。', child: true),
  _r('monk', 1.5, '幼くして寺に入り、掃除と読経に明け暮れた。', child: true),
  _r('master_lit', 1.5, '一夜の宿の礼に、旅の僧から文字と算術の手ほどきを受けた。',
      child: true, group: 'master_child'),
  _r('master_bu', 1.5, '一夜の宿の礼に、旅の剣客から棒術の手ほどきを受けた。',
      child: true, group: 'master_child'),
  // ---- 子どもの重点 その2（`childhood_focus.dart`）と、大人になって返ってきたもの（`e4_`）----
  _r('cf_yumi_praised', 2.5, '弓の稽古で雁を射落とし、家中の大人たちに名を尋ねられた。',
      child: true, group: 'yumi'),
  _r('e4_yumi_archer', 4, '幼い日の弓の噂に違わず、大人になっても的を外さなかった。', group: 'yumi'),
  _r('cf_herb_healer', 3, '幼い身で薬草を煎じ、寝込んだ家の者の熱を下げた。',
      child: true, group: 'herb'),
  _r('e4_herb_saved', 4.5, '熱の出た村を、幼い日に覚えた薬草で救って回った。', group: 'herb'),
  _r('cf_uta_praised', 2.5, '子どもの歌の集まりで詠んだ初雪の歌を、大人たちが褒めた。',
      child: true, group: 'uta'),
  Remembrance('cf_sib_close', 2.5, _f('cf_sib_close'),
      (g) => '子守をして育てた${_sib(g)}は、片時もそばを離れなかった。',
      child: true, group: 'komori'),
  Remembrance('e4_sib_helped', 3.5, _f('e4_sib_helped'),
      (g) => '子守をして育てた${_sib(g)}が困ったとき、黙って手を差し伸べた。',
      group: 'komori'),
  _r('cf_read_river', 3, '川の水の匂いが変わったのに気づき、河原の子らを逃がしたことがあった。',
      child: true, group: 'river'),
  _r('e4_river_saved', 4.5, '大水の前に川の匂いを嗅ぎ分け、人々を高みへ逃がした。', group: 'river'),
  _r('cf_errand_trusted', 2, '市の使いでは、大人たちに正直者と信じられていた。',
      child: true, group: 'errand'),
  _r('cf_sutra_comfort', 3, '幼い身で、死にゆく人の枕元に座って経を読んだ。',
      child: true, group: 'sutra'),
  _r('e4_sutra_mourned', 3, '名もない骸や行き倒れの前で、足を止めて経を読んだ。', group: 'sutra'),
  Remembrance('river_rescue', 3, (g) => _p(g, '川で溺れかけた子を助けた'),
      _t('川で溺れかけた年下の子の手をつかみ、必死で岸へ引き上げた。'),
      child: true),
  _r('tal_c_sumo_win', 2.5, '祭りの子ども相撲で、年上の子を土俵の外へ投げ飛ばした。', child: true),
  _r('tal_c_horse', 3.5, '暴れ馬の轡に飛びつき、立ちすくむ幼い子を救った。', child: true),
  _r('tal_c_read_sign', 2.5, '辻の高札をすらすらと読み上げ、字の読めぬ大人たちをどよめかせた。',
      child: true),
  _r('tal_c_peacemaker', 2.5, '水の分け方で鍬を振り上げた大人たちを、ひと言で笑わせて収めた。',
      child: true),
  _r('tal_c_sharp', 2, '市の商人の釣り銭の誤りを見抜き、「末は勘定奉行だ」と言わせた。',
      child: true),
  _r('tal_c_white_deer', 3, '山で迷い、白い鹿に導かれて帰ってきた子だと語り継がれた。',
      child: true),
  _r('rg_c_ukai', 1.5, '長良川の鵜匠にまとわりついて、鵜の扱いをせがんでいた。', child: true),
  _r('rg_c_tosa_bridge', 2, '揺れる蔓の橋を下も見ずに渡り、山奥の親類へ使いを果たした。',
      child: true),
  _r('rg_c_satsuma_uchikomi', 2, '日が暮れるまで、叫びながら立ち木を打ち続けていた。',
      child: true),
  _r('rg_c_torioi_kind', 1.5, '鳥追いの夜、泣きべそをかく小さな子の手を最後まで離さなかった。',
      child: true),
  _r('rg_c_sake_return', 1.5, '卵を抱いた鮭を、親の渋い顔をよそに、そっと川へ戻してやった。',
      child: true),

  // ================================================================ 才
  _r('tal_tenka_ichi', 6, '「天下一の使い手」の噂は、最後まで消えなかった。', group: 'bu'),
  _r('tal_ikki', 4.5, '戦場で名乗りに応じ、一騎打ちで名のある武者を討ち取った。', group: 'bu'),
  _r('tal_gozen_win', 4, '御前試合で家老の息子を打ち負かし、殿に膝を打たせた。', group: 'bu'),
  _r('tal_beat_challenger', 3, '腕の評判を聞いて訪ねてきた旅の武芸者を、見事に退けた。',
      group: 'bu'),
  _r('tal_shinan', 3.5, '槍の指南役として、家中の若侍たちを朝ごとに鍛えた。'),
  _r('tal_monk_warrior', 4, '寺に押し入った野盗を、錫杖ひとつで追い払った僧として知られた。'),
  _r('tal_taught_youth', 2.5, '夕暮れになると、村の若い衆が棒を持って武芸を習いに集まってきた。'),
  _r('tal_strategy', 3.5, '評定で献じた奇策が見事に当たり、重臣たちの見る目を変えた。'),
  _r('tal_saw_forgery', 3, '偽りの書状や判を見抜く目の確かさは、誰もが認めていた。'),
  _r('tal_nanban_talk', 2, '南蛮の伴天連から、大地は丸いという話を夜通し聞いたことがあった。'),
  _r('tal_mondo_win', 2.5, '訪ねてきた学のある客との問答で、一歩も引かなかった。'),
  Remembrance('tal_fushin_castle', 3.5,
      (g) => g.hasFlag('tal_fushin') && _p(g, '出城の縄張り'),
      _t('縄張りを任された出城は、守りの堅さで知られた。')),
  Remembrance('tal_fushin_river', 3.5,
      (g) => g.hasFlag('tal_fushin') && _p(g, '暴れ川の堤'),
      _t('工夫を凝らした堤のおかげで、暴れ川から村の田が守られた。')),
  Remembrance('tal_gunshi', 5, (g) => g.hasFlag('tal_gunshi') && !g.hasFlag('tal_left_lord'),
      _t('知恵者の噂を聞いた他家に、軍師として迎えられた。'),
      group: 'gunshi'),
  _r('tal_left_lord', 4, '軍師の招きに応じて、元の主家を去った。それを裏切りと呼ぶ者もいた。',
      group: 'gunshi'),
  _r('tal_wrote_book', 4.5, '軍師の招きを断り、見聞きした戦の理を一冊の書に著した。'),
  _r('tal_exposed_fraud', 3, '帳尻のごまかしを見逃さず、上へ申し上げた。不正をする者には煙たがられた。',
      group: 'ledger'),
  _r('tal_bribe', 2, '帳尻のごまかしに目をつぶり、分け前を受け取ったと囁く者もいた。',
      group: 'ledger'),
  _r('tal_judge', 3, '境目の争いを、双方の言い分を聞いて間を取って裁いた。'),
  _r('tal_machi_toshiyori', 3.5, '町の年寄として寄合の上座に座り、町の掟と揉め事を預かった。'),
  _r('tal_bugyo', 4, '奉行として、城下の米と銭の出入りを預かった。'),
  Remembrance('tal_kenchi_hard', 3.5,
      (g) => g.hasFlag('tal_kenchi') && _p(g, '隠し田を残らず改めた'),
      _t('検地を差配して隠し田を残らず改め、主家の蔵を満たした。村々には恨まれた。'),
      group: 'kenchi'),
  Remembrance('tal_kenchi_new', 3.5,
      (g) => g.hasFlag('tal_kenchi') && _p(g, '新田を開かせ'),
      _t('検地のかわりに新田を開かせ、主家と村の双方を立てた。'),
      group: 'kenchi'),
  _r('tal_many_friends', 2.5, '家にはいつも相談事を抱えた者が訪ねてきて、夜更けまで灯がともっていた。'),
  _r('tal_chorayaku', 5, '敵の城へ乗り込み、城将を説き伏せて、城ごと味方に引き入れた。'),
  _r('tal_ikki_head', 5, '一揆の頭に担がれ、年貢を下げさせた。村々はその名を忘れなかった。'),
  _r('tal_favorite', 3, '殿の覚えがめでたく、たびたび御前に召された。同輩には妬まれもした。'),
  _r('tal_followers', 3, '慕って集まった者たちを束ね、頼れる仲間とした。'),
  _r('tal_meibutsu', 2.5, '古道具屋の埃の中から、名のある窯の茶碗を見つけ出した目利きだった。'),
  _r('tal_nursed', 4, '疫病の年、病み上がりの身で看病に回った。命拾いした者たちは、何度も手を合わせた。'),
  _r('tal_big_win', 2, '賭場で夜明けまで勝ち続け、胴元の顔を引きつらせたことがあった。',
      group: 'gamble'),
  _r('tal_gamble_debt', 1.5, '賭場で運が尽き、借りの証文に指を押したことがあった。', group: 'gamble'),
  _r('tal_shrine', 4, '沈んだ船に乗り遅れて命拾いし、浜に小さな社を建てた。人々はそれを強運の社と呼んだ。'),
  _r('tal_night_raid', 5, '別働隊を率いて敵の本陣に夜襲をかけ、戦の勝ちを決めた。'),
  _r('tal_machiwari', 4, '自ら引いた町割りの上に、にぎわう町が育った。'),
  _r('tal_alliance', 4.5, '使者として他家に赴き、婚姻の約定まで取りつけて両家を結んだ。'),
  _r('tal_beloved_captain', 3.5, '慕って集まった兵たちと一人ずつ盃を交わし、一隊を率いた。'),
  _r('tal_jinpu', 1, '陣夫として米俵を担ぎ、戦場の後ろを行き来したことがあった。'),
  _r('tal_cheated', 1, '字が読めず、金貸しの証文に利息を倍にされたことを、長く悔やんでいた。',
      group: 'deed'),
  _r('tal_read_deed', 1, '字は読めずとも、証文は人に読ませてから判を押す用心深さがあった。',
      group: 'deed'),

  // ================================================================ 暮らしと嗜み
  _r('ps_wish_home', 2, '寺社に参れば、家の者の無事ばかりを願っていた。', group: 'wish'),
  _r('ps_wish_rise', 1, '寺社に参っては、身の栄えを願っていた。', group: 'wish'),
  Remembrance('ps_meibutsu_kept', 4,
      (g) => g.hasFlag('ps_meibutsu') && !g.hasFlag('e2_gave_meibutsu'),
      _t('茶の湯の席で譲り受けた名物の茶碗を、何より大事にしていた。'),
      group: 'tea'),
  _r('e2_gave_meibutsu', 3, '大枚をはたいて手に入れた名物の茶碗を、所望されて差し出した。',
      group: 'tea'),
  _r('ps_tea_praise', 2, '茶の湯の席では亭主に好まれ、次の席にもと呼ばれた。', group: 'tea'),
  _r('ps_tea_honest', 2, '茶の湯の席で、分からぬものは分からぬと正直に言い、亭主に茶の心を説かれた。',
      group: 'tea'),
  _r('ps_renga_praised', 3, '連歌の会で詠んだ句を、旅の連歌師が書き留めていった。', group: 'renga'),
  _r('ps_renga_report', 1.5, '連歌の座で主家を恨むような句を詠んだ者を、殿に告げた。座の者は、それから避けるようになった。',
      group: 'renga'),
  _r('ps_hawk_kind', 3, '鷹狩りで降りた麦畑の主に、詫びの銭を置いていった。その話は、思いのほか遠くまで伝わった。'),
  _r('ps_onsen_friend', 2, '湯治場で、遠国の隠居と思わぬ縁を結んだ。'),
  _r('ps_sea_luck', 2, '年寄りの言う沖へ出て、舟べりまで魚を上げたことがあった。'),
  _r('ps_field_river', 2, '川沿いの荒れ野に鍬を入れ、黒く肥えた田に変えた。', group: 'field'),
  _r('ps_field_hill', 2, '石だらけの山裾の荒れ野を、手の皮を厚くして拓いた。', group: 'field'),
  _r('ps_field_border', 2, '隣村との境の野を拓き、長く揉め事の種を抱えた。', group: 'field'),
  _r('ps_kid_home', 1.5, '我が子に字を教えるうちに、自分も字を学び直した。', group: 'kidlearn'),
  _r('ps_kid_tera', 1, '我が子を、謝礼を払って寺の手習いへ通わせた。', group: 'kidlearn'),
  _r('ps_kid_work', 1, '我が子には、字より先に家業を仕込んだ。', group: 'kidlearn'),
  _r('ps_koto_played', 2.5, '奥方さまの宴で琴を弾き、手ずから菓子を下された。'),
  _r('ps_book_med', 2, '医薬の書を写し、草の名と煎じ方をよく知っていた。', group: 'book'),
  _r('ps_book_war', 1.5, '兵法の書を借りて、陣立ての図を一枚ずつ写し取った。', group: 'book'),

  // ================================================================ 女性の暮らし
  _r('wl_letter_warned', 2.5, '取り次ぐ文の封が切られていると気づき、奥方さまにそっと知らせた。'),
  Remembrance('wl_maid_covered', 3.5, _f('wl_maid_covered'),
      (g) => _who(g, '侍女') == null
          ? '茶碗を割った侍女をかばい、自らの不行き届きと申し出た。'
          : '茶碗を割った侍女の${_who(g, '侍女')}をかばい、自らの不行き届きと申し出た。'),
  _r('wl_sold_kosode', 3.5, '郎党が飢えずに冬を越した米が、晴れ着の小袖を売った銭だったことを、誰も知らなかった。'),
  _r('wl_books', 2, '店の帳面を一から付け直し、銭の流れをすっかり掌に収めた。'),
  _r('wl_caught_clerk', 2, '店の銭をくすねた手代を、問い詰めて白状させた。'),
  _r('wl_weavers', 3, '村の女たちと組んで布の値を揃え、町の商人に値を上げさせた。'),
  _r('wl_ondo', 2.5, '田植えの日には早乙女たちの唄の音頭を取り、その声に合わせて苗が揃った。',
      group: 'song'),
  _r('wl_old_song', 2.5, '祖母から聞いた古い田植え唄を、村の娘たちに教え残した。', group: 'song'),
  _r('wl_sheltered', 3.5, '夫の打擲から逃げてきた女を、寺に置いて匿った。'),
  _r('wl_disciples', 3, '親たちを説き伏せて、若い女たちに薙刀を教えた。'),
  _r('wl_envied_by_elder', 2.5, '奥方さまに引き立てられ、年かさの女中を越えて役に就いた。',
      group: 'oku'),
  _r('wl_yielded', 2.5, '奥の役を、長く望んできた年かさの女中に譲った。', group: 'oku'),
  _r('wl_secret_kept', 3.5, '奥方さまの密書を、夜道を越えてひそかにご実家へ届けた。', group: 'secret'),
  _r('wl_told_lord', 2, '奥方さまの密書のことを殿のお耳に入れ、奥の空気を凍らせた。', group: 'secret'),
  _r('wl_hid_hime', 5, '落ち延びた姫を尼の姿にして匿い、追手の目から守った。'),
  _r('wl_mourned_field', 4, '戦のあとの野で、村の女たちと敵味方の別なく骸を弔った。'),
  _r('wl_held_firm', 3, '夫の討死の噂が流れた日も取り乱さず、家の者を落ち着かせた。'),
  _r('wl_fair_judge', 1.5, '郎党の女房たちの諍いを、新参の言い分も聞いて裁き直した。'),
  _r('wl_kept_house', 5, '女の身で、幼い子の家督を守り抜いた。', group: 'house'),
  _r('wl_lost_house', 2, '幼い子の家督を守ろうと訴え出たが退けられ、家は人の手に渡った。',
      group: 'house'),
  _r('wl_house_lent', 1.5, '子が育つまで、家を一族の者に預けた。', group: 'house'),
  _r('wl_daughter_served', 1.5, '娘を、城下の武家の屋敷へ奉公に出した。'),
  _r('wl_shop_mistress', 4.5, '倒れた夫に代わって帳場に座り、女あるじとして店を背負った。',
      group: 'shopfall'),
  _r('wl_nursed_husband', 3, '倒れた夫の手をさすりながら、看病に明け暮れた。', group: 'shopfall'),
  _r('wl_shop_closed', 1.5, '夫が倒れたのち、店の暖簾を下ろした。', group: 'shopfall'),
  _r('wl_kou_saved', 3.5, '頼母子の講の穴を自分の銭で埋め、町の女たちに講の頭と仰がれた。'),
  _r('wl_market_judge', 3, '市で揉め事が起きれば、皆があの人に裁いてもらおうと頼ってきた。'),
  _r('wl_led_women', 4.5, '凶作の年、村の女たちの先頭に立ち、売り惜しむ商人の蔵を開けさせた。'),
  _r('wl_helped_flee', 3, '夫から逃げる隣家の女を、夜のうちに山向こうの尼寺まで送った。'),
  _r('wl_midwife', 3.5, '産婆の留守に呼ばれ、村の女房の赤子を取り上げた。', group: 'midwife'),
  _r('wl_midwife_lost', 2.5, '取り上げた赤子が息をしなかった夜のことを、忘れることはなかった。',
      group: 'midwife'),

  // ================================================================ 縁
  // ---- 幼なじみ
  Remembrance('bd_os_close', 6,
      (g) => g.hasFlag('bd_os_close') && !g.hasFlag('bd_os_slew'),
      (g) => '${_osOf(g)}とは、最後まで盃を交わす仲だった。',
      group: 'os'),
  Remembrance('bd_os_oldtalk', 6, _f('bd_os_oldtalk'),
      (g) => '老いてなお、${_osOf(g)}と縁側で日が暮れるまで昔話に興じた。',
      group: 'os'),
  Remembrance('bd_os_walk', 6, _f('bd_os_walk'),
      (g) => '老いた${_osOf(g)}と、子どもの頃に遊んだ場所を連れ立って歩いた。',
      group: 'os'),
  _r('bd_os_last_peace', 6, '長く仲違いした幼なじみと、病の床で手を取り合った。', group: 'os'),
  _r('bd_os_slew', 6, '戦場で、敵方の幼なじみを討った。子どもの頃の呼び名で呼ばれた最期の声が、耳に残った。',
      group: 'os'),
  _r('bd_os_turned', 5, '敵方にいた幼なじみを、文ひとつで味方に引き入れた。', group: 'os'),
  _r('bd_os_never', 4, '仲違いした幼なじみとは、とうとう和解できずに終わった。', group: 'os'),
  _r('bd_os_reconciled', 3.5, '仲違いしかけた幼なじみと、腹を割って話して和解した。', group: 'os'),
  _r('bd_os_kept', 3.5, '身分が開いても、幼なじみとは昔のままに会い続けた。', group: 'os'),
  Remembrance('bd_os_rift', 2.5,
      (g) => g.hasFlag('bd_os_rift') && !g.hasFlag('bd_os_last_peace'),
      _t('幼なじみとは、仲違いしたまま行き来が絶えた。'),
      group: 'os'),
  _r('bd_os_helped', 2.5, '幼なじみの頼みを、渋い顔をされてでも聞き入れた。', group: 'os'),
  _r('bd_os_refused', 1.5, '幼なじみの頼みを断った。友は振り返らずに帰っていった。', group: 'os'),
  _r('bd_os_apart', 1.5, '身分の開いた幼なじみと、会うのをやめた。', group: 'os'),
  Remembrance('os_lifelong', 3,
      (g) => !g.isChild && (g.l.people['幼なじみ']?.bond ?? 0) >= 80,
      (g) => '${_osOf(g)}とは、生涯変わらぬ仲だった。',
      group: 'os'),
  // ---- 好敵手
  _r('bd_rv_mourned', 5.5, '生涯の好敵手の棺を、自ら担いだ。', group: 'rvend'),
  _r('bd_rv_kin', 5, '亡き好敵手の遺児に、目をかけてやった。', group: 'rvend'),
  _r('bd_rv_cup', 5, '好敵手の死を聞いた夜、盃を二つ並べて朝まで偲んだ。', group: 'rvend'),
  _r('bd_rv_forgave', 4.5, 'いがみ合った好敵手の墓に、わだかまりを置いてきた。', group: 'rvend'),
  _r('bd_rv_unsettled', 3.5, '好敵手との勝ち負けは、とうとうつかないまま終わった。', group: 'rvend'),
  Remembrance('bd_rv_respect', 5, _f('bd_rv_respect'),
      (g) => '${_rvOf(g)}と盃を交わし、互いを認め合った。',
      group: 'rv'),
  _r('bd_rv_slew', 5, '果たし合いで、長年の好敵手を斬った。', group: 'rv'),
  _r('bd_rv_backed', 4, '張り合ってきた好敵手を、自ら望む座に推した。', group: 'rv'),
  _r('bd_rv_saved', 4, '窮地に陥った好敵手を、見捨てずに救った。', group: 'rv'),
  _r('bd_rv_rose', 3, '好敵手と働きぶりを競い、望む座を勝ち取った。', group: 'rv'),
  _r('bd_rv_win1', 2.5, '好敵手との腕比べに、正面から挑んで勝った。', group: 'rv'),
  _r('bd_rv_abandoned', 2.5, '窮地の好敵手を見捨てたことがあった。', group: 'rv'),
  _r('bd_rv_bribed', 2, '付け届けで好敵手を退け、座を手にしたと陰で言われた。', group: 'rv'),
  // ---- 師
  Remembrance('bd_ms_keepsake_sword', 6,
      (g) =>
          g.hasFlag('bd_ms_keepsake') &&
          !g.hasFlag('bd_ms_vow') &&
          _p(g, '形見の刀を託された'),
      (g) => '${_msOf(g)}の形見の刀を、生涯手放さなかった。',
      group: 'ms'),
  Remembrance('bd_ms_keepsake_book', 6,
      (g) =>
          g.hasFlag('bd_ms_keepsake') &&
          !g.hasFlag('bd_ms_vow') &&
          _p(g, '形見の書を託された'),
      (g) => '${_msOf(g)}の形見の書を、生涯読み継いだ。',
      group: 'ms'),
  Remembrance('bd_ms_vow', 5.5, _f('bd_ms_vow'),
      (g) => '${_msOf(g)}の枕元で、その教えを次に伝えると約束した。',
      group: 'ms'),
  Remembrance('bd_ms_buried', 4.5, _f('bd_ms_buried'),
      (g) => '${_msOf(g)}を、形見と共に葬った。',
      group: 'ms'),
  Remembrance('bd_ms_regret', 3.5, _f('bd_ms_regret'),
      (g) => '${_msOf(g)}の死を後から聞き、墓前で無沙汰を詫びた。',
      group: 'ms'),
  _r('bd_ms_grave_heir', 5, '若い者を連れて師の墓に参り、教わったことを一つずつ話して聞かせた。',
      group: 'msgrave'),
  _r('bd_ms_book', 5, '師の墓の前で、その教えを書き留めて残した。', group: 'msgrave'),
  _r('bd_ms_grave_rebuilt', 4.5, '傷んだ師の墓を、新しい石で建て直した。', group: 'msgrave'),
  _r('bd_ms_cared', 4.5, '老いて頼ってきた師を引き取り、世話をした。', group: 'msold'),
  _r('bd_ms_turned_away', 2, '老いて頼ってきた師を、会わずに門前から帰した。', group: 'msold'),
  _r('bd_ms_used', 2.5, '師の教えが、ここぞという場でよみがえった。'),
  // ---- 連れ合い
  Remembrance('bd_sp_promise_kept', 6.5, _f('bd_sp_promise_kept'),
      (g) => '長く待たせた約束を果たし、老いた${_spOf(g)}と旅に出た。',
      group: 'sp'),
  Remembrance('bd_sp_journey', 5, _f('bd_sp_journey'),
      (g) => '${_spOf(g)}の願いをかなえ、二人で旅に出た。',
      group: 'sp'),
  Remembrance('bd_sp_thanked', 5, _f('bd_sp_thanked'),
      (g) => '老いた${_spOf(g)}に、苦労をかけたと礼を言った。',
      group: 'sp'),
  Remembrance('bd_sp_quiet', 4.5, _f('bd_sp_quiet'),
      (g) => '晩年は${_spOf(g)}と縁側に並び、黙って同じ茶をすすった。',
      group: 'sp'),
  Remembrance('bd_sp_promise', 4,
      (g) => g.hasFlag('bd_sp_promise') && !g.hasFlag('bd_sp_promise_kept'),
      (g) => '${_spOf(g)}と「いつか必ず」と約束した旅は、果たせぬままだった。',
      group: 'sp'),
  Remembrance('bd_sp_together', 4, _f('bd_sp_together'),
      (g) => '苦しい年を、${_spOf(g)}と粥をすすって二人で凌いだ。',
      group: 'sp'),
  Remembrance('bd_sp_ours', 2.5, _f('bd_sp_ours'),
      (g) => '味噌は半分ずつ合わせると、${_spOf(g)}と二人の家の流儀を決めた。',
      group: 'sp'),
  Remembrance('sp_close', 3,
      (g) => !g.isChild && _spouse(g) != null && g.l.people['伴侶']!.bond >= 80,
      (g) => '${_spOf(g)}とは、終生仲睦まじかった。',
      group: 'sp'),

  // ================================================================ 国
  _r('rg_owari_cross', 2, '増水した木曽川を、渡し舟で押し渡ったことがあった。'),
  _r('rg_seto_kama', 2, '瀬戸の窯場で、幾晩も焚き口の火の番をした。'),
  _r('rg_mino_washi', 2, '美濃の冬の川で、手をひび割れさせて紙を漉いた。'),
  _r('rg_seki_blade', 2.5, '関の鍛冶に誂えた一振りを、大事にしていた。'),
  _r('rg_seki_deshi', 2.5, '関の刀鍛冶に弟子入りし、火の粉を浴びて向こう槌を振るった。'),
  _r('rg_mikawa_momen', 2, '三河の畑に綿を植え、秋には白い実を一面にはじけさせた。'),
  Remembrance('rg_fuji_top', 3,
      (g) => g.hasFlag('rg_fuji_climb') && _p(g, '富士の頂に登った'),
      _t('道者に加わり、富士の頂まで登ったことがあった。')),
  Remembrance('rg_fuji_half', 2.5,
      (g) => g.hasFlag('rg_fuji_climb') && _p(g, '女人の登れるところまで'),
      _t('富士の山を、女人の登れるところまで登ったことがあった。')),
  _r('rg_kai_share', 3, '凶作の冬、煮込みの鍋を隣の一人暮らしの年寄りに分けてやった。'),
  _r('rg_shinano_toge', 2.5, '雪の来た峠を、荷を背負って越えたことがあった。'),
  _r('rg_echigo_yuki_help', 3, '大雪の冬、隣の年寄りの家の雪まで下ろしてやった。'),
  _r('rg_hakone_guide', 2, '箱根の杣道で、身の証のない旅の者をひそかに通してやった。'),
  _r('rg_sagami_gan', 1, '小田原で評判の丸薬を、わざわざ買い求めたことがあった。'),
  _r('rg_omi_fune', 1.5, '琵琶湖の舟に荷を積み、大津へ運んだことがあった。'),
  _r('rg_omi_akinai', 2.5, '天秤棒を担ぎ、近江から見知らぬ国の市まで売り歩いた。'),
  _r('rg_gion', 2.5, '京の祇園会で、町の鉾を曳いた。', group: 'gion'),
  _r('rg_gion_fue', 2.5, '祇園会の囃子の笛を、夜ごと会所で稽古して覚えた。', group: 'gion'),
  _r('rg_kido_ban', 1.5, '夜盗の多い京の町で、拍子木を手に木戸の番に立った。'),
  _r('rg_settsu_funanori', 2.5, '兵庫の湊から船に乗り込み、瀬戸内の島々を縫って西国の湊を見て回った。'),
  _r('rg_settsu_chaya', 2, '兵庫の湊の茶屋で船乗りに飯を出し、遠い湊の話をたくさん聞いた。'),
  _r('rg_jinai_mise', 2.5, '大坂の寺内町に移り住み、堀の内で店を開いた。'),
  _r('rg_jinai_ko', 2, '大坂の御坊の門徒の講に入り、皆と声をそろえて念仏を唱えた。'),
  _r('rg_eiheiji_zazen', 3, '雪に閉ざされた永平寺で、雲水たちと冬の坐禅に連なった。'),
  _r('rg_eiheiji_maki', 2, '永平寺へ上り、雲水たちの薪割りを手伝った。'),
  _r('rg_aki_fune', 4, '嵐の夜、厳島から産婦を舟で対岸へ渡し、母子の命を救った。'),
  _r('rg_aki_broke', 3, '厳島のならわしを破り、島で赤子を産ませた。島の年寄りたちは、しばらく口をきかなかった。'),
  _r('rg_kamiari_en', 3, '出雲の神在月に大社で縁を祈り、その帰り道に出会った相手と夫婦になった。'),
  _r('rg_tatara', 2.5, '出雲の山で、三日三晩たたらの鞴を踏み続けた。'),
  _r('rg_tosa_katsuo', 2.5, '土佐の沖で、跳ねる鰹の群れを追った。'),
  _r('rg_ryukyu', 3.5, '薩摩の湊から船に乗り、琉球の湊まで渡ったことがあった。'),
  _r('rg_bungo_mushiyu', 1.5, '豊後の湯けむりの里で、石の室の蒸し湯に入った。'),
  _r('rg_ariake_oki', 2, '有明の潟に板を滑らせ、潮に追われながら貝を獲った。', group: 'ariake'),
  _r('rg_ariake_tsutsumi', 3, '有明の潟に杭を打ち、堤を築いて田を拓く普請に加わった。',
      group: 'ariake'),
  _r('rg_umaichi_horse', 2.5, '陸奥の馬市で、良い馬を買い求めた。'),
  _r('rg_sakin_hit', 3, '陸奥の冷たい沢で、砂金の粒を掬い当てた。'),
  _r('rg_benibana', 2, '出羽の畑で、指先を黄色く染めて朝露の紅花を摘んだ。'),
  _r('rg_kashima_tachi', 2.5, '鹿島の社に、太刀を奉納した。'),
  _r('rg_aizu_shio', 3, '会津から険しい峠を越え、越後の塩を背負って村へ戻った。'),

  // ================================================================ 戦
  _r('bt_slew_general', 5, '乱戦の中で、敵の将を討ち取った。', group: 'battle'),
  _r('bt_ambush_win', 5, '自らの采配で伏兵を置き、敵を破った。', group: 'battle'),
  _r('bt_rearguard_done', 5, '負け戦で殿を務め、味方を逃がした。', group: 'battle'),
  _r('bt_spared_friend', 4, '戦場で、敵方にいた昔なじみを見逃してやった。'),
  _r('bt_caught_spy', 3.5, '籠城の夜、石垣に取りついた敵の忍びを捕らえた。'),
  _r('bt_spared_foe', 2.5, '傷ついた敵兵に「早う、国へ帰れ」と言って、見逃したことがあった。'),

  // ================================================================ 寺
  _r('tm_orphans', 5, '戦で親を亡くした子らを寺に引き取り、育てた。'),
  _r('tm_segyo', 5, '凶作の冬、寺の蔵を開け、自らも薄い粥をすすりながら施した。'),
  _r('tm_shiso_peace', 5, '使僧として両家の陣を行き来し、和睦を取り次いだ。'),
  _r('tm_atome_won', 4.5, '老いた師の寺の跡目を継ぎ、多くの者を預かった。', group: 'atome'),
  _r('tm_atome_yield', 3, '寺の跡目を争わずに譲り、老いた師の枕元で昔語りを聞いて過ごした。',
      group: 'atome'),
  _r('tm_kubi_returned', 4.5, '討たれた敵の将の首を、ひそかにその家の者へ返した。', group: 'kubi'),
  _r('tm_kubi_plea', 4, '勝った家に願い出て、討たれた将の首をその家へ返させた。', group: 'kubi'),
  _r('tm_bell_hidden', 4.5, '陣鐘に取られそうになった寺の鐘を、夜のうちに土に埋めて守った。'),
  _r('tm_teacher_free', 4, '謝礼の払えない子らにも、寺で読み書きを教えた。', group: 'teacher'),
  _r('tm_teacher_kind', 2.5, 'いろは歌に節をつけ、村の子らに唄わせながら字を教えた。', group: 'teacher'),
  _r('tm_teacher_strict', 2, '寺で村の子らに、厳しく読み書きを仕込んだ。', group: 'teacher'),
  _r('tm_ryochi_kept', 4, '寺領に踏み込んだ兵を、禁制の札を掲げて退かせた。', group: 'ryochi'),
  _r('tm_sohei', 4, '寺領に踏み込んだ兵を、若い僧たちと門を固めて退けた。', group: 'ryochi'),
  _r('tm_honzon_found', 4, '盗まれた本尊を探し出し、寺に迎え戻した。'),
  _r('tm_segaki_all', 3.5, '施餓鬼会では、名も知れず死んだ者たちまで分け隔てなく供養した。'),
  _r('tm_rongi_praised', 3.5, '本山の法会の論義で自らの解釈を述べ、老いた学僧をうならせた。'),
  _r('tm_bright_pupil', 3.5, '覚えのよい教え子の親を説き伏せ、学ばせ続けた。'),
  _r('tm_shuron_win', 3.5, '町の辻の宗論で、他宗の僧を言い負かした。', group: 'shuron'),
  _r('tm_shuron_lost', 1.5, '町の辻の宗論で言葉に詰まり、檀家に去られたことがあった。',
      group: 'shuron'),
  _r('tm_told_spy', 3.5, '寺に泊まった旅の僧を間者と見抜き、役人に知らせた。'),
  _r('tm_retreat_peak', 3.5, '猟師の案内で奥の峰に分け入り、雲の海から日が昇るのを見た。',
      group: 'retreat'),
  _r('tm_retreat_done', 3, '裏山の岩屋にこもり、滝に打たれる行を満願まで貫いた。', group: 'retreat'),
  _r('tm_ko_praised', 3, '女人の講で、経を竈の火や子の熱に喩えて説き、慕われた。'),
  _r('tm_danka_judge', 3, '檀家どうしの争いを、合同の法要を開いて収めた。'),
  _r('tm_prayed_all', 3, '戦勝の祈祷を頼まれても、討たれる者すべての冥福を祈るとだけ答えた。'),
  _r('tm_goke_took', 3, '夫を亡くした武家の後家の髪を下ろし、弟子に迎えた。'),
  _r('tm_estate_field', 2.5, '自ら田に出て水の引き方を見直し、寺の田の実りを増やした。'),
  _r('tm_estate_kind', 2.5, '日照りの年、寺に納める米を半分に負けてやった。百姓たちは薪を山ほど運んで報いた。'),
  _r('tm_hakai', 2, '檀家の宴で戒を破った夜のことは、翌朝には村じゅうが知っていた。'),
  _r('tm_honzan_grudge', 2, '本山に上納の減免を願い出て睨まれ、法会に呼ばれなくなった。'),
  _r('tm_kept_vows', 1.5, '般若湯を勧められても杯を伏せ、戒を守り通した。'),

  // ================================================================ 家族
  _r('fa_hostage_rescued', 5.5, '和が破れた年、人質の我が子を敵地から背負って連れ戻した。'),
  _r('fa_yoshi_foundling', 4.5, '寺の門前の捨て子を引き取り、名を付けて我が子として育てた。',
      group: 'yoshi'),
  _r('fa_yoshi_servant', 3, '働き者の奉公人の子を、養子に迎えた。', group: 'yoshi'),
  _r('fa_yoshi_kin', 2.5, '親類の子を、養子に迎えた。', group: 'yoshi'),
  _r('fa_yoshi_lord', 2, '主君の勧めで、他家の次男を養子に迎えた。', group: 'yoshi'),
  _r('fa_no_heir', 3, '子は授からなかったが、養子は取らず、夫婦二人で生きると決めた。',
      group: 'yoshi'),
  _r('fa_kakun', 4, '子孫のために、家の掟を一巻に書き残した。'),
  _r('fa_eboshi_friend', 4, '嫡男の元服に、旧友を烏帽子親に頼んだ。', group: 'eboshi'),
  _r('fa_eboshi_lord', 3.5, '嫡男の元服に、主君を烏帽子親に仰いだ。', group: 'eboshi'),
  _r('fa_uijin_together', 4, '嫡男の初陣に、自ら付き添って戦場に立った。'),
  _r('fa_comb', 3.5, '娘に、家に伝わる櫛を手ずから渡した。'),
  _r('fa_let_go', 3.5, '別の道を望んだ我が子を、望みのままに送り出した。', group: 'kokorozashi'),
  _r('fa_kid_returned', 3, '一年だけと約束して試させた子は、日に焼けて戻り、家を継ぐと言った。',
      group: 'kokorozashi'),
  _r('fa_kept_home', 2, '別の道を望んだ我が子に、家業を継がせた。', group: 'kokorozashi'),
  _r('fa_bride_love', 3.5, '子が見初めた貧しい家の娘を、嫁に迎えてやった。', group: 'bride'),
  _r('fa_bride_match', 2, '子には、家のためになる嫁を迎えた。', group: 'bride'),
  _r('fa_hoto_back', 3.5, '賭場に入り浸る我が子を、乗り込んで連れ戻した。', group: 'hoto'),
  _r('fa_hoto_reformed', 3.5, '身を持ち崩した我が子の借りを肩代わりし、立ち直るのを黙って待った。',
      group: 'hoto'),
  _r('fa_disowned', 3, '身を持ち崩した我が子を、勘当した。', group: 'hoto'),
  _r('fa_shuppon_let', 3, '出奔した嫡男を黙って見送り、行く先の家に文を送った。', group: 'shuppon'),
  _r('fa_shuppon_cut', 3, '出奔した嫡男を廃し、家の系図からその名を消した。', group: 'shuppon'),
  _r('fa_grief_temple', 3.5, '亡くした子の供養を寺に頼み、月ごとに小さな墓へ参った。', group: 'grief'),
  _r('fa_grief_work', 2.5, '子を亡くしてからは、朝から晩まで働いて悲しみをまぎらわせた。',
      group: 'grief'),
  _r('fa_kid_temple', 3, '病の子を寺に預け、仏に仕える身として命を救ってもらった。'),
  _r('fa_mago_memorial', 3.5, '亡き人の名を、孫に継がせた。', group: 'mago'),
  _r('fa_mago_name', 3.5, '孫に、自分の名の一字を与えた。', group: 'mago'),
  _r('fa_hostage_home', 3, '人質の供に出した子が、立派な若者になって帰ってきた。'),
  _r('fa_atome_younger', 2.5, '家の跡を、兄をさしおいて才のある弟に継がせた。', group: 'atome_kid'),
  _r('fa_atome_elder', 2.5, '家の跡を、筋目どおり兄に継がせた。', group: 'atome_kid'),
  _r('fa_atome_split', 2.5, '家の跡を、二人の子に分けて与えた。', group: 'atome_kid'),
  _r('fa_tested_ok', 2.5, '家督を譲る前に、口を出さずに子の差配を見守った。'),
  _r('fa_spouse_nursed', 4, '病の連れ合いの枕元を、治るまで離れなかった。', group: 'spsick'),
  _r('fa_spouse_cured', 4, '病の連れ合いのために、遠くまで薬を求めに行った。', group: 'spsick'),
  Remembrance('fa_spouse_died', 3,
      (g) => g.hasFlag('fa_spouse_died') && !g.l.married,
      _t('連れ合いを病で亡くし、そののちの歳月をひとりで歩いた。'),
      group: 'spsick'),
  _r('fa_couple_made_up', 2, '連れ合いとの諍いは、いつも長引かせずに収めた。'),
  Remembrance('many_kids', 2, (g) => !g.isChild && g.l.kids >= 5,
      _t('子宝に恵まれ、家はいつも賑やかだった。')),
  Remembrance('grandchild', 2.5, (g) => !g.isChild && g.l.people.containsKey('孫'),
      _t('孫の顔を見るのを、何よりの楽しみにしていた。'),
      group: 'mago'),
  // ================================================================ 商いと村（trade_farm.dart）
  _r('tf_za_voice', 3, '座の仲間の先頭に立ち、本所を相手に座役のことで掛け合った。', group: 'za'),
  _r('tf_rakuichi_held', 3, '座を抜けて楽市に店を移し、古い座の嫌がらせにも屈しなかった。', group: 'za'),
  _r('tf_kome_fair', 4, '米の値が跳ね上がった年も、町の者にはいつもの値で米を売り続けた。'),
  _r('tf_kowashi_opened', 3.5, '凶作の冬、店へ押し寄せた町の者に、黙って蔵を開けた。'),
  _r('tf_norenwake', 4, '小僧から育てた手代に暖簾を分け、同じ屋号の店を持たせた。'),
  _r('tf_yasen_bargain', 4.5, '軍勢の陣へ使いに立ち、町に課された矢銭を値切って帰った。'),
  _r('tf_tekka_held', 5, '水争いの鉄火起請で焼けた鉄を握り、掌の焼け跡を生涯の誇りにした。'),
  _r('tf_kinsei', 3.5, '村じゅうの銭を集めて禁制の札をもらい、乱取りの兵から村を守った。'),
  _r('tf_genmen_won', 4.5, '村の総代として、日照りの年の年貢を軽くさせた。'),
  _r('tf_kept_seed', 3.5, '凶作の冬、飢えても春に蒔く種籾には手をつけなかった。'),
  // ================================================================ 忍び・流れ者・野盗（shadow_life.dart）
  _r('sh_n_heir', 5, '忍びの里の跡目を継ぎ、頭として里の者を束ねた。'),
  _r('sh_saved_comrade', 4, '敵の牢に捕らわれた仲間を、闇にまぎれて救い出した。'),
  _r('sh_cured_village', 4, '熱病の村に入り、忍びの薬で村の者たちを救った。'),
  _r('sh_iga_fought', 5, '天正の伊賀の戦で、焼かれる里のために砦に籠もって戦った。', group: 'iga'),
  _r('sh_iga_led', 4.5, '伊賀の戦の火の中、里の老人や子らを連れて尾根を越えた。', group: 'iga'),
  _r('sh_iga_sheltered', 3.5, '伊賀を焼け出された者たちを、詮議の目から黙ってかくまった。', group: 'iga'),
  _r('sh_band_code', 3.5, '山の一味の頭として、貧しい村からは奪わぬ掟を手下に守らせた。'),
  _r('sh_yojin_fought', 4.5, '用心棒として雇われた村を、押し寄せた野盗から守り抜いた。', group: 'yojin'),
  _r('sh_yojin_saved', 3.5, '野盗の夜、雇われた村の女子どもを山の寺へ逃がした。', group: 'yojin'),
  _r('sh_settled', 3.5, '流れ着いた村に迎えられ、刀を鍬に持ち替えて土に根を下ろした。'),
  _r('sh_ochi_spared', 3, '落ち武者狩りの山で、手負いの武者にひそかに道を教えて逃がした。'),
  // ================================================================ 足軽・雑兵（ashigaru_life.dart）
  _r('al_toritate', 5, '足軽から身を起こし、足軽の組を束ねる侍の列に加わった。'),
  _r('al_kumi_head', 4, '組頭との睨み合いも頼まれごとも越えて、退いた頭の後を継ぎ、足軽の組を預かった。'),
  _r('al_went_home', 4, '同じ村から出た仲間たちと、生きて帰る誓いのとおりに、連れ立って村へ帰った。', group: 'murato'),
  _r('al_told_mother', 4, '戻らなかった同郷の仲間の母を訪ね、鎌の柄を渡して、その最期を語った。', group: 'murato'),
  _r('al_freed_captive', 4, '乱取りで捕らえた子の縄を夜のうちに切り、親のいる村へ逃がした。'),
  _r('al_ochi_remembered', 4, '負け戦の山道で、かつて乱取りから逃がした村の者たちに匿われた。'),
  _r('al_teppo_teacher', 3.5, '鉄砲組で、若い足軽たちに火縄の扱いと撃ち方を一から教えた。'),
  _r('al_kosan_passed', 3.5, '古参の足軽に教わった生き延びる心得を、次の若い足軽に伝えた。'),
  _r('al_kura_ban', 3, '兵糧を正しく配る働きを見込まれ、陣の米蔵の番を任された。'),
  _r('al_old_banner', 3, '滅んだ主家の旗印の切れ端を、降った後もずっと守り袋に縫い込んでいた。'),
  // ================================================================ 晩年と隠居（old_age.dart）
  _r('oa_kuyo_tou', 4.5, '敵も味方も分け隔てなく名を刻んだ供養塔を、寺の裏に建てた。'),
  _r('oa_garden_tree', 3, '隠居所の庭に亡き人の好んだ木を一本植え、毎朝そのそばに立っていた。'),
  _r('oa_tales_hard', 3.5, '囲炉裏のそばで、若い者たちに飢えた冬と失ったものの話を語り聞かせた。'),
  _r('oa_pilgrim_kumano', 3, '老いた足で峠を越え、熊野の社を詣でて那智の滝の飛沫を浴びた。'),
  _r('oa_record_era', 4.5, '見聞きした乱世の人々のことを、年を追って細かに書き残した。'),
  _r('oa_tenarai_taught', 3, '孫の手習いに手本を書いてやるのを、何よりの楽しみにしていた。', group: 'mago'),
  _r('oa_funeral_plain', 3.5, '葬いは質素にと言い置き、残る銭の使い道を貧しい者への施しに決めた。'),
  _r('oa_sin_atoned', 4, '若い日の過ちを、老いてから相手の前で詫びた。'),
  _r('oa_recalled_led', 4.5, '隠居の身で呼び戻され、白髪の将として陣頭に立ち、家の危機を支えた。'),
  _r('oa_late_love_wed', 4, '老いてから思いを寄せた人と、共に暮らす日々を得た。'),
  // ================================================================ 中堅の侍と奥（retainer_life.dart）
  _r('rt_chohei_saved', 4, '主君の怒りを買った同輩のために、静まり返った座敷で一人進み出て命乞いをした。'),
  _r('rt_confidant', 4.5, '主君の秘めた談合を胸に納め、人払いの座敷で相談を受ける身となった。'),
  _r('rt_mori_shielded', 4.5, '傅役として育てた若君の初めての戦で、その馬の轡を取って守り抜いた。'),
  _r('rt_haika_handed', 4, '配下の挙げた兜首を、己の手柄とせず、配下の名で首帳に記させた。'),
  _r('rt_chigyo_levee', 4, '長雨の年、知行地の村の川から田を守る手を、自ら打った。', group: 'chigyo'),
  _r('rt_chigyo_heard', 3.5, '重い年貢を訴え出た知行地の百姓を屋敷に呼び、膝を突き合わせて話を聞いた。', group: 'chigyo'),
  _r('rt_takagari_shielded', 4, '主君の鷹を逃がした同輩が手討ちにされかけたとき、その前に膝をついてかばった。'),
  _r('rt_habatsu_mediated', 3.5, '譜代と新参に割れた家中で、両方の頭を一つの席に呼び、争いを収めた。'),
  _r('rt_o_tsukai_done', 3.5, '御台所の内々の文を携え、峠を越えて実家へ届けた。'),
  _r('rt_o_mediated', 3.5, '御台所方と側室方に割れた奥で、二つの部屋のあいだを取り持った。'),
  // ================================================================ 奥と嫁いだ女性（oku_life.dart）
  _r('ok_kane_found', 3.5, '奥の金子の帳面が表と合わないとき、自ら帳面を繰って出どころを突き止めた。'),
  _r('ok_houbai_saved', 4, '身ごもった奥の朋輩の秘め事を守り、病と偽って里へ帰してやった。', group: 'houbai'),
  _r('ok_houbai_reunited', 3, '老いてから、若い日に奥で共に勤めた朋輩と再会し、昔話に日を暮らした。', group: 'houbai'),
  _r('ok_hoso_nursed', 4, '奥で疱瘡に罹った幼い姫君の枕元に、誰も近づかないなか詰めきって看病した。'),
  _r('ok_rakujo_hime', 5, '囲みの破れる夜、幼い姫君を背負って抜け道から落ちのびた。'),
  _r('ok_rojo_wall', 4.5, '囲まれた日に薙刀を取り、奥の女の身で塀の上に立った。'),
  _r('ok_rusu_kept', 3.5, '夫の長陣の留守を、己の手で切り盛りして家と郎党を守った。'),
  _r('ok_sobame_raised', 4, '夫が外に儲けた男子を引き取り、己の子として育てた。'),
  _r('ok_ryoke_peace', 4.5, '実家と婚家が敵どうしになりかけたとき、文を取り持ち続けて両家に和を結ばせた。'),
  _r('ok_shutome_keys', 3, '何一つ褒めなかった婚家の姑を、その病の床で看取った。'),
  // ================================================================ 城主・家老・宿老（castle_life.dart）
  _r('cl_ishi_ano', 3.5, '土を盛っただけの古い城に、雨にも鉄砲にも崩れぬ石垣を築かせた。'),
  _r('cl_iriai_walked', 4, '入会の山を争う二つの村の古老を連れて尾根を歩き、苔むした境の石を見つけて争いを収めた。'),
  _r('cl_rojo_held', 5, '不意に囲まれた城を守り抜き、主家の後詰めの旗が峠に見えるまで持ちこたえた。'),
  _r('cl_spy_trap', 4, '城の台所に入り込んだ間者に偽りの知らせを拾わせ、攻め寄せた敵を峠の下で破った。'),
  _r('cl_yt_mended', 4.5, '世継ぎをめぐって割れかけた家中を、灯りを提げて一人ずつ訪ね歩き、一つにまとめた。'),
  _r('cl_isame_heard', 4.5, '主君を諫めて遠ざけられたが、鷹狩りの野で馬を並べ、ふたたび信を得た。'),
  _r('cl_domei_warned', 4, 'かつて縁組をまとめた他家の家老から内々の知らせを受け、盟約の破れを夜通し馬を駆けて主君に伝えた。'),
  _r('cl_fudai_entrusted', 4, '長く張り合った譜代の老臣に、その死の床で家中の古い者たちのことを託された。'),
  _r('cl_kiki_envoy', 5, '主家の危機に自ら敵陣へ乗り込み、和を結んで本領を守った。'),
  _r('cl_w_hostages_kind', 4, '長陣のあいだ城の奥に預かった家臣の妻子を、人質でなく客としてもてなした。'),
  // ================================================================ 庶民の生業（craft_life.dart）
  _r('cr_fune_own', 3, '借りを背負って自分の船を持ち、浜で一人前と呼ばれた。'),
  _r('cr_nanpa_saved', 3.5, '嵐の明けた浜に打ち上げられた見知らぬ男を、囲炉裏で温めて命をつないだ。'),
  _r('cr_ochudo_thanked', 4, '追われる落人の主従を山奥の炭焼き小屋にかくまい、のちに礼の使いを山に迎えた。'),
  _r('cr_kurabe_won', 3.5, '親方の跡を賭けた腕比べで、兄弟子を越える品を作ってみせた。'),
  _r('cr_deshi_sent', 3.5, '食べるにも困る家の子を弟子にとり、一人前の職人に育てて送り出した。'),
  _r('cr_mei_cut', 3, '自分の作る品に名を入れ、その名を指して買いに来る客がいた。'),
  _r('cr_niwa_master', 5, '河原の者の身で、殿様の屋形の庭の石を選び、据える場所を決めた。'),
  _r('cr_gei_named', 4, '寺の勧進の舞台で自分の工夫を入れて舞い、町の辻の子らにまで真似された。'),
  _r('cr_ekibyo_buried', 4, '疫病の町で、誰も触れたがらない骸を一人ずつ葬り、名の分かる者には札を立てた。'),
  _r('cr_kaji_broke', 4.5, '町の火事の夜、火の通り道にあった自分の家を壊させて、町を火から救った。'),
  // ================================================================ 大名・天下に手が届く者（daimyo_life.dart）
  _r('dm_shinden_menjo', 4.5, '大河の川筋を落ち着かせ、残った葦原に年貢を免じて村を移し、一面の青い田にした。'),
  _r('dm_joka_plan_saved', 4.5, '自ら割り付けた町の広い通りで、冬の大火を一つの町内で食い止めた。'),
  _r('dm_tokusei_fair', 3.5, '借りに苦しむ村々のため、証文を一枚ずつ改めさせ、利が元を越えた分だけを棒引きにした。'),
  _r('dm_chokumei', 4.5, '都から迎えた公家を通じて勅使を仰ぎ、長く争った隣家との戦を名分を保ったまま収めた。'),
  _r('dm_senrei_noslave', 4, '硝石と引き換えに民を連れて行こうとした南蛮の船に、領内の者を一人も渡さなかった。'),
  _r('dm_tori_raised', 4, '字も満足に書けない百姓あがりの足軽を、才を見込んで家老にまで引き上げた。'),
  _r('dm_ichi_reconciled', 4, '隠居させた叔父の屋敷を一人で訪ね、夜更けまで盃を重ねて和を結んだ。'),
  _r('dm_t_buji', 4, '諸国の大名に私の戦を禁じる命を下し、国境の兵を引かせた。'),
  _r('dm_t_fumi_wrote', 4, '天下を前にしても、故郷の村の年寄からの文に、自ら筆を取って返事を書いた。'),
  _r('dm_w_proved', 4.5, '女の当主を侮る重臣たちの前で算用の誤りを一つずつ正し、評定の席を黙らせた。'),
  // ================================================================ 年中行事と季節（seasons.dart）
  _r('sn_odori_wed', 4, '盆踊りの輪で出会った人と、次の年の盆に夫婦の約束を交わした。'),
  _r('sn_tsuki_kept', 3.5, '十五夜に交わした約束を守り、次の年も連れ合いと縁側で同じ月を見た。'),
  _r('sn_yabu_master', 3.5, '祭礼の流鏑馬で駆ける馬から的を射抜き、のちには若い射手を育てた。'),
  _r('sn_toro_foe', 3.5, '盆の灯籠流しでは、戦で討った名も知らぬ敵のためにも灯を流した。'),
  _r('sn_tanagyo_poor', 3.5, '盆の棚経は、布施の多い家より先に、貧しい家・遠い家から回った。'),
  Remembrance('sn_susu_reunited', 3.5, _f('sn_susu_reunited'),
      (g) => '煤払いで見つけた子どもの日の文をきっかけに、${_osOf(g)}とふたたび会った。',
      group: 'os'),
  _r('sn_wish_kept', 3, '幼い日に七夕の梶の葉へ書いた願いを、大人になって子らに語って聞かせた。'),
  _r('sn_c_kakizome_praised', 2, '正月の書き初めで古い歌を一首書き、焚き上げずに取っておけと大人に言われた。',
      child: true),
  _r('sn_c_lost_helped', 2, '盆踊りの夜、輪の外れで泣いていた迷子の手を引いて、親のもとへ送り届けた。',
      child: true),
  _r('sn_c_inoko_shared', 1.8, '亥の子の日にもらった餅を割って、いちばん小さな子らに分けてやった。',
      child: true),
];

/// この人生で当てはまる行の定義（重みの高い順。同じ組は一つだけ。最大 [kRemembranceMax]）。
List<Remembrance> rememberedEntries(Game g) {
  if (g.life == null) return const [];
  final child = g.age < 15;
  final hits = <(int, Remembrance)>[];
  for (var i = 0; i < kRemembrances.length; i++) {
    final r = kRemembrances[i];
    if (child && !r.child) continue;
    if (r.when(g)) hits.add((i, r));
  }
  hits.sort((a, b) {
    final c = b.$2.weight.compareTo(a.$2.weight);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  final groups = <String>{};
  final texts = <String>{};
  final out = <Remembrance>[];
  for (final (_, r) in hits) {
    if (out.length >= kRemembranceMax) break;
    if (r.group != null && !groups.add(r.group!)) continue;
    final s = r.say(g);
    if (s.isEmpty || !texts.add(s)) continue;
    out.add(r);
  }
  return out;
}

/// 人々が覚えていたこと（「遺されたもの」）。何もなければ空。
List<String> remembrances(Game g) =>
    [for (final r in rememberedEntries(g)) r.say(g)];
