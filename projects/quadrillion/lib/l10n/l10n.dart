// ignore_for_file: non_constant_identifier_names
/// 日本語と英語の切り替え。Flutter に依存しない（仕組みの lib/game からも使う）。
///
/// しくみ:
/// - 文の鍵は日本語の文そのもの（gettext と同じ考え方）。英語は [enText] の表で引く。
///   表は画面の文（ui_en.dart）・仕組みの文（game_en.dart）・定義の名前（data_en.dart）に分けて置く。
/// - 画面の文は [tr] で組み立てる（`tr('{0}年{1}月', [y, q])`）。
/// - 仕組みが作る文（ニュース・記録・社史・出来事・手の結果）は [M] で「鍵と引数」の形に包んで持つ。
///   セーブにはこの包んだ形のまま入るので、セーブは言語に依存しない。見せるときに [tx] で今の言語に組み立てる。
///   古いセーブの日本語の文（包んでいないもの）は、そのまま日本語で見せる。
/// - 引数の金額・業種・国・人や会社の名前は、印を付けて持ち、見せるときに今の言語で書く（[Y] [I] [C] [Nm] など）。
library;

import 'dart:convert';

import '../game/data.dart';
import '../game/format.dart';
import 'data_en.dart';
import 'game_en.dart';
import 'lang.dart';
import 'mid_en.dart';
import 'ui_en.dart';

export 'lang.dart';

const _msgMark = '\u0001';
const _tagMark = '\u0002';
const _joinKey = '\u0003join';

/// 英語の表（日本語の文 → 英語の文）。同じ日本語の鍵は、どの表でも同じ英語にする
String? enText(String ja) => uiEn[ja] ?? gameEn[ja] ?? dataEn[ja] ?? midEn[ja];

/// 定義の名前など、引数のない日本語を今の言語にする
String de(String ja) => L.en ? (enText(ja) ?? _strip(ja)) : _strip(ja);

/// 同じ日本語でも英語が場面で変わるものは、鍵の後ろに「@@場面」を付けて分ける（日本語ではそこを落とす）
String _strip(String k) {
  final i = k.indexOf('@@');
  return i < 0 ? k : k.substring(0, i);
}

/// 画面の文を今の言語で組み立てる。{0} {1} … に引数を入れる（引数は文字・数・包んだ文）
String tr(String ja, [List<Object?> args = const []]) => _fill(L.en ? (enText(ja) ?? _strip(ja)) : _strip(ja), args, L.en);

/// 仕組みが作る文を「鍵と引数」の形に包む（セーブにはこのまま入る）
String M(String ja, [List<Object?> args = const []]) => _msgMark + jsonEncode([ja, for (final a in args) _enc(a)]);

/// 包んだ文を並べる（日本語は「・」、英語は「, 」でつなぐ）
String J(Iterable<Object?> items) => _msgMark + jsonEncode([_joinKey, for (final a in items) _enc(a)]);

/// 包んだ文をつなげる（日本語は [ja] でつなぎ、英語は [en] でつなぐ）
String Cat(List<Object?> parts, {String ja = '', String en = ' '}) =>
    _msgMark + jsonEncode(['\u0003cat', ja, en, for (final a in parts) _enc(a)]);

/// 金額の印（見せるときに円・兆億万 / ¥・K M B T で書く）
String Y(double v) => '${_tagMark}y$v';

/// 業種の印
String I(String id) => '${_tagMark}i$id';

/// 国の印
String C(String code) => '${_tagMark}c$code';

/// 人・会社の名前の印（英語ではローマ字にする）
String Nm(String name) => '${_tagMark}n$name';

/// 定義の名前の印（日本語の名前を持ち、英語では表で引く。例: 稼ぎ方・社風・分類）
String D(String ja) => '${_tagMark}d$ja';

/// 包んだ文か
bool isMsg(String s) => s.startsWith(_msgMark);

/// 包んだ文の鍵（日本語の文）。包んでいなければ文そのもの
String msgKey(String s) {
  if (!isMsg(s)) return s;
  try {
    final l = jsonDecode(s.substring(1)) as List;
    return l.first as String;
  } catch (_) {
    return s;
  }
}

/// 包んだ文を今の言語で組み立てる。包んでいない文（古いセーブの日本語など）はそのまま
String tx(String? s) => s == null ? '' : _render(s, L.en);

/// 言語を決めて組み立てる（テストと自動プレイ用）
String txIn(String? s, String lang) => s == null ? '' : _render(s, lang == 'en');

Object? _enc(Object? a) {
  if (a == null) return '';
  if (a is int) return a;
  if (a is double) return jsNum(a);
  return a.toString();
}

