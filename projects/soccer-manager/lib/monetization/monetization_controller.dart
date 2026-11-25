import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'funds_pack.dart';
import 'purchase_service.dart';

/// 広告・課金の状態を持つ。
///
/// 2026-11-26 に整理した形:
/// - 広告は全画面の1種類だけ。ゲームの中で3か月たつごとに1回出る
///   ([showQuarterlyInterstitial])。
/// - 課金は「広告を消す」(買い切り)の1つだけ。買うと全画面広告が出なく
///   なる。**それ以外は何も変わらない**(払っても有利にならない)。
/// - 資金パックは売るのをやめた。前に買って受け取り損ねたぶんを渡す
///   仕組みだけ残している([undeliveredFundsPacks])。
///
/// セーブデータではなく端末側 (SharedPreferences) に置いている。
/// 購入はストアのアカウントに紐づくもので、どのセーブスロットで
/// 遊んでいるかとは関係がないため。
class MonetizationController extends ChangeNotifier {
  /// [prefs] はテスト用。書き込みの途中で落ちる場面を作るために差し替える。
  MonetizationController({
    AdService? adService,
    PurchaseService? purchases,
    @visibleForTesting Future<SharedPreferences> Function()? prefs,
  })  : _ads = adService ?? createAdService(),
        _purchases = purchases ?? createPurchaseService(),
        _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const _supporterKey = 'monetization.supporter';

  /// 届いたがまだクラブ資金に移していない資金パックの商品ID(順番付き)。
  ///
  /// 資金はセーブの中(クラブ資金)に入るので、セーブが無いあいだ・別の
  /// スロットを開いているあいだは渡せない。端末側に預かっておき、
  /// セーブが開かれたときに移す。消費型なので「復元」では戻らない——
  /// ここで預かり損ねると、払った額がそのまま消える。
  static const _undeliveredFundsKey = 'monetization.undeliveredFunds';

  /// 受け取り済みの取引の識別子。**同じ取引が二度届くことがある。**
  ///
  /// 完了通知(`completePurchase`)は投げっぱなしで送るため、それが届く前に
  /// アプリが落ちると、次の起動でストアが同じ購入をもう一度送ってくる。
  /// 消費型(資金パック)は渡すたびに預かりへ積むので、そのぶん二重に渡る。
  /// 払ったのは1回なので、渡すのも1回にする。
  static const _deliveredIdsKey = 'monetization.deliveredPurchaseIds';

  /// 覚えておく取引の数。際限なく貯めない。
  static const int _deliveredIdsKept = 200;

  /// 最後に全画面広告を出した(または数え始めた)ゲームの中の月。
  /// 年×12+月-1 の数([GameStateSupporters.monthKeyOf] と同じ)。
  static const _lastAdMonthKey = 'monetization.lastAdMonth';

  /// 全画面広告を出す間隔(ゲームの中の月数)。
  static const int adIntervalMonths = 3;

  final AdService _ads;
  final PurchaseService _purchases;

  bool initialized = false;

  /// 「広告を消す」を購入済みか。
  ///
  /// 名前が supporter のままなのは、ストアの商品ID
  /// (`soccer_manager_supporter`)と端末に残した記録の鍵を変えないため。
  /// 前に「サポーター」として買った人も、そのまま広告が消えた状態で続く。
  bool isSupporter = false;

  /// ストアが使えるか。使えない環境では購入導線を出さない。
  bool storeAvailable = false;

  /// 届いたが、まだクラブ資金に移していない資金パック。
  List<FundsPack> get undeliveredFundsPacks =>
      [for (final q in _queue) q.pack];

  /// 預かりの中身(取引の識別子つき)。端末側の保存と同じ順。
  List<_QueuedPack> _queue = const [];

  /// 渡し終えた取引の識別子(端末側の保存の写し)。
  List<String> _deliveredIds = const [];

  /// 表示用の価格。取得できていなければ null。
  /// 「¥」は全角に置き換えてある([displayPrice])。
  String? priceLabel;

  /// ストアの価格を、同梱フォントで必ず描ける形にする。
  ///
  /// App Store は日本の価格を半角の「¥」(U+00A5)で返すが、同梱の
  /// NotoSansJP にも ShipporiMincho にもこの字が無い(全角の U+FFE5 はある)。
  /// 端末のフォントで補われる見込みはあるが、Web 版では補えずに豆腐のまま
  /// 出た前例がある(docs/app-pitfalls.md の6)。補われるかに賭けず、
  /// 持っている字に置き換える。
  static String displayPrice(String price) =>
      price.replaceAll('\u00A5', '\uFFE5');

