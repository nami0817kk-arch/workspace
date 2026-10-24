import 'honors.dart';
import 'money.dart';
import 'game.dart';
import 'season.dart';
import 'player.dart';

/// ポジションの呼び名。
String positionNickname(Position p) => switch (p) {
      Position.pointGuard => '司令塔',
      Position.shootingGuard => 'シューター',
      Position.smallForward => 'ウイング',
      Position.powerForward => 'パワーフォワード',
      Position.center => '大黒柱',
    };

bool _wentPro(Game g) => g.records.any((r) => r.league.name.startsWith('pro'));

/// プロで戦った年数(プロの大会の記録がある年の数)。
int proYears(Game g) => g.records
    .where((r) => r.league == League.proDomestic || r.league == League.proAbroad)
    .map((r) => r.age)
    .toSet()
    .length;

/// 引退後の進路(セカンドキャリア)。実績・人柄・収入で決まる。優先順に最初に当てはまるもの。
String secondCareer(Game g) {
  final py = proYears(g);
  final name = g.player.name;
  if (py >= 5 && (g.coachBond >= 50 || g.teamwork >= 60)) {
    return '引退後は指導者の道へ。チームのコーチとして、次の世代の選手を育てている。';
  }
  if (g.honorTotal >= 3 || worldChampion(g) || (g.abroad && g.titles > 0)) {
    return '引退後は解説者として、試合の中継で語り口が人気になった。${name}の解説を待つファンも多い。';
  }
  if (g.totalEarnings >= 100000) {
    return '引退後は、稼いだ資金でバスケットボールの育成アカデミーを開き、子どもたちを教えている。';
  }
  if (py == 0) {
    return '引退後は、地元のクラブで子どもたちにバスケを教えている。';
  }
  return '引退後は会社員として働きながら、週末はクラブチームでボールを追いかけている。';
}

/// 日本代表で世界大会を制したか。
bool worldChampion(Game g) =>
    g.records.any((r) => r.league == League.national && r.champion);

/// 栄光の結末か(エンディングの絵を選ぶ)。世界王者・永久欠番・3回以上の優勝・海外での優勝のどれか。
bool gloriousEnding(Game g) =>
    worldChampion(g) ||
    retiredNumber(g) ||
    g.titles >= 3 ||
    (g.abroad && g.titles >= 1);

/// 一生につく称号。到達点で決まる。
String careerTitle(Game g) {
  final nick = positionNickname(g.player.position);
  if (worldChampion(g)) return '世界王者の$nick';
  if (g.abroad && g.titles > 0) return '世界を制した$nick';
  if (g.abroad) return '世界に挑んだ$nick';
  if (_wentPro(g) && g.titles >= 3) return '常勝の$nick';
  if (_wentPro(g)) return 'プロで戦い抜いた$nick';
  if (g.titles > 0 && g.secondChance) return '学生王者の$nick';
  if (g.records.isEmpty) return '夢の途中の$nick';
  return '情熱の$nick';
}

/// 背番号が永久欠番になるか(プロで長く活躍し、優勝や個人賞を重ねたとき)。
bool retiredNumber(Game g) =>
    g.number > 0 &&
    _wentPro(g) &&
    (g.titles >= 3 || (g.abroad && g.titles >= 1) || g.awardCount >= 4);

