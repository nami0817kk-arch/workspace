/// 人の画面（1.1.0+27。企画書「人の画面（決定）」）。
/// 左に人の一覧（区分: 幹部・責任者・採用の候補・社外。並べ替え: 能力・給料・不満。注意の印: 引き抜かれそう・体を壊しそう・不満。下に採用＝新卒・中途・引き抜き）、
/// 右に1人の中身（経歴・分野ごとの能力・人柄・暮らし・健康・やる気・給料と相場。下に昇給・異動・研修・任せる・話を聞く・解雇）
library;

import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'life_screens.dart';
import 'sheets.dart';
import 'tabs.dart';
import 'widgets.dart';

/// 2列にする真ん中の最小の幅（事業の画面と同じ）
const peopleSplitMin = 520.0;

/// 区分（id・名前）
const peopleSegs = [('exec', '幹部'), ('mgr', '責任者@@people'), ('cand', '採用の候補'), ('out', '社外')];

/// 並べ替え（id・名前）
const peopleSorts = [('ab', '能力'), ('pay', '給料'), ('mood', '不満')];

/// 採用の道（id・名前）
const candSrcs = [('grad', '新卒'), ('mid', '中途'), ('poach', '引き抜き')];

/// 区分の人（並べ替え済み）。幹部は事業を任されていない部下、責任者は事業を任されている部下
List<Person> peopleOf(Game s, String seg, {String src = 'all', String sort = 'ab'}) {
  bool isMgr(Person p) => s.biz.any((b) => b.mgr == p.id);
  final l = switch (seg) {
    'mgr' => s.staff.where(isMgr).toList(),
    'cand' => s.cands.where((p) => src == 'all' || (p.src ?? 'mid') == src).toList(),
    'out' => [...s.alumni, ?s.meet],
    _ => s.staff.where((p) => !isMgr(p)).toList(),
  };
  double key(Person p) => switch (sort) {
    'pay' => -p.salary,
    'mood' => p.loy - (s.unhappy(p) ? 100 : 0),
    _ => -s.topSkill(p),
  };
  l.sort((a, b) => key(a).compareTo(key(b)));
  return l;
}

/// 人の注意の印（引き抜かれそう・体を壊しそう・不満）
List<(IconData, Color, String)> personWarns(Game s, Person p) => !s.staff.contains(p)
    ? const []
    : [
        if (s.poachRisk(p)) (Icons.directions_run, Pal.down, tr('引き抜かれそう')),
        if (s.healthRisk(p)) (Icons.healing, Pal.warn, tr('体を壊しそう')),
        if (s.unhappy(p)) (Icons.sentiment_dissatisfied, Pal.warn, tr('不満がある')),
      ];

