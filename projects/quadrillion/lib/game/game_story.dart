// ignore_for_file: non_constant_identifier_names
part of 'game.dart';

/// 宿敵のせりふ（型ごと）。鍵は RTYPE と同じ（label があれば label、なければ type）
const Map<String, String> storyMeet = {
  'zaibatsu': '「新参の会社ね。この業界には百年続く決まりごとがあるの。覚えておきなさい」',
  'fund': '「いい会社だ。値札が付いて見える。いずれ私が買ってあげよう」',
  'genius': '「古いやり方の会社だね。3年で追い抜くよ。悪く思わないで」',
  'peer': '「よう、久しぶり。同じ年に始めたお前にだけは、負けるつもりはない」',
  'state': '「我々の後ろには国がある。あなたの後ろには何がある？」',
  'asia': '「アジアは広い。だが、我々の通り道に立つなら話は別だ」',
  'bigtech': '「君の市場は小さい。僕らにとっては誤差だ。邪魔はしないでくれ」',
  'grit': '「わしは裸一貫からここまで来た。坊ちゃんの商売には負けん」',
  'ex': '「社長、お世話になりました。これからは対等な商売敵です」',
  'avenger': '「{0}を覚えているか。あの日のことを、一族は一日も忘れていない」',
};

const Map<String, String> storyClash = {
  'zaibatsu': '「礼儀を知らない人。そろそろ本気で相手をしてあげる」',
  'fund': '「抵抗するほど、買値は安くなるものだよ」',
  'genius': '「面白くなってきた。君、思ったよりしぶといね」',
  'peer': '「やっぱりお前か。こうでなくちゃ張り合いがない」',
  'state': '「これはもう商売ではない。国と国の話だ」',
  'asia': '「一族の名にかけて、ここは一歩も引かない」',
  'bigtech': '「誤差だと思っていたけど、訂正しよう。君は脅威だ」',
  'grit': '「なかなかやるのう。だが、根性ならわしの方が上じゃ」',
  'ex': '「社長に教わったやり方で、社長を倒します」',
  'avenger': '「まだ足りない。一族が失ったものは、こんなものではない」',
};

/// 決着のせりふ（決着の種類 → 型 → せりふ）
const Map<String, Map<String, String>> storyEndLines = {
  'bought': {
    'zaibatsu': '「百年の看板を、あなたに預けるとはね……大事にしなさい」',
    'fund': '「売り手に回るのは初めてだ。いい値段だった、とだけ言っておく」',
    'genius': '「負けたよ。でも次に作る会社は、もっと強い」',
    'peer': '「……完敗だ。お前の下で働くのも、悪くないのかもな」',
    'state': '「本国には私から報告しておく。あなたの勝ちだと」',
    'asia': '「一族の歴史に、この負けも書き残そう」',
    'bigtech': '「まさか僕らが買われる側になるとはね。おめでとう」',
    'grit': '「わしの会社を頼んだぞ。社員は皆、ええ奴らじゃ」',
    'ex': '「やっぱり社長には敵わなかった。また一緒に働かせてください」',
    'avenger': '「二代続けて負けるとは……だが、まだ終わりではない」',
  },
  'boughtBy': {
    'zaibatsu': '「よく頑張ったわね。あとは私たちが引き継ぐわ」',
    'fund': '「いい買い物だった。安心しろ、高く売ってやる」',
    'genius': '「君の会社、僕のやり方で生まれ変わらせるよ」',
    'peer': '「これで決着だな。……長かったよ、お前との勝負は」',
    'state': '「この会社は、今日から国のものだ」',
    'asia': '「あなたの会社は、我々の大きな地図の一部になる」',
    'bigtech': '「統合はすぐ終わる。君の名前は残らないけどね」',
    'grit': '「最後に勝つのは、根性のある方じゃ」',
    'ex': '「社長、今度は僕が社長です」',
    'avenger': '「これで一族の恨みは晴れた」',
  },
  'peace': {
    'zaibatsu': '「あなたとは、張り合うより並んで歩く方が得みたい」',
    'fund': '「敵に回すより、仲良くしておく方が儲かる。計算の結果だ」',
    'genius': '「もう競争はいいや。君とは別の山を登ることにする」',
    'peer': '「いつの間にか、張り合うのが楽しみになってた。これからは友だちだ」',
    'state': '「国にも、信頼できる相手は必要だ」',
    'asia': '「長い付き合いになりそうだ。茶でも飲みに来てくれ」',
    'bigtech': '「戦うより手を振る方が安くつく。また会おう」',
    'grit': '「お主は筋が通っとる。もう喧嘩はやめじゃ」',
    'ex': '「社長、やっと胸を張って会えます」',
    'avenger': '「恨みは……もういい。一族にもそう伝える」',
  },
  'ally': {
    'zaibatsu': '「5年も組めば家族同然。これからも頼りにしているわ」',
    'fund': '「5年も持ち続けた株は初めてだ。君は例外だよ」',
    'genius': '「一人で勝つより、二人で勝つ方が面白かった」',
    'peer': '「同期で組んで正解だったな。これからも頼むぞ、相棒」',
    'state': '「我が国の友として、あなたの名を記録しておく」',
    'asia': '「我々が組めば、世界は狭い」',
    'bigtech': '「最高のパートナーだ。シリコンバレーでも自慢しておくよ」',
    'grit': '「お主と組んで、わしの会社も大きくなった。ありがとうよ」',
    'ex': '「社長と組めてよかった。昔に戻ったみたいです」',
    'avenger': '「一族の敵と組むことになるとはな。……悪くない」',
  },
};

