// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 子会社の名前と、子会社と同じ業種の決まり（1.1.0+36）
///
/// 名前:
/// - 分社・現地法人を作るときに名前を決める。はじめは案が入っていて、そのまま決めても書き換えてもよい。
/// - 案は「冠の言葉＋分類の言葉」（例: 暁星食品）。自社には名前が無いので、最初の子会社の冠をグループの冠として
///   次の子会社にも付ける。冠は CPU の会社と同じ作り物の言葉の表（CO_A・CO_C）から取り、実在の会社名は使わない。
///   ゲームの乱数は引かない（並びをずらさない）。
/// - あとから「名前を変える」で変えられる（株を過半持つ会社だけ。買収した会社も）。手は使わない。
/// - 空・長すぎ（全角16字、半角は2つで1字）・ほかの会社と同じ名前（日本語の名前でも、英語の画面の読みでも）は弾く。
///
/// 自社の名前（1.1.0+37）:
/// - 始める画面で社長の名前と自社の名前を決める（案が入っている。空にすると、社長は仕組みが名付け、自社は名前なし）。
/// - 自社の名前はランキング・続きからの一覧・社史・決算書・終わりのまとめに出る。
/// - 自社の名前があれば、子会社の名前の案は「自社の名前の頭（商会などを外したもの）＋分類」（例: 暁星商会→暁星食品）。
/// - 会社を丸ごと売ると、前の会社は今の名前のまま残り、新しい会社の名前を決め直す。
///
/// 同じ業種:
/// - 株を過半（50%超）持つ国内の子会社がいる業種は、自社では始められない（業態を変える・部下の提案も同じ）。
///   広げるなら子会社に任せる。現地法人は別の国の市場で戦うので数えない。持ち分50%以下の会社は他社として扱う。
/// - 買収・合併は相手の事業ごと入るので止めない（自社と子会社に同じ業種が並ぶことはある）。
extension GameNames on Game {
  /// 名前の長さの上限（全角の字数。半角は2つで1字）
  static const nameMax = 16;

  /// 株を過半持つ国内の会社のうち、その業種にいるもの（現地法人は数えない）
  Company? subOn(String ind) => cos.where((c) => c.alive && c.loc == null && pctOf(c) > 50 && c.biz.any((b) => b.ind == ind)).firstOrNull;

  /// 子会社がいるので自社では始められない理由（始められるなら null）
  String? subBlock(String ind) {
    final c = subOn(ind);
    return c == null ? null : M('子会社「{0}」がこの業種にいます。広げるなら子会社に任せます', [Nm(c.name)]);
  }

  /// 名前の長さ（全角1・半角0.5）
  static double nameLen(String s) => s.runes.fold(0.0, (a, r) => a + (r < 0x80 || (r >= 0xFF61 && r <= 0xFF9F) ? .5 : 1));

  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// 名前として使えるか（使えるなら null、使えなければ理由）。[self] は名前を変える会社（自分の今の名前とは比べない）
  String? coNameErr(String name, {Company? self}) {
    final n = name.trim();
    if (n.isEmpty) return M('名前を入れてください');
    if (n.runes.any((r) => r < 0x20 || r == 0x7F)) return M('使えない文字が入っています');
    if (nameLen(n) > nameMax) return M('名前は全角{0}字（半角{1}字）までです', [nameMax, nameMax * 2]);
    final keys = {_norm(n), _norm(romanize(n))};
    bool same(String other) => keys.contains(_norm(other)) || keys.contains(_norm(romanize(other)));
    // ほかの会社（CPU・宿敵・自分の子会社。もう無い会社も、記録に名前が残るので）と、まだ出ていない宿敵の会社
    for (final c in cos) {
      if (identical(c, self)) continue;
      if (same(c.name)) return M('「{0}」という会社はもうあります', [Nm(n)]);
    }
    for (final r in RIVALS) {
      if (self != null && self.name == r.co) continue;
      if (same(r.co)) return M('「{0}」という会社はもうあります', [Nm(n)]);
    }
    // 自社の名前とも同じにしない（1.1.0+37）
    if (myCo.isNotEmpty && same(myCo)) return M('「{0}」は自社の名前です', [Nm(n)]);
    return null;
  }

  /// 子会社の名前の案（乱数は引かない）。[cat] は業種の分類。
  /// [group] を下ろすと、グループの冠を付けない（渡して独立させた会社は、よその会社になるので。1.1.0+37）
  String subNameIdea(String cat, {bool group = true}) {
    final suf = CO_SUF[cat]!;
    final fsuf = CO_FSUF[cat]!;
    final words = [...CO_A, ...CO_C];
    // 自社の名前があれば、その頭（「商会」などの終わりを外したもの）をグループの冠にする（1.1.0+37）。
    // 無ければ、自分の子会社の冠（いちばん古いもの）をグループの冠にする
    String? crown = group ? myCrown() : null;
    if (group && crown == null) {
      for (final c in cos) {
        if (c.parent != 'player' || pctOf(c) <= 50) continue;
        crown = words.where((w) => c.name.startsWith(w) && c.name.length > w.length).firstOrNull;
        if (crown != null) break;
      }
    }
    final start = (turn * 7 + cos.length) % words.length;
    final order = [?crown, for (var i = 0; i < words.length; i++) words[(start + i) % words.length]];
    for (final w in order) {
      for (final s in [suf, fsuf]) {
        final n = '$w$s';
        if (coNameErr(n) == null) return n;
      }
    }
    // ここまで来ることはまず無い（冠40語×2つの言い方が全部使われている）
    for (var i = 2;; i++) {
      final n = '${words[start]}$suf$i';
      if (coNameErr(n) == null) return n;
    }
  }

