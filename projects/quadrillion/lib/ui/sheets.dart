import 'package:flutter/material.dart';

import '../game/game.dart';
import '../version.dart';
import 'controller.dart';
import 'guide.dart';
import 'widgets.dart';

/// 小窓（試作の openXxx / showReport / nextEvent / showHelp）

Widget _col(List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: c);
Widget _note(String s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(s));
Widget _cancel(GameController ctl, [String label = 'やめる']) =>
    Padding(padding: const EdgeInsets.only(top: 10), child: Align(alignment: Alignment.centerLeft, child: Btn(tr(label), ctl.closeSheet)));

/// 取り返しのつかない操作の前に「本当によいか」を1回聞く小窓。[onYes] は「する」を押したときだけ動く
void confirmThen(GameController ctl, {required String title, required String text, required String yes, required VoidCallback onYes}) {
  ctl.showSheet((_) => _col([
        H2(title, top: true),
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: ts(height: 1.5))),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Muted(tr('この操作は取り消せません。本当によいですか？'))),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn(tr('やめる'), ctl.closeSheet),
          DangerBtn(yes, onYes),
        ]),
      ]));
}

/// 確認してから手を打つ（売る・解雇など）
void actConfirmed(GameController ctl, String title, String text, String yes, String? Function() fn) =>
    confirmThen(ctl, title: title, text: text, yes: yes, onYes: () => ctl.act(fn));

/// 確認してから、はじめの画面に戻る（セーブは消える）
void confirmRestart(GameController ctl) =>
    confirmThen(ctl, title: tr('はじめから'), text: tr('今の会社の続きは消え、はじめの画面に戻ります。'), yes: tr('はじめからにする'), onYes: ctl.backToSetup);

void openIntro(GameController ctl) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2(tr('{0}年 春', [s.year]), top: true),
        Say(
            face: Face(s.pres.name, col: '#f2c14e'),
            who: tr('{0}（{1}歳）', [nmL(s.pres.name), 22]),
            text: tr('大学を出たばかり。手元には{0}。会社の名前だけは登記した。最初の事業を決める前に、一緒にやる相棒を探そうか。', [yen(s.cash)])),
        _note(tr('毎月「手」の数だけ動けます。街の「社長の行動」から、相棒探し・日銭稼ぎ・腕磨き・人脈作り・事業の種探しができます。最初の事業を始めるのは手を使いません。')),
        const SizedBox(height: 4),
        ChoiceBtn(tr('相棒を探しに行く'), () => openSeek(ctl), subs: [tr('行き先で出会う人の型が変わる')]),
        ChoiceBtn(tr('先に最初の事業を決める'), () => openStart(ctl), subs: [tr('手を使わない')]),
        ChoiceBtn(tr('街を見てから考える'), ctl.closeSheet),
      ]));
}

