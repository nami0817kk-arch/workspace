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

/// 課金で買った権利（広告を消す・見抜く目・セーブ枠・オリジナル選手チケット）。
/// 書き込むのはここ（Flutter）だけ。ページ側は届いた値を読むだけ（ページには `ya_ent` として渡る）。
class Entitlements {
  Entitlements({this.noAds = false, this.eye = false, this.slots = 0, this.tickets = 0});

  bool noAds;
  bool eye;

  /// 追加したセーブ枠の数（0〜4。最初の1枠は無料なので合計は最大5）。
  int slots;
  int tickets;

  static const key = 'ya_ent';
  static const seenKey = 'ya_ent_seen';
  static const maxSlots = 4;

  Map<String, Object> toJson() => {'noAds': noAds, 'eye': eye, 'slots': slots, 'tickets': tickets};

  factory Entitlements.fromJson(Object? j) {
    if (j is! Map) return Entitlements();
    int n(Object? v, int hi) => v is num ? v.toInt().clamp(0, hi) : 0;
    return Entitlements(noAds: j['noAds'] == true, eye: j['eye'] == true, slots: n(j['slots'], maxSlots), tickets: n(j['tickets'], 99));
  }

  static Entitlements load(SharedPreferences p) {
    try {
      final s = p.getString(key);
      return s == null ? Entitlements() : Entitlements.fromJson(jsonDecode(s));
    } catch (_) {
      return Entitlements();
    }
  }

  Future<void> save(SharedPreferences p) => p.setString(key, jsonEncode(toJson()));

  /// 商品を渡す。非消費型（広告を消す・見抜く目）は何度来ても同じ。消費型（枠・チケット）は来た回数ぶん増える。
  /// [purchaseId] が同じものは二度渡さない（落ちたあとの再送で増えすぎないように）。
  Future<bool> grant(SharedPreferences p, String productId, {String? purchaseId}) async {
    final tag = purchaseId == null || purchaseId.isEmpty ? null : '$productId:$purchaseId';
    if (tag != null && (p.getStringList(seenKey) ?? <String>[]).contains(tag)) return false;
    switch (productId) {
      case productRemoveAds:
        noAds = true;
      case productKeenEye:
        eye = true;
      case productSaveSlot:
        slots = (slots + 1).clamp(0, maxSlots);
      case productTicket1:
        tickets = (tickets + 1).clamp(0, 99);
      case productTicket3:
        tickets = (tickets + 3).clamp(0, 99);
      default:
        return false;
    }
    await save(p);
    if (tag != null) {
      final seen = p.getStringList(seenKey) ?? <String>[];
      seen.add(tag);
      await p.setStringList(seenKey, seen.length > 60 ? seen.sublist(seen.length - 60) : seen);
    }
    return true;
  }

  /// 返金・取り消された非消費型を戻す。
  Future<void> revoke(SharedPreferences p, String productId) async {
    if (productId == productRemoveAds) noAds = false;
    if (productId == productKeenEye) eye = false;
    await save(p);
  }

  /// チケットを1枚使う。無ければ false。
  Future<bool> useTicket(SharedPreferences p) async {
    if (tickets < 1) return false;
    tickets--;
    await save(p);
    return true;
  }
}
