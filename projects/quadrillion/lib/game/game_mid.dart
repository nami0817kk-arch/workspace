// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 中盤に起きること（1.0.0+19 で足した仕組み。Game.extras で切れる）
///
/// 国ごとの事件で決めたこと:
/// - 事業が出ている国（始めた国・現地法人のある国も）でだけ起きる。良い知らせ・悪い知らせはその場で効き、選ぶ事件は2〜3択。
/// - 効き目は「その国の分の事業の力」にかかる（事業の届く市場のうち、その国が占める割合だけ）。現地法人には丸ごとかかる。
/// - 払う額は、その国でいちばん売れている事業の「店・工場1つ分」の値段の何倍か（1単位の固定額）。
///   罰と見返りは、その国の売上の何か月分か。現金や時価総額の割合では決めない。
/// - 時期は年の幅の中でくじ、規模は 0.7〜1.3 倍にぶれる。
/// - 間隔: 事件のあと [ceGap] か月は起きない。毎月の確率は出ている国の数で上がるが [ceMaxP] で頭打ち。
///   同じ事件は [ceRepeat] か月は繰り返さない。ほかの選ぶ出来事と同じ月には、選ぶ事件は出さない。
///
/// 宿敵の張り合う場面で決めたこと:
/// - 出会ったあと決着する前（張り合う段）の宿敵とのあいだに、6種類の場面が起きる（同じ業種に入ってきた・人を引き抜かれた・
///   同じ会社を取り合った・手を組む話・不祥事を暴かれた・助けを求めてきた）。どれも2〜3択。
/// - 恨み（あなたがしたこと）が多いと攻める場面（入ってくる・引き抜く・暴く）が、恩が多いと歩み寄る場面（手を組む・助けを求める）が出やすい。
///   選び方で恨み・恩が増え、次の場面と、宿敵の値下げ合戦・提携の申し出の出やすさが変わる（[tieMood]）。
/// - 間隔: 場面のあと [rsGap] か月は起きない。同じ宿敵とは [rsEach] か月あける。同じ種類の場面は同じ宿敵と [rsKind] か月あける。
///   ほかの選ぶ出来事がある月には出さない。

/// 国ごとの事件の選択肢。得と損を数で持つ
class CeOpt {
  /// 呼び名（日本語の鍵）
  final String l;

  /// 払う額（その国でいちばん売れている事業の、店・工場1つ分の何倍か）
  final double u;

  /// その国の分の事業の力の増減（%）・失敗したときの増減（%）
  final double pow, fail;

  /// 払う額・入る額（その国の売上の何か月分か）
  final double fine, gain;

  /// 部下の忠誠・評判の増減、株価に響く月数、失敗の確率（%）
  final int loy, rep, sc, risk;
  const CeOpt(this.l, {this.u = 0, this.pow = 0, this.fail = 0, this.fine = 0, this.gain = 0, this.loy = 0, this.rep = 0, this.sc = 0, this.risk = 0});
}

/// 国ごとの事件（kind: good 良い知らせ / bad 悪い知らせ / pick 選ぶ）
class CeDef {
  final String id, c, kind, title, text;

  /// 起きる年の幅（この年のあいだだけ）
  final int y0, y1;
  final double pow, fine, gain;
  final List<CeOpt> opts;
  const CeDef(this.id, this.c, this.kind, this.title, this.text, {this.y0 = 0, this.y1 = 9999, this.pow = 0, this.fine = 0, this.gain = 0, this.opts = const []});
}

/// 事件のあと起きない月数・毎月の確率の頭打ち・同じ事件を繰り返さない月数
const int ceGap = 4, ceRepeat = 96;
const double ceMaxP = .16;

/// 宿敵の場面の間隔（全体・同じ宿敵・同じ宿敵との同じ種類）と、毎月の確率
const int rsGap = 5, rsEach = 14, rsKind = 60;
const double rsP = .12;