void openSeek(GameController ctl) {
  final s = ctl.game!;
  if (!s.canAP(1)) {
    ctl.toast(M('今月の手が残っていません'));
    return;
  }
  if (s.partners().length >= 2) {
    ctl.toast(M('相棒は2人までです'));
    return;
  }
  ctl.showSheet((_) => _col([
        H2(tr('相棒を探す'), top: true),
        _note(tr('手を1つ使います。相棒には給料ではなく株を渡して口説きます。今の相棒 {0}/2人', [s.partners().length])),
        for (final pl in PLACES)
          ChoiceBtn(tx(s.placeName(pl.id)), () {
            final m = s.presAct('seek', pl.id);
            if (m != null) {
              ctl.toast(m);
              return;
            }
            markGuide(s, 'partner');
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
        H2(tr('{0}で出会った', [s.placeName(p.place ?? 'net')]), top: true),
        Say(face: Face(p.name), who: tr('{0}（{1}歳）', [nmL(p.name), p.age]), text: tr('「{0}」', [s.meetLine(p)])),
        Grid2([for (final k in abKeys) Kv(ABN[k]!, s.showAb(p, k))]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(TextSpan(children: [
            p.traitKnown
                ? TextSpan(text: tr('特性 {0}', [STRAITS.firstWhere((x) => x.id == p.trait).n]), style: ts(size: 12.5))
                : TextSpan(text: tr('評判：{0}', [traitHints[p.trait]]), style: ts(size: 12.5, color: Pal.mute)),
            if (p.money != null && p.money! > 0) TextSpan(text: tr('　出資 {0} 付き', [yen(p.money!)]), style: ts(size: 12.5, color: Pal.goldtx)),
          ])),
        ),
        for (final x in [10, 20, 30])
          ChoiceBtn(tr('株を{0}%渡して誘う', [x]), () => ctl.act(() => s.recruitPartner(p, x)),
              enabled: !(s.sh.own - x < 40),
              subs: [tr('様子：{0}　あなたの持ち株 {1} → {2}', [chanceWord(s.partnerChance(p, x)), pct(s.sh.own), pct(s.sh.own - x)])]),
        ChoiceBtn(tr('今回は見送る'), () {
          s.meet = null;
          ctl.save();
          ctl.closeSheet();
        }, subs: [tr('この人とはもう会えない')]),
      ]));
}

void openTrain(GameController ctl) {
  final s = ctl.game!;
  if (!s.canAP(1)) {
    ctl.toast(M('今月の手が残っていません'));
    return;
  }
  ctl.showSheet((_) => _col([
        H2(tr('腕を磨く'), top: true),
        _note(tr('手を1つ使い、社長の能力を1つ {0} 伸ばします。若いほどよく伸びます。', [s.trainGain()])),
        for (final k in abKeys) ChoiceBtn(tr('{0}（今 {1}）', [ABN[k], s.pres.ab[k]]), () => ctl.act(() => s.presAct('train', k)), subs: [trainDesc[k]!]),
        _cancel(ctl),
      ]));
}

String _indNote(Game s, Industry i) {
  final y = s.yr();
  final age = y - i.b;
  final stage = age < 3
      ? tr('・生まれたばかり（今入ると先行者）')
      : age < 10
          ? tr('・生まれて10年以内')
          : i.f != 0 && y > i.f
              ? tr('・沈み中')
              : '';
  final sens = i.sens > 1
      ? tr('・不況に弱い')
      : i.sens < .35
          ? tr('・不況に強い')
          : '';
  return '${tr('{0}・市場 {1}・利益率{2}%・効く能力 {3}', [CATN[i.cat], yen(s.mkt(i) / 3), jsNum(jsRound(i.mg * 100)), ABN[i.key]])}$stage$sens';
}

void openStart(GameController ctl) {
  final s = ctl.game!;
  final list = s.liveInds().where((i) => s.capexOf(i) <= s.cash).toList()..ssort((a, b) => s.capexOf(a).compareTo(s.capexOf(b)));
  ctl.showSheet((_) => _col([
        H2(tr('{0}年 創業', [s.year]), top: true),
        Say(face: Face(s.pres.name, col: '#f2c14e'), who: tr('{0}（{1}歳）', [nmL(s.pres.name), s.pres.age]), text: tr('手元にあるのは{0}。まずは何で稼ぐか決めよう。', [yen(s.cash)])),
        const SizedBox(height: 6),
        for (final i in list)
          ChoiceBtn(tr('{0}（元手 {1}）', [i.name, yen(s.capexOf(i))]), () {
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
        H2(b != null ? tr('「{0}」の稼ぎ方を変える', [ind.name]) : tr('「{0}」をどう稼ぐか', [ind.name]), top: true),
        _note(b != null ? tr('切り替えると、混乱で力が1割5分落ちます。手を1つ使います。') : tr('元手 {0}。稼ぎ方は、あとから手を使って変えられます。', [yen(s.capexOf(ind))])),
        for (final m in ms)
          ChoiceBtn('${MODELN[m]}${b != null && b.model == m ? tr('（今）') : ''}', () => ctl.act(() => b != null ? s.changeModel(b, m) : s.startBiz(id, m)),
              enabled: !(b != null && b.model == m), subs: [MODELD[m]!]),
        _cancel(ctl),
      ]));
}

void openPivot(GameController ctl, Biz b) {
  final s = ctl.game!;
  final from = indm[b.ind]!;
  final list = s.pivotTargets(b)..ssort((x, y) => s.capexOf(x).compareTo(s.capexOf(y)));
  ctl.showSheet((_) => _col([
        H2(tr('「{0}」の業態を変える', [from.name]), top: true),
        _note(tr('同じ分類の業種に乗り換えます。今の事業の力の半分を引き継ぎ、新しい業種の元手がかかります。手を1つ使います。')),
        for (final i in list)
          ChoiceBtn(tr('{0}（元手 {1}）', [i.name, yen(s.capexOf(i))]), () => ctl.act(() => s.pivot(b, i.id)), enabled: s.cash >= s.capexOf(i), subs: [
            tr('利益率{0}%・{1}', [jsNum(jsRound(i.mg * 100)), s.yr() - i.b < 10 ? tr('生まれたばかり') : i.f != 0 && s.yr() > i.f ? tr('沈み中') : tr('市場 {0}', [yen(s.mkt(i) / 3)])])
          ]),
        _cancel(ctl),
      ]));
}

void openDirty(GameController ctl, Company c) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2(tr('{0}への裏の手', [nmL(c.name)]), top: true),
        _note(tr('手を1つ使います。使うほど、ばれやすくなります。')),
        for (final k in DIRTYN.keys)
          ChoiceBtn(
              tr('{0}（{1}・ばれる見込み {2}%）', [DIRTYN[k], yen(s.dirtyCost(k)), jsNum(jsRound(s.dirtyRisk(k, c) * 100))]),
              () => k == 'cook'
                  ? actConfirmed(ctl, DIRTYN[k]!, tr(s.listed ? '決算の数字を飾ります。ばれる見込みは{0}%。ばれると上場廃止になり、信用は2年のあいだ地に落ちます。' : '決算の数字を飾ります。ばれる見込みは{0}%。ばれると信用は2年のあいだ地に落ちます。', [jsNum(jsRound(s.dirtyRisk(k, c) * 100))]),
                      tr('粉飾する'), () => s.doDirty(k, c))
                  : ctl.act(() => s.doDirty(k, c)),
              enabled: !(s.cash < s.dirtyCost(k) || s.ap < 1),
              subs: ['${DIRTYD[k]}${k == 'cartel' && s.cartelBiz(c) != null ? tr('。対象は「{0}」', [indm[s.cartelBiz(c)!.ind]!.name]) : ''}']),
        _cancel(ctl),
      ]));
}

