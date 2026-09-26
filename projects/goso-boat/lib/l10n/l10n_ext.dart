import 'package:flutter/widgets.dart';

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

  String world(int no) => [world1, world2, world3, world4, world5, world6, world7, world8][no - 1];
  String introTitle(int no) => [intro1Title, intro2Title, intro3Title, intro4Title, intro5Title, intro6Title, intro7Title, intro8Title][no - 1];
  String introBody(int no) => [intro1Body, intro2Body, intro3Body, intro4Body, intro5Body, intro6Body, intro7Body, intro8Body][no - 1];
}
