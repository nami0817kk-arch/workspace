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
  /// **'囚人を舟で向こう岸へ。1人も逃がすな。'**
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
  /// **'・舟は「手前の岸と中州」「中州と向こう岸」の間を行き来する。岸から岸へ直接は行けない'**
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
  /// **'舟は「手前の岸と中州」「中州と向こう岸」の間を行き来する。岸から岸へ直接は行けない。\n中州に人を残すこともできる。中州でも見張りが要る。'**
  String get intro6Body;

  /// No description provided for @world7.
  ///
  /// In ja, this message translates to:
  /// **'総力戦'**
  String get world7;

  /// No description provided for @world8.
  ///
  /// In ja, this message translates to:
  /// **'鬼門'**
  String get world8;

  /// No description provided for @intro7Title.
  ///
  /// In ja, this message translates to:
  /// **'総力戦'**
  String get intro7Title;

  /// No description provided for @intro7Body.
  ///
  /// In ja, this message translates to:
  /// **'中州に、看守長も警察犬もボスも手錠の2人も。\nこれまでの決まりを全部使って渡しきる。'**
  String get intro7Body;

  /// No description provided for @intro8Title.
  ///
  /// In ja, this message translates to:
  /// **'鬼門'**
  String get intro8Title;

  /// No description provided for @intro8Body.
  ///
  /// In ja, this message translates to:
  /// **'全部の組み合わせを解いて選び抜いた、最難関だけの舞台。\n最短で渡れたら本物。'**
  String get intro8Body;

  /// No description provided for @hintWithAd.
  ///
  /// In ja, this message translates to:
  /// **'動画でヒント'**
  String get hintWithAd;

  /// No description provided for @hintDeclined.
  ///
  /// In ja, this message translates to:
  /// **'動画を最後まで見るとヒントが出る'**
  String get hintDeclined;

  /// No description provided for @removeAds.
  ///
  /// In ja, this message translates to:
  /// **'広告を消す（{price}）'**
  String removeAds(String price);

  /// No description provided for @restorePurchases.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元'**
  String get restorePurchases;

  /// No description provided for @adFreeOn.
  ///
  /// In ja, this message translates to:
  /// **'広告なし'**
  String get adFreeOn;

  /// No description provided for @purchaseThanks.
  ///
  /// In ja, this message translates to:
  /// **'広告を消しました。ご購入ありがとうございます！'**
  String get purchaseThanks;

  /// No description provided for @purchaseRestored.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元しました'**
  String get purchaseRestored;

  /// No description provided for @purchaseNothing.
  ///
  /// In ja, this message translates to:
  /// **'復元できる購入が見つかりませんでした。購入したときの Apple ID でサインインしているか確かめてください'**
  String get purchaseNothing;

  /// No description provided for @purchaseFailed.
  ///
  /// In ja, this message translates to:
  /// **'購入できませんでした。時間をおいてもう一度お試しください'**
  String get purchaseFailed;

  /// No description provided for @kicker.
  ///
  /// In ja, this message translates to:
  /// **'脱獄させるな！'**
  String get kicker;

  /// No description provided for @settingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @settingSound.
  ///
  /// In ja, this message translates to:
  /// **'効果音'**
  String get settingSound;

  /// No description provided for @settingHaptics.
  ///
  /// In ja, this message translates to:
  /// **'振動'**
  String get settingHaptics;

  /// No description provided for @licenses.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス'**
  String get licenses;

  /// No description provided for @resetProgress.
  ///
  /// In ja, this message translates to:
  /// **'進み具合を消す'**
  String get resetProgress;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'進み具合を消しますか？'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'星・記録・実績がすべて消えます。「広告を消す」の購入はそのまま残ります。'**
  String get resetConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get cancel;

  /// No description provided for @doReset.
  ///
  /// In ja, this message translates to:
  /// **'消す'**
  String get doReset;

  /// No description provided for @resetDone.
  ///
  /// In ja, this message translates to:
  /// **'進み具合を消しました'**
  String get resetDone;

  /// No description provided for @personalBest.
  ///
  /// In ja, this message translates to:
  /// **'自己ベスト {n}回'**
  String personalBest(int n);

  /// No description provided for @newRecord.
  ///
  /// In ja, this message translates to:
  /// **'新記録！'**
  String get newRecord;

  /// No description provided for @placeBoat.
  ///
  /// In ja, this message translates to:
  /// **'舟'**
  String get placeBoat;

  /// No description provided for @lockedHint.
  ///
  /// In ja, this message translates to:
  /// **'前の面を解くと開く'**
  String get lockedHint;

  /// No description provided for @hintNoAd.
  ///
  /// In ja, this message translates to:
  /// **'動画の準備ができていません。少し待ってもう一度'**
  String get hintNoAd;

  /// No description provided for @daily.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問（{id}）'**
  String daily(String id);

  /// No description provided for @dailyDoneLabel.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問 達成済み'**
  String get dailyDoneLabel;

  /// No description provided for @dailyStreak.
  ///
  /// In ja, this message translates to:
  /// **'連続{n}日'**
  String dailyStreak(int n);

  /// No description provided for @dailyCleared.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問 達成！ 連続{n}日'**
  String dailyCleared(int n);

  /// No description provided for @dailyAbout.
  ///
  /// In ja, this message translates to:
  /// **'星3で解くと達成'**
  String get dailyAbout;

  /// No description provided for @records.
  ///
  /// In ja, this message translates to:
  /// **'記録'**
  String get records;

  /// No description provided for @statClears.
  ///
  /// In ja, this message translates to:
  /// **'解いた面'**
  String get statClears;

  /// No description provided for @statStars.
  ///
  /// In ja, this message translates to:
  /// **'星'**
  String get statStars;

  /// No description provided for @statThree.
  ///
  /// In ja, this message translates to:
  /// **'星3の面'**
  String get statThree;

  /// No description provided for @statEscapes.
  ///
  /// In ja, this message translates to:
  /// **'脱走された回数'**
  String get statEscapes;

  /// No description provided for @statTrips.
  ///
  /// In ja, this message translates to:
  /// **'舟を出した回数'**
  String get statTrips;

  /// No description provided for @statStreak.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問の最長連続'**
  String get statStreak;

  /// No description provided for @achievementsTitle.
  ///
  /// In ja, this message translates to:
  /// **'実績'**
  String get achievementsTitle;

  /// No description provided for @achUnlocked.
  ///
  /// In ja, this message translates to:
  /// **'実績: {name}'**
  String achUnlocked(String name);

  /// No description provided for @nightmareLock.
  ///
  /// In ja, this message translates to:
  /// **'舞台1〜7で★{need}を集めると開く（いま★{now}）'**
  String nightmareLock(int need, int now);

  /// No description provided for @ach_firstClear.
  ///
  /// In ja, this message translates to:
  /// **'初めての護送'**
  String get ach_firstClear;

  /// No description provided for @achDesc_firstClear.
  ///
  /// In ja, this message translates to:
  /// **'最初の面を解く'**
  String get achDesc_firstClear;

  /// No description provided for @ach_clears10.
  ///
  /// In ja, this message translates to:
  /// **'見習い看守'**
  String get ach_clears10;

  /// No description provided for @achDesc_clears10.
  ///
  /// In ja, this message translates to:
  /// **'10面を解く'**
  String get achDesc_clears10;

  /// No description provided for @ach_clears60.
  ///
  /// In ja, this message translates to:
  /// **'一人前の看守'**
  String get ach_clears60;

  /// No description provided for @achDesc_clears60.
  ///
  /// In ja, this message translates to:
  /// **'60面を解く'**
  String get achDesc_clears60;

  /// No description provided for @ach_allClear.
  ///
  /// In ja, this message translates to:
  /// **'伝説の看守'**
  String get ach_allClear;

  /// No description provided for @achDesc_allClear.
  ///
  /// In ja, this message translates to:
  /// **'全120面を解く'**
  String get achDesc_allClear;

  /// No description provided for @ach_threeStar30.
  ///
  /// In ja, this message translates to:
  /// **'最短の達人'**
  String get ach_threeStar30;

  /// No description provided for @achDesc_threeStar30.
  ///
  /// In ja, this message translates to:
  /// **'30面を星3で解く'**
  String get achDesc_threeStar30;

  /// No description provided for @ach_threeStarAll.
  ///
  /// In ja, this message translates to:
  /// **'完全護送'**
  String get ach_threeStarAll;

  /// No description provided for @achDesc_threeStarAll.
  ///
  /// In ja, this message translates to:
  /// **'全面を星3で解く'**
  String get achDesc_threeStarAll;

  /// No description provided for @ach_escape10.
  ///
  /// In ja, this message translates to:
  /// **'逃げられ上手'**
  String get ach_escape10;

  /// No description provided for @achDesc_escape10.
  ///
  /// In ja, this message translates to:
  /// **'10回脱走される'**
  String get achDesc_escape10;

  /// No description provided for @ach_escape100.
  ///
  /// In ja, this message translates to:
  /// **'脱獄の名所'**
  String get ach_escape100;

  /// No description provided for @achDesc_escape100.
  ///
  /// In ja, this message translates to:
  /// **'100回脱走される'**
  String get achDesc_escape100;

  /// No description provided for @ach_nightmareThree.
  ///
  /// In ja, this message translates to:
  /// **'鬼門を越えて'**
  String get ach_nightmareThree;

  /// No description provided for @achDesc_nightmareThree.
  ///
  /// In ja, this message translates to:
  /// **'鬼門の面を星3で解く'**
  String get achDesc_nightmareThree;

  /// No description provided for @ach_dailyWeek.
  ///
  /// In ja, this message translates to:
  /// **'毎日の見回り'**
  String get ach_dailyWeek;

  /// No description provided for @achDesc_dailyWeek.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問を7日続けて達成'**
  String get achDesc_dailyWeek;

  /// No description provided for @startGoal.
  ///
  /// In ja, this message translates to:
  /// **'最短{n}回で★3'**
  String startGoal(int n);

  /// No description provided for @resumed.
  ///
  /// In ja, this message translates to:
  /// **'続きから'**
  String get resumed;

  /// No description provided for @triesClear.
  ///
  /// In ja, this message translates to:
  /// **'{n}回目の挑戦でクリア！'**
  String triesClear(int n);

  /// No description provided for @worldClear.
  ///
  /// In ja, this message translates to:
  /// **'舞台{no}「{name}」クリア！ ★{got}/{max}'**
  String worldClear(int no, String name, int got, int max);

  /// No description provided for @nightmareNeed.
  ///
  /// In ja, this message translates to:
  /// **'鬼門まで あと★{n}'**
  String nightmareNeed(int n);

  /// No description provided for @taunt1.
  ///
  /// In ja, this message translates to:
  /// **'あばよ！'**
  String get taunt1;

  /// No description provided for @taunt2.
  ///
  /// In ja, this message translates to:
  /// **'お先に〜'**
  String get taunt2;

  /// No description provided for @taunt3.
  ///
  /// In ja, this message translates to:
  /// **'へへっ'**
  String get taunt3;

  /// No description provided for @taunt4.
  ///
  /// In ja, this message translates to:
  /// **'自由だー！'**
  String get taunt4;

  /// No description provided for @timeLine.
  ///
  /// In ja, this message translates to:
  /// **'タイム {t}'**
  String timeLine(String t);

  /// No description provided for @bestTimeLine.
  ///
  /// In ja, this message translates to:
  /// **'最速 {t}'**
  String bestTimeLine(String t);

  /// No description provided for @fastest.
  ///
  /// In ja, this message translates to:
  /// **'最速！'**
  String get fastest;

  /// No description provided for @noUndoClear.
  ///
  /// In ja, this message translates to:
  /// **'一手も戻さずにクリア'**
  String get noUndoClear;

  /// No description provided for @rankUp.
  ///
  /// In ja, this message translates to:
  /// **'階級が上がった: {name}'**
  String rankUp(String name);

  /// No description provided for @rankNext.
  ///
  /// In ja, this message translates to:
  /// **'次の階級まで ★{n}'**
  String rankNext(int n);

  /// No description provided for @reminder.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問のお知らせ'**
  String get reminder;

  /// No description provided for @reminderBody.
  ///
  /// In ja, this message translates to:
  /// **'今日の1問が届いています。星3で達成！'**
  String get reminderBody;

  /// No description provided for @reminderDenied.
  ///
  /// In ja, this message translates to:
  /// **'お知らせが許可されていません。iPhone の設定から許可してください'**
  String get reminderDenied;

  /// No description provided for @rank0.
  ///
  /// In ja, this message translates to:
  /// **'見習い'**
  String get rank0;

  /// No description provided for @rank1.
  ///
  /// In ja, this message translates to:
  /// **'巡査'**
  String get rank1;

  /// No description provided for @rank2.
  ///
  /// In ja, this message translates to:
  /// **'巡査長'**
  String get rank2;

  /// No description provided for @rank3.
  ///
  /// In ja, this message translates to:
  /// **'巡査部長'**
  String get rank3;

  /// No description provided for @rank4.
  ///
  /// In ja, this message translates to:
  /// **'警部補'**
  String get rank4;

  /// No description provided for @rank5.
  ///
  /// In ja, this message translates to:
  /// **'警部'**
  String get rank5;

  /// No description provided for @rank6.
  ///
  /// In ja, this message translates to:
  /// **'警視'**
  String get rank6;

  /// No description provided for @rank7.
  ///
  /// In ja, this message translates to:
  /// **'警視正'**
  String get rank7;

  /// No description provided for @rank8.
  ///
  /// In ja, this message translates to:
  /// **'警視長'**
  String get rank8;

  /// No description provided for @rank9.
  ///
  /// In ja, this message translates to:
  /// **'警視総監'**
  String get rank9;

  /// No description provided for @ach_perfect1.
  ///
  /// In ja, this message translates to:
  /// **'川べりの達人'**
  String get ach_perfect1;

  /// No description provided for @achDesc_perfect1.
  ///
  /// In ja, this message translates to:
  /// **'舞台1「川べり」の全面を星3で解く'**
  String get achDesc_perfect1;

  /// No description provided for @ach_perfect2.
  ///
  /// In ja, this message translates to:
  /// **'看守長の達人'**
  String get ach_perfect2;

  /// No description provided for @achDesc_perfect2.
  ///
  /// In ja, this message translates to:
  /// **'舞台2「看守長」の全面を星3で解く'**
  String get achDesc_perfect2;

  /// No description provided for @ach_perfect3.
  ///
  /// In ja, this message translates to:
  /// **'手錠の達人'**
  String get ach_perfect3;

  /// No description provided for @achDesc_perfect3.
  ///
  /// In ja, this message translates to:
  /// **'舞台3「手錠」の全面を星3で解く'**
  String get achDesc_perfect3;

  /// No description provided for @ach_perfect4.
  ///
  /// In ja, this message translates to:
  /// **'ボスの達人'**
  String get ach_perfect4;

  /// No description provided for @achDesc_perfect4.
  ///
  /// In ja, this message translates to:
  /// **'舞台4「ボス」の全面を星3で解く'**
  String get achDesc_perfect4;

  /// No description provided for @ach_perfect5.
  ///
  /// In ja, this message translates to:
  /// **'警察犬の達人'**
  String get ach_perfect5;

  /// No description provided for @achDesc_perfect5.
  ///
  /// In ja, this message translates to:
  /// **'舞台5「警察犬」の全面を星3で解く'**
  String get achDesc_perfect5;

  /// No description provided for @ach_perfect6.
  ///
  /// In ja, this message translates to:
  /// **'中州の達人'**
  String get ach_perfect6;

  /// No description provided for @achDesc_perfect6.
  ///
  /// In ja, this message translates to:
  /// **'舞台6「中州」の全面を星3で解く'**
  String get achDesc_perfect6;

  /// No description provided for @ach_perfect7.
  ///
  /// In ja, this message translates to:
  /// **'総力戦の達人'**
  String get ach_perfect7;

  /// No description provided for @achDesc_perfect7.
  ///
  /// In ja, this message translates to:
  /// **'舞台7「総力戦」の全面を星3で解く'**
  String get achDesc_perfect7;

  /// No description provided for @ach_perfect8.
  ///
  /// In ja, this message translates to:
  /// **'鬼門の達人'**
  String get ach_perfect8;

  /// No description provided for @achDesc_perfect8.
  ///
  /// In ja, this message translates to:
  /// **'舞台8「鬼門」の全面を星3で解く'**
  String get achDesc_perfect8;

  /// No description provided for @ach_firstTryThree.
  ///
  /// In ja, this message translates to:
  /// **'一発護送'**
  String get ach_firstTryThree;

  /// No description provided for @achDesc_firstTryThree.
  ///
  /// In ja, this message translates to:
  /// **'1回目の挑戦で星3を取る'**
  String get achDesc_firstTryThree;

  /// No description provided for @ach_nightmareNoUndo.
  ///
  /// In ja, this message translates to:
  /// **'戻らない勇気'**
  String get ach_nightmareNoUndo;

  /// No description provided for @achDesc_nightmareNoUndo.
  ///
  /// In ja, this message translates to:
  /// **'一手も戻さずに鬼門の面を解く'**
  String get achDesc_nightmareNoUndo;

  /// No description provided for @sep.
  ///
  /// In ja, this message translates to:
  /// **'・'**
  String get sep;

  /// No description provided for @colon.
  ///
  /// In ja, this message translates to:
  /// **'：'**
  String get colon;

  /// No description provided for @purchasePending.
  ///
  /// In ja, this message translates to:
  /// **'購入の手続きが保留中です。完了すると広告が消えます'**
  String get purchasePending;

  /// No description provided for @privacyPolicy.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get privacyPolicy;

  /// No description provided for @supportAndAdReport.
  ///
  /// In ja, this message translates to:
  /// **'お問い合わせ・広告の報告'**
  String get supportAndAdReport;

  /// No description provided for @linkFailed.
  ///
  /// In ja, this message translates to:
  /// **'開けなかった: {url}'**
  String linkFailed(String url);

  /// No description provided for @restoreFailed.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元できませんでした。時間をおいてもう一度お試しください'**
  String get restoreFailed;
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
