import '../l10n/tr.dart';

/// 新規開始のときに選ぶシナリオ。初期の資金・期待・施設が変わる。
enum StartScenario {
  /// ふつうの開始。
  standard,

  /// 債務を抱えたクラブ。資金がマイナスで、株主の期待が低い。立て直す遊び方。
  debt,

  /// 資産家がオーナーのクラブ。資金は潤沢だが、期待が高い。
  patron,

  /// 育成が自慢のクラブ。資金は少ないが、ユースとトレーニング施設が育っている。
  academy;

  String get label => switch (this) {
        standard => Tr.pick('標準', 'Standard'),
        debt => Tr.pick('債務を抱えたクラブ', 'Debt-laden club'),
        patron => Tr.pick('資産家のオーナー', 'Wealthy patron'),
        academy => Tr.pick('育成の名門', 'Academy club'),
      };

  String get description => switch (this) {
        standard => Tr.pick('ふつうの開始。', 'A normal start.'),
        debt => Tr.pick('資金は-1500万円、株主の期待は低め。立て直しの腕が試されます。',
            'Funds start at -1500 and shareholders are wary. A rebuilding job.'),
        patron => Tr.pick('資金が3倍、株主の期待は高め。理事会の目標も上がります。',
            'Triple the funds, but shareholders expect more and the board aims higher.'),
        academy => Tr.pick('資金は7割。ユース施設Lv3とトレーニング施設Lv2から始まります。',
            '70% of the funds, but you start with youth facilities Lv3 and training Lv2.'),
      };
}

/// クラブの年表の1行。
class TimelineEntry {
  const TimelineEntry({required this.season, required this.text});

  final int season;
  final String text;

  Map<String, dynamic> toJson() => {'season': season, 'text': text};

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
        season: json['season'] as int,
        text: json['text'] as String,
      );
}