  Future<void> initialize() async {
    final prefs = await _prefs();
    isSupporter = prefs.getBool(_supporterKey) ?? false;

    _queue = _readQueue(prefs);
    _deliveredIds = prefs.getStringList(_deliveredIdsKey) ?? const [];

    await _ads.initialize();
    // **受け取りはここ1か所。** 買った瞬間に呼び出し側で渡していた頃、
    // アプリを落としている間に決済が通った購入は誰も受け取らなかった。
    // initialize() より先に繋ぐ(起動時に溜まっていた通知が流れてくる)。
    _purchases.onDelivered = _grant;
    await _purchases.initialize();
    storeAvailable = await _purchases.isAvailable();
    if (storeAvailable) {
      final supporterPrice = await _purchases.priceLabel();
      priceLabel = supporterPrice == null ? null : displayPrice(supporterPrice);
    }

    initialized = true;
    notifyListeners();
  }

  /// ゲームの中で前回から3か月たっていれば、全画面広告を出す。
  /// 閉じられるまで待つ。
  ///
  /// 節を進め終えたところ(結果のダイジェストやお知らせを出し終えた後)で
  /// 呼ぶ。試合中やメニュー操作の途中には割り込まない。
  ///
  /// [monthKey] は今日のゲームの中の月(年×12+月-1)。
  /// - 初めて呼ばれたときは数え始めるだけで出さない(始めてすぐ出さない)。
  /// - 別のセーブを開いて月が戻ったときも、そこから数え直す。
  /// - 3か月以上たっていれば出して、その月から数え直す。
  ///   何か月まとめて進めても出すのは1回だけ。
  ///
  /// 「広告を消す」を買った人には出さない。在庫が無いときは [AdService]
  /// 側が何もせずに戻るので、広告のせいで進めなくなることはない。
  /// 戻り値は広告を出そうとしたか(在庫が無くて出なかったときも true)。
  Future<bool> showQuarterlyInterstitial(int monthKey) async {
    if (isSupporter) return false;
    final prefs = await _prefs();
    final last = prefs.getInt(_lastAdMonthKey);
    if (last == null || monthKey < last) {
      await prefs.setInt(_lastAdMonthKey, monthKey);
      return false;
    }
    if (monthKey - last < adIntervalMonths) return false;
    // 先に記録する。広告の途中でアプリが落ちても、次の起動ですぐまた
    // 出ることはない。
    await prefs.setInt(_lastAdMonthKey, monthKey);
    await _ads.showInterstitialAd();
    return true;
  }

  /// 「広告を消す」を買う。**受け取るのは [_grant] のほう**なので、ここでは結果を返すだけ。
  Future<PurchaseOutcome> buySupporter() => _purchases.buySupporter();

  Future<PurchaseOutcome> restorePurchases() => _purchases.restorePurchases();

  /// 届いたものを受け取る。買った直後のぶんも、アプリを落としている間に
  /// 決済が通ったぶんも、復元したぶんも、全部ここを通る。
  ///
  /// ここで失敗すると窓口は完了通知を返さないので、次の起動でまた届く。
  ///
  /// **渡してから「渡した」と記録する。** 以前は記録を先に書いていたので、
  /// その後で落ちると、ストアが送り直してきても「渡し済み」として弾き、
  /// 払ったぶんが届かなかった(消費型は復元でも戻らない)。
  /// 資金パックは、預かりの1件に取引の識別子を添えて**1回の書き込み**で
  /// 預ける。預かりに入った時点で記録も済んでいるので、どこで落ちても
  /// 「届かない」と「二重に渡る」のどちらにもならない。
  Future<void> _grant(String productId, String? purchaseId) async {
    // 同じ取引を二度渡さない。識別子が無いストアもあるので、その場合は
    // 弾かずに渡す(渡しすぎより、渡し損ねのほうが害が大きい)。
    // 判定は手元の写しで、待たずに行う(同時に届いた2通が両方すり抜けない)。
    if (purchaseId != null && _alreadyReceived(purchaseId)) return;

    if (productId == PurchaseService.supporterProductId) {
      // サポーターは「購入済み」の札そのものが記録なので、二度渡っても
      // 害は無い。札を立ててから取引を覚える。
      if (!isSupporter) await _markSupporter();
      await _rememberDelivered(purchaseId);
      return;
    }

    final pack = FundsPack.byProductId(productId);
    if (pack == null) return;

    // 資金はセーブの中に入るため、ここでは預かるだけ。手元の一覧を先に
    // 書き換えてから保存する(保存を待つ間に同じ取引がもう一度届いても弾く)。
    final entry = _QueuedPack(pack, purchaseId);
    _queue = [..._queue, entry];
    try {
      await _persistQueue();
    } catch (_) {
      // 預けられなかった。手元からも外し、完了通知を返させない
      // (次の起動でストアがもう一度送ってくる)。
      _queue = [
        for (final q in _queue)
          if (!identical(q, entry)) q,
      ];
      rethrow;
    }
    notifyListeners();
  }