const List<CeDef> countryEvents = [
  // ===== 日本 =====
  CeDef('jp_yen', 'jp', 'pick', '急な円高', '為替が大きく動き、円が急に高くなりました。輸出の採算が合わなくなっています。', y0: 1985, y1: 1996, opts: [
    CeOpt('海外に生産を移す', u: 3, pow: 6, loy: -4),
    CeOpt('値段を据え置いて耐える', pow: -2, rep: 2),
    CeOpt('円高が収まるのを待つ', pow: -5),
  ]),
  CeDef('jp_quake', 'jp', 'bad', '大きな地震', '大きな地震が起き、店や工場が止まりました。立て直しに時間がかかります。', pow: -6),
  CeDef('jp_expo', 'jp', 'good', '国際的な催しの開催', '国際的な大きな催しが開かれ、世界中から客が集まっています。', pow: 5),
  // ===== 米国 =====
  CeDef('us_probe', 'us', 'pick', '規制当局の調べ', '競争を守る役所が、大きくなった会社のやり方を調べ始めました。あなたの会社も対象です。', opts: [
    CeOpt('和解金を払う', fine: 2, rep: 1),
    CeOpt('法廷で争う', risk: 40, fail: -10, rep: 2),
    CeOpt('やり方を改める', pow: -4, rep: 3),
  ]),
  CeDef('us_taxcut', 'us', 'good', '大型の減税', '大型の減税が決まり、買い物が活気づいています。', pow: 5),
  CeDef('us_storm', 'us', 'bad', '大型のハリケーン', '大型のハリケーンが上陸し、物流が何週間も止まりました。', pow: -4),
  // ===== 中国 =====
  CeDef('cn_rule', 'cn', 'pick', '規制の急な変更', '当局が外国の会社への決まりを急に変えました。今のやり方は続けられません。', opts: [
    CeOpt('地元の会社に株を持たせる', gain: 1, pow: -5),
    CeOpt('決まりどおりに作り直す', u: 2, pow: 2),
    CeOpt('事業を小さくして様子を見る', pow: -6),
  ]),
  CeDef('cn_boom', 'cn', 'good', '高度成長', '二けたの成長が続き、街に新しい客があふれています。', y0: 1992, y1: 2012, pow: 8),
  CeDef('cn_boycott', 'cn', 'bad', '不買の動き', '外交のもつれから、外国の商品を買わない動きが広がりました。', pow: -7),
  // ===== 韓国 =====
  CeDef('kr_crisis', 'kr', 'pick', '通貨危機', '通貨が急落し、国が国際機関の支援を受けることになりました。地元の会社が次々に売りに出ています。', y0: 1996, y1: 1999, opts: [
    CeOpt('安くなった資産を買う', u: 3, pow: 10),
    CeOpt('人を減らして耐える', pow: -2, loy: -6),
    CeOpt('嵐が過ぎるのを待つ', pow: -6),
  ]),
  CeDef('kr_wave', 'kr', 'good', '文化の流行', '音楽とドラマが世界で流行し、国の商品まで人気になっています。', y0: 2002, pow: 5),
  CeDef('kr_strike', 'kr', 'bad', '大きなスト', '大きなストが続き、工場と港が止まりました。', pow: -5),
  // ===== 台湾 =====
  CeDef('tw_chip', 'tw', 'good', '半導体の好況', '半導体の注文が世界中から集まり、街全体がうるおっています。', y0: 1990, pow: 6),
  CeDef('tw_strait', 'tw', 'pick', '海峡の緊張', '海峡をはさんだ緊張が高まり、取引先が先行きを心配しています。', opts: [
    CeOpt('在庫と拠点を分散する', u: 2, pow: -1, rep: 3),
    CeOpt('今のうちに増産する', u: 1, pow: 6, risk: 30, fail: -8),
    CeOpt('ふだんどおり続ける', pow: -2),
  ]),
  CeDef('tw_typhoon', 'tw', 'bad', '大型の台風', '大型の台風が直撃し、停電と浸水で数日間の休みを強いられました。', pow: -4),
  // ===== インド =====
  CeDef('in_open', 'in', 'good', '経済の自由化', '許可だらけだった決まりが緩み、外国の会社にも門が開きました。', y0: 1991, y1: 2003, pow: 8),
  CeDef('in_cash', 'in', 'pick', '高額紙幣の廃止', '政府が突然、高額の紙幣を使えなくしました。現金払いの客が店に来られません。', y0: 2010, opts: [
    CeOpt('電子の支払いに切り替える', u: 1, pow: 4),
    CeOpt('つけ払いで客をつなぐ', fine: 1, pow: 1),
    CeOpt('現金が戻るのを待つ', pow: -5),
  ]),
  CeDef('in_monsoon', 'in', 'bad', '雨季の不順', '雨季の雨が少なく、農村の買う力が落ち込みました。', pow: -4),
  // ===== インドネシア =====
  CeDef('id_riot', 'id', 'bad', '通貨危機と暴動', '通貨が暴落して物価が跳ね上がり、各地で暴動が起きました。', y0: 1997, y1: 1999, pow: -10),
  CeDef('id_capital', 'id', 'pick', '首都の移転', '政府が首都を別の島へ移すと決めました。新しい街づくりが始まります。', y0: 2019, opts: [
    CeOpt('新しい首都に拠点を出す', u: 3, pow: 8, risk: 30, fail: -3),
    CeOpt('今の街で守りを固める', u: 1, pow: 2),
    CeOpt('移転の行方を見る', pow: -2),
  ]),
  CeDef('id_resource', 'id', 'good', '資源の値上がり', '石炭やパーム油の値が上がり、地方の町まで景気が良くなっています。', pow: 5),
  // ===== タイ =====
  CeDef('th_flood', 'th', 'bad', '大洪水', '大雨で川があふれ、工業団地が何か月も水につかりました。', pow: -8),
  CeDef('th_baht', 'th', 'pick', '通貨の急落', '通貨を守りきれず、相場が一気に半分になりました。借金の重さは倍です。', y0: 1996, y1: 1999, opts: [
    CeOpt('輸出に振り向ける', u: 1, pow: 6),
    CeOpt('現地の借金を前倒しで返す', fine: 2, rep: 2),
    CeOpt('相場が戻るのを待つ', pow: -6),
  ]),
  CeDef('th_tour', 'th', 'good', '観光客の急増', '海外からの観光客が増え、街のどの店もにぎわっています。', pow: 5),
  // ===== ベトナム =====
  CeDef('vn_open', 'vn', 'good', '開放政策', '国が市場を開き、外国の会社を呼び込み始めました。', y0: 1988, y1: 2008, pow: 8),
  CeDef('vn_power', 'vn', 'pick', '電力不足', '暑さで電気が足りず、工場に輪番の停電が言い渡されました。', opts: [
    CeOpt('自前の発電機を入れる', u: 1, pow: 2),
    CeOpt('夜の操業に切り替える', pow: -1, loy: -5),
    CeOpt('停電の日は休む', pow: -5),
  ]),
  CeDef('vn_shift', 'vn', 'good', '工場の移転先に', '周りの国から工場が移ってきて、働き手の給料と買う力が伸びています。', y0: 2015, pow: 5),
  // ===== フィリピン =====
  CeDef('ph_typhoon', 'ph', 'bad', '超大型の台風', '超大型の台風が島々を横切り、店も倉庫も大きな被害を受けました。', pow: -7),
  CeDef('ph_rule', 'ph', 'pick', '政権交代', '選挙で政権が替わり、外国の会社への決まりが見直されます。', opts: [
    CeOpt('地元の名家と組む', u: 1, pow: 4, rep: -2),
    CeOpt('決まりどおりに組み直す', pow: -3, rep: 2),
    CeOpt('新しい政権の出方を見る', risk: 35, fail: -7),
  ]),
  CeDef('ph_remit', 'ph', 'good', '海外からの送金', '海外で働く人からの送金が増え、買い物が活気づいています。', pow: 4),
  // ===== シンガポール =====
  CeDef('sg_hub', 'sg', 'good', '拠点としての優遇', '政府が、地域の本部を置く会社への税を軽くしました。', pow: 5),
  CeDef('sg_quota', 'sg', 'pick', '働き手の枠の引き締め', '政府が外国から来る働き手の枠を絞りました。人が足りなくなります。', opts: [
    CeOpt('地元の人を高い賃金で雇う', fine: 1, loy: 4),
    CeOpt('機械に置き換える', u: 2, pow: 3, loy: -3),
    CeOpt('店を早じまいしてしのぐ', pow: -4),
  ]),
  CeDef('sg_haze', 'sg', 'bad', '煙害', '隣国の野焼きの煙が街をおおい、人が外に出なくなりました。', pow: -3),
  // ===== カナダ =====
  CeDef('ca_boom', 'ca', 'good', '資源の好況', '原油と鉱物の値が上がり、西の町にお金が流れ込んでいます。', pow: 5),
  CeDef('ca_fire', 'ca', 'bad', '大規模な山火事', '山火事が町に迫り、何万人もが避難しました。', pow: -5),
  CeDef('ca_trade', 'ca', 'pick', '貿易協定の見直し', '隣の大国が貿易協定の見直しを迫り、関税がかかるかもしれません。', opts: [
    CeOpt('隣国にも拠点を置く', u: 3, pow: 4),
    CeOpt('国内向けに作り直す', u: 1, pow: -2, rep: 2),
    CeOpt('交渉の決着を待つ', risk: 40, fail: -8),
  ]),
  // ===== 英国 =====
  CeDef('uk_bang', 'uk', 'good', '金融の自由化', '金融の決まりが一気に緩み、世界のお金が街に集まっています。', y0: 1986, y1: 1992, pow: 7),
  CeDef('uk_exit', 'uk', 'pick', '連合からの離脱', '国民投票で、大陸の連合から抜けることが決まりました。人も物も今までどおりには動きません。', y0: 2016, y1: 2024, opts: [
    CeOpt('大陸に拠点を移す', u: 3, pow: 3, loy: -3),
    CeOpt('国内に腰を据える', pow: -4, rep: 3),
    CeOpt('決まりが固まるのを待つ', risk: 50, fail: -8),
  ]),
  CeDef('uk_winter', 'uk', 'bad', '長い冬のスト', '鉄道も郵便もストで止まり、不満の冬になりました。', pow: -4),
  CeDef('uk_rate', 'uk', 'pick', '通貨の売り浴びせ', '投機筋に通貨を売り浴びせられ、金利が1日で何度も動きました。', opts: [
    CeOpt('輸出を増やす', u: 1, pow: 5),
    CeOpt('借金を前倒しで返す', fine: 1, rep: 2),
    CeOpt('嵐が過ぎるのを待つ', pow: -4),
  ]),
  // ===== オーストラリア =====
  CeDef('au_mine', 'au', 'good', '鉱山の好況', '鉄鉱石と石炭が飛ぶように売れ、国中の景気が良くなっています。', pow: 6),
  CeDef('au_fire', 'au', 'bad', '森林火災', '乾いた夏に森林火災が広がり、煙が大きな街までおおいました。', pow: -5),
  CeDef('au_water', 'au', 'pick', '干ばつと水の制限', '何年も雨が少なく、水の使い方に厳しい制限がかかりました。', opts: [
    CeOpt('水を使わない設備に替える', u: 2, pow: 3, rep: 2),
    CeOpt('水を買い付ける', fine: 1, loy: 2),
    CeOpt('操業を減らす', pow: -5),
  ]),
  // ===== 南アフリカ =====
  CeDef('za_free', 'za', 'good', '制裁の解除', '長く続いた制裁が解け、世界との商売が戻ってきました。', y0: 1994, y1: 2000, pow: 8),
  CeDef('za_power', 'za', 'pick', '計画停電', '電力会社の発電が追いつかず、毎日決まった時間に電気が止まります。', y0: 2007, opts: [
    CeOpt('太陽光と蓄電池を入れる', u: 2, pow: 3),
    CeOpt('発電機の燃料でしのぐ', fine: 1, pow: 1),
    CeOpt('停電の時間は閉める', pow: -6),
  ]),
  CeDef('za_rand', 'za', 'bad', '通貨の急落', '通貨が売られ、輸入する品の値段が跳ね上がりました。', pow: -5),
  CeDef('za_mine', 'za', 'good', '金と白金の高値', '金と白金の値が上がり、鉱山の町に活気が戻りました。', pow: 4),
  // ===== メキシコ =====
  CeDef('mx_peso', 'mx', 'bad', '通貨の暴落', '通貨が一夜で暴落し、買い物客が消えました。', y0: 1994, y1: 1996, pow: -9),
  CeDef('mx_near', 'mx', 'pick', '隣国向けの工場ブーム', '隣の大国の会社が、遠い国から工場を移し始めました。土地も人も取り合いです。', y0: 2017, opts: [
    CeOpt('工場を建て増す', u: 3, pow: 8),
    CeOpt('部品の会社と長い契約を結ぶ', u: 1, pow: 3),
    CeOpt('ブームに乗らない', pow: -2),
  ]),
  CeDef('mx_quake', 'mx', 'bad', '大きな地震', '首都を大きな地震が襲い、古い建物の多くが崩れました。', pow: -5),
  CeDef('mx_border', 'mx', 'good', '国境の貿易の伸び', '国境をまたぐ貿易が伸び、北の町に仕事が増えています。', pow: 4),
  // ===== スペイン =====
  CeDef('es_games', 'es', 'good', '五輪と万博', '同じ年に大きな催しが2つ開かれ、国中が工事と観光でにぎわっています。', y0: 1990, y1: 1994, pow: 7),
  CeDef('es_bust', 'es', 'pick', '不動産の崩れ', '建てすぎた家が売れ残り、銀行も若者の仕事も行きづまりました。', y0: 2008, y1: 2014, opts: [
    CeOpt('安くなった店を買い増す', u: 3, pow: 8),
    CeOpt('値下げで客をつなぐ', pow: -2, rep: 2),
    CeOpt('店を減らす', gain: 1, pow: -7),
  ]),
  CeDef('es_tour', 'es', 'good', '観光の当たり年', '記録的な数の観光客が訪れ、海辺の町はどこも満員です。', pow: 4),
  CeDef('es_drought', 'es', 'bad', '干ばつ', '雨が降らず、水の制限で農家も観光地も困っています。', pow: -4),
  // ===== ブラジル =====
  CeDef('br_infl', 'br', 'pick', '激しい物価高', '物価が月に何割も上がり、朝と夕方で値札が変わります。', y0: 1986, y1: 1995, opts: [
    CeOpt('毎週値段を見直す', pow: 3, rep: -3),
    CeOpt('外貨で貯えを持つ', u: 1, pow: 2),
    CeOpt('値段を据え置く', pow: -6, rep: 2),
  ]),
  CeDef('br_cup', 'br', 'good', '大きな催しの連続', '世界的な球技の大会と五輪が続けて開かれます。', y0: 2013, y1: 2017, pow: 6),
  CeDef('br_crop', 'br', 'good', '農産物の豊作', '大豆とコーヒーが豊作で、内陸の町まで景気が良くなっています。', pow: 4),
  CeDef('br_politics', 'br', 'bad', '政治の混乱', '汚職の調べが政界に広がり、公共の仕事が軒並み止まりました。', pow: -5),
  // ===== ドイツ =====
  CeDef('de_unite', 'de', 'pick', '東西の統一', '壁がなくなり、東の町に新しい市場が開けました。ただ、設備は古く、先は読めません。', y0: 1989, y1: 1993, opts: [
    CeOpt('東に大きく出る', u: 3, pow: 10, risk: 30, fail: -3),
    CeOpt('東に小さく店を出す', u: 1, pow: 3),
    CeOpt('西に集中する', pow: -1),
  ]),
  CeDef('de_energy', 'de', 'bad', 'エネルギーの高騰', 'ガスの値段が何倍にもなり、工場の採算が合わなくなりました。', y0: 2021, pow: -6),
  CeDef('de_fair', 'de', 'good', '見本市の成功', '世界最大級の見本市で引き合いが相次ぎました。', pow: 4),
  CeDef('de_hours', 'de', 'pick', '労働時間の短縮', '組合が週の労働時間を減らすよう求め、産業ごとの交渉が始まりました。', opts: [
    CeOpt('短い時間で回す仕組みに投資する', u: 2, pow: 3, loy: 4),
    CeOpt('求めをのむ', pow: -3, loy: 6),
    CeOpt('交渉を長引かせる', pow: -1, loy: -5),
  ]),
  // ===== フランス =====
  CeDef('fr_strike', 'fr', 'pick', '年金のスト', '年金の見直しに反対するストが広がり、鉄道も港も止まりました。あなたの現場でも声が上がっています。', opts: [
    CeOpt('組合の求めに応じる', fine: 1, loy: 6),
    CeOpt('管理職だけで動かす', pow: 1, loy: -6),
    CeOpt('ストが終わるのを待つ', pow: -5),
  ]),
  CeDef('fr_games', 'fr', 'good', '世界的な大会の開催', '世界的な大会が開かれ、街は観光客であふれています。', pow: 5),
  CeDef('fr_tax', 'fr', 'bad', '大企業への増税', '政府が大きな会社への税を重くしました。', fine: 1),
  // ===== イタリア =====
  CeDef('it_lira', 'it', 'pick', '通貨の切り下げ', '通貨が欧州の仕組みから外れ、大きく切り下がりました。輸出には追い風、輸入には向かい風です。', y0: 1990, y1: 1998, opts: [
    CeOpt('輸出を増やす', u: 1, pow: 6),
    CeOpt('値段を見直す', pow: 2, rep: -2),
    CeOpt('何も変えない', pow: -3),
  ]),
  CeDef('it_lux', 'it', 'good', '高級品の流行', '職人の手仕事が世界で見直され、「この国の品」というだけで売れています。', pow: 5),
  CeDef('it_quake', 'it', 'bad', '地震と政局', '中部で地震が続き、同じころ内閣も倒れました。', pow: -4),
  // ===== ロシア =====
  CeDef('ru_private', 'ru', 'pick', '国営企業の民営化', '国の会社が次々に売りに出ています。安いが、後ろに誰がいるかは分かりません。', y0: 1991, y1: 1997, opts: [
    CeOpt('払い下げを買う', u: 2, pow: 12, risk: 40, fail: -6),
    CeOpt('地元の有力者と組む', pow: 5, rep: -4),
    CeOpt('手を出さない', pow: -1),
  ]),
  CeDef('ru_default', 'ru', 'bad', '債務の不履行', '国が借金を返せなくなり、通貨は紙くず同然になりました。', y0: 1998, y1: 2000, pow: -10),
  CeDef('ru_oil', 'ru', 'good', '原油高の好況', '原油の値上がりで国にお金があふれ、街に新しい客が生まれています。', y0: 2000, y1: 2014, pow: 7),
  CeDef('ru_winter', 'ru', 'bad', '記録的な寒波', '記録的な寒波で物流が止まり、暖房の費用もかさみました。', pow: -3),
  // ===== サウジアラビア =====
  CeDef('sa_oil', 'sa', 'good', '原油の高騰', '原油の値が跳ね上がり、国の事業と買い物が一気に増えました。', pow: 6),
  CeDef('sa_vision', 'sa', 'pick', '脱石油の改革', '国が石油に頼らない国づくりを掲げ、娯楽や観光を一気に解禁しました。', y0: 2016, opts: [
    CeOpt('新しい街づくりに加わる', u: 3, pow: 9, risk: 30, fail: -3),
    CeOpt('解禁された分野に店を出す', u: 1, pow: 4),
    CeOpt('改革が続くかを見る', pow: -2),
  ]),
  CeDef('sa_glut', 'sa', 'bad', '原油の値崩れ', '原油の値が半分になり、国の事業が次々に先送りされました。', pow: -6),
  // ===== ナイジェリア =====
  CeDef('ng_naira', 'ng', 'bad', '外貨の不足', '原油安で外貨が足りなくなり、通貨が大きく切り下げられました。', pow: -7),
  CeDef('ng_mobile', 'ng', 'pick', '携帯電話の普及', '銀行の無かった町にも携帯電話が届き、若い客が一気に増えました。', y0: 2005, opts: [
    CeOpt('携帯で買える仕組みを作る', u: 2, pow: 9),
    CeOpt('若者向けに品をそろえ直す', u: 1, pow: 4),
    CeOpt('今の客を守る', pow: -2),
  ]),
  CeDef('ng_youth', 'ng', 'good', '若い人口の伸び', '働く世代が毎年大きく増え、街の買う力が伸びています。', pow: 5),
];

