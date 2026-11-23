import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/club_look.dart';
import '../state/game_state.dart';
import 'club_emblem.dart';

/// クラブの見た目の札。今のエンブレムと「見た目を変える」だけを出し、
/// 色・形・模様を選ぶ欄は別の画面([ClubLookEditor])へ移した。タブの中に
/// 広げていたときは画面2つ分を使っていた(2026-11-21)。
class ClubLookCard extends StatelessWidget {
  const ClubLookCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final save = gs.save;
    if (save == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClubEmblem(
                teamId: save.userTeamId,
                teamName: save.clubName,
                size: 48,
                look: gs.currentClubLook),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Tr.pick('クラブの見た目', 'Club look'),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    gs.clubLookChangeCosts
                        ? Tr.pick(
                            '1季に1回まで(変えると期待-${GameStateClubLook.changePenalty})',
                            'Once a season (supporter expectation -${GameStateClubLook.changePenalty})')
                        : Tr.pick('最初の季は何度でも変えられます',
                            'Free to change in your first season'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(Tr.pick('クラブの見た目', 'Club look'))),
                  body: const SingleChildScrollView(
                    padding: EdgeInsets.all(12),
                    child: ClubLookEditor(popOnSave: true),
                  ),
                ),
              )),
              child: Text(Tr.pick('見た目を変える', 'Change')),
            ),
          ],
        ),
      ),
    );
  }
}

/// クラブの見た目を決める。選んだ形を手元で見て、決めてから反映する。
class ClubLookEditor extends StatefulWidget {
  const ClubLookEditor({super.key, this.popOnSave = false});

  /// 決めたら前の画面へ戻るか(別の画面で開いたとき)。
  final bool popOnSave;

  @override
  State<ClubLookEditor> createState() => _ClubLookEditorState();
}

class _ClubLookEditorState extends State<ClubLookEditor> {
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
                        'Choose colours and crest. From your second season you can change it once a season, and long-time fans will be unsettled (supporter expectation -${GameStateClubLook.changePenalty}).')
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
                        if (!ok || !mounted) return;
                        setState(() => _draft = null);
                        if (widget.popOnSave) Navigator.of(this.context).pop();
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