void openSell(GameController ctl) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2(tr('会社を丸ごと売る'), top: true),
        _note(tr(
            'あなたの持ち株 {0} の分が入ります。半分は財産に、半分は新しい会社の元手になります。「同じ業種に入らない約束」を付けると高く売れます。相棒は、忠誠が高ければついてきます。前の会社はライバルとして残ります。', [pct(s.sh.own)])),
        for (final c in s.buyers())
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nmL(c.name), style: ts(bold: true)),
              Muted(tr('時価総額 {0}', [yen(c.cap)])),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final nc in const [true, false])
                  Btn(
                      tr(nc ? '約束を付けて売る {0}' : '約束なしで売る {0}', [yen(s.salePrice(nc))]),
                      () => actConfirmed(
                          ctl,
                          tr('会社を丸ごと売る'),
                          '${tr('{0}に、今の会社を{1}で売ります。事業と部下は手放し、新しい会社をゼロから始めます。', [nmL(c.name), yen(s.salePrice(nc))])}${nc ? tr('何年かは同じ業種に入れません。') : ''}',
                          tr('売る'),
                          () => s.sellCompany(c, nc)),
                      small: true),
              ]),
            ]),
          ),
        _cancel(ctl),
      ]));
}

void openDeal(GameController ctl, Company c) {
  final s = ctl.game!;
  ctl.showSheet((_) => _col([
        H2(tr('{0}と組む', [nmL(c.name)]), top: true),
        _note(tr('手を1つ使います。関係が悪すぎる相手とは組めません。')),
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
        H2(tr('「{0}」の形を変える', [ind.name]), top: true),
        _note(p != null ? tr('責任者は{0}です。手を1つ使います。', [nmL(p.name)]) : tr('先に責任者を置いてください。その人が社長になります。')),
        ChoiceBtn(tr('分社する'), () => ctl.act(() => s.spinOff(b)), enabled: p != null, subs: [tr('子会社にして、責任者を社長にする。株は100%持ったまま。社長は自分の判断で動く')]),
        ChoiceBtn(tr('渡して独立させる'), () => ctl.act(() => s.releaseBiz(b)), enabled: p != null, subs: [tr('責任者に事業ごと渡す。株を10%だけ持つ。相手との関係がとても良くなる')]),
        if (s.extras) ...[
          H3(tr('現地法人に分ける')),
          _note(s.localCountries(b).isEmpty
              ? tr('海外に出ている国があると、その国の分を現地法人（株100%の子会社）にできます。')
              : tr('出ている国の分を、株100%の子会社（現地法人）にします。社長は自分の判断で動き、地元の規制が少し緩みます。')),
          for (final c in s.localCountries(b))
            ChoiceBtn(tr('{0}の分を現地法人にする', [cm[c]!.n]), () => openLocal(ctl, b, c),
                enabled: !s.hasLocal(c, b.ind), subs: [tr('その国の市場 ×{0}・事業の力の{1}を移す', [(cw(c, s.yr()) / cw(s.home, s.yr())).toStringAsFixed(2), pct(cw(c, s.yr()) / s.reachOf(b) * 100)])]),
        ],
        _cancel(ctl),
      ]));
}