/// 宿敵の張り合う場面の種類と題
const Map<String, String> sceneTitle = {
  'enter': '宿敵：同じ業種に入ってきた',
  'poach': '宿敵：現場の人を引き抜かれた',
  'bid': '宿敵：同じ会社を取り合う',
  'pact': '宿敵：手を組まないかという話',
  'expose': '宿敵：不祥事を暴かれた',
  'help': '宿敵：助けを求めてきた',
};

/// 場面のせりふ（場面の種類 → 宿敵の型 → せりふ）。鍵は storyMeet と同じ
const Map<String, Map<String, String>> sceneLines = {
  'enter': {
    'zaibatsu': '「その商売、うちでも始めることにしたわ。老舗の名前は強いわよ」',
    'fund': '「君の市場は儲かると数字が言っている。だから入った。それだけだ」',
    'genius': '「君のやってること、僕ならもっとうまくやれると思って」',
    'peer': '「お前が始めたなら、俺もやる。昔からそうだったろ」',
    'state': '「この分野は国の柱になる。我々が出ないわけにはいかない」',
    'asia': '「一族の次の柱を探していた。あなたの畑はよく肥えている」',
    'bigtech': '「この市場、うちの仕組みに載せることにしたよ。悪いね」',
    'grit': '「お主の商売、わしもやってみることにした。汗なら負けん」',
    'ex': '「社長の隣に店を出します。教わったことを全部使って」',
    'avenger': '「お前の庭を、一つずつ奪っていく」',
  },
  'poach': {
    'zaibatsu': '「あなたの所の人たち、うちの看板の下で働きたいそうよ」',
    'fund': '「人は給料で動く。倍出すと言ったら、すぐに来たよ」',
    'genius': '「君の現場の人たち、僕の会社のほうが面白いってさ」',
    'peer': '「悪いな、何人かもらった。腕のいい奴はお互い欲しいだろ」',
    'state': '「彼らは国のために働くことを選んだ」',
    'asia': '「良い人には良い席を用意する。それが一族のやり方だ」',
    'bigtech': '「うちの社食と株の話をしたら、みんな来てくれたよ」',
    'grit': '「お主の所の若いのが、わしの下で鍛えられたいと言うてな」',
    'ex': '「昔の仲間に声をかけました。来たいと言ってくれた人がいます」',
    'avenger': '「お前の周りから、人が一人ずつ消えていく」',
  },
  'bid': {
    'zaibatsu': '「あの会社はうちが引き取るの。順番というものがあるわ」',
    'fund': '「あの会社は私が先に目をつけた。値をつり上げるのはやめたまえ」',
    'genius': '「あの会社、僕も欲しいんだ。早い者勝ちでいいよね」',
    'peer': '「あの会社、お前も狙ってたのか。なら競争だ」',
    'state': '「あの会社は国の計画に入っている。手を引いてもらおう」',
    'asia': '「あの会社とは祖父の代からの縁がある。譲ってもらえないか」',
    'bigtech': '「あの会社はうちが買う。値段の話なら、いくらでも付き合うよ」',
    'grit': '「あの会社はわしが育てる。金で横取りはさせん」',
    'ex': '「あの会社、僕も交渉しています。今回は譲れません」',
    'avenger': '「お前が欲しがるものは、すべて先に取る」',
  },
  'pact': {
    'zaibatsu': '「一度くらい、同じ側に立ってみない？　悪い話ではないはずよ」',
    'fund': '「一緒にやれば双方が儲かる。計算は済んでいる」',
    'genius': '「君と僕で一つ作ってみない？　きっと面白いものになる」',
    'peer': '「たまには組まないか。お前とならうまくいく気がする」',
    'state': '「国の事業に、あなたの力を借りたい」',
    'asia': '「一族の者とあなたの会社で、一つ商品を作りたい」',
    'bigtech': '「一緒に作らないか。うちの仕組みと君の現場を合わせるんだ」',
    'grit': '「お主とわしで一つ作ってみんか。喧嘩ばかりも飽きた」',
    'ex': '「社長、一度だけ一緒にやりませんか。昔みたいに」',
    'avenger': '「……一度だけ手を貸せ。一族のためだ、お前のためではない」',
  },
  'expose': {
    'zaibatsu': '「あなたの会社のこと、記者の方々にお話ししておいたわ」',
    'fund': '「君の会社の資料を新聞に渡した。株が下がれば、私は買いやすい」',
    'genius': '「隠し事はよくないよ。みんなに知らせておいたから」',
    'peer': '「悪く思うな。勝負に使えるものは使う」',
    'state': '「あなたの会社について、当局が関心を持っている」',
    'asia': '「噂は風より早い。もう町中が知っている」',
    'bigtech': '「君の会社の件、うちの検索で一番上に出るようにしておいたよ」',
    'grit': '「曲がったことは許せん性分でな。世間に話させてもらった」',
    'ex': '「社長、あの件はやはり黙っていられませんでした」',
    'avenger': '「お前の隠してきたものを、すべて日の下に出す」',
  },
  'help': {
    'zaibatsu': '「……恥を忍んでお願いするわ。少しだけ力を貸してほしいの」',
    'fund': '「資金の手当てが要る。貸してくれれば、利子を付けて返す」',
    'genius': '「ちょっと失敗しちゃってさ。助けてくれない？」',
    'peer': '「すまん、今回だけは頼む。お前にしか言えない」',
    'state': '「これは内々の話だ。少しのあいだ支えてもらいたい」',
    'asia': '「一族の恥だが、頭を下げに来た。力を貸してほしい」',
    'bigtech': '「今期だけ厳しいんだ。助けてくれたら、借りは必ず返す」',
    'grit': '「面目ない。わしの会社を、少しだけ助けてくれんか」',
    'ex': '「社長、厚かましいお願いですが、助けてください」',
    'avenger': '「……お前に頭を下げる日が来るとはな。金を貸してくれ」',
  },
};

