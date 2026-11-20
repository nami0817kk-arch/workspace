import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/club_look.dart';
import '../state/game_state.dart';
import 'club_emblem.dart';

/// クラブの見た目を決める。選んだ形を手元で見て、決めてから反映する。
class ClubLookCard extends StatefulWidget {
  const ClubLookCard({super.key});

  @override
  State<ClubLookCard> createState() => _ClubLookCardState();
}

class _ClubLookCardState extends State<ClubLookCard> {
  ClubLook? _draft;
  final _initial = TextEditingController();

  @override
  void dispose() {
    _initial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    final current = gs.currentClubLook;
    final draft = _draft ?? current;
    if (_draft == null && _initial.text != current.initial) {
      _initial.text = current.initial;
    }
    final changed = _draft != null &&
        (draft.hue != current.hue ||
            draft.accentHue != current.accentHue ||
            draft.shape != current.shape ||
            draft.motif != current.motif ||
            draft.initial != current.initial);
    Widget swatches(double selected, void Function(double) pick) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (hue, name) in ClubLook.colors)
              Tooltip(
                message: name,
                child: InkWell(
                  onTap: () => pick(hue),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor(),
                      border: Border.all(
                        width: 3,
                        color: selected == hue
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
    Widget chips(List<String> names, int selected, void Function(int) pick) =>
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var i = 0; i < names.length; i++)
              ChoiceChip(
                label: Text(names[i]),
                selected: selected == i,
                onSelected: (_) => pick(i),
              ),
          ],
        );
    void update(ClubLook l) => setState(() => _draft = l);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('クラブの見た目', 'Club look'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                gs.clubLookChangeCosts
                    ? Tr.pick(
                        '色とエンブレムを決めます。2季目からは1季に1回までで、変えると古いサポーターが戸惑います(期待-${GameStateClubLook.changePenalty})。',
                        'Choose colours and crest. From your second season you can change it once a season, and long-time fans will be unsettled (support -${GameStateClubLook.changePenalty}).')
                    : Tr.pick('色とエンブレムを決めます。最初の季のうちは何度でも変えられます。',
                        'Choose colours and crest. You can change them freely during your first season.'),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Center(
              child: _PreviewEmblem(
                  look: draft, teamId: save.userTeamId, name: save.clubName),
            ),
            const SizedBox(height: 8),
            Text(Tr.pick('主の色', 'Main colour')),
            swatches(draft.hue, (h) => update(draft.copyWith(hue: h))),
            const SizedBox(height: 8),
            Text(Tr.pick('差し色', 'Second colour')),
            swatches(
                draft.accentHue, (h) => update(draft.copyWith(accentHue: h))),
            const SizedBox(height: 8),
            Text(Tr.pick('形', 'Shape')),
            chips(ClubLook.shapeNames, draft.shape,
                (i) => update(draft.copyWith(shape: i))),
            const SizedBox(height: 8),
            Text(Tr.pick('模様', 'Pattern')),
            chips(ClubLook.motifNames, draft.motif,
                (i) => update(draft.copyWith(motif: i))),
            const SizedBox(height: 8),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _initial,
                maxLength: 2,
                decoration: InputDecoration(
                    labelText: Tr.pick('頭文字(1〜2文字)', 'Initials (1-2)')),
                onChanged: (v) => update(draft.copyWith(initial: v)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: changed && gs.canChangeClubLook
                    ? () async {
                        final ok = await gs.setClubLook(draft);
                        if (ok && mounted) setState(() => _draft = null);
                      }
                    : null,
                child: Text(gs.canChangeClubLook
                    ? Tr.pick('この見た目にする', 'Use this look')
                    : Tr.pick('今季はもう変えられません', 'Already changed this season')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 決める前の見た目を描く。
class _PreviewEmblem extends StatelessWidget {
  final ClubLook look;
  final String teamId;
  final String name;

  const _PreviewEmblem(
      {required this.look, required this.teamId, required this.name});

  @override
  Widget build(BuildContext context) =>
      ClubEmblem(teamId: teamId, teamName: name, size: 96, look: look);
}