/// 決着の種類の呼び名
const Map<String, String> storyEndName = {'bought': '買収した', 'boughtBy': '買収された', 'peace': '和解', 'ally': '手を組んだ'};

/// 和解に要る友好の月数・組んだに要る月数
const int peaceMonths = 36, allyMonths = 60;

/// 取締役会と宿敵の物語（試作のあとに足した仕組み。Game.extras で切れる）
extension GameStory on Game {
  // ===== 宿敵の物語 =====
  String _line(Map<String, String> m, Rival r) => m[r.kind] ?? m[r.type] ?? m['peer']!;

  /// 因縁を1つ記録する。kind: g 恨み（あなたが相手にしたこと）/ f 恩（助けた・組んだ）/ h 相手からされたこと / '' 記録だけ
  void tieRec(Company? c, String kind, String what) {
    if (!extras || c == null || c.rival == null) return;
    final r = c.rival!;
    if (r.st >= 2) return;
    if (kind == 'g') r.grudge++;
    if (kind == 'f') r.favor++;
    if (kind == 'h') r.hurt++;
    r.ties.add(M('{0}年：{1}', [year, what]));
    if (r.ties.length > 6) r.ties.removeAt(0);
  }

  GameEvent _scene(Company c, String title, String line, List<Object?> args, String note) => GameEvent(
      who: c,
      face: c.rival!.col,
      title: title,
      text: Cat([M(line, args), note], ja: '\n', en: '\n'),
      choices: [Choice(M('うなずく'), M('物語は次へ進む'), () => M('{0}との因縁を胸に刻みました', [Nm(c.rival!.pres)]))]);

  /// 毎月の物語の進み（出会い・張り合う・和解・組んだ）。乱数は使わない
  void storyMonthly(void Function(String, [String]) N) {
    if (!extras) return;
    final mine = <String>{for (final b in biz) b.ind};
    var met = false;
    for (final c in cos) {
      final r = c.rival;
      if (r == null || !c.alive || r.st >= 2) continue;
      if (c.parent == 'player') continue;
      // 出会い: 初めて同じ業種でぶつかった（先に何かでぶつかっていても出会いとする）
      if (r.st == 0) {
        final hit = c.biz.where((b) => mine.contains(b.ind)).firstOrNull;
        if ((hit != null || r.grudge + r.favor + r.hurt > 0) && !met) {
          met = true;
          r.st = 1;
          final note = hit != null
              ? M('「{0}」で{1}（{2}）とぶつかりました。ここから因縁が始まります', [I(hit.ind), Nm(c.name), D(RTYPE.ja[r.kind] ?? '')])
              : M('{0}（{1}）と顔を合わせました。ここから因縁が始まります', [Nm(c.name), D(RTYPE.ja[r.kind] ?? '')]);
          tieRec(c, '', hit != null ? M('「{0}」で出会った', [I(hit.ind)]) : M('初めて顔を合わせた'));
          events.add(_scene(c, M('宿敵との出会い'), _line(storyMeet, r), [Nm(r.from ?? '')], note));
        }
        continue;
      }
      // 張り合う: ぶつかった数が3つに届いたら一度だけ場面を出す
      if (!r.vexed && r.grudge + r.hurt >= 3) {
        r.vexed = true;
        events.add(_scene(c, M('因縁が深まる'), _line(storyClash, r), const [],
            M('{0}との因縁が深まりました（恨み{1}・恩{2}・されたこと{3}）', [Nm(c.name), r.grudge, r.favor, r.hurt])));
      }
      // 組んでいる（提携・取引）が続けば「組んだ」、組まずに友好が続けば「和解」
      final allied = (r.allied && c.rel >= -20) || dealWith(c).isNotEmpty;
      if (r.allied && c.rel < -20) r.allied = false;
      if (allied) {
        if (r.allySince < 0) r.allySince = turn;
        r.friendSince = -1;
        if (turn - r.allySince >= allyMonths) {
          storyEnd(c, 'ally');
          continue;
        }
      } else {
        r.allySince = -1;
        if (c.rel > 25) {
          if (r.friendSince < 0) r.friendSince = turn;
          if (turn - r.friendSince >= peaceMonths) storyEnd(c, 'peace');
        } else {
          r.friendSince = -1;
        }
      }
    }
  }