List<Widget> peopleSplit(GameController ctl, double width) {
  final s = ctl.game!;
  final seg = ctl.peopleSeg;
  final list = peopleOf(s, seg, src: ctl.candSrc, sort: ctl.peopleSort);
  final presSel = seg == 'exec' && (ctl.openPerson == 0 || (ctl.openPerson == null));
  Person? sel;
  if (!presSel) {
    sel = list.where((p) => p.id == ctl.openPerson).firstOrNull ?? (seg == 'exec' ? null : list.firstOrNull);
  }
  final leftW = clampD(width * .32, 168, 250);
  final m = s.hireMarket0;
  final left = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 6),
      // 区分は2つずつ2行に並べる（幅の狭い列でも4つが2行に収まるよう、入りきらない字は縮める）
      for (var r = 0; r < peopleSegs.length; r += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              for (final g in peopleSegs.skip(r).take(2)) ...[
                if (g != peopleSegs[r]) const SizedBox(width: 4),
                Expanded(
                  child: PickChip(
                    tr('{0} {1}', [tr(g.$2), _segCount(s, g.$1)]),
                    key: ValueKey('pseg-${g.$1}'),
                    on: seg == g.$1,
                    onTap: () => ctl.setPeopleSeg(g.$1),
                  ),
                ),
              ],
            ],
          ),
        ),
      const SizedBox(height: 4),
      // 並べ替えは1つの札にまとめ、押すたびに 能力→給料→不満 と替わる（横向きの低い画面で一覧を上に出すため）
      Builder(
        builder: (_) {
          final i = peopleSorts.indexWhere((o) => o.$1 == ctl.peopleSort);
          final next = peopleSorts[(i + 1) % peopleSorts.length].$1;
          return Align(
            alignment: Alignment.centerLeft,
            child: PickChip(tr('並べ替え：{0}', [tr(peopleSorts[i < 0 ? 0 : i].$2)]), key: const ValueKey('psort'), on: false, onTap: () => ctl.setPeopleSort(next)),
          );
        },
      ),
      const SizedBox(height: 6),
      if (seg == 'exec') _presRow(ctl, presSel),
      for (final p in list) _personRow(ctl, p, p == sel),
      if (list.isEmpty && seg != 'exec')
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Muted(switch (seg) {
            'mgr' => tr('事業を任せている部下はいません。'),
            'cand' => tr('今月はこの道の候補はいません。'),
            _ => tr('社外の知り合いはまだいません。辞めた部下はここに残り、呼び戻せます。'),
          }),
        ),
      const SizedBox(height: 8),
      // 採用＝新卒・中途・引き抜き（押すと、その道の候補を一覧に出す）
      Panel(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('採用'), style: ts(size: 12.5, bold: true)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in candSrcs)
                  Btn(
                    tr('{0}（{1}人）', [tr(c.$2), s.cands.where((p) => (p.src ?? 'mid') == c.$1).length]),
                    () => ctl.setPeopleSeg('cand', src: c.$1),
                    key: ValueKey('hire-${c.$1}'),
                    small: true,
                    primary: seg == 'cand' && ctl.candSrc == c.$1,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('会社の評判 {0}・失業率 {1}%', [s.coRep().round(), s.unempOf().toStringAsFixed(1)]), style: ts(size: 11.5, color: Pal.mute)),
            Text(m, style: ts(size: 11.5, color: Pal.mute)),
          ],
        ),
      ),
      Padding(key: const ValueKey('face-legend'), padding: const EdgeInsets.only(top: 6, bottom: 4), child: faceLegend()),
    ],
  );
  final right = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: presSel ? [_presHead(ctl), ...presPanels(ctl), ...presLifePanels(ctl)] : (sel == null ? [Panel(child: Muted(tr('左の一覧から人を選んでください。')))] : [personDetail(ctl, sel, seg)]),
  );
  return [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: leftW, child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    ),
  ];
}

int _segCount(Game s, String seg) => switch (seg) {
  'exec' => s.staff.where((p) => !s.biz.any((b) => b.mgr == p.id)).length + 1,
  'mgr' => s.staff.where((p) => s.biz.any((b) => b.mgr == p.id)).length,
  'cand' => s.cands.length,
  _ => s.alumni.length + (s.meet != null ? 1 : 0),
};

extension on Game {
  /// 採用の市場のひとこと（働き方の慣習）
  String get hireMarket0 {
    final n = normOf();
    return tr(
      n.life > .6
          ? '終身雇用が強く、中途の市場は薄い'
          : n.hop > .15
          ? '転職が多く、中途の市場が厚い'
          : '中途の市場はほどほど',
    );
  }
}

