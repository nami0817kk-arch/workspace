import 'package:flutter/material.dart';

import '../engine/data.dart';
import '../engine/game.dart';
import 'theme.dart';

/// 位の解説（2026-11-24、ユーザー「位がよくわからない時がある。解説ページ作れる？」）。
/// 立ち位置のカードや上の一行を押すと下から出る。いまの位に印を付け、位ごとの暮らしと、上がるのに要るものを並べる。

/// 位ごとの一言（男）。`kRanksM` と同じ並び。
const kRankNotesM = <String>[
  '主家を持たない身。百姓・町人・浪人など。仕官すれば足軽から始まる。',
  '槍を担いで戦に出る、いちばん下の兵。',
  '足軽の組をまとめる頭。十数人を預かる。',
  '主君のそば近くに仕える騎馬の侍。ここからが一人前の武士。',
  '一手の軍勢を率いる将。戦では采配を振るう。',
  '城をひとつ預かる身。領地と家臣を持つ。',
  '主家の政を取り仕切る重臣。',
  '家中の筆頭。主君に次ぐ立場。ここから先は、下剋上か主君の死でしか上がれない。',
  '一国の主。他家を攻め、天下の半ばを握れば天下人。',
  '天下を統べる者。',
];

/// 位ごとの一言（女）。`kRanksF` と同じ並び。
const kRankNotesF = <String>[
  '主家を持たない身。奉公に上がれば下女から始まる。',
  '奥向きの水仕事や使い走りをする、いちばん下の奉公人。',
  '下女たちをまとめる頭。',
  '奥方や姫のそばに仕える女中。ここからが奥の表に立つ身。',
  '奥で重い役を務める上位の女中。',
  '殿や奥方に近い、名を呼ばれる身。',
  '奥向きの万事を取り仕切る年かさの重役。',
  '奥の筆頭。家の内のことはこの人を通る。',
  '当主の正室、または幼い当主の後見。家を動かす。',
  '女の身で一国を治める主。',
];

/// 位の段の外の暮らし。
const kOffLadderNotes = <(String, String)>[
  ('僧・尼', '仏門に入った身。位は上がらないが、寺の務めや修行の道がある。住持になることも。'),
  ('商人', '商いの道を選んだ身。銭と人の縁で身を立てる。御用商人になることも。'),
  ('忍び・流れ者・野盗', '主家に縛られず野に生きる身。里の務めや旅の暮らしがある。'),
  ('隠居', '家督を譲り、務めを離れた身。'),
];

void showRankGuide(BuildContext context, Game g) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pal.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      minChildSize: .5,
      builder: (context, scroll) => RankGuide(g, controller: scroll),
    ),
  );
}

class RankGuide extends StatelessWidget {
  const RankGuide(this.g, {super.key, this.controller});
  final Game g;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l = g.l;
    final female = l.female;
    final names = female ? kRanksF : kRanksM;
    final notes = female ? kRankNotesF : kRankNotesM;
    final onLadder =
        !g.isChild &&
        !(l.rank == 0 &&
            (g.hasFlag('priesthood') ||
                g.hasFlag('way_merchant') ||
                g.hasFlag('way_outlaw') ||
                g.hasFlag('retired')));
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Pal.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '位の解説',
          style: TextStyle(
            fontSize: 20,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: Pal.gold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          g.isChild
              ? 'いまは幼少期。十五になると、生まれに応じた身分から大人の人生が始まる。'
              : onLadder
              ? 'いまの位は「${g.rankName()}」。下の表の朱の印がいまの段。'
              : 'いまは「${g.rankName()}」。位の段の外を歩んでいる（下の「段の外の暮らし」）。',
          style: const TextStyle(fontSize: 13.5, height: 1.6),
        ),
        const SizedBox(height: 14),
        _head(female ? '奥向きの位（女性）' : '武家の位（男性）'),
        for (var i = names.length - 1; i >= 0; i--)
          _RankRow(
            step: i + 1,
            name: names[i],
            note: notes[i],
            need: _need(i, female, g.canFight),
            current: onLadder && l.rank == i,
          ),
        const SizedBox(height: 16),
        _head('位を上げるもの'),
        _Para(
          female && !g.canFight
              ? '功 … 奥の務めや頼まれごとの働きで増える。\n'
                    '信頼 … 主の覚え。「奥向きに尽くす」や、頼まれごとを果たすと増える。\n'
                    '二つがそろうと、次の位へ上がる（兵は要らない）。'
              : '功 … 戦の手柄や務めの働きで増える。\n'
                    '信頼 … 主君の覚え。「主君に尽くす」や、頼まれごとを果たすと増える。\n'
                    '兵 … 自分の手勢。「戦に備える」で集まる（戦に出ない人には要らない）。\n'
                    '三つがそろうと、次の位へ上がる。',
        ),
        const SizedBox(height: 16),
        _head('段の外の暮らし'),
        for (final (name, note) in kOffLadderNotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$name　',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Pal.ink,
                    ),
                  ),
                  TextSpan(text: note),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.55),
            ),
          ),
        const SizedBox(height: 8),
        const _Para('位は高いほどよいとは限らない。名もなき幸せな最期も、図鑑の一本。'),
      ],
    );
  }

  static Widget _head(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        color: Pal.gold,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        fontSize: 15,
      ),
    ),
  );

  /// その位に上がるのに要るもの（`kPromo`）。表にない位は、道筋を言葉で。
  static String? _need(int rank, bool female, bool canFight) {
    final p = kPromo[rank];
    if (p != null) {
      final troops = !female || canFight ? '・兵${p.troops}' : '';
      return 'この位になるには　功${p.merit}・信頼${p.fav}${p.troops > 0 ? troops : ''}';
    }
    return switch (rank) {
      1 => female ? 'この位になるには　奉公先を探して奉公に上がる' : 'この位になるには　仕官の口を探して仕える',
      8 => female ? 'この位になるには　輿入れや側室を経て、後見に立つ' : 'この位になるには　下剋上、または主君の死で家を継ぐ',
      9 => female ? 'この位になるには　当主として国を治める' : 'この位になるには　天下の勢力の半ばを握る',
      _ => null,
    };
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, height: 1.7, color: Pal.ink),
  );
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.step,
    required this.name,
    required this.note,
    required this.need,
    required this.current,
  });
  final int step;
  final String name, note;
  final String? need;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: current ? Pal.accent.withValues(alpha: .08) : Pal.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? Pal.accent : Pal.line,
          width: current ? 1.6 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: current ? Pal.accent : Pal.muted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: current ? Pal.accent : Pal.ink,
                      ),
                    ),
                    if (current)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          '← いまここ',
                          style: TextStyle(fontSize: 12, color: Pal.accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(note, style: const TextStyle(fontSize: 12.5, height: 1.5)),
                if (need != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      need!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Pal.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