  /// この取引をもう受け取っているか(渡し終えた／預かっている)。
  bool _alreadyReceived(String purchaseId) =>
      _deliveredIds.contains(purchaseId) ||
      _queue.any((q) => q.purchaseId == purchaseId);

  /// 渡し終えた取引として覚える。
  Future<void> _rememberDelivered(String? purchaseId) async {
    if (purchaseId == null || _deliveredIds.contains(purchaseId)) return;
    final kept = [..._deliveredIds, purchaseId];
    _deliveredIds = kept.length <= _deliveredIdsKept
        ? kept
        : kept.sublist(kept.length - _deliveredIdsKept);
    final prefs = await _prefs();
    await prefs.setStringList(_deliveredIdsKey, _deliveredIds);
  }

  Future<void> _persistQueue() async {
    final prefs = await _prefs();
    await prefs.setStringList(
        _undeliveredFundsKey, [for (final q in _queue) q.encode()]);
  }

  /// 預かっている資金パックをクラブ資金へ移したあとに呼ぶ。
  Future<void> markFundsPackDelivered(FundsPack pack) async {
    final at = _queue.indexWhere((q) => q.pack == pack);
    if (at < 0) return;
    final done = _queue[at];
    // 手元の一覧を先に書き換える。保存を待っている間に別の受け取りが
    // 一覧を読むと、渡し終えたパックがまだ残って見える。
    // 同じパックを複数抱えていても1つだけ消す。
    _queue = [..._queue]..removeAt(at);
    // 預かりから消す前に、取引を「渡し終えた」の側へ移す。逆の順だと、
    // その間に落ちたときに取引の記録がどこにも無くなり、ストアが送り直して
    // きたぶんをもう一度渡してしまう。
    await _rememberDelivered(done.purchaseId);
    await _persistQueue();
    notifyListeners();
  }

  /// 預かりを読む。古い版は商品IDだけを並べていたので、識別子の無い
  /// 行もそのまま読む。
  static List<_QueuedPack> _readQueue(SharedPreferences prefs) {
    final rows = prefs.getStringList(_undeliveredFundsKey) ?? const [];
    return [
      for (final row in rows)
        if (_QueuedPack.decode(row) case final q?) q,
    ];
  }

  /// 保存できてから手元の札を立てる。先に立てると、保存に失敗して
  /// 送り直されたときに「もう渡してある」と見て取引だけ覚えてしまい、
  /// 次の起動でサポーターが消える。
  Future<void> _markSupporter() async {
    final prefs = await _prefs();
    await prefs.setBool(_supporterKey, true);
    isSupporter = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _ads.dispose();
    _purchases.dispose();
    super.dispose();
  }
}

/// 預かっている資金パック1件。どの取引で届いたかを添えて持つ。
///
/// 取引の識別子を預かりと同じ行に書くのは、「預けた」と「その取引を
/// 受け取った」を1回の書き込みで済ませるため。別々に書くと、間で落ちた
/// ときに片方だけが残る。
class _QueuedPack {
  const _QueuedPack(this.pack, this.purchaseId);

  final FundsPack pack;
  final String? purchaseId;

  /// 商品IDと取引の識別子の区切り。商品IDには使っていない字。
  static const _sep = '|';

  String encode() =>
      purchaseId == null ? pack.productId : '${pack.productId}$_sep$purchaseId';

  static _QueuedPack? decode(String row) {
    final at = row.indexOf(_sep);
    final productId = at < 0 ? row : row.substring(0, at);
    final pack = FundsPack.byProductId(productId);
    if (pack == null) return null;
    return _QueuedPack(pack, at < 0 ? null : row.substring(at + 1));
  }
}