extension GameMid on Game {
  // ===== 国ごとの事件 =====
  /// 事業が出ている国（始めた国・現地法人のある国も）
  List<String> cePresent() => <String>{for (final b in biz) ...ctryOf(b), for (final c in locals()) c.loc!}.toList();

  /// その国に出ている事業
  List<Biz> ceBiz(String c) => biz.where((b) => ctryOf(b).contains(c)).toList();

  /// 事業の届く市場のうち、その国が占める割合
  double ceFrac(Biz b, String c) => clampD(cw(c, yr()) / math.max(reachOf(b), 1e-9), 0, 1);

  /// その国の毎月の売上（事業のその国の分＋現地法人）
  double ceRev(String c) =>
      ceBiz(c).fold(0.0, (s, b) => s + b.rev * ceFrac(b, c)) + locals().where((x) => x.loc == c).fold(0.0, (s, x) => s + x.rev);

  /// その国でいちばん売れている事業の業種（現地法人だけならその業種）
  String? ceTop(String c) {
    final l = ceBiz(c)..ssort((a, b) => (b.rev * ceFrac(b, c)).compareTo(a.rev * ceFrac(a, c)));
    if (l.isNotEmpty) return l.first.ind;
    return locals().where((x) => x.loc == c && x.biz.isNotEmpty).firstOrNull?.biz.first.ind;
  }

