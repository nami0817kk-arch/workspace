/// 会社どうしの仕組み（1.1.0+29 から。企画書「現実に寄せる」の段4: 宿敵・M&A・上場・株価・独禁法・取引先・隠れた情報）の状態。
/// どれも JSON に出し入れできる。古いセーブには無いので、無ければ空から始める
library;

double _d(dynamic x, [double def = 0]) => x == null ? def : (x as num).toDouble();
int _i(dynamic x, [int def = 0]) => x == null ? def : (x as num).round();
List<String> _sl(dynamic x) => x == null ? <String>[] : (x as List).map((e) => e as String).toList();

/// CPU の会社のお金（自社と同じ決まりで動かすための借金・資金繰り・調べ・統合）
class CoFin {
  /// 借金と、その平均の年の金利
  double debt, rate;

  /// 借り方（0 借りない / 1 少し借りる / 2 借りまくる）
  int appetite;

  /// 払えずに苦しんでいる月の数（6か月続くと銀行の管理、12か月で倒れる）
  int distress;

  /// 先月開いた店などの数（同じ業種の物件の取り合いに効く）
  double heat;

  /// 上場の準備の残りの月（-1 は準備していない）
  int ipoLeft;

  // ===== 隠れた情報（あなたから見た） =====
  /// 調べたか（0 まだ / 1 調べた）。調べると数字の幅が狭まり、隠れた問題が分かる
  int dd;

  /// 隠れた問題（調べないと見えない）: 簿外の借金（時価総額に対する割合）・訴訟（同）・人の流出（統合のあいだに辞める人の割合の上乗せ）
  double offDebt, suit, flight;

  /// 隠れた問題をもう決めたか（買う話を始めたときに一度だけ決める）
  bool rolled;

  // ===== 買ったあと =====
  /// 統合の残りの月・かかる月の合計・統合のあいだに辞めた人の割合
  int integ, integAll;
  double attr;

  /// のれん（買った値段のうち、会社の正味の値打ちを超えた分）・買ったときの年の利益の見込み・減損した額の累計
  double gw, plan, impaired;

  CoFin({
    this.debt = 0,
    this.rate = 0,
    this.appetite = 1,
    this.distress = 0,
    this.heat = 0,
    this.ipoLeft = -1,
    this.dd = 0,
    this.offDebt = 0,
    this.suit = 0,
    this.flight = 0,
    this.rolled = false,
    this.integ = 0,
    this.integAll = 0,
    this.attr = 0,
    this.gw = 0,
    this.plan = 0,
    this.impaired = 0,
  });

  Map<String, dynamic> toJson() => {
        'debt': debt,
        'rate': rate,
        'ap': appetite,
        'dis': distress,
        'heat': heat,
        'ipo': ipoLeft,
        'dd': dd,
        'od': offDebt,
        'suit': suit,
        'fl': flight,
        'rl': rolled,
        'ig': integ,
        'iga': integAll,
        'attr': attr,
        'gw': gw,
        'plan': plan,
        'imp': impaired,
      };

  factory CoFin.fromJson(Map<String, dynamic> j) => CoFin(
        debt: _d(j['debt']),
        rate: _d(j['rate']),
        appetite: _i(j['ap'], 1),
        distress: _i(j['dis']),
        heat: _d(j['heat']),
        ipoLeft: _i(j['ipo'], -1),
        dd: _i(j['dd']),
        offDebt: _d(j['od']),
        suit: _d(j['suit']),
        flight: _d(j['fl']),
        rolled: j['rl'] == true,
        integ: _i(j['ig']),
        integAll: _i(j['iga']),
        attr: _d(j['attr']),
        gw: _d(j['gw']),
        plan: _d(j['plan']),
        impaired: _d(j['imp']),
      );
}

/// 買う話の1件（調べ→申し入れ→当局の審査→手続き）
class MaDeal {
  int co;

  /// 段: dd 調べ / offer 相手の返事待ち（TOB の期間） / review 当局の審査 / close 手続き
  String stage;

  /// 今の段の残りの月
  int left;

  /// 狙う持ち株の割合・株価への上乗せ（0.3 = 30%）・払い方（cash 現金 / swap 株式交換）
  double target, prem;
  String pay;

  /// これまでにかかった費用（調べ・助言の手数料）
  double spent;

  /// 当局の審査に止められる見込み（0〜1。審査に入ったときに決める）
  double block;

  /// 審査で求められた、手放す店などの割合（0 は求められていない）
  double divest;

  MaDeal({required this.co, required this.stage, required this.left, this.target = 50.1, this.prem = .3, this.pay = 'cash', this.spent = 0, this.block = 0, this.divest = 0});

  Map<String, dynamic> toJson() => {'co': co, 'st': stage, 'left': left, 'tg': target, 'prem': prem, 'pay': pay, 'spent': spent, 'block': block, 'div': divest};
  factory MaDeal.fromJson(Map<String, dynamic> j) => MaDeal(
        co: _i(j['co']),
        stage: j['st'] as String? ?? 'dd',
        left: _i(j['left']),
        target: _d(j['tg'], 50.1),
        prem: _d(j['prem'], .3),
        pay: j['pay'] as String? ?? 'cash',
        spent: _d(j['spent']),
        block: _d(j['block']),
        divest: _d(j['div']),
      );
}

