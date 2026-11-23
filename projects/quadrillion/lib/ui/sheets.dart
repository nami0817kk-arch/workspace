import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'widgets.dart';

/// 小窓（試作の openXxx / showReport / nextEvent / showHelp）

Widget _col(List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: c);
Widget _note(String s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(s));
Widget _cancel(GameController ctl, [String label = 'やめる']) =>
    Padding(padding: const EdgeInsets.only(top: 10), child: Align(alignment: Alignment.centerLeft, child: Btn(label, ctl.closeSheet)));

void openIntro(GameController ctl) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2('${s.year}年 春', top: true),
        Say(
            face: Face(s.pres.name, col: '#f2c14e'),
            who: '${s.pres.name}（22歳）',
            text: '大学を出たばかり。手元には${yen(s.cash)}。会社の名前だけは登記した。最初の事業を決める前に、一緒にやる相棒を探そうか。'),
        _note('毎月「手」の数だけ動けます。街の「社長の行動」から、相棒探し・日銭稼ぎ・腕磨き・人脈作り・事業の種探しができます。最初の事業を始めるのは手を使いません。'),
        const SizedBox(height: 4),
        ChoiceBtn('相棒を探しに行く', () => openSeek(ctl), subs: const ['行き先で出会う人の型が変わる']),
        ChoiceBtn('先に最初の事業を決める', () => openStart(ctl), subs: const ['手を使わない']),
        ChoiceBtn('街を見てから考える', ctl.closeSheet),
      ]));
}

void openSeek(GameController ctl) {
  final s = ctl.game!;
  if (!s.canAP(1)) {
    ctl.toast('今月の手が残っていません');
    return;
  }
  if (s.partners().length >= 2) {
    ctl.toast('相棒は2人までです');
    return;
  }
  ctl.showSheet((_) => _col([
        const H2('相棒を探す', top: true),
        _note('手を1つ使います。相棒には給料ではなく株を渡して口説きます。今の相棒 ${s.partners().length}/2人'),
        for (final pl in PLACES)
          ChoiceBtn(s.placeName(pl.id), () {
            final m = s.presAct('seek', pl.id);
            if (m != null) {
              ctl.toast(m);
              return;
            }
            ctl.save();
            openMeet(ctl);
          }, subs: [pl.s]),
        _cancel(ctl),
      ]));
}

void openMeet(GameController ctl) {
  final s = ctl.game!;
  final p = s.meet;
  if (p == null) {
    ctl.closeSheet();
    return;
  }
  ctl.showSheet((_) => _col([
        H2('${s.placeName(p.place ?? 'net')}で出会った', top: true),
        Say(face: Face(p.name), who: '${p.name}（${p.age}歳）', text: '「${s.meetLine(p)}」'),
        Grid2([for (final k in abKeys) Kv(ABN[k]!, s.showAb(p, k))]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(TextSpan(children: [
            p.traitKnown
                ? TextSpan(text: '特性 ${STRAITS.firstWhere((x) => x.id == p.trait).n}', style: ts(size: 12.5))
                : TextSpan(text: '評判：${traitHints[p.trait]}', style: ts(size: 12.5, color: Pal.mute)),
            if (p.money != null && p.money! > 0) TextSpan(text: '　出資 ${yen(p.money!)} 付き', style: ts(size: 12.5, color: Pal.goldtx)),
          ])),
        ),
        for (final x in [10, 20, 30])
          ChoiceBtn('株を$x%渡して誘う', () => ctl.act(() => s.recruitPartner(p, x)),
              enabled: !(s.sh.own - x < 40),
              subs: ['様子：${chanceWord(s.partnerChance(p, x))}　あなたの持ち株 ${pct(s.sh.own)} → ${pct(s.sh.own - x)}']),
        ChoiceBtn('今回は見送る', () {
          s.meet = null;
          ctl.save();
          ctl.closeSheet();
        }, subs: const ['この人とはもう会えない']),
      ]));
}

void openTrain(GameController ctl) {
  final s = ctl.game!;
  if (!s.canAP(1)) {
    ctl.toast('今月の手が残っていません');
    return;
  }
  ctl.showSheet((_) => _col([
        const H2('腕を磨く', top: true),
        _note('手を1つ使い、社長の能力を1つ ${s.trainGain()} 伸ばします。若いほどよく伸びます。'),
        for (final k in abKeys) ChoiceBtn('${ABN[k]}（今 ${s.pres.ab[k]}）', () => ctl.act(() => s.presAct('train', k)), subs: [trainDesc[k]!]),
        _cancel(ctl),
      ]));
}