Widget _presRow(GameController ctl, bool on) {
  final s = ctl.game!;
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TapCard(
      border: on ? Pal.gold : Pal.line,
      color: on ? Pal.onBg : Pal.panel,
      inkKey: const ValueKey('person-row-pres'),
      onTap: () => ctl.selectPerson(0),
      child: Container(
        constraints: const BoxConstraints(minHeight: minTap),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Row(
          children: [
            presFace(s, size: 30),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nmL(s.pres.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 13, bold: true)),
                  Text(
                    tr('社長・{0}歳', [s.pres.age]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(size: 11.5, color: Pal.mute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _personRow(GameController ctl, Person p, bool on) {
  final s = ctl.game!;
  final job = s.biz.where((b) => b.mgr == p.id).firstOrNull;
  final warns = personWarns(s, p);
  final sub = s.cands.contains(p)
      ? tr('{0}・{1}／月', [tr(candSrcs.firstWhere((c) => c.$1 == (p.src ?? 'mid'), orElse: () => candSrcs[1]).$2), yen(p.salary)])
      : s.alumni.contains(p) || p == s.meet
      ? tr(_leftJa[p.left] ?? '知り合い')
      : p.away > 0
      ? tr('休み・あと{0}か月', [p.away])
      : job != null
      ? indm[job.ind]!.name
      : (p.partner ? tr('相棒@@tag') : tr('本社'));
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: TapCard(
      border: on ? Pal.gold : (warns.isNotEmpty ? Pal.warn : Pal.line),
      color: on ? Pal.onBg : Pal.panel,
      inkKey: ValueKey('person-row-${p.id}'),
      onTap: () => ctl.selectPerson(p.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: minTap),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Row(
          children: [
            staffFace(s, p, size: 30),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('{0}（{1}）', [nmL(p.name), p.age]), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 13, bold: true)),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(size: 11.5, color: Pal.mute),
                  ),
                ],
              ),
            ),
            for (final w in warns.take(3))
              Tooltip(
                message: w.$3,
                child: Icon(w.$1, key: ValueKey('pwarn-${p.id}-${w.$1.codePoint}'), size: 15, color: w.$2, semanticLabel: w.$3),
              ),
          ],
        ),
      ),
    ),
  );
}

const _leftJa = {'quit': '辞めた', 'poached': '引き抜かれた', 'fired': '解雇した', 'retired': '引退した'};

Widget _presHead(GameController ctl) => Padding(
  padding: const EdgeInsets.only(top: 6, bottom: 2),
  child: Text(tr('社長'), style: ts(size: 13, bold: true)),
);

