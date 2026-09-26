// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Prison Boat';

  @override
  String get tagline => 'Get the prisoners across. Don\'t let them escape.';

  @override
  String get start => 'Start';

  @override
  String continueAt(String id) {
    return 'Continue ($id)';
  }

  @override
  String get chooseStage => 'Choose a stage';

  @override
  String get stages => 'Stages';

  @override
  String levelLocked(String id) {
    return '$id, locked';
  }

  @override
  String levelStars(String id, int stars) {
    return '$id, $stars stars';
  }

  @override
  String get placeLeft => 'near bank';

  @override
  String get placeRight => 'far bank';

  @override
  String get placeIsland => 'island';

  @override
  String goTo(String place) {
    return 'To $place';
  }

  @override
  String boatIsAt(String place) {
    return 'The boat is at the $place';
  }

  @override
  String boatSeats(int n) {
    return 'The boat has $n seats';
  }

  @override
  String boatSeatsCuffed(int n) {
    return 'The boat has $n seats (a cuffed pair takes 2)';
  }

  @override
  String get needSomeone => 'Put someone in the boat first';

  @override
  String get noRower => 'Only officers and chiefs can row';

  @override
  String get notAdjacent => 'You can\'t go there directly';

  @override
  String get unsolvable => 'No way across from here. Undo a move.';

  @override
  String hintSay(String load, String place) {
    return 'Send $load to the $place';
  }

  @override
  String get hintJoin => ' + ';

  @override
  String get undo => 'Undo';

  @override
  String get restart => 'Restart';

  @override
  String get hint => 'Hint';

  @override
  String failBoat(int guard, int weight) {
    return 'On the boat: $guard guard vs $weight prisoner.\nNot enough guards — they jumped into the river!';
  }

  @override
  String failAlone(String place) {
    return 'Prisoners were left alone on the $place.';
  }

  @override
  String failBank(String place, int guard, int weight) {
    return 'On the $place: $guard guard vs $weight prisoner.\nNot enough guards!';
  }

  @override
  String personLabel(String name, String where) {
    return '$name, $where';
  }

  @override
  String get onBoat => 'on the boat';

  @override
  String get coachTap => 'Tap an officer or prisoner to board';

  @override
  String coachGo(String button) {
    return 'Now tap \"$button\" below';
  }

  @override
  String tallyGuard(int n) {
    return 'Guards $n';
  }

  @override
  String tallyPrisoner(int n) {
    return 'Prisoners $n';
  }

  @override
  String get backToStages => 'Back to stages';

  @override
  String tripsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n trips',
      one: '1 trip',
    );
    return '$_temp0';
  }

  @override
  String par(int n) {
    return 'Best: $n';
  }

  @override
  String get escaped => 'They escaped!';

  @override
  String get cleared => 'All across!';

  @override
  String get noteHint => 'Hint used: 2 stars max';

  @override
  String get noteBest => 'Perfect — the shortest route!';

  @override
  String noteParFor3(int n) {
    return 'Cross in $n trips for 3 stars';
  }

  @override
  String crossedIn(int n) {
    return 'Crossed in $n trips';
  }

  @override
  String get nextLevel => 'Next level';

  @override
  String allCleared(int n) {
    return 'All $n levels cleared!';
  }

  @override
  String get again => 'Retry';

  @override
  String get stageSelect => 'Stages';

  @override
  String get gotIt => 'Got it';

  @override
  String get rulesTitle => 'Rules';

  @override
  String rulesBody(int cap) {
    return '• On a bank or in the boat, prisoners escape if they outnumber the guards\n• Prisoners left with no guard escape too\n• The boat has $cap seats and needs someone who can row';
  }

  @override
  String get rulesIsland =>
      '• The boat goes bank to island to bank — never straight across';

  @override
  String get rolePolice => 'Officer';

  @override
  String get roleChief => 'Chief';

  @override
  String get roleDog => 'Police dog';

  @override
  String get rolePrisoner => 'Prisoner';

  @override
  String get roleBoss => 'Boss';

  @override
  String get roleCuffed => 'Cuffed pair';

  @override
  String get descPolice => 'Guards 1. Can row.';

  @override
  String get descChief => 'Guards 2. Can row.';

  @override
  String get descDog => 'Guards 1. Can\'t row.';

  @override
  String get descPrisoner => 'Needs 1 guard.';

  @override
  String get descBoss => 'Needs 2 guards alone.';

  @override
  String get descCuffed => 'Needs 2 guards. Takes 2 seats.';

  @override
  String get world1 => 'Riverside';

  @override
  String get world2 => 'The Chief';

  @override
  String get world3 => 'Handcuffs';

  @override
  String get world4 => 'The Boss';

  @override
  String get world5 => 'K9 Unit';

  @override
  String get world6 => 'The Island';

  @override
  String get intro1Title => 'Get them across';

  @override
  String get intro1Body =>
      'Tap officers and prisoners to put them in the boat, then tap \"To far bank\".\nOn a bank or in the boat, if prisoners outnumber officers, they escape.\nPrisoners left with no officer escape too.';

  @override
  String get intro2Title => 'The Chief arrives';

  @override
  String get intro2Body =>
      'A chief can guard two prisoners alone, and can row the boat.';

  @override
  String get intro3Title => 'The cuffed pair';

  @override
  String get intro3Body =>
      'These two are chained together. They need two guards and take two seats in the boat.';

  @override
  String get intro4Title => 'The Boss arrives';

  @override
  String get intro4Body => 'The boss alone needs two guards — in the boat too.';

  @override
  String get intro5Title => 'The police dog';

  @override
  String get intro5Body =>
      'A police dog can guard one prisoner, but can\'t row the boat.';

  @override
  String get intro6Title => 'An island in the river';

  @override
  String get intro6Body =>
      'The boat goes bank to island to bank — never straight across.\nYou can leave people on the island, but it needs guards too.';

  @override
  String get world7 => 'All Hands';

  @override
  String get world8 => 'Nightmare';

  @override
  String get intro7Title => 'All hands on deck';

  @override
  String get intro7Body =>
      'The island returns — with chiefs, police dogs, bosses and cuffed pairs.\nEverything you\'ve learned, all at once.';

  @override
  String get intro8Title => 'Nightmare';

  @override
  String get intro8Body =>
      'The hardest levels, picked by solving every combination.\nCross in the fewest trips and you\'re the real deal.';
}
