import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

/// ユースの有望株に一軍のベテランを付ける「メンター」の検査。
///
/// 施設のレベルを上げる以外に、育成へ手を入れる方法が無かった。メンターは
/// 「誰を誰に付けるか」という判断を1つ増やすためのもので、効いていること・
/// 選択に代償があることの両方を見る。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player youngster() => PlayerGenerator.generate(
        position: Position.st,
        ageOverride: 17,
        strengthTier: 40,
      );

  Player veteran({int age = 31}) => PlayerGenerator.generate(
        position: Position.dc,
        ageOverride: age,
        strengthTier: 60,
      );

  test('メンターを付けた有望株のほうが速く伸びる', () {
    // 同じ能力の2人を同じ施設で育て、片方にだけメンターを付ける。
    final withMentor = youngster();
    final without = youngster();
    for (final p in [withMentor, without]) {
      // 出発点を揃える(生成のばらつきを持ち込まない)。
      p.attributes.addAll(Map<String, int>.from(withMentor.attributes));
      p.potential = 90;
    }
    final mentor = veteran();
    withMentor.mentorId = mentor.id;

    for (var week = 0; week < 40; week++) {
      TrainingEngine.applyYouthAcademyGrowth(
        [withMentor],
        3,
        mentors: [mentor],
      );
      TrainingEngine.applyYouthAcademyGrowth([without], 3, mentors: [mentor]);
    }

    // 総合力は丸めが入るため、40週では差が出ない週もある(CIで実際に
    // 同値になった)。伸びそのものを見るため、能力値の合計で比べる。
    int total(Player p) =>
        p.attributes.values.fold<int>(0, (s, v) => s + v);
    expect(total(withMentor), greaterThan(total(without)),
        reason: 'メンターを付けても伸びが変わらない');
  });

  test('若すぎるメンターは効かない', () {
    final p = youngster()..potential = 90;
    final tooYoung = veteran(age: TrainingEngine.minMentorAge - 1);
    p.mentorId = tooYoung.id;
    final before = Map<String, int>.from(p.attributes);

    TrainingEngine.applyYouthAcademyGrowth([p], 3, mentors: [tooYoung]);

    // メンター分の上乗せが無いこと(=倍率1.0のときと同じ伸び)を、
    // 対照と比べて確かめる。
    final control = youngster()..potential = 90;
    control.attributes.addAll(before);
    TrainingEngine.applyYouthAcademyGrowth([control], 3);
    expect(p.overall, control.overall);
  });

  test('教えたベテランは少し前向きになる', () {
    final p = youngster()..potential = 90;
    final mentor = veteran();
    mentor.happiness = 50;
    p.mentorId = mentor.id;

    TrainingEngine.applyYouthAcademyGrowth([p], 3, mentors: [mentor]);

    expect(mentor.happiness, greaterThan(50));
  });

  test('一軍の若手を見ているベテランは、ユースのメンターに選べない', () async {
    // 指導の時間は有限。兼任できると、ベテラン1人でクラブ中の若手が
    // 速く育ち、誰に付けるかという判断が無くなる。
    final game = GameState();
    await game.startNewGame('育成FC');

    // 新規開始時点でユースに誰も居ないことがあるため、検査対象は自分で置く。
    final prospect = youngster();
    game.save!.youthProspects.add(prospect);
    final elder = veteran();
    game.userTeam.players.add(elder);

    expect(game.youthMentorCandidates().map((p) => p.id), contains(elder.id));

    // 一軍の若手に付けると、ユース側の候補から消える。
    game.userTeam.players.first.mentorId = elder.id;
    expect(game.youthMentorCandidates().map((p) => p.id),
        isNot(contains(elder.id)));
  });

  test('同じベテランを2人の有望株に付けられない', () async {
    final game = GameState();
    await game.startNewGame('兼任FC');

    final first = youngster();
    final second = youngster();
    game.save!.youthProspects.addAll([first, second]);
    final elder = veteran();
    game.userTeam.players.add(elder);

    game.setYouthProspectMentor(first.id, elder.id);

    // もう1人から見ると、そのベテランはもう選べない。
    expect(game.youthMentorCandidates(forProspectId: second.id).map((p) => p.id),
        isNot(contains(elder.id)));
    // 本人から見ると、付け替えのために自分のメンターは選べたままにする。
    expect(game.youthMentorCandidates(forProspectId: first.id).map((p) => p.id),
        contains(elder.id));
  });

  test('メンターの指名がセーブに残る', () async {
    final game = GameState();
    await game.startNewGame('保存FC');

    final prospect = youngster();
    game.save!.youthProspects.add(prospect);
    final mentorId = game.userTeam.players.first.id;
    game.setYouthProspectMentor(prospect.id, mentorId);

    final json = game.save!.toJson();
    final restored = SaveGame.fromJson(json)
        .youthProspects
        .firstWhere((p) => p.id == prospect.id);
    expect(restored.mentorId, mentorId);
  });
}