/// 現地法人の社長を選ぶ（部下から、または現地で雇う）
void openLocal(GameController ctl, Biz b, String c) {
  final s = ctl.game!;
  final ind = indm[b.ind]!;
  ctl.showSheet((_) => _col([
        H2(tr('「{0}」の{1}の現地法人', [ind.name, cm[c]!.n]), top: true),
        _note(tr('手を1つ使います。社長を部下から選ぶか、現地で雇います（相棒は本社に残ります）。')),
        for (final p in s.localPresCands().take(6))
          ChoiceBtn(tr('{0}を社長にする', [nmL(p.name)]), () => ctl.act(() => s.makeLocal(b, c, p.id)),
              enabled: s.ap > 0,
              subs: [[tr('{0}歳', [p.age]), for (final k in abKeys) '${ABN[k]} ${s.showAb(p, k)}'].join('　')]),
        ChoiceBtn(tr('現地で社長を雇う'), () => ctl.act(() => s.makeLocal(b, c)), enabled: s.ap > 0, subs: [tr('その国の人を雇う。腕と特性は働かせてみるまで分からない')]),
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
        H2(tr('「{0}」を海外に出す', [ind.name]), top: true),
        _note(tr('手を1つ使います。市場の大きさは{0}を1としたときの比べ。単独は6か月、組むは3か月かかり、組むとその国の利益は半分になります。買うとすぐ始められます。', [cm[s.home]!.n])),
        for (final x in list)
          Builder(builder: (_) {
            final ms = s.entryModes(b, x.c);
            return Panel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(flex: 2, child: Text(x.n, style: ts(bold: true))),
                  Flexible(flex: 3, child: Muted('${tr('市場 ×{0}', [(cw(x.c, y) / hw).toStringAsFixed(2)])}${cw(x.c, y + 10) > cw(x.c, y) * 1.4 ? tr('　これから伸びる') : ''}')),
                ]),
                const SizedBox(height: 4),
                if (ms.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final m in ms)
                      Btn('${ENTRYN[m]} ${yen(s.entryCost(b, x.c, m))}', () => ctl.act(() => s.enterCountry(b, x.c, m)),
                          small: true, enabled: !(s.cash < s.entryCost(b, x.c, m) || s.ap < 1)),
                  ])
                else
                  Muted(tr('今は入れません')),
                if (ms.length == 1 && ms[0] == 'jv') Muted(tr('規制で、地元の会社と組まないと入れません'), size: 12),
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
    ('宿敵の物語', '宿敵とは、同じ業種で初めてぶつかったときに出会います。値下げ合戦・株の買い集め・引き抜き・裏の手でぶつかるたびに、恨み（あなたがしたこと）と恩（助けた・組んだ）が「街」の宿敵の欄に因縁として残ります。買収する・買収される・友好のまま3年で和解・提携が5年続く、のどれかで決着がつきます。倒した宿敵の一族は、恨みを覚えて戻ってきます。'),
    ('現地法人', '事業が海外に出ていれば、「分社・独立」からその国の分を現地法人（株100%の子会社）に分けられます。社長は部下から選ぶか現地で雇い、その人が自分の判断で動かします。現地法人は地元の会社なので、組んで出ていた国でも利益を半分にされず、中国に現地法人があればネットと金融も組まずに入れます。株の30%をその国の市場に上場させて大金を得ることもできますが、上場すると宿敵に株を狙われることがあります。'),
    ('臨時の会議', '乗っ取りの危機（宿敵の持ち分が20%・33.4%・50%に近づく）、大きな不祥事、資金が尽きかける、のときに臨時の会議が開かれます。相棒・部下・株主の代表（またはメインバンク）が別々の案を出すので、1つを選びます。案は手を使わずに実行されます。選ばれなかった部下と相棒は忠誠が下がります。'),
    ('取締役会', '毎年1月に取締役会が開かれ、1年の売上・利益・時価総額・順位を振り返ります。利益が前年の7割を切り、味方の株（あなた・相棒・味方の会社）が50%に届かないと、解任動議が出ます。改革を約束する・配当を払う・強気で押し切る、から選びます。解任されても後継ぎや部下が社長を継ぎ、会社は続きます。'),
    ('飲み込む', '「株」で他社の株を買い、50%を超えると子会社、66.7%で合併できます。'),
    ('株式交換', '上場すると、自分より小さい会社を、現金の代わりに自社の株を渡して丸ごと買えます。大きくなる近道ですが、あなたの持ち株が薄まり、乗っ取られやすくなります。'),
    ('時代', 'バブル、ネット、スマホ、AI。時代の波は史実に近い順で来ますが、時期と深さは毎回ずれます。沈む業種からは早めに手を引きましょう。社長は年をとるので、後継ぎも決めておきます。'),
  ];
  ctl.showSheet((_) => _col([
        H2(tr('遊び方'), top: true),
        for (final p in parts) ...[
          if (p.$1 != null) H3(tr(p.$1!)),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(tr(p.$2), style: ts(size: 14, height: 1.55))),
        ],
        Align(alignment: Alignment.centerLeft, child: Btn(tr('閉じる'), ctl.closeSheet, primary: true)),
      ]));
}