  /// 決着をつける（場面・社史に残す）。決着した宿敵の物語は締まるが、会社は残る
  void storyEnd(Company c, String end) {
    if (!extras || c.rival == null) return;
    final r = c.rival!;
    if (r.st >= 2) return;
    r.st = 2;
    r.end = end;
    r.endY = year;
    final what = D(storyEndName[end]!);
    chron('rival', M('{0}（{1}）との因縁に決着がついた：{2}', [Nm(r.pres), Nm(c.name), what]));
    final note = switch (end) {
      'bought' => M('{0}を手に入れ、{1}との因縁に決着がつきました', [Nm(c.name), Nm(r.pres)]),
      'boughtBy' => M('{0}に会社を買われ、{1}との因縁に決着がつきました', [Nm(c.name), Nm(r.pres)]),
      'peace' => M('{0}年のあいだ友好が続き、{1}と和解しました', [peaceMonths ~/ 12, Nm(r.pres)]),
      _ => M('{0}年のあいだ組み続け、{1}とは盟友になりました', [allyMonths ~/ 12, Nm(r.pres)]),
    };
    events.add(_scene(c, M('決着：{0}', [what]), _line(storyEndLines[end]!, r), const [], note));
  }

  /// 物語の段の呼び名（画面用）
  String storyStage(Rival r) => r.st == 0
      ? M('出会う前')
      : r.st == 1
          ? M('張り合う')
          : M('決着（{0}）', [D(storyEndName[r.end] ?? '和解')]);

  // ===== 取締役会（毎年1月） =====
  /// 味方の株（あなた・相棒・味方の会社）
  double friendlyStake() => sh.own + sh.pt + sh.ally;

  /// 動議に回りそうな株（宿敵・投資家・市場の半分）
  double hostileStake() => sh.rivSum + sh.vc + sh.float * .5;

  /// 強気で押し切ったときに解任される確率
  double oustChance() {
    final f = friendlyStake(), h = hostileStake();
    return clampD(h / math.max(f + h, 1e-9), .1, .85);
  }

  /// 毎月の終わりに呼ぶ。1月なら取締役会を開き、それから今月の数字を積む
  void boardMonthly() {
    if (!extras) return;
    if (q == 1 && (yAcc['n'] ?? 0) >= 11) holdBoard();
    yAcc['rev'] = (yAcc['rev'] ?? 0) + rev;
    yAcc['pre'] = (yAcc['pre'] ?? 0) + pre;
    yAcc['n'] = (yAcc['n'] ?? 0) + 1;
  }

  static String _chg(double now, double before) {
    if (before <= 0) return M(now > 0 ? '黒字に転換' : '前年も赤字');
    final x = (now / before - 1) * 100;
    return '${x >= 0 ? '+' : ''}${jsNum(jsRound(x))}%';
  }

  /// 利益が前年の7割未満（赤字なら前年より悪い）
  static bool weakYear(Map<String, double> cur, Map<String, double> prev) =>
      (prev['pre']! > 0 && cur['pre']! < prev['pre']! * .7) || (cur['pre']! < 0 && cur['pre']! < prev['pre']!);

