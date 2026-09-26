// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '護送ボート';

  @override
  String get tagline => '囚人を向こう岸へ。逃がすな。';

  @override
  String get start => 'はじめる';

  @override
  String continueAt(String id) {
    return 'つづきから（$id）';
  }

  @override
  String get chooseStage => 'ステージを選ぶ';

  @override
  String get stages => 'ステージ';

  @override
  String levelLocked(String id) {
    return '$id、まだ遊べない';
  }

  @override
  String levelStars(String id, int stars) {
    return '$id、星$stars';
  }

  @override
  String get placeLeft => '手前の岸';

  @override
  String get placeRight => '向こう岸';

  @override
  String get placeIsland => '中州';

  @override
  String goTo(String place) {
    return '$placeへ';
  }

  @override
  String boatIsAt(String place) {
    return '舟は$placeにある';
  }

  @override
  String boatSeats(int n) {
    return '舟は$n席まで';
  }

  @override
  String boatSeatsCuffed(int n) {
    return '舟は$n席まで（手錠の2人は2席）';
  }

  @override
  String get needSomeone => '先に誰かを舟に乗せる';

  @override
  String get noRower => '舟を漕げるのは警官と看守長だけ';

  @override
  String get notAdjacent => 'そこへは直接行けない';

  @override
  String get unsolvable => 'ここからは渡しきれない。一手戻して';

  @override
  String hintSay(String load, String place) {
    return '$loadで$placeへ';
  }

  @override
  String get hintJoin => '＋';

  @override
  String get undo => '一手戻す';

  @override
  String get restart => '最初から';

  @override
  String get hint => 'ヒント';

  @override
  String failBoat(int guard, int weight) {
    return '舟の上で 見張り$guard人分に 囚人$weight人分。\n見張りが足りず、川へ飛び込んだ。';
  }

  @override
  String failAlone(String place) {
    return '$placeに囚人だけが残った。';
  }

  @override
  String failBank(String place, int guard, int weight) {
    return '$placeで 見張り$guard人分に 囚人$weight人分。\n見張りが足りなかった。';
  }

  @override
  String personLabel(String name, String where) {
    return '$name、$where';
  }

  @override
  String get onBoat => '舟の上';

  @override
  String get coachTap => '警官や囚人をタップすると舟に乗る';

  @override
  String coachGo(String button) {
    return '乗せたら、下の「$button」を押す';
  }

  @override
  String tallyGuard(int n) {
    return '見張り$n';
  }

  @override
  String tallyPrisoner(int n) {
    return '囚人$n';
  }

  @override
  String get backToStages => 'ステージ選択へ';

  @override
  String tripsCount(int n) {
    return '$n回';
  }

  @override
  String par(int n) {
    return '最短 $n回';
  }

  @override
  String get escaped => '脱走された';

  @override
  String get cleared => '全員護送';

  @override
  String get noteHint => 'ヒントを使ったので星2つまで';

  @override
  String get noteBest => '最短で渡りきった';

  @override
  String noteParFor3(int n) {
    return '$n回で渡れば星3つ';
  }

  @override
  String crossedIn(int n) {
    return '$n回で渡りきった';
  }

  @override
  String get nextLevel => '次の面へ';

  @override
  String allCleared(int n) {
    return '全$n面 クリア';
  }

  @override
  String get again => 'もう一度';

  @override
  String get stageSelect => 'ステージ選択';

  @override
  String get gotIt => 'わかった';

  @override
  String get rulesTitle => '決まり';

  @override
  String rulesBody(int cap) {
    return '・岸でも舟の上でも、見張りが囚人より少ないと逃げる\n・見張りのいない所に囚人を残しても逃げる\n・舟は$cap席。漕げる人がいないと出せない';
  }

  @override
  String get rulesIsland => '・舟は「手前の岸と中州」「中州と向こう岸」の間を行き来する。岸から岸へ直接は行けない';

  @override
  String get rolePolice => '警官';

  @override
  String get roleChief => '看守長';

  @override
  String get roleDog => '警察犬';

  @override
  String get rolePrisoner => '囚人';

  @override
  String get roleBoss => 'ボス';

  @override
  String get roleCuffed => '手錠の2人';

  @override
  String get descPolice => '見張り1人分。舟を漕げる';

  @override
  String get descChief => '見張り2人分。舟を漕げる';

  @override
  String get descDog => '見張り1人分。舟は漕げない';

  @override
  String get descPrisoner => '見張りが1人分要る';

  @override
  String get descBoss => '1人で見張りが2人分要る';

  @override
  String get descCuffed => '2人で見張り2人分。舟の席を2つ使う';

  @override
  String get world1 => '川べり';

  @override
  String get world2 => '看守長';

  @override
  String get world3 => '手錠';

  @override
  String get world4 => 'ボス';

  @override
  String get world5 => '警察犬';

  @override
  String get world6 => '中州';

  @override
  String get intro1Title => '囚人を向こう岸へ';

  @override
  String get intro1Body =>
      '警官や囚人をタップして舟に乗せ、「向こう岸へ」で渡す。\n岸でも舟の上でも、囚人より警官が少ないと逃げる。\n警官のいない岸に囚人を残しても逃げる。';

  @override
  String get intro2Title => '看守長が来た';

  @override
  String get intro2Body => '看守長は1人で囚人2人分を見張れる。舟も漕げる。';

  @override
  String get intro3Title => '手錠の2人';

  @override
  String get intro3Body => '2人はつながっていて離れられない。見張りは2人分、舟の席も2つ使う。';

  @override
  String get intro4Title => 'ボスが来た';

  @override
  String get intro4Body => 'ボスは1人でも見張りが2人分いる。舟の上でも同じ。';

  @override
  String get intro5Title => '警察犬が来た';

  @override
  String get intro5Body => '警察犬は囚人1人を見張れる。でも舟は漕げない。';

  @override
  String get intro6Title => '川に中州がある';

  @override
  String get intro6Body =>
      '舟は「手前の岸と中州」「中州と向こう岸」の間を行き来する。岸から岸へ直接は行けない。\n中州に人を残すこともできる。中州でも見張りが要る。';

  @override
  String get world7 => '総力戦';

  @override
  String get world8 => '鬼門';

  @override
  String get intro7Title => '総力戦';

  @override
  String get intro7Body => '中州に、看守長も警察犬もボスも手錠の2人も。\nこれまでの決まりを全部使って渡しきる。';

  @override
  String get intro8Title => '鬼門';

  @override
  String get intro8Body => '全部の組み合わせを解いて選び抜いた、最難関だけの舞台。\n最短で渡れたら本物。';
}
