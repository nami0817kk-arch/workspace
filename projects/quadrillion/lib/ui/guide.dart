import 'package:flutter/material.dart';

import '../game/game.dart';
import 'controller.dart';
import 'sheets.dart';
import 'widgets.dart';

/// 初めて遊ぶ人への案内。新しく始めたゲームの最初の6か月だけ、街のタブの上に「次にやること」を1行で出す。
/// 進みは Game.guide に入れる（セーブに残る）。

/// 案内を出す月数
const guideMonths = 6;

class GuideStep {
  final String id, text;
  const GuideStep(this.id, this.text);
}

const guideSteps = [
  GuideStep('partner', '相棒を探す（社長の行動から）'),
  GuideStep('biz', '最初の事業を決める'),
  GuideStep('act', '事業のタブで打ち手を使う'),
  GuideStep('meet', '経営会議の提案を見る（1・4・7・10月）'),
];

/// 新しいゲームで案内を始める
void startGuide(Game s) {
  s.guide = {'start': s.turn};
}

/// できたことを記す（案内を出していないゲームでは何もしない）
void markGuide(Game? s, String id) {
  if (s == null || !s.guide.containsKey('start')) return;
  s.guide[id] = 1;
}

bool guideDone(Game s, String id) => switch (id) {
      'partner' => s.partners().isNotEmpty || (s.guide['partner'] ?? 0) > 0,
      'biz' => s.biz.isNotEmpty,
      _ => (s.guide[id] ?? 0) > 0,
    };

/// 今出す案内（出さないなら null）
GuideStep? currentGuide(Game s) {
  final start = s.guide['start'];
  if (start == null || (s.guide['off'] ?? 0) > 0) return null;
  if (s.turn - start >= guideMonths || s.over != null || s.won != null) return null;
  for (final st in guideSteps) {
    if (!guideDone(s, st.id)) return st;
  }
  return null;
}

/// 街のタブの上に出す1行
class GuideBar extends StatelessWidget {
  final GameController ctl;
  final GuideStep step;
  const GuideBar({super.key, required this.ctl, required this.step});

  VoidCallback? _go() => switch (step.id) {
        'partner' => () => openSeek(ctl),
        'biz' => () => openStart(ctl),
        'act' => () => ctl.setTab('biz'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final go = _go();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Pal.goldBg,
        shape: RoundedRectangleBorder(side: const BorderSide(color: Pal.gold), borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: go,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(children: [
              Text(tr('次にやること'), style: ts(size: 12, bold: true, color: Pal.goldtx)),
              const SizedBox(width: 8),
              Expanded(child: Text(tr(step.text), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(size: 13.5, bold: true))),
              if (go != null) const Icon(Icons.chevron_right, size: 20, color: Pal.goldtx),
              IconButton(
                tooltip: tr('案内を閉じる'),
                visualDensity: VisualDensity.standard,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: minTap, minHeight: minTap),
                icon: const Icon(Icons.close, size: 18, color: Pal.mute),
                onPressed: () {
                  ctl.game!.guide['off'] = 1;
                  ctl.save();
                  ctl.render();
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