  // ===== 自社の名前（1.1.0+37） =====
  /// 自社の名前から取ったグループの冠（終わりの会社の種類・分類の言葉を外したもの。自社の名前が無い・外すと何も残らないなら null）
  String? myCrown() {
    var n = myCo.trim();
    if (n.isEmpty) return null;
    if (n.startsWith(CO_HEAD)) n = n.substring(CO_HEAD.length).trim();
    for (final t in [...CO_TAILS, ...CO_SUF.values, ...CO_FSUF.values]) {
      if (n.length > t.length && n.endsWith(t)) {
        n = n.substring(0, n.length - t.length).trim();
        break;
      }
    }
    return n.isEmpty ? null : n;
  }

  /// ランキングなどに出す自社の呼び名（名前があれば「名前（あなた）」、無ければ今までどおり「あなたのグループ」）
  String myLabel() => myCo.isNotEmpty ? M('{0}（あなた）', [Nm(myCo)]) : M('あなたのグループ');

  /// 自社の名前として使えるか（始める画面の欄。空は「名前なし」で使える。ゲームが無くても見られる分だけ）
  static String? myNameErrStatic(String name) {
    final n = name.trim();
    if (n.isEmpty) return null;
    if (n.runes.any((r) => r < 0x20 || r == 0x7F)) return M('使えない文字が入っています');
    if (nameLen(n) > nameMax) return M('名前は全角{0}字（半角{1}字）までです', [nameMax, nameMax * 2]);
    final keys = {_norm(n), _norm(romanize(n))};
    for (final r in RIVALS) {
      if (keys.contains(_norm(r.co)) || keys.contains(_norm(romanize(r.co)))) return M('「{0}」という会社はもうあります', [Nm(n)]);
    }
    return null;
  }

  /// 自社の名前として使えるか（遊びの途中。ほかの会社とも比べる）。[selling] は会社を売って新しい会社を立ち上げるとき（今の名前は前の会社に残る）
  String? myNameErr(String name, {bool selling = false}) {
    final n = name.trim();
    if (n.isEmpty) return selling ? null : M('名前を入れてください');
    if (selling && myCo.isNotEmpty && _norm(n) == _norm(myCo)) return M('「{0}」は前の会社の名前として残ります。新しい名前を決めてください', [Nm(n)]);
    return coNameErr(n);
  }

  /// 会社を売ったあとに立ち上げる会社の名前の案（冠の言葉＋「商会」。乱数は引かない）
  String nextCoIdea() {
    final words = [...CO_A, ...CO_C];
    final start = (turn * 7 + cos.length) % words.length;
    for (var i = 0; i < words.length; i++) {
      final n = '${words[(start + i) % words.length]}商会';
      if (myNameErr(n, selling: true) == null) return n;
    }
    return '';
  }

  /// 社長の名前として使えるか（始める画面の欄。空は「おまかせ」で使える）
  static String? presNameErr(String name) {
    final n = name.trim();
    if (n.isEmpty) return null;
    if (n.runes.any((r) => r < 0x20 || r == 0x7F)) return M('使えない文字が入っています');
    if (nameLen(n) > nameMax) return M('名前は全角{0}字（半角{1}字）までです', [nameMax, nameMax * 2]);
    return null;
  }

  /// 始める画面の自社の名前の案（冠の言葉＋「商会」。作り物の言葉だけで、実在の会社名は使わない。ゲームの乱数は引かない）
  static String myNameIdea(math.Random r) {
    final words = [...CO_A, ...CO_C];
    for (var i = 0; i < 20; i++) {
      final n = '${words[r.nextInt(words.length)]}商会';
      if (myNameErrStatic(n) == null) return n;
    }
    return '${words.first}商会';
  }

  /// 始める画面の社長の名前の案（その国の名前の表から。ゲームの乱数は引かない）
  static String presNameIdea(math.Random r, String home) {
    String p(List<String> l) => l[r.nextInt(l.length)];
    final k = NAMEC[home] ?? 'jp';
    if (k == 'jp') return '${p(SEI)} ${p(MEI)}';
    if (eastPools.contains(k)) return '${p(NAMEP[k]![0])} ${p(NAMEP[k]![1])}';
    return '${p(NAMEP[k]![1])}・${p(NAMEP[k]![0])}';
  }

  /// 名前を変えられる会社か（株を過半持つ会社）
  bool canRename(Company c) => c.alive && pctOf(c) > 50;

  /// 会社の名前を変える（手は使わない）
  String renameCo(Company c, String name) {
    if (!canRename(c)) return M('名前を変えられるのは、株を過半持つ会社だけです');
    final n = name.trim();
    if (n == c.name) return M('今と同じ名前です');
    final e = coNameErr(n, self: c);
    if (e != null) return e;
    final old = c.name;
    c.name = n;
    // 記録（log）には、画面の結果の小窓が載せる
    return M('{0}の名前を「{1}」に変えました', [Nm(old), Nm(n)]);
  }
}
