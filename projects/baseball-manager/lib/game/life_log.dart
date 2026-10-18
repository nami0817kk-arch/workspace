import 'career.dart';
import 'path.dart';
import 'player.dart';
import 'records.dart';

/// 人生の節目(入学・進路・ドラフト・特性の習得・転向・引退)の記録。経歴の年表に出す。
class LifeEvent {
  const LifeEvent(this.age, this.kind, this.text);
  final int age;

  /// stage / route / draft / trait / role / retire
  final String kind;
  final String text;

  Map<String, dynamic> toJson() => {'age': age, 'kind': kind, 'text': text};

  factory LifeEvent.fromJson(Map<String, dynamic> j) => LifeEvent(
        (j['age'] as num?)?.toInt() ?? 0,
        (j['kind'] as String?) ?? 'stage',
        (j['text'] as String?) ?? '',
      );
}

String stageNameOf(Stage s) => switch (s) {
      Stage.youth => '少年野球',
      Stage.juniorHigh => '中学',
      Stage.highSchool => '高校',
      Stage.pathChoice => '進路(大学・社会人)',
      Stage.pro => 'プロ',
      Stage.retired => '引退',
    };

String roleNameOf(Role r) => switch (r) {
      Role.batter => '打者',
      Role.pitcher => '投手',
      Role.twoWay => '二刀流',
    };

String courseNameOf(Course c) => switch (c) {
      Course.university => '大学',
      Course.corporate => '社会人',
    };

/// 年表の1行。
class TimelineEntry {
  const TimelineEntry(this.age, this.kind, this.text);
  final int age;

  /// life の kind に加えて、champion / title(成績から作る)。
  final String kind;
  final String text;
}

/// 節目の記録と、年ごとの成績(優勝・タイトル)を合わせた年表。年齢順。
List<TimelineEntry> timelineOf(
    List<LifeEvent> events, List<SeasonRecord> records) {
  const order = {
    'stage': 0,
    'route': 1,
    'draft': 2,
    'role': 3,
    'trait': 4,
    'champion': 5,
    'title': 6,
    'retire': 9,
  };
  final all = <TimelineEntry>[
    for (final e in events) TimelineEntry(e.age, e.kind, e.text),
    for (final r in records) ...[
      if (r.champion)
        TimelineEntry(r.age, 'champion', r.isLeague ? 'リーグ優勝' : '大会で優勝'),
      for (final t in r.titles) TimelineEntry(r.age, 'title', 'タイトル獲得: $t'),
    ],
  ];
  // 同じ年の中は、節目→成績→引退の順。元の順序は保つ。
  final indexed = [for (var i = 0; i < all.length; i++) (i, all[i])];
  indexed.sort((a, b) {
    final c = a.$2.age.compareTo(b.$2.age);
    if (c != 0) return c;
    final o = (order[a.$2.kind] ?? 5).compareTo(order[b.$2.kind] ?? 5);
    return o != 0 ? o : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
