import 'characters.dart';
import 'path.dart' show draftTeams;

/// ライバル(同い年)の人生。素質と名前から決まる(乱数も保存も使わない)。
/// 自分と同じ時間を生きて、進路を選び、プロで活躍し、引退する。
class RivalStory {
  const RivalStory({
    required this.name,
    required this.talent,
    required this.proAge,
    required this.college,
    required this.retireAge,
    required this.team,
    required this.draftRound,
  });

  final String name;
  final int talent;

  /// プロ入りする年齢。プロにならなければ null。
  final int? proAge;

  /// 大学を経由するか(素質が中くらいの子)。
  final bool college;
  final int retireAge;
  final String team;
  final int draftRound;

  /// 自分と同じ球団に居るのは不自然なので、同じなら隣の球団に替える(ライバルは別のチームで戦う)。
  RivalStory avoiding(String? mine) {
    if (mine == null || mine != team) return this;
    final i = draftTeams.indexOf(team);
    return RivalStory(
      name: name,
      talent: talent,
      proAge: proAge,
      college: college,
      retireAge: retireAge,
      team: draftTeams[(i + 1) % draftTeams.length],
      draftRound: draftRound,
    );
  }
}

int _h(String s) {
  var v = 7;
  for (final c in s.codeUnits) {
    v = (v * 131 + c) & 0x7fffffff;
  }
  return v;
}

/// 素質70以上は高卒でプロ(18歳)、50〜69は大学を経て(22歳)プロ、それ未満は社会人で続けて引退(プロにならない)。
RivalStory storyOf(String name, int talent) {
  final int? proAge = talent >= 70 ? 18 : (talent >= 50 ? 22 : null);
  final retire =
      proAge == null ? 30 : proAge + 10 + ((talent - 40) ~/ 5).clamp(0, 12);
  return RivalStory(
    name: name,
    talent: talent,
    proAge: proAge,
    college: talent >= 50 && talent < 70,
    retireAge: retire,
    team: draftTeams[_h(name) % draftTeams.length],
    draftRound: talent >= 85 ? 1 : (talent >= 78 ? 2 : (talent >= 70 ? 3 : 4)),
  );
}

/// この年齢になった年に伝える、ライバルの知らせ(なければ空)。
List<String> rivalNews(RivalStory s, int age) {
  final n = s.name;
  final out = <String>[];
  if (age == 19) {
    // 進路が決まった年(高校を卒業した年)。
    if (s.proAge == 18) {
      out.add('ライバルの$nは、${s.team}にドラフト${s.draftRound}位で入団した。');
    } else if (s.college) {
      out.add('ライバルの$nは、大学に進学した。');
    } else {
      out.add('ライバルの$nは、社会人で野球を続けている。');
    }
  }
  final pa = s.proAge;
  if (pa == 22 && age == 23) {
    out.add('ライバルの$nは、大学から${s.team}にドラフト${s.draftRound}位で入団した。');
  }
  if (pa != null && age > pa + 1 && age < s.retireAge && (age - pa) % 5 == 0) {
    out.add('ライバルの$nは、プロ${age - pa}年目。いまも第一線で戦っている。');
  }
  if (age == s.retireAge + 1) {
    out.add(pa == null ? 'ライバルの$nは、野球を引退して新しい道へ進んだ。' : 'ライバルの$nが、現役を引退した。');
  }
  return out;
}

/// いまのライバルの様子(自分の年齢 `age` のとき)。成績画面に出す。
String rivalStatus(RivalStory s, int age) {
  final pa = s.proAge;
  if (age < 18) return '同い年のライバル。いまは切磋琢磨している。';
  if (age <= s.retireAge) {
    if (pa == null) return age < 19 ? '進路を考えている。' : '社会人で野球を続けている。';
    if (age < pa) return '大学で腕を磨いている。';
    return '${s.team}でプレー中(プロ${age - pa + 1}年目)。';
  }
  return pa == null ? '野球を引退した。' : '${s.team}で活躍したあと、引退した。';
}

/// 登場人物から物語を作る。
RivalStory? storyOfCharacter(Character? r) =>
    r == null ? null : storyOf(r.name, r.talent);
