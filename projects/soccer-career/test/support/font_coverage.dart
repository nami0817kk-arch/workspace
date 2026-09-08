/// 同梱フォントが、どの文字を持っているかを調べる道具。
///
/// 画面に出す文字がフォントに無いと、その字だけ豆腐（□）になる。
/// ほとんどの字は出るので、普通のウィジェットテストでは気付けない
/// （実際に公開ページで「監□の期待」が出ていた）。
library;

import 'dart:io';
import 'dart:typed_data';

/// TTF の cmap を読んで、収録されているコードポイントを返す。
///
/// format 4（BMP）と format 12（それ以外も含む）だけを見る。
/// 日本語フォントはこのどちらかを必ず持っている。
Set<int> fontCodePoints(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  final numTables = data.getUint16(4);
  int? cmap;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  if (cmap == null) throw StateError('cmap が無い: $path');

  final subtables = data.getUint16(cmap + 2);
  int? format4;
  int? format12;
  for (var i = 0; i < subtables; i++) {
    final record = cmap + 4 + 8 * i;
    final offset = cmap + data.getUint32(record + 4);
    switch (data.getUint16(offset)) {
      case 4:
        format4 ??= offset;
      case 12:
        format12 ??= offset;
    }
  }

  if (format12 != null) return _readFormat12(data, format12);
  if (format4 != null) return _readFormat4(data, format4);
  throw StateError('読める cmap が無い: $path');
}

Set<int> _readFormat12(ByteData data, int p) {
  final groups = data.getUint32(p + 12);
  final result = <int>{};
  for (var i = 0; i < groups; i++) {
    final g = p + 16 + 12 * i;
    final start = data.getUint32(g);
    final end = data.getUint32(g + 4);
    final glyph = data.getUint32(g + 8);
    if (glyph == 0) continue;
    for (var c = start; c <= end; c++) {
      result.add(c);
    }
  }
  return result;
}

Set<int> _readFormat4(ByteData data, int p) {
  final segCount = data.getUint16(p + 6) ~/ 2;
  final endCodes = p + 14;
  final startCodes = endCodes + segCount * 2 + 2;
  final idDeltas = startCodes + segCount * 2;
  final idRangeOffsets = idDeltas + segCount * 2;

  final result = <int>{};
  for (var seg = 0; seg < segCount; seg++) {
    final end = data.getUint16(endCodes + seg * 2);
    final start = data.getUint16(startCodes + seg * 2);
    if (start > end) continue;
    final delta = data.getInt16(idDeltas + seg * 2);
    final rangeOffset = data.getUint16(idRangeOffsets + seg * 2);
    for (var c = start; c <= end && c != 0xFFFF; c++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final at = idRangeOffsets + seg * 2 + rangeOffset + (c - start) * 2;
        if (at + 1 >= data.lengthInBytes) continue;
        glyph = data.getUint16(at);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      if (glyph != 0) result.add(c);
    }
  }
  return result;
}

/// ソースの文字列リテラルに出てくる文字を集める。
///
/// 画面に出るのは文字列リテラルだけ。コメントまで拾うと、
/// 表示されない字でテストが落ちる。
Set<String> literalCharactersIn(Directory dir) {
  // 1行に収まる '…' を拾う。エスケープは飛ばす。
  final literal = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
  final result = <String>{};

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    for (final line in entity.readAsLinesSync()) {
      final trimmed = line.trimLeft();
      // 行まるごとのコメントは読まない。
      if (trimmed.startsWith('//')) continue;
      if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
        continue;
      }
      for (final match in literal.allMatches(line)) {
        result.addAll(match.group(1)!.split(''));
      }
    }
  }
  return result;
}