/// 1人の中身（経歴・能力・人柄・暮らし・給料と相場・手）
Widget personDetail(GameController ctl, Person p, String seg) {
  final s = ctl.game!;
  final job = s.biz.where((b) => b.mgr == p.id).firstOrNull;
  final isCand = s.cands.contains(p), isOut = s.alumni.contains(p) || p == s.meet;
  final head = Panel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        staffFace(s, p, size: faceBig),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('{0}（{1}歳）', [nmL(p.name), p.age]), style: ts(bold: true)),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  if (p.partner) Tag(tr('相棒・株{0}', [pct(p.stake)]), kind: TagKind.gold),
                  if (job != null) Tag(tr('{0}の責任者', [indm[job.ind]!.name]), kind: TagKind.good),
                  if (!isCand && !isOut && job == null && !p.partner) Tag(tr('本社の幹部')),
                  if (isCand) Tag(tr(candSrcs.firstWhere((c) => c.$1 == (p.src ?? 'mid'), orElse: () => candSrcs[1]).$2), kind: TagKind.gold),
                  if (isOut) Tag(tr(_leftJa[p.left] ?? '知り合い')),
                  if (p.away > 0) Tag(tr('{0}・あと{1}か月', [tr(_awayJa(p.awayWhy)), p.away]), kind: TagKind.bad),
                  for (final w in personWarns(s, p)) Tag(w.$3, kind: TagKind.bad),
                ],
              ),
              if (isCand) Padding(padding: const EdgeInsets.only(top: 4), child: Muted(tr('面接で分かるのは能力の幅だけです。働かせると本当の値と人柄が見えてきます。'), size: 11.5)),
            ],
          ),
        ),
      ],
    ),
  );
  final career = _sec(tr('経歴'), [
    Text(
      tr('{0}{1}', [
        tr(EDU_JA[p.edu.clamp(0, 4)]),
        p.major != null ? tr('・{0}', [tr(MAJOR_JA[p.major]!)]) : '',
      ]),
      style: ts(size: 12.5),
    ),
    if (p.jobs.isEmpty) Muted(tr('職歴なし（新卒）'), size: 12),
    for (final j in p.jobs.reversed.take(3))
      Text(
        j.own
            ? tr('この会社・{0}・{1}年', [j.ind != null ? indm[j.ind]?.name ?? '' : CATN[j.cat], j.years])
            : tr('{0}の{1}・{2}・{3}年', [
                tr(const ['小さな会社', '中くらいの会社', '大手'][j.size.clamp(0, 2)]),
                CATN[j.cat],
                tr(const ['担当', '管理職', '役員'][j.role.clamp(0, 2)]),
                j.years,
              ]),
        style: ts(size: 12.5),
      ),
    Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final l in p.lic) Tag(tr(LIC_JA[l]!), kind: TagKind.gold),
        if (p.tf != null) Tag(tr('技術: {0}', [tr(TF_JA[p.tf]!)])),
        if (p.lg != null) Tag(tr('語学: {0}', [tr(LANG_JA[p.lg] ?? '英語')])),
      ],
    ),
    if (job != null && s.expF(p, indm[job.ind]!) > 1.001) Muted(tr('同じ業界の経験が効いています（×{0}）', [s.expF(p, indm[job.ind]!).toStringAsFixed(2)]), size: 11.5),
  ]);
  final skills = _sec(tr('分野ごとの能力'), [
    for (final g in SK_GROUPS) ...[
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(tr(g.$1), style: ts(size: 12, bold: true, color: Pal.goldtx)),
      ),
      Grid2([
        for (final k in g.$2)
          if (s.skRange(p, k) case final r) AbKv(tr(SK_JA[k]!), s.showSk(p, k), r[0], r[1]),
      ]),
    ],
  ]);
  String lv(int v) => tr(
    v >= 70
        ? '高い'
        : v >= 40
        ? 'ふつう@@lv'
        : '低い',
  );
  Widget trait(String label, String k, int v, {String? hiJa, String? loJa}) =>
      Kv(label, s.knows(p, k) ? (hiJa != null ? tr(v >= 55 ? hiJa : loJa!) : lv(v)) : tr('？'));
  final t = STRAITS.firstWhere((x) => x.id == p.trait, orElse: () => STRAITS.first);
  final person = _sec(tr('人柄'), [
    Grid2([
      trait(tr('誠実さ'), 'hon', p.hon),
      trait(tr('ストレスへの強さ'), 'str', p.str),
      trait(tr('協調性'), 'coop', p.coop),
      trait(tr('気質'), 'amb', p.amb, hiJa: '挑戦好き', loJa: '慎重'),
    ]),
    Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(tr('特性'), style: ts(size: 12.5)),
          if (p.traitKnown) ...[
            Tag(t.n),
            colored('${tr('＋')}${t.g}', Pal.up, size: 12),
            colored('${tr('－')}${t.b}', Pal.down, size: 12),
          ] else
            Muted(tr('？（働かせると分かる）'), size: 12),
        ],
      ),
    ),
  ]);
  final famKnown = s.knows(p, 'fam');
  final kids = p.kidsAge.isEmpty
      ? tr('子どもなし')
      : tr('子ども{0}人（{1}）', [
          p.kidsAge.length,
          p.kidsAge.map((a) => tr('{0}歳', [a])).join(tr('・')),
        ]);
  final life = _sec(tr('暮らし・健康・やる気'), [
    Text(
      famKnown ? tr('{0}・{1}{2}', [tr(p.married ? '結婚している' : '独身'), kids, p.care ? tr('・親の介護') : '']) : tr('家族のことはまだ分かりません（話を聞くと分かる）'),
      style: ts(size: 12.5),
    ),
    if (famKnown && s.refusesPosting(p)) Text(tr('→ 海外への赴任は断りがち'), style: ts(size: 12, color: Pal.warn)),
    const SizedBox(height: 3),
    _meter(tr('健康'), p.health, s.knows(p, 'health') || p.health < healthWarn || !isCand, key: ValueKey('health-${p.id}')),
    if (!isCand) _meter(tr('やる気'), p.loy.clamp(0, 100).toDouble(), true, key: ValueKey('mood-${p.id}')),
  ]);
  final mk = s.mktPay(p), r = s.payRatio(p);
  final pay = _sec(tr('給料と相場'), [
    Kv(tr('今の給料（月）'), yen(p.salary * (s.hasT('frugal') && !isCand ? .7 : 1))),
    Kv(tr('相場（月）'), yen(mk)),
    Text(
      p.partner && r < payLowRatio
          ? tr('相場より{0}低い（相棒は株を持つので、給料の低さでは不満を持たない）', [pct((1 - r) * 100)])
          : r < payLowRatio
          ? tr('相場より{0}低い。引き抜きに注意', [pct((1 - r) * 100)])
          : r > 1.1
          ? tr('相場より{0}高い', [pct((r - 1) * 100)])
          : tr('ほぼ相場どおり'),
      key: ValueKey('payratio-${p.id}'),
      style: ts(size: 12, color: r < payLowRatio ? Pal.down : Pal.mute),
    ),
    Muted(tr('業界での評判 {0}', [p.fame]), size: 11.5),
    if (isCand) Kv(tr('雇う費用'), yen(s.hireFeeOf(p))),
  ]);
  final acts = _actions(ctl, p, job, isCand: isCand, isOut: isOut);
  return LayoutBuilder(
    builder: (context, c) {
      final wide = c.maxWidth >= 560;
      final a = [career, person, life, pay];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: a),
                ),
                const SizedBox(width: 6),
                Expanded(child: skills),
              ],
            )
          else ...[
            career,
            skills,
            person,
            life,
            pay,
          ],
          acts,
        ],
      );
    },
  );
}

