import 'package:flutter/material.dart';

import '../../gm/skills.dart';
import '../gm_controller.dart';
import '../layout.dart';
import 'common.dart';
import 'style.dart';

/// GM の技能。格が上がるたびにもらう点で、5本の木を伸ばす(各3段階)。
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key, required this.c});
  final GmController c;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final car = c.career!;
          return Scaffold(
            appBar: AppBar(title: const Text('GMの技能')),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth(context, phone: 620)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('GMの格が1つ上がるごとに1点。1点で、どれかの技能を1段階上げる(各3段階まで)。今の格は Lv${car.gmLevel}。',
                            style: const TextStyle(fontSize: 12, color: GmColors.sub, height: 1.5)),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('使える点: ${car.skillPoints}', style: const TextStyle(fontWeight: FontWeight.bold, color: GmColors.gold, fontSize: 16)),
                        ),
                      ),
                      for (final s in Skill.values) ...[
                        SectionTitle('${s.label}(${car.skillOf(s)}/$skillMax)'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              for (var i = 0; i < skillMax; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text('${i + 1}段階: ${s.levels[i]}',
                                      style: TextStyle(fontSize: 13, color: car.skillOf(s) > i ? GmColors.good : GmColors.sub)),
                                ),
                              const SizedBox(height: 6),
                              FilledButton(
                                onPressed: car.skillProblem(s) != null || c.busy ? null : () => c.learnSkill(s),
                                child: Text(car.skillProblem(s) ?? '1段階上げる(1点)'),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
