import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../engine/rng.dart';
import 'theme.dart';
import 'widgets.dart';

const _titlesM = [
  '名もなき民として生きた', '一兵卒として戦場を駆けた', '足軽組頭として名を残した', '馬廻として主君を支えた',
  '侍大将として軍を率いた', '一城の主となった', '家老として家中を動かした', '宿老として国を支えた',
  '大名として一国を治めた', '天下人となった',
];
const _titlesF = [
  '名もなき女として生きた', '下女として働き抜いた', '女中頭として奥を支えた', '奥女中として仕えた',
  '上臈として家を支えた', '御方として一城を守った', '老女として家中を動かした', '大局として奥を束ねた',
  '正室として国を治めた', '女大名として天下に名を残した',
];

/// 一生の終わり。人生の振り返りを見せる。
class EndScreen extends StatelessWidget {
  const EndScreen(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final l = g.l;
    final child = g.age < 15;
    final cause = l.victory ? '天下を掌握した' : (l.end == 'era' ? '乱世の終わりを見届けた' : l.dead ?? '');
    final aj = g.avgJoy;
    final jt = aj >= 65 ? '満ち足りた一生だった' : (aj >= 42 ? '人並みに、喜びも苦しみもあった一生だった' : '苦難の多い一生だった');
    final head = child ? '幼き命' : (l.victory ? '天下統一' : '一生の終わり');
    final rankText = child ? '—' : (l.victory ? (l.female ? '女大名・天下人' : '天下人') : g.rk[l.maxRank]);
    final title = child
        ? '幼くして世を去った。戦国の世では、五つ、十になる前に命を落とす子は珍しくなかった。'
        : '${(l.female ? _titlesF : _titlesM)[l.maxRank]}。';
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 28, 16, 28), children: [
          Text(head,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Text(l.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text('${g.year}年（${gengo(g.year)}）、${g.age}歳。$cause。',
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.muted, fontSize: 13)),
          const SizedBox(height: 10),
          Text(rankText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, color: Pal.gold)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(height: 1.7)),
          const SizedBox(height: 16),
          Panel(
            title: '人生の軌跡',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LifeChart(l.hist),
              const SizedBox(height: 10),
              Text('平均の幸福度は${aj.round()}。$jt。',
                  style: const TextStyle(color: Pal.muted, fontSize: 13)),
              const SizedBox(height: 8),
              KV('最高位', child ? '—' : g.rk[l.maxRank]),
              KV('功', '${l.merit}'),
              KV('名声', '${l.fame}'),
              KV('滅ぼした家', '${l.conq}'),
              KV('子', '${l.kids}人'),
              KV('銭', '${l.gold}貫'),
              const SizedBox(height: 8),
              Text('生まれの稀少度：約${fmtN(l.rarity)}分の1／同じ身分の者は約${fmtN(l.sameClass)}人',
                  style: const TextStyle(color: Pal.muted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),
          Text('スコア ${g.score}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, color: Pal.gold)),
          if (c.newBest)
            const Text('最高記録を更新した！',
                textAlign: TextAlign.center, style: TextStyle(color: Pal.good)),
          const SizedBox(height: 14),
          Panel(title: '最期のころ', child: LogList(l.log.take(8).toList())),
          const SizedBox(height: 20),
          BigButton('新たな生を引く', c.draw),
          const SizedBox(height: 10),
          BigButton('タイトルへ', c.toTitle, secondary: true),
        ]),
      ),
    );
  }
}