/// 共有用の短い文章(「結果をコピー」で使う)。
String shareText(Game g) {
  final p = g.player;
  final b = StringBuffer()
    ..writeln('バスケ育成: ${p.name}の物語')
    ..writeln('称号「${careerTitle(g)}」(${g.difficulty.label})${g.number > 0 ? ' 背番号${g.number}${retiredNumber(g) ? '(永久欠番)' : ''}' : ''}')
    ..writeln('${p.heightCm.toStringAsFixed(0)}cm ${positionNickname(p.position)} 総合${p.overall.round()}  ${p.age}歳で引退')
    ..writeln('通算 ${g.totalGames}試合 ${g.totalPoints}得点 ${g.totalRebounds}リバウンド ${g.totalAssists}アシスト')
    ..writeln('スティール${g.totalSteals} ブロック${g.totalBlocks} 3P${g.totalThrees}本${g.careerHigh == null ? '' : ' キャリアハイ${g.careerHigh!.points}点'}')
    ..writeln('優勝${g.titles}回 個人賞${g.awardCount}回${g.abroad ? ' 海外挑戦' : ''}');
  if (p.skills.isNotEmpty) {
    b.writeln('得意技: ${p.skills.map((k) => k.label).join('・')}');
  }
  if (g.rival.games > 0) {
    b.writeln('宿敵${g.rival.name}との通算 ${g.rival.wins}勝${g.rival.losses}敗');
  }
  b.write('#バスケ育成');
  return b.toString();
}

/// 舞台の格(全盛期を選ぶときの加点)。
double _leagueWeight(League l) => switch (l) {
      League.minibasket => 0,
      League.juniorHigh => 8,
      League.highSchool => 16,
      League.university => 24,
      League.corporate => 24,
      League.proDomestic => 36,
      League.proAbroad => 48,
      League.national => 44,
    };

String _talent(int potential) {
  if (potential >= 80) return '天賦の才に恵まれた';
  if (potential >= 60) return '確かな素質を持った';
  if (potential >= 45) return '平凡な素質から出発した';
  return '決して恵まれてはいない素質で挑んだ';
}

