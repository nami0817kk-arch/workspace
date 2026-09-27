// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Prison Ferry';

  @override
  String get tagline => 'Get every prisoner across the river.';

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

  @override
  String get hintWithAd => 'Hint (video)';

  @override
  String get hintDeclined => 'Watch the whole video to get a hint';

  @override
  String removeAds(String price) {
    return 'Remove ads ($price)';
  }

  @override
  String get restorePurchases => 'Restore purchase';

  @override
  String get adFreeOn => 'Ad-free';

  @override
  String get purchaseThanks => 'Ads removed. Thank you!';

  @override
  String get purchaseRestored => 'Purchase restored';

  @override
  String get purchaseNothing => 'No purchase to restore';

  @override
  String get purchaseFailed => 'Purchase failed. Please try again later.';

  @override
  String get kicker => 'Don\'t let them escape!';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingSound => 'Sound effects';

  @override
  String get settingHaptics => 'Vibration';

  @override
  String get licenses => 'Licenses';

  @override
  String get resetProgress => 'Reset progress';

  @override
  String get resetConfirmTitle => 'Reset progress?';

  @override
  String get resetConfirmBody =>
      'All stars and records will be deleted. Your ad-free purchase stays.';

  @override
  String get cancel => 'Cancel';

  @override
  String get doReset => 'Reset';

  @override
  String get resetDone => 'Progress reset';

  @override
  String personalBest(int n) {
    return 'Your best: $n';
  }

  @override
  String get newRecord => 'New record!';

  @override
  String get placeBoat => 'Boat';

  @override
  String get lockedHint => 'Clear the previous level to unlock';

  @override
  String get hintNoAd => 'Couldn\'t load the video. Try again in a moment.';

  @override
  String daily(String id) {
    return 'Daily puzzle ($id)';
  }

  @override
  String get dailyDoneLabel => 'Daily puzzle done';

  @override
  String dailyStreak(int n) {
    return '$n-day streak';
  }

  @override
  String dailyCleared(int n) {
    return 'Daily puzzle done! $n-day streak';
  }

  @override
  String get dailyAbout => 'Clear it with 3 stars';

  @override
  String get records => 'Records';

  @override
  String get statClears => 'Levels cleared';

  @override
  String get statStars => 'Stars';

  @override
  String get statThree => '3-star levels';

  @override
  String get statEscapes => 'Escapes';

  @override
  String get statTrips => 'Boat trips';

  @override
  String get statStreak => 'Longest daily streak';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String achUnlocked(String name) {
    return 'Achievement: $name';
  }

  @override
  String nightmareLock(int need, int now) {
    return 'Collect ★$need in worlds 1-7 to unlock (now ★$now)';
  }

  @override
  String get ach_firstClear => 'First escort';

  @override
  String get achDesc_firstClear => 'Clear your first level';

  @override
  String get ach_clears10 => 'Rookie guard';

  @override
  String get achDesc_clears10 => 'Clear 10 levels';

  @override
  String get ach_clears60 => 'Seasoned guard';

  @override
  String get achDesc_clears60 => 'Clear 60 levels';

  @override
  String get ach_allClear => 'Legendary guard';

  @override
  String get achDesc_allClear => 'Clear all 120 levels';

  @override
  String get ach_threeStar30 => 'Shortcut master';

  @override
  String get achDesc_threeStar30 => 'Get 3 stars on 30 levels';

  @override
  String get ach_threeStarAll => 'Perfect escort';

  @override
  String get achDesc_threeStarAll => 'Get 3 stars on every level';

  @override
  String get ach_escape10 => 'Oops';

  @override
  String get achDesc_escape10 => 'Let prisoners escape 10 times';

  @override
  String get ach_escape100 => 'Jailbreak hotspot';

  @override
  String get achDesc_escape100 => 'Let prisoners escape 100 times';

  @override
  String get ach_nightmareThree => 'Beyond the nightmare';

  @override
  String get achDesc_nightmareThree => 'Get 3 stars on a Nightmare level';

  @override
  String get ach_dailyWeek => 'Daily patrol';

  @override
  String get achDesc_dailyWeek => 'Finish the daily puzzle 7 days in a row';

  @override
  String startGoal(int n) {
    return '★3 in $n trips';
  }

  @override
  String get resumed => 'Resumed';

  @override
  String triesClear(int n) {
    return 'Cleared on try #$n!';
  }

  @override
  String worldClear(int no, String name, int got, int max) {
    return 'World $no \"$name\" cleared! ★$got/$max';
  }

  @override
  String nightmareNeed(int n) {
    return '$n more ★ to unlock Nightmare';
  }

  @override
  String get taunt1 => 'See ya!';

  @override
  String get taunt2 => 'Bye-bye!';

  @override
  String get taunt3 => 'Heh heh!';

  @override
  String get taunt4 => 'Freedom!';

  @override
  String timeLine(String t) {
    return 'Time $t';
  }

  @override
  String bestTimeLine(String t) {
    return 'Best $t';
  }

  @override
  String get fastest => 'Fastest!';

  @override
  String get noUndoClear => 'Cleared without undo';

  @override
  String rankUp(String name) {
    return 'Promoted: $name';
  }

  @override
  String rankNext(int n) {
    return '★$n to next rank';
  }

  @override
  String get reminder => 'Daily puzzle reminder';

  @override
  String get reminderBody => 'Today\'s puzzle is ready. Clear it with 3 stars!';

  @override
  String get reminderDenied =>
      'Notifications are off. Allow them in your iPhone Settings.';

  @override
  String get rank0 => 'Cadet';

  @override
  String get rank1 => 'Officer';

  @override
  String get rank2 => 'Senior Officer';

  @override
  String get rank3 => 'Sergeant';

  @override
  String get rank4 => 'Lieutenant';

  @override
  String get rank5 => 'Captain';

  @override
  String get rank6 => 'Major';

  @override
  String get rank7 => 'Commander';

  @override
  String get rank8 => 'Deputy Chief';

  @override
  String get rank9 => 'Commissioner';

  @override
  String get ach_perfect1 => 'Riverside master';

  @override
  String get achDesc_perfect1 => 'Get 3 stars on every level in world 1';

  @override
  String get ach_perfect2 => 'The Chief master';

  @override
  String get achDesc_perfect2 => 'Get 3 stars on every level in world 2';

  @override
  String get ach_perfect3 => 'Handcuffs master';

  @override
  String get achDesc_perfect3 => 'Get 3 stars on every level in world 3';

  @override
  String get ach_perfect4 => 'The Boss master';

  @override
  String get achDesc_perfect4 => 'Get 3 stars on every level in world 4';

  @override
  String get ach_perfect5 => 'K9 Unit master';

  @override
  String get achDesc_perfect5 => 'Get 3 stars on every level in world 5';

  @override
  String get ach_perfect6 => 'The Island master';

  @override
  String get achDesc_perfect6 => 'Get 3 stars on every level in world 6';

  @override
  String get ach_perfect7 => 'All Hands master';

  @override
  String get achDesc_perfect7 => 'Get 3 stars on every level in world 7';

  @override
  String get ach_perfect8 => 'Nightmare master';

  @override
  String get achDesc_perfect8 => 'Get 3 stars on every level in world 8';

  @override
  String get ach_firstTryThree => 'One-shot escort';

  @override
  String get achDesc_firstTryThree => 'Get 3 stars on your first try';

  @override
  String get ach_nightmareNoUndo => 'No turning back';

  @override
  String get achDesc_nightmareNoUndo => 'Clear a Nightmare level without undo';
}
