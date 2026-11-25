import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/club_crests.dart';
import '../l10n/tr.dart';
import '../models/club_look.dart';
import '../state/game_state.dart';
import 'club_emblem.dart';
import 'disabled_reason.dart';
import 'offseason_lock_note.dart';

/// クラブの見た目の札。今のエンブレムと「見た目を変える」だけを出し、
/// 色・形・模様を選ぶ欄は別の画面([ClubLookEditor])へ移した。タブの中に
/// 広げていたときは画面2つ分を使っていた(2026-11-21)。
///
/// 変えられるのはオフシーズン(季の終わり〜開幕前)だけ。シーズン中は
/// 「見た目を変える」を出さず、1行で見せる(2026-11-25)。
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
            // 決めていなければ、出ているとおり(表の画像かクラブで決まる画像)。
            ClubEmblem(
              teamId: save.userTeamId,
              teamName: save.clubName,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.pick('クラブの見た目', 'Club look'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!gs.isOffseason)
                    OffseasonLockNote(
                      Tr.pick('このエンブレムと色', 'this crest and colours'),
                    )
                  else if (gs.clubLookChangedThisOffseason)
                    Text(
                      Tr.pick(
                        'このオフシーズンはもう変えました(1回まで)',
                        'Already changed this off-season (once only)',
                      ),
                      style: const TextStyle(fontSize: 12),
                    )
                  else
                    Text(
                      gs.clubLookChangeCosts
                          ? Tr.pick(
                              'オフシーズンに1回まで(変えると期待-${GameStateClubLook.changePenalty})',
                              'Once per off-season (supporter expectation -${GameStateClubLook.changePenalty})',
                            )
                          : Tr.pick(
                              '最初の季のオフシーズンは何度でも変えられます',
                              'Free to change in your first off-season',
                            ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  // 描いたエンブレムを選んでいる人に、画像を勧める。
                  if (gs.canChangeClubLook &&
                      save.clubLook != null &&
                      save.clubLook!.crest == null)
                    Text(
                      Tr.pick(
                        '絵のエンブレム(25種)からも選べます',
                        'You can also pick one of 25 illustrated crests',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (gs.canChangeClubLook)
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(Tr.pick('クラブの見た目', 'Club look')),
                      ),
                      body: const SingleChildScrollView(
                        padding: EdgeInsets.all(12),
                        child: ClubLookEditor(popOnSave: true),
                      ),
                    ),
                  ),
                ),
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
    // 決めていない(表の画像を出している)ときは、選べばそれが変更。
    final changed =
        _draft != null && (save.clubLook == null || !draft.sameAs(current));
    final drawn = draft.crest == null;
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // 画像のエンブレムの格子。最後の1枠は描いたエンブレム(形・模様・頭文字)。
    Widget crestTile({
      required bool selected,
      required String label,
      required VoidCallback onTap,
      required Widget child,
    }) => Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                width: 3,
                color: selected ? onSurface : Colors.transparent,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
    final crestGrid = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < ClubLook.crestCount; i++)
          crestTile(
            selected: draft.crest == i,
            label: ClubLook.crestNames[i],
            onTap: () => update(draft.withCrest(i)),
            child: Image.asset(
              ClubCrests.ownAssetPath(i),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        crestTile(
          selected: drawn,
          label: Tr.pick(
            '描いたエンブレム(形・模様・頭文字)',
            'Drawn crest (shape, pattern, initials)',
          ),
          onTap: () => update(draft.withoutCrest()),
          child: ClubEmblem(
            teamId: save.userTeamId,
            teamName: save.clubName,
            size: 48,
            look: draft.withoutCrest(),
          ),
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick('クラブの見た目', 'Club look'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              gs.clubLookChangeCosts
                  ? Tr.pick(
                      '色とエンブレムを決めます。変えられるのはオフシーズン(季の終わり〜開幕前)に1回までで、変えると古いサポーターが戸惑います(期待-${GameStateClubLook.changePenalty})。',
                      'Choose colours and crest. You can change them once per off-season (end of season to kick-off), and long-time fans will be unsettled (supporter expectation -${GameStateClubLook.changePenalty}).',
                    )
                  : Tr.pick(
                      '色とエンブレムを決めます。最初の季のオフシーズン(開幕前)は何度でも変えられます。',
                      'Choose colours and crest. You can change them freely in your first off-season (before kick-off).',
                    ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            Center(
              child: _PreviewEmblem(
                look: draft,
                teamId: save.userTeamId,
                name: save.clubName,
              ),
            ),
            const SizedBox(height: 8),
            Text(Tr.pick('エンブレム', 'Crest')),
            const SizedBox(height: 4),
            crestGrid,
            const SizedBox(height: 8),
            if (!drawn)
              Text(
                Tr.pick(
                  'クラブの色はエンブレムの色になります。最後の枠で、形・模様・頭文字を選んで描くこともできます。',
                  'Club colours follow the crest. Use the last tile to draw your own with a shape, pattern and initials.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            if (drawn) ...[
              Text(Tr.pick('主の色', 'Main colour')),
              swatches(draft.hue, (h) => update(draft.copyWith(hue: h))),
              const SizedBox(height: 8),
              Text(Tr.pick('差し色', 'Second colour')),
              swatches(
                draft.accentHue,
                (h) => update(draft.copyWith(accentHue: h)),
              ),
              const SizedBox(height: 8),
              Text(Tr.pick('形', 'Shape')),
              chips(
                ClubLook.shapeNames,
                draft.shape,
                (i) => update(draft.copyWith(shape: i)),
              ),
              const SizedBox(height: 8),
              Text(Tr.pick('模様', 'Pattern')),
              chips(
                ClubLook.motifNames,
                draft.motif,
                (i) => update(draft.copyWith(motif: i)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _initial,
                  maxLength: 2,
                  decoration: InputDecoration(
                    labelText: Tr.pick('頭文字(1〜2文字)', 'Initials (1-2)'),
                  ),
                  onChanged: (v) => update(draft.copyWith(initial: v)),
                ),
              ),
            ],
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
                child: Text(
                  gs.canChangeClubLook
                      ? Tr.pick('この見た目にする', 'Use this look')
                      : gs.isOffseason
                      ? Tr.pick(
                          'このオフシーズンはもう変えられません',
                          'Already changed this off-season',
                        )
                      : Tr.pick(
                          '来季の開幕前に変えられます',
                          'You can change it before next season starts',
                        ),
                ),
              ),
            ),
            // まだ何も変えていないときも押せない(今季済みはボタンの字に出る)。
            if (!changed && gs.canChangeClubLook)
              Align(
                alignment: Alignment.centerRight,
                child: DisabledReason(
                  Tr.pick(
                    'エンブレムか、色・形・模様・頭文字を変えると決められます',
                    'Pick a crest, or change a colour, shape, pattern or initials, to save',
                  ),
                  alignEnd: true,
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

  const _PreviewEmblem({
    required this.look,
    required this.teamId,
    required this.name,
  });

  @override
  Widget build(BuildContext context) =>
      ClubEmblem(teamId: teamId, teamName: name, size: 96, look: look);
}