String _indNote(Game s, Industry i) {
  final y = s.yr();
  final age = y - i.b;
  final stage = age < 3
      ? '・生まれたばかり（今入ると先行者）'
      : age < 10
          ? '・生まれて10年以内'
          : i.f != 0 && y > i.f
              ? '・沈み中'
              : '';
  final sens = i.sens > 1
      ? '・不況に弱い'
      : i.sens < .35
          ? '・不況に強い'
          : '';
  return '${CATN[i.cat]}・市場 ${yen(s.mkt(i) / 3)}・利益率${jsNum(jsRound(i.mg * 100))}%・効く能力 ${ABN[i.key]}$stage$sens';
}

void openStart(GameController ctl) {
  final s = ctl.game!;
  final list = s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList()..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)));
  ctl.showSheet((_) => _col([
        H2('${s.year}年 創業', top: true),
        Say(face: Face(s.pres.name, col: '#f2c14e'), who: '${s.pres.name}（${s.pres.age}歳）', text: '手元にあるのは${yen(s.cash)}。まずは何で稼ぐか決めよう。'),
        const SizedBox(height: 6),
        for (final i in list)
          ChoiceBtn('${i.name}（元手 ${yen(s.capexOf(i))}）', () {
            if (s.modelsFor(i.id).length > 1) {
              openModel(ctl, i.id);
              return;
            }
            final m = s.startBiz(i.id);
            ctl.save();
            ctl.toast(m);
          }, subs: [_indNote(s, i)]),
        _cancel(ctl),
      ]));
}

void openModel(GameController ctl, String id, [Biz? b]) {
  final s = ctl.game!;
  final ind = indm[id]!;
  final ms = s.modelsFor(id);
  ctl.showSheet((_) => _col([
        H2(b != null ? '「${ind.name}」の稼ぎ方を変える' : '「${ind.name}」をどう稼ぐか', top: true),
        _note(b != null ? '切り替えると、混乱で力が1割5分落ちます。手を1つ使います。' : '元手 ${yen(s.capexOf(ind))}。稼ぎ方は、あとから手を使って変えられます。'),
        for (final m in ms)
          ChoiceBtn('${MODELN[m]}${b != null && b.model == m ? '（今）' : ''}', () => ctl.act(() => b != null ? s.changeModel(b, m) : s.startBiz(id, m)),
              enabled: !(b != null && b.model == m), subs: [MODELD[m]!]),
        _cancel(ctl),
      ]));
}

void openPivot(GameController ctl, Biz b) {
  final s = ctl.game!;
  final from = indm[b.ind]!;
  final list = s.pivotTargets(b)..ssort((x, y) => s.capexOf(x).compareTo(s.capexOf(y)));
  ctl.showSheet((_) => _col([
        H2('「${from.name}」の業態を変える', top: true),
        _note('同じ分類の業種に乗り換えます。今の事業の力の半分を引き継ぎ、新しい業種の元手がかかります。手を1つ使います。'),
        for (final i in list)
          ChoiceBtn('${i.name}（元手 ${yen(s.capexOf(i))}）', () => ctl.act(() => s.pivot(b, i.id)), enabled: s.cash >= s.capexOf(i), subs: [
            '利益率${jsNum(jsRound(i.mg * 100))}%・${s.yr() - i.b < 10 ? '生まれたばかり' : i.f != 0 && s.yr() > i.f ? '沈み中' : '市場 ${yen(s.mkt(i) / 3)}'}'
          ]),
        _cancel(ctl),
      ]));
}

void openDirty(GameController ctl, Company c) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2('${c.name}への裏の手', top: true),
        _note('手を1つ使います。使うほど、ばれやすくなります。'),
        for (final k in DIRTYN.keys)
          ChoiceBtn('${DIRTYN[k]}（${yen(s.dirtyCost(k))}・ばれる見込み ${jsNum(jsRound(s.dirtyRisk(k, c) * 100))}%）', () => ctl.act(() => s.doDirty(k, c)),
              enabled: !(s.cash < s.dirtyCost(k) || s.ap < 1),
              subs: ['${DIRTYD[k]}${k == 'cartel' && s.cartelBiz(c) != null ? '。対象は「${indm[s.cartelBiz(c)!.ind]!.name}」' : ''}']),
        _cancel(ctl),
      ]));
}