String _awayJa(String? why) => switch (why) {
  'sick' => '病気の休み',
  'baby' => '育児の休み',
  'care' => '介護の休み',
  'abroad' => '留学中',
  _ => (why ?? '').startsWith('course') ? '研修中' : '休み',
};

Widget _sec(String title, List<Widget> c) => Panel(
  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: ts(size: 13, bold: true)),
      const SizedBox(height: 3),
      ...c,
    ],
  ),
);

/// 0〜100 の目盛り（健康・やる気）
Widget _meter(String label, double v, bool known, {Key? key}) {
  final c = v < 40 ? Pal.down : (v < 60 ? Pal.warn : Pal.up);
  return Padding(
    key: key,
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(size: 12, color: Pal.mute),
          ),
        ),
        Expanded(child: known ? Bar([(v.clamp(0, 100), c)], height: 7) : Muted(tr('？'), size: 12)),
        const SizedBox(width: 6),
        SizedBox(
          width: 26,
          child: Text(known ? '${v.round()}' : '', textAlign: TextAlign.right, style: ts(size: 12)),
        ),
      ],
    ),
  );
}

/// 下の手（社員: 昇給・異動・研修・任せる・話を聞く・解雇。候補: 雇う。社外: 呼び戻す）
Widget _actions(GameController ctl, Person p, Biz? job, {required bool isCand, required bool isOut}) {
  final s = ctl.game!;
  final btns = <Widget>[];
  if (isCand) {
    btns.add(Btn(tr('雇う（{0}）', [yen(s.hireFeeOf(p))]), () => ctl.act(() => s.hire(p)), key: ValueKey('p-hire-${p.id}'), primary: true, small: true));
  } else if (isOut) {
    if (s.alumni.contains(p)) {
      btns.add(Btn(tr('呼び戻す'), () => ctl.act(() => s.rehire(p)), key: ValueKey('p-back-${p.id}'), small: true, enabled: p.left != 'fired'));
    }
  } else {
    btns.addAll([
      Btn(tr('昇給'), () => ctl.act(() => s.raisePay(p)), key: ValueKey('p-raise-${p.id}'), small: true, enabled: p.real && s.payRatio(p) < 1.02),
      Btn(tr('異動'), () => openTransfer(ctl, p), key: ValueKey('p-move-${p.id}'), small: true, more: true),
      Btn(tr('研修'), () => openTraining(ctl, p), key: ValueKey('p-train-${p.id}'), small: true, more: true, enabled: p.real && p.away == 0),
      if (job != null)
        Btn(
          tr(s.delegated(job) ? '任せるのをやめる' : '任せる'),
          () {
            s.setDeleg(job, !s.delegated(job));
            ctl.save();
            ctl.render();
          },
          key: ValueKey('p-deleg-${p.id}'),
          small: true,
        ),
      Btn(tr('話を聞く'), () => ctl.act(() => s.talkTo(p)), key: ValueKey('p-talk-${p.id}'), small: true),
      Btn(
        tr(p.partner ? '相棒と別れる' : '解雇'),
        () => p.partner
            ? actConfirmed(
                ctl,
                tr('相棒と別れる'),
                tr(s.listed ? '{0}は会社を去り、持っている株{1}は市場で売られます。' : '{0}は会社を去り、持っている株{1}は投資家の手に渡ります。', [nmL(p.name), pct(p.stake)]),
                tr('別れる'),
                () => s.dismiss(p),
              )
            : actConfirmed(
                ctl,
                tr('解雇'),
                p.real
                    ? tr('{0}を解雇します。解雇の手当は{1}（給料の{2}か月分）。ほかの部下のやる気も下がります。', [nmL(p.name), yen(p.salary * s.severanceMonths()), s.severanceMonths().round()])
                    : tr('{0}を解雇します。もう呼び戻せません。', [nmL(p.name)]),
                tr('解雇する'),
                () => s.dismiss(p),
              ),
        key: ValueKey('p-fire-${p.id}'),
        small: true,
      ),
    ]);
  }
  return Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 6),
    child: Wrap(spacing: 6, runSpacing: 6, children: btns),
  );
}

