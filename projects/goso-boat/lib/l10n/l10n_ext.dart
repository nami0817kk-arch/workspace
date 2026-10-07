import 'package:flutter/widgets.dart';

import '../app/achievements.dart';
import '../engine/rules.dart';
import 'app_localizations.dart';

/// `AppLocalizations.of(context)!` を毎回書かずに済むようにする。
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// エンジンの列挙を、画面に出す言葉にする。
extension L10nNames on AppLocalizations {
  String place(Place p) => switch (p) {
        Place.left => placeLeft,
        Place.right => placeRight,
        Place.island => placeIsland,
      };

  String role(Role r) => switch (r) {
        Role.police => rolePolice,
        Role.chief => roleChief,
        Role.dog => roleDog,
        Role.prisoner => rolePrisoner,
        Role.boss => roleBoss,
        Role.cuffed => roleCuffed,
      };

  String roleDesc(Role r) => switch (r) {
        Role.police => descPolice,
        Role.chief => descChief,
        Role.dog => descDog,
        Role.prisoner => descPrisoner,
        Role.boss => descBoss,
        Role.cuffed => descCuffed,
      };

  String achName(Achievement a) => switch (a) {
        Achievement.firstClear => ach_firstClear,
        Achievement.clears10 => ach_clears10,
        Achievement.clears60 => ach_clears60,
        Achievement.allClear => ach_allClear,
        Achievement.threeStar30 => ach_threeStar30,
        Achievement.threeStarAll => ach_threeStarAll,
        Achievement.escape10 => ach_escape10,
        Achievement.escape100 => ach_escape100,
        Achievement.nightmareThree => ach_nightmareThree,
        Achievement.dailyWeek => ach_dailyWeek,
        Achievement.perfect1 => ach_perfect1,
        Achievement.perfect2 => ach_perfect2,
        Achievement.perfect3 => ach_perfect3,
        Achievement.perfect4 => ach_perfect4,
        Achievement.perfect5 => ach_perfect5,
        Achievement.perfect6 => ach_perfect6,
        Achievement.perfect7 => ach_perfect7,
        Achievement.perfect8 => ach_perfect8,
        Achievement.firstTryThree => ach_firstTryThree,
        Achievement.nightmareNoUndo => ach_nightmareNoUndo,
      };

  String achDesc(Achievement a) => switch (a) {
        Achievement.firstClear => achDesc_firstClear,
        Achievement.clears10 => achDesc_clears10,
        Achievement.clears60 => achDesc_clears60,
        Achievement.allClear => achDesc_allClear,
        Achievement.threeStar30 => achDesc_threeStar30,
        Achievement.threeStarAll => achDesc_threeStarAll,
        Achievement.escape10 => achDesc_escape10,
        Achievement.escape100 => achDesc_escape100,
        Achievement.nightmareThree => achDesc_nightmareThree,
        Achievement.dailyWeek => achDesc_dailyWeek,
        Achievement.perfect1 => achDesc_perfect1,
        Achievement.perfect2 => achDesc_perfect2,
        Achievement.perfect3 => achDesc_perfect3,
        Achievement.perfect4 => achDesc_perfect4,
        Achievement.perfect5 => achDesc_perfect5,
        Achievement.perfect6 => achDesc_perfect6,
        Achievement.perfect7 => achDesc_perfect7,
        Achievement.perfect8 => achDesc_perfect8,
        Achievement.firstTryThree => achDesc_firstTryThree,
        Achievement.nightmareNoUndo => achDesc_nightmareNoUndo,
      };

  String rankName(int r) => [rank0, rank1, rank2, rank3, rank4, rank5, rank6, rank7, rank8, rank9][r];

  String world(int no) => [world1, world2, world3, world4, world5, world6, world7, world8][no - 1];
  String introTitle(int no) => [intro1Title, intro2Title, intro3Title, intro4Title, intro5Title, intro6Title, intro7Title, intro8Title][no - 1];
  String introBody(int no) => [intro1Body, intro2Body, intro3Body, intro4Body, intro5Body, intro6Body, intro7Body, intro8Body][no - 1];
}