void openSell(GameController ctl) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        const H2('会社を丸ごと売る', top: true),
        _note(
            'あなたの持ち株 ${pct(s.sh.own)} の分が入ります。半分は財産に、半分は新しい会社の元手になります。「同じ業種に入らない約束」を付けると高く売れます。相棒は、忠誠が高ければついてきます。前の会社はライバルとして残ります。'),
        for (final c in s.buyers())
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: ts(bold: true)),
              Muted('時価総額 ${yen(c.cap)}'),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Btn('約束を付けて売る ${yen(s.salePrice(true))}', () => ctl.act(() => s.sellCompany(c, true)), small: true),
                Btn('約束なしで売る ${yen(s.salePrice(false))}', () => ctl.act(() => s.sellCompany(c, false)), small: true),
              ]),
            ]),
          ),
        _cancel(ctl),
      ]));
}

void openDeal(GameController ctl, Company c) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2('${c.name}と組む', top: true),
        _note('手を1つ使います。関係が悪すぎる相手とは組めません。'),
        for (final t in const ['sales', 'codev', 'outsrc'])
          ChoiceBtn(DEALN[t]!, () => ctl.act(() => s.makeDeal(c, t)),
              enabled: s.dealOk(c, t).isEmpty, subs: [s.dealOk(c, t).isNotEmpty ? s.dealOk(c, t) : DEALD[t]!]),
        _cancel(ctl),
      ]));
}

void openShape(GameController ctl, Biz b) {
  final s = ctl.game!;
  final ind = indm[b.ind]!;
  final p = s.staffById(b.mgr);
  ctl.showSheet((_) => _col([
        H2('「${ind.name}」の形を変える', top: true),
        _note(p != null ? '責任者は${p.name}です。手を1つ使います。' : '先に責任者を置いてください。その人が社長になります。'),
        ChoiceBtn('分社する', () => ctl.act(() => s.spinOff(b)), enabled: p != null, subs: const ['子会社にして、責任者を社長にする。株は100%持ったまま。社長は自分の判断で動く']),
        ChoiceBtn('渡して独立させる', () => ctl.act(() => s.releaseBiz(b)), enabled: p != null, subs: const ['責任者に事業ごと渡す。株を10%だけ持つ。相手との関係がとても良くなる']),
        _cancel(ctl),
      ]));
}

void openEnter(GameController ctl, Biz b) {
  final s = ctl.game!;
  final ind = indm[b.ind]!;
  final y = s.yr();
  final hw = cw(s.home, y);
  final list = CTRY.where((x) => !s.ctryOf(b).contains(x.c)).toList()..ssort((p, q) => cw(q.c, y).compareTo(cw(p.c, y)));
  ctl.showSheet((_) => _col([
        H2('「${ind.name}」を海外に出す', top: true),
        _note('手を1つ使います。市場の大きさは${cm[s.home]!.n}を1としたときの比べ。単独は6か月、組むは3か月かかり、組むとその国の利益は半分になります。買うとすぐ始められます。'),
        for (final x in list)
          Builder(builder: (_) {
            final ms = s.entryModes(b, x.c);
            return Panel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(x.n, style: ts(bold: true))),
                  Muted('市場 ×${(cw(x.c, y) / hw).toStringAsFixed(2)}${cw(x.c, y + 10) > cw(x.c, y) * 1.4 ? '　これから伸びる' : ''}'),
                ]),
                const SizedBox(height: 4),
                if (ms.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final m in ms)
                      Btn('${ENTRYN[m]} ${yen(s.entryCost(b, x.c, m))}', () => ctl.act(() => s.enterCountry(b, x.c, m)),
                          small: true, enabled: !(s.cash < s.entryCost(b, x.c, m) || s.ap < 1)),
                  ])
                else
                  const Muted('今は入れません'),
                if (ms.length == 1 && ms[0] == 'jv') const Muted('規制で、地元の会社と組まないと入れません', size: 12),
              ]),
            );
          }),
        _cancel(ctl, '閉じる'),
      ]));
}