/// 異動: どの事業の責任者にするか（海外だけの事業は、子どもが学校に通う人・介護をしている人が断りがち）
void openTransfer(GameController ctl, Person p) {
  final s = ctl.game!;
  final now = s.biz.where((b) => b.mgr == p.id).firstOrNull;
  ctl.showSheet(
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        H2(tr('{0}の異動', [nmL(p.name)]), top: true),
        if (s.biz.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(tr('まだ事業がありません。'))),
        for (final b in s.biz)
          Builder(
            builder: (_) {
              final abroad = !s.ctryOf(b).contains(s.home);
              final no = abroad && s.refusesPosting(p);
              final cur = s.staffById(b.mgr);
              return ChoiceBtn(
                tr('「{0}」の責任者にする', [indm[b.ind]!.name]),
                no
                    ? null
                    : () {
                        s.setManager(b, p.id);
                        ctl.closeSheet();
                        ctl.save();
                        ctl.render();
                      },
                key: ValueKey('move-${b.id}'),
                on: b == now,
                enabled: !no && b != now,
                subs: [
                  if (cur != null && cur != p) tr('今の責任者: {0}', [nmL(cur.name)]),
                  if (no) tr('海外への赴任を断られます（家族の事情）'),
                ],
              );
            },
          ),
        if (now != null)
          ChoiceBtn(tr('担当を外して本社に戻す'), () {
            s.setManager(now, null);
            ctl.closeSheet();
            ctl.save();
            ctl.render();
          }, key: const ValueKey('move-hq')),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(alignment: Alignment.centerLeft, child: Btn(tr('やめる'), ctl.closeSheet)),
        ),
      ],
    ),
  );
}

/// 研修（分野を1つ・1か月）か留学（1年）
void openTraining(GameController ctl, Person p) {
  final s = ctl.game!;
  ctl.showSheet(
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        H2(tr('{0}を研修に出す', [nmL(p.name)]), top: true),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(tr('出ているあいだは責任者の仕事ができません。社長の時間は1時間。'))),
        for (var i = 0; i < SK_GROUPS.length; i++)
          ChoiceBtn(
            tr('{0}の研修（1か月）', [tr(SK_GROUPS[i].$1)]),
            () => ctl.act(() => s.sendTraining(p, i)),
            key: ValueKey('train-$i'),
            subs: [
              tr('{0}・その分野の能力が伸びる', [yen(s.courseCost())]),
            ],
            dim: s.cash < s.courseCost(),
          ),
        ChoiceBtn(
          tr('海外の大学院に留学させる（1年）'),
          () => ctl.act(() => s.sendTraining(p, -1)),
          key: const ValueKey('train-abroad'),
          subs: [
            tr('{0}・語学と経営の力が伸び、名が知られる（引き抜かれやすくなる）', [yen(s.abroadCost())]),
          ],
          dim: s.cash < s.abroadCost(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(alignment: Alignment.centerLeft, child: Btn(tr('やめる'), ctl.closeSheet)),
        ),
      ],
    ),
  );
}
