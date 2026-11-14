// ignore_for_file: avoid_print
import 'package:basketball_career/gm/bot.dart';
import 'package:basketball_career/gm/personality.dart';

void main(List<String> args) {
  final rank = int.parse(args.isEmpty ? '28' : args[0]);
  if (args.contains('noform')) tuneForm = false;
  if (args.contains('nomin')) tuneMinutes = false;
  var titles = 0, fired = 0;
  const n = 30;
  final seasons = <int>[];
  for (var i = 0; i < n; i++) {
    final c = botPlayCareer(500 + i, team: teamAtRank(500 + i, rank));
    titles += c.titles;
    if (c.fired) fired++;
    seasons.add(c.history.length);
  }
  print('$args rank $rank fired ${fired / n} titles ${titles / n} seasons $seasons');
}