void showHelp(GameController ctl) {
  const parts = [
    (null, '1期は1か月。毎月、使える「手」（金色の四角）の数だけ行動できます。手は事業が増えると増えます。'),
    ('社長の行動', '社長は22歳の大卒から始まります。「街」の「社長の行動」で、相棒を探す・日銭を稼ぐ・腕を磨く・人脈を作る・事業の種を探す、ができます。相棒には株を渡して口説きます。相棒が責任者の事業は強くなりますが、野心が強いと独立を言い出すこともあります。'),
    ('稼ぐ', '「事業」で業種を始め、打ち手で伸ばします。「商品を作る」は3〜6か月後に出て、大当たりも不発もあります。「店・工場を増やす」は1〜2か月後に確実に伸びますが、維持費がかかります。店や工場は「現場の人」がいないと動きません。仕掛かり中のものは、取り下げると半分戻ります。値付けを「安く」にすると客は増えますが利益は薄くなります。'),
    ('任せる', '社長が直接見られる事業は2つまで。それより多いと放置された事業が弱ります。「人」で採用し、責任者に置きましょう。責任者は利益の一部を自分で事業に回します。能力は働かせるまで幅でしか分かりません。'),
    ('裏の手', '「街」の宿敵の欄から、引き抜き・産業スパイ・ロビー活動・粉飾決算・談合が使えます。効き目は大きいかわりに、ばれると重い罰があります。使うほどばれやすくなります。宿敵も同じ手を使ってきます。もみ消した不祥事は、数年後にもっと大きくなって戻ってくることがあります。'),
    ('売り抜け', '「株」の画面で、持ち株を売る、非上場に戻す、会社を丸ごと売る、ができます。売ったお金はあなたの財産になり、半分を元手にもう一度起業します。勝ち負けは、今の会社の時価総額とあなたの財産の合計で測ります。倒した宿敵は、一族や元の社員が新しい会社を作って戻ってきます。'),
    ('組む・会社の形', '「株」の画面で、他社と販売の提携・共同開発・製造を任せる、で組めます。相手から話が来ることもあります。裏切って客を奪うこともできますが、評判が落ちます。事業ごとに業界団体にも入れます。会社が大きくなったら、持株会社、分社、子会社の上場、事業を部下に渡して独立させる、会社を2つに割る、ができます。分社した子会社の社長は自分の判断で動きます。'),
    ('お金の縛り', '投資家からお金を集めると「3年以内に上場」が条件になります。社債は5年後に全額返します。取引先の出資を受けると、その取引先と同じ業種に入ったとき取引を切られます。資金が尽きかけると、宿敵が出資を持ちかけてきます。'),
    ('社風', '「人」で社風を選べます。実力主義・家族的・体育会系・自由放任・堅実。切り替えには2年かかり、その間は人が辞めやすくなります。買収した会社の社風が違うと、合併のときにぶつかります。'),
    ('海外', '事業ごとに「海外に出る」から、24か国に出られます。単独で出る（6か月）、地元の会社と組む（3か月・その国の利益は半分）、地元の会社を買う（すぐ・高い）の3つ。国の市場は年とともに変わり、中国は2000年代、インドは2030年代に大きくなります。中国のネットと金融は、組まないと入れません。'),
    ('稼ぎ方', '業種によって、直営・フランチャイズ・下請け・場をつくる、から稼ぎ方を選べます。フランチャイズは速く広がるが取り分が薄い。下請けは安定するが薄く、切られることがある。場をつくるは小さいうちは赤字で、大きくなると一人勝ちしやすい。'),
    ('経営会議', '1月・4月・7月・10月は経営会議です。責任者を任せた部下や相棒が、提案を持ってきます。承認も却下も手を使いません。却下が続くと不満がたまります。二人の意見がぶつかったら、どちらかを選びます。「全部まかせる」にすると、その人の提案は自動で通ります。'),
    ('組み合わせる', '2つの業種を同時に持つと、隠れたシナジーが見つかることがあります。見つけると両方の力が2割上がります。「図鑑」で確かめられます。'),
    ('戦う', '宿敵は値下げ合戦を仕掛け、あなたの株を買い集め、部下を引き抜きます。上場すると大金が入りますが、株を買われるようになります。50%を超えて握られると社長を追われます。'),
    ('飲み込む', '「株」で他社の株を買い、50%を超えると子会社、66.7%で合併できます。'),
    ('株式交換', '上場すると、自分より小さい会社を、現金の代わりに自社の株を渡して丸ごと買えます。大きくなる近道ですが、あなたの持ち株が薄まり、乗っ取られやすくなります。'),
    ('時代', 'バブル、ネット、スマホ、AI。時代の波は史実に近い順で来ますが、時期と深さは毎回ずれます。沈む業種からは早めに手を引きましょう。社長は年をとるので、後継ぎも決めておきます。'),
  ];
  ctl.showSheet((_) => _col([
        const H2('遊び方', top: true),
        for (final p in parts) ...[
          if (p.$1 != null) H3(p.$1!),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(p.$2, style: ts(size: 14, height: 1.55))),
        ],
        Align(alignment: Alignment.centerLeft, child: Btn('閉じる', ctl.closeSheet, primary: true)),
      ]));
}