/// 上場の準備（監査・社内の決まり・主幹事）
class IpoPrep {
  /// 始めた月・かかる月の合計・進んだ月
  int start, total, done;

  /// 監査を受けた月の数（2期分＝24か月が要る）
  int audit;

  /// 社内の決まり（内部統制）の進み（0〜1）
  double ctrl;

  /// これまでにかかった費用
  double spent;

  /// 主幹事（big 大手 / mid 中堅 / small 小さな証券会社）
  String uw;

  IpoPrep({required this.start, required this.total, this.done = 0, this.audit = 0, this.ctrl = 0, this.spent = 0, this.uw = 'mid'});

  Map<String, dynamic> toJson() => {'start': start, 'total': total, 'done': done, 'audit': audit, 'ctrl': ctrl, 'spent': spent, 'uw': uw};
  factory IpoPrep.fromJson(Map<String, dynamic> j) => IpoPrep(
        start: _i(j['start']),
        total: _i(j['total'], 30),
        done: _i(j['done']),
        audit: _i(j['audit']),
        ctrl: _d(j['ctrl']),
        spent: _d(j['spent']),
        uw: j['uw'] as String? ?? 'mid',
      );
}

/// 大口の客（事業ごと。会社に売る業種・役所に売る業種だけ）
class Client {
  /// 客の会社（CPU の会社の番号。役所なら 0）
  int co;

  /// 売上のうち、その客の割合
  double share;

  /// 取引の始まった年
  int since;

  Client({required this.co, required this.share, required this.since});
  Map<String, dynamic> toJson() => {'co': co, 'sh': share, 'since': since};
  factory Client.fromJson(Map<String, dynamic> j) => Client(co: _i(j['co']), share: _d(j['sh']), since: _i(j['since']));
}

/// 自社の株と、会社どうしの話（ゲームに1つ）
class CorpState {
  /// 出している株の数（上場や増資・株式交換で増える。株価＝時価総額÷株の数）
  double nSh;

  /// 毎月の株価（古い順・最大240）
  List<double> px;

  /// 先月から株価が動いた理由（包んだ文。大きい順に最大4つ）
  List<String> why;

  /// うわさ（市場の思惑。1 が平ら。毎月少しずつ1へ戻る）・減損や不祥事の売り（同じく戻る）
  double noise, shock;

  /// 上場の準備
  IpoPrep? ipo;

  /// 進めている買う話
  List<MaDeal> deals;

  /// 大口の客（事業の番号 → 客）
  Map<int, Client> clients;

  /// 前の決算の利益（3か月分）・決算の見込み
  double lastQ, expQ;

  /// 株主総会を開いた年・物言う株主の要求（null は無し）
  int agmY;
  String? demand;

  /// 格付けが下がって、仕入れ先に支払いを早められている
  bool tight;

  /// 先月の株価を決めた部分（動いた理由を出すため）
  Map<String, double> pp;

  CorpState({
    this.nSh = 1e4,
    List<double>? px,
    List<String>? why,
    this.noise = 1,
    this.shock = 1,
    this.ipo,
    List<MaDeal>? deals,
    Map<int, Client>? clients,
    this.lastQ = 0,
    this.expQ = 0,
    this.agmY = 0,
    this.demand,
    this.tight = false,
    Map<String, double>? pp,
  })  : pp = pp ?? {},
        px = px ?? [],
        why = why ?? [],
        deals = deals ?? [],
        clients = clients ?? {};

  Map<String, dynamic> toJson() => {
        'nSh': nSh,
        'px': px,
        'why': why,
        'noise': noise,
        'shock': shock,
        if (ipo != null) 'ipo': ipo!.toJson(),
        'deals': deals.map((e) => e.toJson()).toList(),
        'cl': {for (final e in clients.entries) '${e.key}': e.value.toJson()},
        'lastQ': lastQ,
        'expQ': expQ,
        'agmY': agmY,
        'demand': demand,
        'tight': tight,
        'pp': pp,
      };

  factory CorpState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return CorpState();
    return CorpState(
      nSh: _d(j['nSh'], 1e4),
      px: (j['px'] as List? ?? []).map((e) => _d(e)).toList(),
      why: _sl(j['why']),
      noise: _d(j['noise'], 1),
      shock: _d(j['shock'], 1),
      ipo: j['ipo'] == null ? null : IpoPrep.fromJson(j['ipo'] as Map<String, dynamic>),
      deals: (j['deals'] as List? ?? []).map((e) => MaDeal.fromJson(e as Map<String, dynamic>)).toList(),
      clients: {for (final e in (j['cl'] as Map? ?? {}).entries) int.parse(e.key as String): Client.fromJson(e.value as Map<String, dynamic>)},
      lastQ: _d(j['lastQ']),
      expQ: _d(j['expQ']),
      agmY: _i(j['agmY']),
      demand: j['demand'] as String?,
      tight: j['tight'] == true,
      pp: {for (final e in (j['pp'] as Map? ?? {}).entries) e.key as String: _d(e.value)},
    );
  }
}
