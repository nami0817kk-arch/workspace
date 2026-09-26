import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'護送ボート'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In ja, this message translates to:
  /// **'囚人を向こう岸へ。逃がすな。'**
  String get tagline;

  /// No description provided for @start.
  ///
  /// In ja, this message translates to:
  /// **'はじめる'**
  String get start;

  /// No description provided for @continueAt.
  ///
  /// In ja, this message translates to:
  /// **'つづきから（{id}）'**
  String continueAt(String id);

  /// No description provided for @chooseStage.
  ///
  /// In ja, this message translates to:
  /// **'ステージを選ぶ'**
  String get chooseStage;

  /// No description provided for @stages.
  ///
  /// In ja, this message translates to:
  /// **'ステージ'**
  String get stages;

  /// No description provided for @levelLocked.
  ///
  /// In ja, this message translates to:
  /// **'{id}、まだ遊べない'**
  String levelLocked(String id);

  /// No description provided for @levelStars.
  ///
  /// In ja, this message translates to:
  /// **'{id}、星{stars}'**
  String levelStars(String id, int stars);

  /// No description provided for @placeLeft.
  ///
  /// In ja, this message translates to:
  /// **'手前の岸'**
  String get placeLeft;

  /// No description provided for @placeRight.
  ///
  /// In ja, this message translates to:
  /// **'向こう岸'**
  String get placeRight;

  /// No description provided for @placeIsland.
  ///
  /// In ja, this message translates to:
  /// **'中州'**
  String get placeIsland;

  /// No description provided for @goTo.
  ///
  /// In ja, this message translates to:
  /// **'{place}へ'**
  String goTo(String place);

  /// No description provided for @boatIsAt.
  ///
  /// In ja, this message translates to:
  /// **'舟は{place}にある'**
  String boatIsAt(String place);

  /// No description provided for @boatSeats.
  ///
  /// In ja, this message translates to:
  /// **'舟は{n}席まで'**
  String boatSeats(int n);

  /// No description provided for @boatSeatsCuffed.
  ///
  /// In ja, this message translates to:
  /// **'舟は{n}席まで（手錠の2人は2席）'**
  String boatSeatsCuffed(int n);

  /// No description provided for @needSomeone.
  ///
  /// In ja, this message translates to:
  /// **'先に誰かを舟に乗せる'**
  String get needSomeone;

  /// No description provided for @noRower.
  ///
  /// In ja, this message translates to:
  /// **'舟を漕げるのは警官と看守長だけ'**
  String get noRower;

  /// No description provided for @notAdjacent.
  ///
  /// In ja, this message translates to:
  /// **'そこへは直接行けない'**
  String get notAdjacent;

  /// No description provided for @unsolvable.
  ///
  /// In ja, this message translates to:
  /// **'ここからは渡しきれない。一手戻して'**
  String get unsolvable;

  /// No description provided for @hintSay.
  ///
  /// In ja, this message translates to:
  /// **'{load}で{place}へ'**
  String hintSay(String load, String place);

  /// No description provided for @hintJoin.
  ///
  /// In ja, this message translates to:
  /// **'＋'**
  String get hintJoin;

  /// No description provided for @undo.
  ///
  /// In ja, this message translates to:
  /// **'一手戻す'**
  String get undo;

  /// No description provided for @restart.
  ///
  /// In ja, this message translates to:
  /// **'最初から'**
  String get restart;

  /// No description provided for @hint.
  ///
  /// In ja, this message translates to:
  /// **'ヒント'**
  String get hint;

  /// No description provided for @failBoat.
  ///
  /// In ja, this message translates to:
  /// **'舟の上で 見張り{guard}人分に 囚人{weight}人分。\n見張りが足りず、川へ飛び込んだ。'**
  String failBoat(int guard, int weight);

  /// No description provided for @failAlone.
  ///
  /// In ja, this message translates to:
  /// **'{place}に囚人だけが残った。'**
  String failAlone(String place);

  /// No description provided for @failBank.
  ///
  /// In ja, this message translates to:
  /// **'{place}で 見張り{guard}人分に 囚人{weight}人分。\n見張りが足りなかった。'**
  String failBank(String place, int guard, int weight);

  /// No description provided for @personLabel.
  ///
  /// In ja, this message translates to:
  /// **'{name}、{where}'**
  String personLabel(String name, String where);

  /// No description provided for @onBoat.
  ///
  /// In ja, this message translates to:
  /// **'舟の上'**
  String get onBoat;

  /// No description provided for @coachTap.
  ///
  /// In ja, this message translates to:
  /// **'警官や囚人をタップすると舟に乗る'**
  String get coachTap;

  /// No description provided for @coachGo.
  ///
  /// In ja, this message translates to:
  /// **'乗せたら、下の「{button}」を押す'**
  String coachGo(String button);

  /// No description provided for @tallyGuard.
  ///
  /// In ja, this message translates to:
  /// **'見張り{n}'**
  String tallyGuard(int n);

  /// No description provided for @tallyPrisoner.
  ///
  /// In ja, this message translates to:
  /// **'囚人{n}'**
  String tallyPrisoner(int n);

  /// No description provided for @backToStages.
  ///
  /// In ja, this message translates to:
  /// **'ステージ選択へ'**
  String get backToStages;

  /// No description provided for @tripsCount.
  ///
  /// In ja, this message translates to:
  /// **'{n}回'**
  String tripsCount(int n);

  /// No description provided for @par.
  ///
  /// In ja, this message translates to:
  /// **'最短 {n}回'**
  String par(int n);

  /// No description provided for @escaped.
  ///
  /// In ja, this message translates to:
  /// **'脱走された'**
  String get escaped;

  /// No description provided for @cleared.
  ///
  /// In ja, this message translates to:
  /// **'全員護送'**
  String get cleared;

  /// No description provided for @noteHint.
  ///
  /// In ja, this message translates to:
  /// **'ヒントを使ったので星2つまで'**
  String get noteHint;

  /// No description provided for @noteBest.
  ///
  /// In ja, this message translates to:
  /// **'最短で渡りきった'**
  String get noteBest;

  /// No description provided for @noteParFor3.
  ///
  /// In ja, this message translates to:
  /// **'{n}回で渡れば星3つ'**
  String noteParFor3(int n);

  /// No description provided for @crossedIn.
  ///
  /// In ja, this message translates to:
  /// **'{n}回で渡りきった'**
  String crossedIn(int n);

  /// No description provided for @nextLevel.
  ///
  /// In ja, this message translates to:
  /// **'次の面へ'**
  String get nextLevel;

  /// No description provided for @allCleared.
  ///
  /// In ja, this message translates to:
  /// **'全{n}面 クリア'**
  String allCleared(int n);

  /// No description provided for @again.
  ///
  /// In ja, this message translates to:
  /// **'もう一度'**
  String get again;

  /// No description provided for @stageSelect.
  ///
  /// In ja, this message translates to:
  /// **'ステージ選択'**
  String get stageSelect;

  /// No description provided for @gotIt.
  ///
  /// In ja, this message translates to:
  /// **'わかった'**
  String get gotIt;

  /// No description provided for @rulesTitle.
  ///
  /// In ja, this message translates to:
  /// **'決まり'**
  String get rulesTitle;

  /// No description provided for @rulesBody.
  ///
  /// In ja, this message translates to:
  /// **'・岸でも舟の上でも、見張りが囚人より少ないと逃げる\n・見張りのいない所に囚人を残しても逃げる\n・舟は{cap}席。漕げる人がいないと出せない'**
  String rulesBody(int cap);

  /// No description provided for @rulesIsland.
  ///
  /// In ja, this message translates to:
  /// **'・舟は 手前の岸 ↔ 中州 ↔ 向こう岸 を1区間ずつ進む'**
  String get rulesIsland;

  /// No description provided for @rolePolice.
  ///
  /// In ja, this message translates to:
  /// **'警官'**
  String get rolePolice;

  /// No description provided for @roleChief.
  ///
  /// In ja, this message translates to:
  /// **'看守長'**
  String get roleChief;

  /// No description provided for @roleDog.
  ///
  /// In ja, this message translates to:
  /// **'警察犬'**
  String get roleDog;

  /// No description provided for @rolePrisoner.
  ///
  /// In ja, this message translates to:
  /// **'囚人'**
  String get rolePrisoner;

  /// No description provided for @roleBoss.
  ///
  /// In ja, this message translates to:
  /// **'ボス'**
  String get roleBoss;

  /// No description provided for @roleCuffed.
  ///
  /// In ja, this message translates to:
  /// **'手錠の2人'**
  String get roleCuffed;

  /// No description provided for @descPolice.
  ///
  /// In ja, this message translates to:
  /// **'見張り1人分。舟を漕げる'**
  String get descPolice;

  /// No description provided for @descChief.
  ///
  /// In ja, this message translates to:
  /// **'見張り2人分。舟を漕げる'**
  String get descChief;

  /// No description provided for @descDog.
  ///
  /// In ja, this message translates to:
  /// **'見張り1人分。舟は漕げない'**
  String get descDog;

  /// No description provided for @descPrisoner.
  ///
  /// In ja, this message translates to:
  /// **'見張りが1人分要る'**
  String get descPrisoner;

  /// No description provided for @descBoss.
  ///
  /// In ja, this message translates to:
  /// **'1人で見張りが2人分要る'**
  String get descBoss;

  /// No description provided for @descCuffed.
  ///
  /// In ja, this message translates to:
  /// **'2人で見張り2人分。舟の席を2つ使う'**
  String get descCuffed;

  /// No description provided for @world1.
  ///
  /// In ja, this message translates to:
  /// **'川べり'**
  String get world1;

  /// No description provided for @world2.
  ///
  /// In ja, this message translates to:
  /// **'看守長'**
  String get world2;

  /// No description provided for @world3.
  ///
  /// In ja, this message translates to:
  /// **'手錠'**
  String get world3;

  /// No description provided for @world4.
  ///
  /// In ja, this message translates to:
  /// **'ボス'**
  String get world4;

  /// No description provided for @world5.
  ///
  /// In ja, this message translates to:
  /// **'警察犬'**
  String get world5;

  /// No description provided for @world6.
  ///
  /// In ja, this message translates to:
  /// **'中州'**
  String get world6;

  /// No description provided for @intro1Title.
  ///
  /// In ja, this message translates to:
  /// **'囚人を向こう岸へ'**
  String get intro1Title;

  /// No description provided for @intro1Body.
  ///
  /// In ja, this message translates to:
  /// **'警官や囚人をタップして舟に乗せ、「向こう岸へ」で渡す。\n岸でも舟の上でも、囚人より警官が少ないと逃げる。\n警官のいない岸に囚人を残しても逃げる。'**
  String get intro1Body;

  /// No description provided for @intro2Title.
  ///
  /// In ja, this message translates to:
  /// **'看守長が来た'**
  String get intro2Title;

  /// No description provided for @intro2Body.
  ///
  /// In ja, this message translates to:
  /// **'看守長は1人で囚人2人分を見張れる。舟も漕げる。'**
  String get intro2Body;

  /// No description provided for @intro3Title.
  ///
  /// In ja, this message translates to:
  /// **'手錠の2人'**
  String get intro3Title;

  /// No description provided for @intro3Body.
  ///
  /// In ja, this message translates to:
  /// **'2人はつながっていて離れられない。見張りは2人分、舟の席も2つ使う。'**
  String get intro3Body;

  /// No description provided for @intro4Title.
  ///
  /// In ja, this message translates to:
  /// **'ボスが来た'**
  String get intro4Title;

  /// No description provided for @intro4Body.
  ///
  /// In ja, this message translates to:
  /// **'ボスは1人でも見張りが2人分いる。舟の上でも同じ。'**
  String get intro4Body;

  /// No description provided for @intro5Title.
  ///
  /// In ja, this message translates to:
  /// **'警察犬が来た'**
  String get intro5Title;

  /// No description provided for @intro5Body.
  ///
  /// In ja, this message translates to:
  /// **'警察犬は囚人1人を見張れる。でも舟は漕げない。'**
  String get intro5Body;

  /// No description provided for @intro6Title.
  ///
  /// In ja, this message translates to:
  /// **'川に中州がある'**
  String get intro6Title;

  /// No description provided for @intro6Body.
  ///
  /// In ja, this message translates to:
  /// **'舟は 手前の岸 ↔ 中州 ↔ 向こう岸 を1区間ずつ進む。\n中州に人を残すこともできる。中州でも見張りが要る。'**
  String get intro6Body;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