// ===== 仕掛かり =====
/// 仕掛かりの種類の名前（開発中・進出準備・建設中）
String pipeKindName(String k) => tr(k == 'dev'
    ? '開発中'
    : k == 'enter'
        ? '進出準備'
        : '建設中');

/// 仕掛かり1件の説明（「新商品（1億円）あと2か月」）
String pipeText(Game s, Biz b, Pipe x) => tr('{0}（{1}）あと{2}か月', [
      x.k == 'dev'
          ? tr('新商品')
          : x.k == 'enter'
              ? tr('{0}（{1}）', [cm[x.c]!.n, ENTRYN[x.mode]])
              : tx(s.uw(b)),
      yen(x.cost),
      x.left
    ]);

/// 事業の仕掛かりを種類ごとにまとめたもの
class PipeGroup {
  final String k;

  /// [Biz.pipe] の何番目か（早く終わる順）
  final List<int> idx;
  final double total;
  final int soonest;
  const PipeGroup(this.k, this.idx, this.total, this.soonest);
  int get count => idx.length;
}

/// 仕掛かりを種類ごとにまとめる（種類は最初に出てきた順）
List<PipeGroup> pipeGroups(Biz b) {
  final order = <String>[];
  final by = <String, List<int>>{};
  for (var i = 0; i < b.pipe.length; i++) {
    final k = b.pipe[i].k;
    if (!by.containsKey(k)) order.add(k);
    (by[k] ??= []).add(i);
  }
  return [
    for (final k in order)
      if (by[k]! case final idx)
        PipeGroup(
          k,
          idx..sort((x, y) => b.pipe[x].left.compareTo(b.pipe[y].left)),
          idx.fold<double>(0, (a, i) => a + b.pipe[i].cost),
          b.pipe[idx.first].left,
        ),
  ];
}

/// まとめた1行（「開発中 7件・合計 36.6億円・早いもので あと1か月」）
String pipeGroupText(PipeGroup g) => tr('{0}件・合計 {1}・早いもので あと{2}か月', [g.count, yen(g.total), g.soonest]);