  /// その国での1単位の値段（いちばん売れている事業の、店・工場1つ分）
  double ceUnit(String c) {
    final t = ceTop(c);
    return t == null ? 0 : capexOf(indm[t]!);
  }

  /// その国の分の事業の力を増減する（%）
  void cePow(String c, double p) {
    for (final b in ceBiz(c)) {
      final m = 1 + p / 100 * ceFrac(b, c);
      b.power *= m;
      if (b.crew != null && b.crew != 0) b.crew = b.crew! * m;
    }
    for (final x in locals().where((x) => x.loc == c)) {
      for (final b in x.biz) {
        b.power *= 1 + p / 100;
      }
    }
  }

  static int _ceRound(double v) => v == 0
      ? 0
      : v.round() == 0
          ? (v > 0 ? 1 : -1)
          : v.round();
  static String _signed(num v) => '${v > 0 ? '+' : ''}${jsNum(v.toDouble())}';

  /// 得と損の一覧（選択肢の説明・知らせの末尾に出す）。[s] は規模のぶれ
  String ceChips(String c, CeOpt o, double s, double unit, double rev0) {
    final pw = _ceRound(o.pow * s), fl = _ceRound(o.fail * s);
    final pay = o.u * unit + o.fine * s * rev0;
    return J([
      if (pay > 0) M('支払い {0}', [Y(pay)]),
      if (o.gain > 0) M('収入 {0}', [Y(o.gain * s * rev0)]),
      if (pw != 0) M('{0}の事業の力 {1}%', [C(c), _signed(pw)]),
      if (o.risk > 0) M('{0}%の確率で裏目に出る（{1}の事業の力 {2}%）', [o.risk, C(c), _signed(fl)]),
      if (o.loy != 0) M('部下の忠誠 {0}', [_signed(o.loy)]),
      if (o.rep != 0) M('評判 {0}', [_signed(o.rep)]),
      if (o.sc > 0) M('株価に{0}か月響く', [o.sc]),
      if (pay <= 0 && o.gain <= 0 && pw == 0 && o.risk <= 0 && o.loy == 0 && o.rep == 0 && o.sc <= 0) M('何も起きない'),
    ]);
  }

  /// 得と損を効かせる。裏目に出たら true
  bool _ceApply(String c, CeOpt o, double s, double unit, double rev0) {
    cfAdd('sp', -(o.u * unit + o.fine * s * rev0));
    cfAdd('sp', o.gain * s * rev0);
    var failed = false;
    if (o.risk > 0 && rnd() * 100 < o.risk) {
      failed = true;
      cePow(c, _ceRound(o.fail * s).toDouble());
    } else {
      cePow(c, _ceRound(o.pow * s).toDouble());
    }
    if (o.loy != 0) {
      for (final p in staff) {
        p.loy = clampD(p.loy + o.loy, 0, 99);
      }
    }
    rep = rep + o.rep;
    if (o.sc > 0) scandal = math.max(scandal, o.sc);
    calcAll();
    return failed;
  }

