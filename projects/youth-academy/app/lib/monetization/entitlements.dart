import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// App Store Connect の商品IDと一致させること（決定93・124）。
const productRemoveAds = 'youth_remove_ads';
const productKeenEye = 'youth_keen_eye';
const productSaveSlot = 'youth_save_slot';
const productTicket1 = 'youth_ticket_1';
const productTicket3 = 'youth_ticket_3';
const allProductIds = {productRemoveAds, productKeenEye, productSaveSlot, productTicket1, productTicket3};
const consumableIds = {productSaveSlot, productTicket1, productTicket3};

/// 買い切り（非消費型）。端末の購入記録と照らし合わせられるのはこの2つだけ。
/// 消費型（枠・チケット）は App Store が記録を残さないので、入れ直すと戻らない（ショップの文で知らせている）。
const nonConsumableIds = {productRemoveAds, productKeenEye};

/// 課金で買った権利（広告を消す・見抜く目・セーブ枠・オリジナル選手チケット）。
/// 書き込むのはここ（Flutter）だけ。ページ側は届いた値を読むだけ（ページには `ya_ent` として渡る）。
class Entitlements {
  Entitlements({this.noAds = false, this.eye = false, this.slots = 0, this.tickets = 0, this.used = 0, List<int>? spent})
    : spent = spent ?? <int>[];

  bool noAds;
  bool eye;

  /// 追加したセーブ枠の数（0〜4。最初の1枠は無料なので合計は最大5）。
  int slots;
  int tickets;

  /// これまでに使ったチケットの枚数。使うたびに1つ進み、その値がオリジナル選手の通し番号になる。
  int used;

  /// 新入生として迎え終えたオリジナル選手の通し番号。
  /// 書き出したセーブを復元して、同じチケットで二度迎えられないようにページ側で突き合わせる。
  List<int> spent;

  static const key = 'ya_ent';
  // 受け取り済みの取引の控え。ページに渡す保存（`ya_` で始まる文字の値）と混ざらないよう `ya_` の外に置く。
  // 2026-11-17：前は `ya_ent_seen`（文字の並び）で、起動時の読み込みが `ya_` の全部を文字として読もうとして落ち、課金した人が起動できなくなった
  static const seenKey = 'ent_seen';
  static const oldSeenKey = 'ya_ent_seen';
  static List<String> seenOf(SharedPreferences p) {
    final v = p.get(seenKey) ?? p.get(oldSeenKey);
    return v is List ? v.whereType<String>().toList() : <String>[];
  }

  static const maxSlots = 4;
  static const maxTickets = 99;
  static const _maxSpent = 500;

  /// 受け取りの最中の取引。控えを書き終える前に同じ取引がもう一度届いても、二度渡さない
  final Set<String> _granting = {};

  Map<String, Object> toJson() => {'noAds': noAds, 'eye': eye, 'slots': slots, 'tickets': tickets, 'used': used, 'spent': spent};

  factory Entitlements.fromJson(Object? j) {
    if (j is! Map) return Entitlements();
    int n(Object? v, int hi) => v is num ? v.toInt().clamp(0, hi) : 0;
    final sp = j['spent'];
    return Entitlements(
      noAds: j['noAds'] == true,
      eye: j['eye'] == true,
      slots: n(j['slots'], maxSlots),
      tickets: n(j['tickets'], maxTickets),
      used: n(j['used'], 1000000),
      spent: sp is List ? sp.whereType<num>().map((x) => x.toInt()).toList() : <int>[],
    );
  }

  static Entitlements load(SharedPreferences p) {
    try {
      final s = p.getString(key);
      return s == null ? Entitlements() : Entitlements.fromJson(jsonDecode(s));
    } catch (_) {
      return Entitlements();
    }
  }

  Future<void> save(SharedPreferences p) async {
    if (!await p.setString(key, jsonEncode(toJson()))) throw StateError('権利を保存できませんでした');
  }

  void _restore(Map<String, Object> before) {
    final b = Entitlements.fromJson(before);
    noAds = b.noAds;
    eye = b.eye;
    slots = b.slots;
    tickets = b.tickets;
    used = b.used;
    spent = b.spent;
  }

  /// 書き込みに失敗したら、中身を元に戻して投げ直す（呼んだ側は完了通知を返さず、次の起動でもう一度届く）。
  Future<void> _commit(SharedPreferences p, Map<String, Object> before, Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      _restore(before);
      try {
        await save(p);
      } catch (_) {}
      rethrow;
    }
  }

  /// 商品を渡す。非消費型（広告を消す・見抜く目）は何度来ても同じ。消費型（枠・チケット）は来た回数ぶん増える。
  /// [purchaseId] が同じものは二度渡さない（落ちたあとの再送・続けて届いた同じ取引で増えすぎないように）。
  /// 保存に失敗したら例外を投げる（受け取れなかったことにする）。
  Future<bool> grant(SharedPreferences p, String productId, {String? purchaseId}) async {
    if (!allProductIds.contains(productId)) return false;
    final tag = purchaseId == null || purchaseId.isEmpty ? null : '$productId:$purchaseId';
    // 確かめてから印を付けるまでの間に await を挟まない（続けて届いた同じ取引が、確かめをすり抜けないように）
    if (tag != null && (_granting.contains(tag) || seenOf(p).contains(tag))) return false;
    if (tag != null) _granting.add(tag);
    final before = toJson();
    switch (productId) {
      case productRemoveAds:
        noAds = true;
      case productKeenEye:
        eye = true;
      case productSaveSlot:
        slots = (slots + 1).clamp(0, maxSlots);
      case productTicket1:
        tickets = (tickets + 1).clamp(0, maxTickets);
      case productTicket3:
        tickets = (tickets + 3).clamp(0, maxTickets);
    }
    try {
      await _commit(p, before, () async {
        await save(p);
        if (tag != null) {
          final seen = seenOf(p);
          seen.add(tag);
          if (!await p.setStringList(seenKey, seen.length > 60 ? seen.sublist(seen.length - 60) : seen)) {
            throw StateError('受け取りの控えを保存できませんでした');
          }
          if (p.containsKey(oldSeenKey)) await p.remove(oldSeenKey);
        }
      });
    } finally {
      if (tag != null) _granting.remove(tag);
    }
    return true;
  }

  /// 返金・取り消された非消費型を戻す。
  Future<void> revoke(SharedPreferences p, String productId) async {
    if (productId == productRemoveAds) noAds = false;
    if (productId == productKeenEye) eye = false;
    await save(p);
  }

  /// チケットを1枚使う。使えたらその通し番号（これまでに使った枚数）を返す。無ければ null。
  Future<int?> useTicket(SharedPreferences p) async {
    if (tickets < 1) return null;
    final before = toJson();
    tickets--;
    used++;
    await _commit(p, before, () => save(p));
    return used;
  }

  /// 新入生として迎え終えたオリジナル選手の通し番号を控える（使った枚数より大きい番号は受け付けない）。
  Future<void> markSpent(SharedPreferences p, Iterable<int> serials) async {
    final add = serials.where((s) => s >= 1 && s <= used && !spent.contains(s)).toSet();
    if (add.isEmpty) return;
    final before = toJson();
    spent = [...spent, ...add];
    if (spent.length > _maxSpent) spent = spent.sublist(spent.length - _maxSpent);
    await _commit(p, before, () => save(p));
  }
}