  void holdBoard() {
    final n = yAcc['n']!;
    final cur = <String, double>{'rev': yAcc['rev']! * 12 / n, 'pre': yAcc['pre']! * 12 / n, 'cap': cap, 'rank': rank.toDouble()};
    final prev = yPrev;
    yPrev = cur;
    yAcc = {};
    if (biz.isEmpty && !everBiz) return;
    final y0 = year - 1;
    final review = prev == null
        ? M('{0}年の振り返り。売上 {1}・利益 {2}・時価総額 {3}・世界{4}位。初めての取締役会です', [y0, Y(cur['rev']!), Y(cur['pre']!), Y(cur['cap']!), rank])
        : M('{0}年の振り返り。売上 {1}（前年比 {2}）・利益 {3}（{4}）・時価総額 {5}（{6}）・世界{7}位（前年 {8}位）', [
            y0,
            Y(cur['rev']!),
            _chg(cur['rev']!, prev['rev']!),
            Y(cur['pre']!),
            _chg(cur['pre']!, prev['pre']!),
            Y(cur['cap']!),
            _chg(cur['cap']!, prev['cap']!),
            rank,
            prev['rank']!.round(),
          ]);
    final title = M('取締役会（{0}年1月）', [year]);
    // 去年の改革の約束
    final v = vow;
    if (v != null && turn >= v['due']!) {
      vow = null;
      if (friendlyStake() >= 50) {
        events.add(_note(title, [review, M('改革の約束の期限です。今は味方の株が過半数あるので、解任の話は立ち消えになりました')]));
      } else if (cur['pre']! >= v['target']!) {
        events.add(_note(title, [review, M('改革の約束どおり、利益が戻りました。取締役会は「よくやってくれた」と認めています')]));
      } else {
        events.add(_note(title, [review, M('改革の約束を果たせませんでした。取締役会は約束どおり社長の解任を決めました'), oust()]));
      }
      return;
    }
    final good = prev != null && cur['pre']! > 0 && (prev['pre']! <= 0 || cur['pre']! >= prev['pre']! * 1.1);
    final bad = prev != null && weakYear(cur, prev);
    final word = good
        ? M('良い')
        : bad
            ? M('悪い')
            : M('ふつう@@board');
    final say = good
        ? M('「この調子で頼みます」')
        : bad
            ? M('「このままでは困ります」')
            : M('「来年はもう一段の成長を」');
    final eval = M('取締役の評価：{0}　{1}', [word, say]);
    final f = friendlyStake();
    if (!bad || f >= 50) {
      events.add(_note(title, [review, eval, if (bad) M('業績は悪いものの、味方の株が{0}あるので、解任の声は上がりませんでした', [pct(f)])]));
      return;
    }
    // 解任動議
    final h = hostileStake();
    final target = math.max(prev['pre']! * .9, 0.0);
    final cost = math.max(0.0, cash * .2);
    final p = oustChance();
    events.add(GameEvent(
        title: M('取締役会：解任動議'),
        text: Cat([
          review,
          eval,
          M('業績の悪化を受けて、社長の解任動議が出ました。味方の株は{0}、動議に回りそうな株は{1}です', [pct(f), pct(h)]),
        ], ja: '\n', en: '\n'),
        choices: [
          Choice(M('改革を約束する'), M('1年後の取締役会までに、年の利益を{0}まで戻せなければ解任される', [Y(target)]), () {
            vow = {'due': (turn + 12).toDouble(), 'target': target, 'y': (year + 1).toDouble()};
            return M('改革を約束しました。1年後に利益が戻っていなければ、社長の座を追われます');
          }),
          Choice(M('株主に配当を約束して乗り切る'), M('{0}を配当として払う', [Y(cost)]), () {
            cash -= cost;
            return M('{0}の配当を約束し、動議は取り下げられました', [Y(cost)]);
          }),
          Choice(M('強気で押し切る'), M('お金はかからない。{0}%の確率で解任され、社長が替わる', [jsNum(jsRound(p * 100))]), () {
            if (rnd() < p) return Cat([M('押し切れず、動議は可決されました'), oust()], ja: '。', en: '. ');
            return M('強気で押し切り、動議は否決されました');
          }),
        ]));
  }

  GameEvent _note(String title, List<Object?> parts) =>
      GameEvent(title: title, text: Cat(parts, ja: '\n', en: '\n'), choices: [Choice(M('承知した'), M('取締役会を閉じる'), () => M('取締役会が終わりました'))]);

  /// 取締役会で社長を解任する。後継ぎ、なければ一番の部下、子、それもいなければ外から呼ぶ。ゲームは続く
  String oust() {
    Person? s;
    if (succ != null) s = staffById(succ) ?? kids.where((k) => k.id == succ && k.age >= 20).firstOrNull;
    if (s == null) {
      final cand = staff.where((p) => p.age < 65).toList()..ssort((a, b) => Game.totOf(b) - Game.totOf(a));
      s = cand.firstOrNull ?? kids.where((k) => k.age >= 20).firstOrNull ?? staff.firstOrNull;
    }
    final outside = s == null;
    s ??= mkPerson(.8);
    final old = pres.name;
    takeOver(s);
    vow = null;
    calcAll();
    chron('board', M(outside ? '取締役会で{0}が解任され、外から来た{1}が社長になった' : '取締役会で{0}が解任され、{1}が社長になった', [Nm(old), Nm(s.name)]));
    return M(outside ? '{0}は解任され、取締役会が外から呼んだ{1}が社長になりました' : '{0}は解任され、{1}が社長になりました', [Nm(old), Nm(s.name)]);
  }
}