  /// 今その国で起こせる事件か（年の幅・出ているか）
  bool ceCan(CeDef d) => extras && yr() >= d.y0 && yr() < d.y1 + 1 && ceTop(d.c) != null;

  /// 事件を起こす。良い・悪い知らせはその場で効かせて null、選ぶ事件は出来事を返す。[s] は規模のぶれ
  GameEvent? ceFire(CeDef d, void Function(String, [String]) N, {double s = 1}) {
    final c = d.c;
    final unit = ceUnit(c), rev0 = ceRev(c);
    crisis['ce:${d.id}'] = turn;
    crisis['ce:last'] = turn;
    if (d.kind != 'pick') {
      final o = CeOpt('', pow: d.pow, fine: d.fine, gain: d.gain);
      final chips = ceChips(c, o, s, unit, rev0);
      _ceApply(c, o, s, unit, rev0);
      // 国の事件は時代の波と同じ「大きな知らせ」。悪いものは bad
      N(M('【{0}：{1}】{2}（{3}）', [C(c), M(d.title), M(d.text), chips]), d.kind == 'bad' ? 'bad' : 'big');
      return null;
    }
    final n = ceBiz(c).length + locals().where((x) => x.loc == c).length;
    final top = ceTop(c)!;
    return GameEvent(
        title: M('{0}：{1}', [C(c), M(d.title)]),
        text: Cat([M(d.text), M('{0}に出ている「{1}」など{2}つの事業に響きます。', [C(c), I(top), n])]),
        choices: [
          for (final o in d.opts)
            Choice(M(o.l), ceChips(c, o, s, unit, rev0), () {
              if (o.u * unit + o.fine * s * rev0 > math.max(cash, 0.0) && o.u > 0) {
                // 払えないときは、いちばん下の（お金のかからない）選択肢と同じ結果になる
                _ceApply(c, d.opts.last, s, unit, rev0);
                return M('お金が足りず、「{0}」はできませんでした。「{1}」ことになりました', [M(o.l), M(d.opts.last.l)]);
              }
              final failed = _ceApply(c, o, s, unit, rev0);
              return Cat([M('「{0}」ことにしました', [M(o.l)]), if (o.risk > 0) M(failed ? '裏目に出ました' : 'うまくいきました')], ja: '。', en: '. ');
            }),
        ]);
  }

  /// 毎月、国ごとの事件が起きるかを見る
  void countryMonthly(void Function(String, [String]) N) {
    if (!extras || over != null) return;
    if (turn - (crisis['ce:last'] ?? -99) < ceGap) return;
    final here = cePresent();
    if (here.isEmpty) return;
    // 出ている国が多いほど起きやすいが、頭打ちにする
    if (rnd() >= math.min(ceMaxP, .04 + .015 * here.length)) return;
    final busy = events.isNotEmpty;
    final pool = countryEvents
        .where((d) => here.contains(d.c) && ceCan(d) && turn - (crisis['ce:${d.id}'] ?? -999) >= ceRepeat && !(busy && d.kind == 'pick'))
        .toList();
    if (pool.isEmpty) return;
    // 先に国を選ぶ（事件の種類が多い国に偏らないように）
    final c = pick(<String>{for (final d in pool) d.c}.toList());
    final d = pick(pool.where((d) => d.c == c).toList());
    final ev = ceFire(d, N, s: .7 + rnd() * .6);
    if (ev != null) events.add(ev);
  }

  // ===== 宿敵の張り合う場面 =====
  /// 恨みと恩で決まる宿敵の気分（1 より大きいと攻めてくる・小さいと歩み寄る）。値下げ合戦の出やすさにかける
  double tieMood(Rival r) => !extras || r.st != 1 ? 1 : clampD(1 + .25 * (r.grudge - r.favor), .4, 2);

  /// 恩で提携の申し出が出やすくなる倍率
  double tieWarm(Rival r) => !extras || r.st != 1 ? 1 : 1 + .5 * math.min(math.max(r.favor - r.grudge, 0), 4);

  /// 宿敵が弱っているか（赤字・資金切れ・売上が1年で1割5分落ちた）
  bool rivalWeak(Company c) => c.profit <= 0 || c.cash <= 0 || (c.revHist.length >= 12 && c.rev < c.revHist[c.revHist.length - 12] * .85);

  /// 取り合う会社（自分の事業と同じ分類の、宿敵でも子会社でもない会社。払える中でいちばん大きいもの）
  Company? bidTarget(Company foe) {
    final cats = <String>{for (final b in biz) indm[b.ind]!.cat};
    final l = cos
        .where((x) =>
            x.alive &&
            x.rival == null &&
            x.parent != 'player' &&
            x.stakePlayer <= 0 &&
            x.biz.isNotEmpty &&
            x.cap > 0 &&
            x.biz.any((b) => cats.contains(indm[b.ind]!.cat)) &&
            bidCost(x) <= cash)
        .toList()
      ..ssort((a, b) => b.cap.compareTo(a.cap));
    return l.firstOrNull;
  }

  /// 取り合いに競り勝つ値段（相手の会社の時価総額の65%。株51%に上乗せを付けた額）
  double bidCost(Company t) => t.cap * .65;

  /// 助けを求められたときに貸す額（相手の売上3か月分。少なくとも1000万円×物価）
  double helpCost(Company c) => math.max(c.rev * 3, 1e7 * nom());

  /// 今その宿敵と起こせる場面の種類と重み（恨みが多いと攻める場面、恩が多いと歩み寄る場面）
  Map<String, int> sceneWeights(Company c) {
    final r = c.rival;
    if (!extras || r == null || r.st != 1 || !c.alive || c.parent == 'player' || biz.isEmpty) return const {};
    final hostile = r.grudge + r.hurt - r.favor * 2;
    final w = <String, int>{};
    if (biz.any((b) => !c.biz.any((x) => x.ind == b.ind))) w['enter'] = 2 + math.max<int>(0, math.min<int>(hostile, 4));
    if (biz.any((b) => crewOf(b) > 0)) w['poach'] = 1 + math.max(0, math.min(r.grudge, 3));
    if (bidTarget(c) != null) w['bid'] = 2;
    if (hostile <= 2 && c.biz.isNotEmpty) w['pact'] = 1 + math.min(r.favor, 3) * 2;
    if (r.grudge >= 1 || c.rel < -20) w['expose'] = 1 + math.min<int>(r.grudge, 3) + (buried.isNotEmpty ? 3 : 0);
    if (rivalWeak(c)) w['help'] = 3 + math.min(r.favor, 3);
    w.removeWhere((k, v) => turn - (crisis['rs:${c.id}:$k'] ?? -999) < rsKind);
    return w;
  }