/// 仕掛かりの一覧（1件ずつ取り下げられる）
void openPipes(GameController ctl, Biz b, String k) {
  final s = ctl.game!;
  final g = pipeGroups(b).where((x) => x.k == k).firstOrNull;
  if (g == null || !s.biz.contains(b)) {
    ctl.closeSheet();
    return;
  }
  ctl.showSheet((_) => _col([
        H2(tr('「{0}」の{1}（{2}件）', [indm[b.ind]!.name, pipeKindName(k), g.count]), top: true),
        _note('${pipeGroupText(g)}${tr('。取り下げると、かけたお金の半分が戻ります。')}'),
        for (final i in g.idx)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.line))),
            child: Row(children: [
              Expanded(child: Text(pipeText(s, b, b.pipe[i]), style: ts(size: 13))),
              Btn(tr('取り下げる（半分戻る）'), () {
                final m = s.cancelPipe(b, i);
                ctl.save();
                ctl.toast(m, then: () => openPipes(ctl, b, k));
              }, small: true),
            ]),
          ),
        _cancel(ctl, '閉じる'),
      ]));
}

// ===== 設定 =====
void openSettings(GameController ctl) {
  ctl.showSheet((context) => _col([
        H2(tr('設定'), top: true),
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('言語 / Language', style: ts(size: 13, color: Pal.mute))),
        Row(children: [
          for (final o in const [('ja', '日本語'), ('en', 'English')]) ...[
            Expanded(child: ChoiceBtn(o.$2, () => ctl.setLang(o.$1), on: L.lang == o.$1)),
            if (o.$1 == 'ja') const SizedBox(width: 8),
          ],
        ]),
        ChoiceBtn(tr('遊び方'), () => showHelp(ctl), subs: [tr('手・事業・人・株のしくみ')]),
        ChoiceBtn(tr('はじめから'), () => confirmRestart(ctl), subs: [tr('今の会社の続きを消して、はじめの画面に戻る（確認があります）')]),
        ChoiceBtn(tr('フォントのライセンス'), () {
          // 小窓を閉じる前に開く（閉じると context が外れる）
          showLicensePage(context: context, applicationName: tr('クアドリリオン'), applicationVersion: appVersion);
          ctl.closeSheet();
        }, subs: [tr('Noto Sans JP（SIL Open Font License）ほか')]),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Kv(tr('版'), appVersion)),
        _cancel(ctl, '閉じる'),
      ]));
}

// ===== 月を進める =====
class ReportBase {
  final double cap, cash;
  final String? label;

  /// まとめて進めたのを途中で止めたときの理由（止まらなかったら null）
  String? stop;
  ReportBase(this.cap, this.cash, [this.label]);
}

/// まとめて進めたのが出来事で途中で止まったときの文（「〇〇が起きたので、〇年〇月で止めました」）
String stopReason(Game s) {
  final when = ym(s.year, s.q);
  if (s.over != null) return tr('ゲームが終わったので、{0}で止めました', [when]);
  if (s.won != null) return tr('目標を達成したので、{0}で止めました', [when]);
  return tr('「{0}」が起きたので、{1}で止めました', [tx(s.events.first.title), when]);
}

void doNext(GameController ctl) {
  final s = ctl.game!;
  final before = ReportBase(s.cap, s.cash);
  final snap = ctl.snap();
  final news = s.nextQuarter();
  ctl.buzzAfter(snap, news);
  ctl.save();
  if (news.isEmpty && s.q % 3 != 1 && s.events.isEmpty && s.over == null && s.won == null) {
    ctl.render();
    return;
  }
  showReport(ctl, news, before);
}