/// エンディングの文章(段落ごと)。生い立ち・全盛期・ライバル・結末・ひとこと。
List<String> epilogueLines(Game g) {
  final p = g.player;
  final lines = <String>[];

  final traits = p.traits.isEmpty
      ? ''
      : '「${p.traits.map((t) => t.label).join('」「')}」の持ち主だった。';
  lines.add('${_talent(p.potential)}${p.name}は、最終的に'
      '${p.heightCm.toStringAsFixed(0)}cmの${positionNickname(p.position)}になった。$traits');

  if (g.records.isNotEmpty) {
    // 全盛期: 実績に、舞台の格(ミニバスより海外プロ)を加えて比べる。
    double score(YearRecord r) => r.achievement + _leagueWeight(r.league);
    final best = g.records.reduce((a, b) => score(b) > score(a) ? b : a);
    lines.add('いちばん輝いたのは${best.age}歳、${best.league.label}'
        '${best.winter ? 'の冬' : ''}の大会。'
        '${best.champion ? '頂点に立ち、' : ''}平均${best.ppg.toStringAsFixed(1)}得点を記録した。');
  }

  final r = g.rival;
  if (r.games > 0) {
    if (r.wins > r.losses) {
      lines.add('宿敵${r.name}との対戦は${r.wins}勝${r.losses}敗。最後には、あの背中を越えた。');
    } else if (r.wins == r.losses) {
      lines.add('宿敵${r.name}との対戦は${r.wins}勝${r.losses}敗の五分。お互い、最高の好敵手だった。');
    } else {
      lines.add('宿敵${r.name}との対戦は${r.wins}勝${r.losses}敗。届かなかったが、あの存在が自分を強くした。');
    }
  }

  if (g.caps > 0) {
    lines.add(worldChampion(g)
        ? '日本代表として世界の頂点に立った。${g.caps}度の代表の舞台は、誇りだった。'
        : '日本代表として${g.caps}度、世界の舞台に立った。');
  }

  final hc = g.honorCounts;
  if (hc.isNotEmpty) {
    lines.add('個人タイトルは、${[
      for (final h in Honor.all)
        if (hc.containsKey(h)) hc[h]! > 1 ? '$h${hc[h]}回' : h,
    ].join('、')}。');
  }

  if (g.totalEarnings > 0) {
    lines.add('プロで稼いだ生涯収入は、年俸とスポンサー契約をあわせて約${moneyLabel(g.totalEarnings)}。');
  }

  final cp = g.totalPoints;
  if (cp >= 500) {
    lines.add('通算$cp得点・${g.totalRebounds}リバウンド・${g.totalAssists}アシストを積み上げた。');
  }

  if (g.draftPick == 1) {
    lines.add('ドラフトでは全体1位。いきなり、リーグの顔として迎えられた。');
  } else if (g.draftPick > 0 && g.draftPick <= 10) {
    lines.add('ドラフトでは全体${g.draftPick}位の上位指名。大きな期待を背負ってプロの扉を開いた。');
  } else if (g.draftPick > 30) {
    lines.add('ドラフトでは全体${g.draftPick}位。決して高い評価ではなかったが、そこからのし上がった。');
  }

  // 引退セレモニー(プロで戦った選手だけ)。
  final py = proYears(g);
  if (py > 0) {
    final forced = g.retiredReason == '戦力外通告を受けた';
    if (py >= 10 && (g.titles > 0 || g.honorTotal > 0 || g.abroad)) {
      lines.add('引退セレモニーには満員のアリーナが詰めかけ、スタンディングオベーションで${p.name}を見送った。');
    } else if (py >= 5) {
      lines.add(forced
          ? '戦力外通告を受けたが、最後の試合までコートに立った。仲間とファンが温かく送り出してくれた。'
          : '引退セレモニーでは、仲間とファンに見送られ、静かにユニフォームを脱いだ。');
    } else {
      lines.add('短いプロ生活だったが、最後の試合では温かい拍手が送られた。');
    }
  }

  if (retiredNumber(g)) {
    lines.add('背番号${g.number}は、永久欠番になった。');
  } else if (g.number > 0 && _wentPro(g)) {
    lines.add('背番号${g.number}を背負って、プロの舞台に立った。');
  }

  if (p.skills.isNotEmpty) {
    lines.add('得意技は「${p.skills.map((k) => k.label).join('」「')}」。');
  }

  if (g.careerHigh != null && g.careerHigh!.points >= 20) {
    lines.add('キャリアハイは${g.careerHigh!.age}歳の${g.careerHigh!.points}得点。');
  }

  if (r.games > 0) lines.add(r.fate);

  // 支えてくれた人たち。信頼・チームワークが高かったときだけ。
  final thanks = <String>[];
  if (g.coachBond >= 60 && g.coachLabel.isNotEmpty) {
    thanks.add('${g.coachLabel}コーチへの感謝は、最後まで忘れなかった。');
  }
  if (g.teamwork >= 60 && g.mate.isNotEmpty) {
    thanks.add('仲間の${g.mate}とは、いまも連絡を取り合っている。');
  }
  if (thanks.isNotEmpty) lines.add(thanks.join(''));

  lines.add(secondCareer(g));

  final reason = g.retiredReason ?? '現役を退いた';
  // 古いセーブの理由は「41歳で…」と年齢を含んでいる(重ねない)。
  lines.add(reason.startsWith('${p.age}歳') ? '$reason。' : '${p.age}歳、$reason。');

  lines.add(_closing(g));
  return lines;
}

String _closing(Game g) {
  if (g.abroad && g.titles > 0) return '世界の舞台で戦い、勝ち取った栄光。語り継がれる選手になった。';
  if (g.abroad) return '海を渡り、世界最高峰に挑んだ。その経験は、なにものにも代えがたい。';
  if (_wentPro(g)) {
    return g.titles > 0
        ? 'プロとして頂点を知った。ファンの記憶に残る選手だった。'
        : 'プロの世界で戦い抜いた。コートに立ち続けた誇りがある。';
  }
  if (g.records.isEmpty) return '大きな舞台には届かなかった。それでも、バスケは好きなままだ。';
  return 'プロの扉は開かなかった。それでも、仲間とコートを駆けた日々は本物だった。';
}