  /// 場面の前置き（恨みと恩で変わる）
  String? _mood(Company c) {
    final r = c.rival!;
    if (r.grudge - r.favor >= 2) return M('これまでの恨みを、{0}は忘れていません。', [Nm(c.presName)]);
    if (r.favor - r.grudge >= 2) return M('これまでの恩を、{0}は覚えています。', [Nm(c.presName)]);
    return null;
  }

  GameEvent _rs(Company c, String k, String note, List<Choice> choices) {
    final r = c.rival!;
    final line = sceneLines[k]![r.kind] ?? sceneLines[k]![r.type] ?? sceneLines[k]!['peer']!;
    return GameEvent(who: c, face: r.col, title: M(sceneTitle[k]!), text: Cat([M(line), Cat([note, ?_mood(c)])], ja: '\n', en: '\n'), choices: choices);
  }

  /// 張り合う場面を作る（条件がそろわなければ null）。場面の入り口で起きること（相手が入ってくる・人が抜ける）はここで効く
  GameEvent? rivalScene(Company c, String k) {
    final r = c.rival;
    if (!extras || r == null || biz.isEmpty) return null;
    final top = (biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).first;
    switch (k) {
      case 'enter':
        final b = (biz.where((b) => !c.biz.any((x) => x.ind == b.ind)).toList()..ssort((a, b) => b.rev.compareTo(a.rev))).firstOrNull;
        if (b == null) return null;
        final x = CoBiz(ind: b.ind, power: b.power * .35);
        c.biz.add(x);
        tieRec(c, 'h', M('「{0}」に乗り込まれた', [I(b.ind)]));
        final cost = invBase(b) * .25;
        return _rs(c, k, M('{0}（{1}）が、あなたの「{2}」と同じ商売を始めました。', [Nm(c.presName), Nm(c.name), I(b.ind)]), [
          Choice(M('広告で迎え撃つ'), M('{0}で6か月の広告を打つ。相手の出足をくじくが、関係は悪くなる', [Y(cost)]), () {
            if (cash < cost) return M('お金が足りず、迎え撃てませんでした');
            cfAdd('grow', -cost);
            b.ad = 6;
            b.adCost = 0;
            x.power *= .75;
            c.rel -= 8;
            tieRec(c, 'g', M('「{0}」で迎え撃った', [I(b.ind)]));
            calcAll();
            return M('「{0}」で広告を打ち、{1}の出足をくじきました', [I(b.ind), Nm(c.name)]);
          }),
          Choice(M('棲み分けを持ちかける'), M('相手は控えめに入り、こちらも客を少し譲る。関係が良くなる'), () {
            x.power *= .55;
            b.power *= .96;
            c.rel += 12;
            tieRec(c, 'f', M('「{0}」で棲み分けた', [I(b.ind)]));
            calcAll();
            return M('{0}と話をつけ、「{1}」では棲み分けることにしました', [Nm(c.presName), I(b.ind)]);
          }),
          Choice(M('静観する'), M('お金はかからない。相手はそのまま客を取りに来る'), () => M('静観することにしました')),
        ]);
      case 'poach':
        final b = top;
        final lost = crewOf(b) * .08;
        b.crew = crewOf(b) - lost;
        tieRec(c, 'h', M('「{0}」の現場の人を引き抜かれた', [I(b.ind)]));
        calcAll();
        final cost = hireCost(b, crewUnits.first);
        return _rs(c, k, M('{0}（{1}）に、「{2}」の現場の人をまとめて引き抜かれました。現場の力が8%落ちています。', [Nm(c.presName), Nm(c.name), I(b.ind)]), [
          Choice(M('引き抜き返す'), M('{0}で相手の人を引き抜く。現場は元に戻り、相手は弱るが、関係は悪くなる', [Y(cost)]), () {
            if (cash < cost) return M('お金が足りず、引き抜き返せませんでした');
            cfAdd('grow', -cost);
            b.crew = crewOf(b) + lost;
            for (final x in c.biz) {
              x.power *= .96;
            }
            c.rel -= 10;
            tieRec(c, 'g', M('現場の人を引き抜き返した'));
            calcAll();
            return M('{0}から人を引き抜き返しました', [Nm(c.name)]);
          }),
          Choice(M('待遇を良くして守る'), M('部下の給料が5%増える。部下の忠誠が上がり、これ以上は抜かれにくくなる'), () {
            for (final p in staff) {
              p.salary *= 1.05;
              p.loy = math.min(99, p.loy + 8);
            }
            calcAll();
            return M('待遇を良くして、残った人を守りました');
          }),
          Choice(M('放っておく'), M('お金はかからない。部下の忠誠が少し下がる'), () {
            for (final p in staff) {
              p.loy -= 3;
            }
            return M('放っておくことにしました');
          }),
        ]);
      case 'bid':
        final t = bidTarget(c);
        if (t == null) return null;
        final cost = bidCost(t);
        void absorb() {
          for (final x in t.biz) {
            c.biz.add(CoBiz(ind: x.ind, power: x.power));
          }
          t.alive = false;
          calcAll();
        }
        return _rs(c, k, M('売りに出た{0}を、{1}（{2}）と取り合うことになりました。', [Nm(t.name), Nm(c.presName), Nm(c.name)]), [
          Choice(M('競り勝つ'), M('{0}で株の51%を買い、子会社にする。関係は悪くなる', [Y(cost)]), () {
            if (cash < cost || !t.alive || t.parent == 'player') return M('お金が足りず、競り負けました');
            cfAdd('stock', -cost);
            t.fam = math.min(t.fam, 49);
            t.stakePlayer = 51;
            c.rel -= 12;
            tieRec(c, 'g', M('{0}を競り落とした', [Nm(t.name)]));
            afterStake(t);
            return M('{0}を競り落とし、子会社にしました', [Nm(t.name)]);
          }),
          Choice(M('譲って貸しを作る'), M('お金はかからない。相手が大きくなるが、関係が良くなる'), () {
            if (t.alive && t.parent != 'player') absorb();
            c.rel += 15;
            tieRec(c, 'f', M('{0}を譲った', [Nm(t.name)]));
            return M('{0}を{1}に譲りました', [Nm(t.name), Nm(c.presName)]);
          }),
          Choice(M('値をつり上げてから降りる'), M('相手に高値で買わせて、手元の資金を削る。関係は悪くなる'), () {
            if (t.alive && t.parent != 'player') absorb();
            c.cash -= t.cap * .4;
            c.rel -= 10;
            tieRec(c, 'g', M('{0}の値をつり上げた', [Nm(t.name)]));
            return M('値をつり上げてから降りました。{0}は高い買い物をしました', [Nm(c.name)]);
          }),
        ]);
      case 'pact':
        final b = top;
        final cost = devCost(b, 1);
        String joint(double mine) {
          b.pipe.add(Pipe(k: 'dev', cost: cost * 1.5, left: ri(devMonths[1].$1, devMonths[1].$2), sz: 1));
          cfAdd('grow', -mine);
          for (final x in c.biz) {
            x.power *= 1.04;
          }
          calcAll();
          return M('{0}と一緒に、「{1}」の新しい商品を作り始めました', [Nm(c.name), I(b.ind)]);
        }
        return _rs(c, k, M('{0}（{1}）が、「{2}」の新しい商品を一緒に作ろうと言ってきました。', [Nm(c.presName), Nm(c.name), I(b.ind)]), [
          Choice(M('組む'), M('{0}を出す。相手も同じだけ出すので、1.5倍の大きさの商品になる。相手も少し強くなる', [Y(cost)]), () {
            if (cash < cost) return M('お金が足りず、話は流れました');
            c.rel += 15;
            tieRec(c, 'f', M('「{0}」の商品を一緒に作った', [I(b.ind)]));
            return joint(cost);
          }),
          Choice(M('条件をつり上げる'), M('6割の確率で、費用を相手に持たせて組める。外れると話は流れ、関係が悪くなる'), () {
            if (rnd() < .6) {
              c.rel += 5;
              tieRec(c, 'f', M('「{0}」の商品を一緒に作った', [I(b.ind)]));
              return joint(0);
            }
            c.rel -= 12;
            tieRec(c, 'g', M('手を組む話で条件をつり上げた'));
            return M('{0}は怒って席を立ちました', [Nm(c.presName)]);
          }),
          Choice(M('断る'), M('お金はかからない。相手は機嫌を損ねる'), () {
            c.rel -= 8;
            tieRec(c, 'g', M('手を組む話を断った'));
            return M('断りました');
          }),
        ]);
      case 'expose':
        tieRec(c, 'h', M('不祥事を暴かれた'));
        final cost = math.max(rev * .1, 1e6 * nom());
        return _rs(c, k, M('{0}（{1}）が、あなたの会社の古い不始末を記者に流しました。', [Nm(c.presName), Nm(c.name)]), [
          Choice(M('謝罪会見を開く'), M('{0}をかけて謝る。株価に3か月響く', [Y(cost)]), () {
            if (cash < cost) {
              scandal = math.max(scandal, 8);
              return M('お金が足りず、会見を開けませんでした。騒ぎは長引きます');
            }
            cfAdd('misc', -cost);
            scandal = math.max(scandal, 3);
            return M('謝罪会見を開き、騒ぎは早めに収まりました');
          }),
          Choice(M('暴き返す'), M('お金はかからない。5割の確率で相手が大きく弱る。外れると泥仕合になり、株価に12か月響く'), () {
            c.rel -= 20;
            tieRec(c, 'g', M('相手の不祥事を暴き返した'));
            if (rnd() < .5) {
              for (final x in c.biz) {
                x.power *= .9;
              }
              calcAll();
              return M('{0}の不祥事も明るみに出て、相手のほうが大きく傷つきました', [Nm(c.name)]);
            }
            scandal = math.max(scandal, 12);
            return M('泥仕合になり、こちらの評判も落ちました');
          }),
          Choice(M('黙ってやり過ごす'), M('お金はかからない。株価に8か月響く'), () {
            scandal = math.max(scandal, 8);
            return M('黙ってやり過ごすことにしました');
          }),
        ]);
      case 'help':
        final cost = helpCost(c);
        final mine = <String>{for (final b in biz) b.ind};
        final x = c.biz.length > 1 ? (c.biz.where((y) => mine.contains(y.ind)).toList()..ssort((a, b) => a.power.compareTo(b.power))).firstOrNull : null;
        final cheap = x == null ? 0.0 : x.power * .5;
        return _rs(c, k, M('{0}（{1}）の資金繰りが苦しくなり、あなたに助けを求めてきました。', [Nm(c.presName), Nm(c.name)]), [
          Choice(M('お金を貸す'), M('{0}を貸す。見返りに相手の株を5%受け取り、大きな恩を売る', [Y(cost)]), () {
            if (cash < cost) return M('お金が足りず、貸せませんでした');
            cfAdd('stock', -cost);
            c.cash += cost;
            if (floatOf(c) >= 5) c.stakePlayer += 5;
            c.rel += 25;
            tieRec(c, 'f', M('苦しいときにお金を貸した'));
            tieRec(c, 'f', M('株を5%預かった'));
            return M('{0}にお金を貸しました。{1}は深く頭を下げました', [Nm(c.name), Nm(c.presName)]);
          }),
          if (x != null)
            Choice(M('弱みにつけこんで事業を買い叩く'), M('{0}で相手の「{1}」を安く買い取る。深い恨みを買う', [Y(cheap), I(x.ind)]), () {
              if (cash < cheap) return M('お金が足りず、買い取れませんでした');
              final b = biz.where((y) => y.ind == x.ind).firstOrNull;
              if (b == null || !c.biz.contains(x)) return M('その話はもう無くなっていました');
              cfAdd('grow', -cheap);
              c.cash += cheap;
              b.power += x.power * .7;
              b.crew = crewOf(b) + x.power * .7;
              c.biz.remove(x);
              c.rel -= 25;
              tieRec(c, 'g', M('苦しいときに「{0}」を買い叩いた', [I(x.ind)]));
              tieRec(c, 'g', M('弱みにつけこんだ'));
              calcAll();
              return M('{0}の「{1}」を安く買い取りました', [Nm(c.name), I(x.ind)]);
            }),
          Choice(M('断る'), M('お金はかからない。相手は少し機嫌を損ねる'), () {
            c.rel -= 6;
            tieRec(c, '', M('助けを求められて断った'));
            return M('断りました');
          }),
        ]);
    }
    return null;
  }

  /// 毎月、宿敵との張り合う場面が起きるかを見る
  void rivalScenes(void Function(String, [String]) N) {
    if (!extras || over != null || biz.isEmpty || events.isNotEmpty) return;
    if (turn - (crisis['rs:last'] ?? -99) < rsGap) return;
    final rs = cos
        .where((c) => c.alive && c.rival != null && c.parent != 'player' && c.rival!.st == 1 && turn - (crisis['rs:${c.id}'] ?? -99) >= rsEach)
        .toList();
    if (rs.isEmpty || rnd() >= rsP) return;
    final c = pick(rs);
    final w = sceneWeights(c);
    if (w.isEmpty) return;
    var x = rnd() * w.values.fold(0, (s, v) => s + v);
    var k = w.keys.first;
    for (final e in w.entries) {
      x -= e.value;
      if (x <= 0) {
        k = e.key;
        break;
      }
    }
    final ev = rivalScene(c, k);
    if (ev == null) return;
    crisis['rs:last'] = turn;
    crisis['rs:${c.id}'] = turn;
    crisis['rs:${c.id}:$k'] = turn;
    events.add(ev);
  }
}