void doYear(GameController ctl, [int n = 12]) {
  final s = ctl.game!;
  final before = ReportBase(s.cap, s.cash, tr('{0}から', [ym(s.year, s.q, sp: true)]));
  final all = <LogEntry>[];
  final snap = ctl.snap();
  for (var i = 0; i < n; i++) {
    all.addAll(s.nextQuarter());
    if (s.events.isNotEmpty || s.over != null || s.won != null) {
      // 最後の月で起きたのなら、途中で止めたことにはならない
      if (i < n - 1) before.stop = stopReason(s);
      break;
    }
  }
  ctl.buzzAfter(snap, all);
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
        ? tr('{0}は値下げ合戦の最中です。シェア{1}、利益は{2}に削られています。', [ind.name, pct(b.share * 100), yen(b.profit)])
        : b.share > .5
            ? tr('{0}はシェア{1}。市場の半分以上を押さえました。', [ind.name, pct(b.share * 100)])
            : tr('{0}の売上は{1}、シェア{2}です。', [ind.name, yen(b.rev), pct(b.share * 100)]);
    return Say(
        face: Face(p != null ? p.name : s.pres.name, col: p != null ? null : '#f2c14e'),
        who: p != null ? tr('{0}（責任者）', [nmL(p.name)]) : tr('{0}（社長が直接）', [nmL(s.pres.name)]),
        text: line);
  }).toList();
  final head = tr(s.q % 3 == 1 ? '{0} の経営会議' : '{0} の報告', [ym(s.year, s.q, sp: true)]);
  if (s.q % 3 == 1) {
    markGuide(s, 'meet');
    ctl.save();
  }
  final pre = s.pre;
  final cap = s.cap;
  ctl.showSheet((_) => _col([
        if (before.stop != null)
          Container(
            key: const ValueKey('stop-reason'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Pal.goldBg, border: Border.all(color: Pal.gold), borderRadius: BorderRadius.circular(8)),
            child: Text(before.stop!, style: ts(size: 13.5, bold: true, color: Pal.goldtx)),
          ),
        H2(head, top: true),
        if (before.label != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Muted(tr('{0}まとめて進めました', [before.label]))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(TextSpan(style: ts(), children: [
            TextSpan(text: tr('時価総額 ')),
            TextSpan(text: yen(cap), style: ts(color: Pal.goldtx, bold: true)),
            const TextSpan(text: ' '),
            TextSpan(text: '${d >= 0 ? tr('＋') : ''}${yen(d)}', style: ts(color: d >= 0 ? Pal.up : Pal.down)),
            TextSpan(text: tr('　今月の利益 ')),
            TextSpan(text: yen(pre), style: ts(color: pre >= 0 ? Pal.up : Pal.down, bold: true)),
          ])),
        ),
        ...lines,
        if (news.isNotEmpty) ...[H3(tr('ニュース')), for (final n in news) NewsLine(n.m, n.t)],
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: Btn(tr('続ける'), () {
              ctl.hideSheet();
              nextEvent(ctl);
            }, primary: true)),
      ]));
}

/// 会議の1人ぶんの吹き出し（部下・相棒は名前の頭文字の丸、株主の代表・銀行・取締役は役割の印）
Widget voiceSay(Voice v) => Say(
    key: const ValueKey('meeting-voice'),
    face: v.name != null ? Face(v.name!) : RoleFace(v.kind),
    who: '${tx(v.who)}${tr('・')}${tx(v.role)}',
    text: v.text);

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
  if (e.voices.isNotEmpty) {
    // 会議: 状況の説明は地の文、発言は話す人ごとに顔の丸と肩書きつきの吹き出しで縦に並べる
    body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(tx(e.text), key: const ValueKey('meeting-lead'), style: ts())),
      for (final v in e.voices) voiceSay(v),
    ]);
  } else if (e.who != null) {
    body = Say(face: Face(e.who!.presName, col: e.face), who: '${nmL(e.who!.presName)}${tr('・')}${nmL(e.who!.name)}', text: e.text);
  } else if (e.person != null) {
    body = Say(face: Face(e.person!.name), who: '${nmL(e.person!.name)}${e.person!.partner ? tr('（相棒）') : ''}', text: e.text);
  } else {
    body = Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(tx(e.text), style: ts()));
  }
  ctl.showSheet((_) => _col([
        H2(e.title, top: true),
        body,
        const SizedBox(height: 8),
        for (final c in e.choices)
          ChoiceBtn(c.l, () {
            final snap = ctl.snap();
            final m = c.f();
            ctl.buzzAfter(snap, [LogEntry(m)]);
            ctl.save();
            ctl.showSheet((_) => ToastBody(msg: m, onOk: () => nextEvent(ctl)));
          }, subs: [c.s]),
      ]));
}
