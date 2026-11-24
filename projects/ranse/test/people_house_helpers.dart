import 'package:ranse/engine/birth.dart';
import 'package:ranse/engine/data.dart';
import 'package:ranse/engine/game.dart';
import 'package:ranse/engine/rng.dart';

import 'bot.dart';

/// 人と家の4項目（縁談の相手・家臣・有名人との縁・子の育て方、2026-11-25）のテストが使う道具。

/// 選択肢の名と匂わせに出してはいけない字（数字）。
final kDigits = RegExp('[0-9０-９%％]');

/// 元服・裳着の問いまで進めた人生。生き延びなければ null。
/// [female] で性別を、[from]〜[to] で生まれた年を絞る（合わなければ null）。
Game? grownUp(int seed, {bool? female, int from = 0, int to = 9999}) {
  final rng = Rng(seed);
  final b = rollBirth(rng);
  if (female != null && b.female != female) return null;
  if (b.startYear < from || b.startYear > to) return null;
  final g = Game(rng: rng)..start(b);
  if (g.finished) return null;
  final r = Rng(seed + 1);
  var n = 0;
  while (!g.finished && g.isChild && n++ < 200) {
    g.choose(r.range(0, g.prompt!.choices.length - 1));
  }
  if (g.finished || g.prompt == null) return null;
  return g;
}

/// [seed] から先で、最初に元服まで生きた人生。
Game firstGrown(int seed, {bool? female, int from = 0, int to = 9999}) {
  for (var s = seed; ; s++) {
    final g = grownUp(s, female: female, from: from, to: to);
    if (g != null) return g;
  }
}

/// 元服の問いのところで、歳を [age] に進める（その年から大人の年が始まる）。
void jumpTo(Game g, int age) {
  g.l.t = age * 2;
}

/// 近くの家に位 [rank] で仕えさせる（男なら城を預かる身。八なら当主）。
void serveAt(Game g, int rank) {
  final l = g.l;
  final f = nearest(g.alive, (f) => f.name, region: l.region, n: 1).first;
  l.rank = rank;
  if (l.maxRank < rank) l.maxRank = rank;
  l.lord = f.name;
  l.fav = 45;
  l.troops = rank >= 5 ? 60 : 20;
  l.ronin = false;
  l.flags.remove('way_merchant');
  l.flags.remove('way_outlaw');
  l.flags.remove('priesthood');
}

/// 人生の終わりまで進める。新しく `scene:<id>` の旗が立った岐路（[prefix] で始まる id）が出た瞬間に
/// [atScene] を呼び、年の初めの問いのたびに [onYear] を呼ぶ。出た岐路の id を返す。
List<String> playWatch(
  Game g,
  Rng r, {
  required String prefix,
  void Function(String id, Prompt p)? atScene,
  void Function()? onYear,
  bool ambitious = false,
  int limit = 4000,
}) {
  final out = <String>[];
  var known = g.l.flags.where((f) => f.startsWith('scene:$prefix')).toSet();
  var n = 0;
  while (!g.finished && n++ < limit) {
    var p = g.prompt;
    if (p == null) break;
    if (p.title == 'この年の心がけ' && !g.isChild) {
      onYear?.call();
      p = g.prompt!;
    }
    final now = g.l.flags.where((f) => f.startsWith('scene:$prefix')).toSet();
    for (final f in now.difference(known)) {
      final id = f.substring(6);
      out.add(id);
      atScene?.call(id, p);
    }
    known = now;
    g.choose(ambitious ? pickAmbitious(g, p, r) : r.range(0, p.choices.length - 1));
  }
  return out;
}