String _render(String s, bool en) {
  if (s.startsWith(_tagMark)) return _tag(s, en);
  if (!s.startsWith(_msgMark)) return s;
  List l;
  try {
    l = jsonDecode(s.substring(1)) as List;
  } catch (_) {
    return s;
  }
  final key = l.first as String;
  final args = l.sublist(1);
  if (key == _joinKey) return args.map((a) => _arg(a, en)).join(en ? ', ' : '・');
  if (key == '\u0003cat') {
    final sep = (en ? args[1] : args[0]) as String;
    return args.sublist(2).map((a) => _arg(a, en)).where((x) => x.isNotEmpty).join(sep);
  }
  return _fill(en ? (enText(key) ?? _strip(key)) : _strip(key), args, en);
}

String _arg(Object? a, bool en) {
  if (a == null) return '';
  if (a is String) return _render(a, en);
  if (a is num) return jsNum(a.toDouble());
  return a.toString();
}

final _ph = RegExp(r'\{(\d+)\}');

String _fill(String t, List args, bool en) {
  if (args.isEmpty) return t;
  return t.replaceAllMapped(_ph, (m) {
    final i = int.parse(m.group(1)!);
    return i < args.length ? _arg(args[i], en) : m.group(0)!;
  });
}

String _tag(String s, bool en) {
  final k = s.length > 1 ? s[1] : '';
  final v = s.length > 2 ? s.substring(2) : '';
  switch (k) {
    case 'y':
      final d = double.tryParse(v) ?? double.nan;
      return en ? yenEn(d) : yenJa(d);
    case 'i':
      final ja = indJa[v] ?? v;
      return en ? (enText(ja) ?? ja) : ja;
    case 'c':
      final ja = ctryJa[v] ?? v;
      return en ? (enText(ja) ?? ja) : ja;
    case 'n':
      return en ? romanize(v) : v;
    case 'd':
      return en ? (enText(v) ?? _strip(v)) : _strip(v);
  }
  return v;
}

/// 業種・国の日本語の名前（id → 名前）
final Map<String, String> indJa = {for (final i in IND) i.id: i.ja};
final Map<String, String> ctryJa = {for (final c in CTRY) c.c: c.ja};

/// 人・会社の名前を今の言語で（英語ではローマ字・元の綴りにする）
String nmL(String? name) => name == null ? '' : (L.en ? romanize(name) : name);

// ===== 名前のローマ字 =====
Map<String, String>? _nameMap;
List<MapEntry<String, String>>? _suffixes;

Map<String, String> _names() {
  final m = <String, String>{};
  void zip(List<String> a, List<String> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      m.putIfAbsent(a[i], () => b[i]);
    }
  }

  zip(SEI, SEI_EN);
  zip(MEI, MEI_EN);
  zip(CO_A, CO_A_EN);
  zip(CO_C, CO_C_EN);
  zip(CO_F, CO_F_EN);
  for (final e in NAMEP.entries) {
    final en = NAMEP_EN[e.key];
    if (en == null) continue;
    zip(e.value[0], en[0]);
    zip(e.value[1], en[1]);
  }
  m.addAll(RIVAL_NAMES_EN);
  for (final e in CO_FSUF.entries) {
    m.putIfAbsent(e.value, () => CO_SUF_EN[e.key]!.$2);
  }
  return m;
}

List<MapEntry<String, String>> _sufs() {
  final l = <MapEntry<String, String>>[
    for (final e in CO_SUF.entries) MapEntry(e.value, CO_SUF_EN[e.key]!.$1),
    for (final e in CO_FSUF.entries) MapEntry(e.value, CO_SUF_EN[e.key]!.$2),
    const MapEntry('グループ', 'Group'),
    const MapEntry('ホールディングス', 'Holdings'),
  ];
  l.sort((a, b) => b.key.length - a.key.length);
  return l;
}

final _sep = RegExp('[・ ]');

/// 名前をローマ字にする（知らない部分はそのまま残す）
String romanize(String name) {
  final m = _nameMap ??= _names();
  final whole = m[name];
  if (whole != null) return whole;
  final parts = name.split(_sep).where((x) => x.isNotEmpty).toList();
  return parts.map(_tok).join(' ');
}

String _tok(String t) {
  final m = _nameMap ??= _names();
  final hit = m[t];
  if (hit != null) return hit;
  for (final s in _suffixes ??= _sufs()) {
    if (t.length > s.key.length && t.endsWith(s.key)) {
      final pre = t.substring(0, t.length - s.key.length);
      final p = m[pre];
      if (p != null) return '$p ${s.value}';
      return '${_tok(pre)} ${s.value}';
    }
  }
  return t;
}