// ===== 月を進める =====
class ReportBase {
  final double cap, cash;
  final String? label;
  ReportBase(this.cap, this.cash, [this.label]);
}

void doNext(GameController ctl) {
  final s = ctl.game!;
  final before = ReportBase(s.cap, s.cash);
  final news = s.nextQuarter();
  ctl.save();
  if (news.isEmpty && s.q % 3 != 1 && s.events.isEmpty && s.over == null && s.won == null) {
    ctl.render();
    return;
  }
  showReport(ctl, news, before);
}

void doYear(GameController ctl, [int n = 12]) {
  final s = ctl.game!;
  final before = ReportBase(s.cap, s.cash, '${s.year}年 ${s.q}月から');
  final all = <LogEntry>[];
  for (var i = 0; i < n; i++) {
    all.addAll(s.nextQuarter());
    if (s.events.isNotEmpty || s.over != null || s.won != null) break;
  }
  ctl.save();
  showReport(ctl, all, before);
}

void showReport(GameController ctl, List<LogEntry> news, ReportBase before) {
  final s = ctl.game!;
  final d = s.cap - before.cap;
  final lines = (s.biz.toList()..ssort((a, b) => b.rev.compareTo(a.rev))).take(4).map((b) {
    final p = s.staffById(b.mgr);
    final ind = indm[b.ind]!;
    final line = b.war > 0
        ? '${ind.name}は値下げ合戦の最中です。シェア${pct(b.share * 100)}、利益は${yen(b.profit)}に削られています。'
        : b.share > .5
            ? '${ind.name}はシェア${pct(b.share * 100)}。市場の半分以上を押さえました。'
            : '${ind.name}の売上は${yen(b.rev)}、シェア${pct(b.share * 100)}です。';
    return Say(
        face: Face(p != null ? p.name : s.pres.name, col: p != null ? null : '#f2c14e'),
        who: p != null ? '${p.name}（責任者）' : '${s.pres.name}（社長が直接）',
        text: line);
  }).toList();
  final head = '${s.year}年 ${s.q}月 ${s.q % 3 == 1 ? 'の経営会議' : 'の報告'}';
  final pre = s.pre;
  final cap = s.cap;
  ctl.showSheet((_) => _col([
        H2(head, top: true),
        if (before.label != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Muted('${before.label}まとめて進めました')),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(TextSpan(style: ts(), children: [
            const TextSpan(text: '時価総額 '),
            TextSpan(text: yen(cap), style: ts(color: Pal.goldtx, bold: true)),
            const TextSpan(text: ' '),
            TextSpan(text: '${d >= 0 ? '＋' : ''}${yen(d)}', style: ts(color: d >= 0 ? Pal.up : Pal.down)),
            const TextSpan(text: '　今月の利益 '),
            TextSpan(text: yen(pre), style: ts(color: pre >= 0 ? Pal.up : Pal.down, bold: true)),
          ])),
        ),
        ...lines,
        if (news.isNotEmpty) ...[const H3('ニュース'), for (final n in news) NewsLine(n.m, n.t)],
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: Btn('続ける', () {
              ctl.hideSheet();
              nextEvent(ctl);
            }, primary: true)),
      ]));
}

void nextEvent(GameController ctl) {
  final s = ctl.game!;
  if (s.over != null) {
    ctl.closeSheet();
    return;
  }
  if (s.events.isEmpty) {
    ctl.save();
    ctl.closeSheet();
    return;
  }
  final e = s.events.removeAt(0);
  Widget body;
  if (e.who != null) {
    body = Say(face: Face(e.who!.presName, col: e.face), who: '${e.who!.presName}・${e.who!.name}', text: e.text);
  } else if (e.person != null) {
    body = Say(face: Face(e.person!.name), who: '${e.person!.name}${e.person!.partner ? '（相棒）' : ''}', text: e.text);
  } else {
    body = Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(e.text, style: ts()));
  }
  ctl.showSheet((_) => _col([
        H2(e.title, top: true),
        body,
        const SizedBox(height: 8),
        for (final c in e.choices)
          ChoiceBtn(c.l, () {
            final m = c.f();
            ctl.save();
            ctl.showSheet((_) => ToastBody(msg: m, onOk: () => nextEvent(ctl)));
          }, subs: [c.s]),
      ]));
}
