import 'bank_loan.dart';
import 'best_eleven.dart';
import 'budget_plan.dart';
import 'owner_event.dart';
import 'owner_goal.dart';
import 'owner_legacy.dart';
import 'club_infrastructure.dart';
import 'enum_json.dart';
import 'continental_cup.dart';
import 'contract_negotiation.dart';
import 'cup.dart';
import 'incoming_offer.dart';
import 'installment.dart';
import 'investment.dart';
import 'league.dart';
import 'live_match_progress.dart';
import 'news_item.dart';
import 'youth_league.dart';
import 'player.dart';
import 'pre_contract.dart';
import 'transfer_talk.dart';
import 'sd_brief.dart';
import 'staff_offer.dart';
import 'rival_owner.dart';
import 'press_question.dart';
import 'season_award.dart';
import 'season_record.dart';
import 'sponsor.dart';
import 'start_scenario.dart';
import 'club_vision.dart';
import 'ledger.dart';
import '../logic/economy_engine.dart';
import '../logic/league_rules.dart';
import '../logic/media_deals_engine.dart';
import '../logic/proposal_engine.dart';
import '../logic/policy_engine.dart';
import 'staff_member.dart';
import 'team.dart';
import '../l10n/tr.dart';

/// ゲーム難易度。ニューゲーム時に選択し、初期資金と理事会の目標順位の
/// 厳しさに影響する(旧セーブには存在しないためnormalへフォールバック)。
enum GameDifficulty { easy, normal, hard }

extension GameDifficultyInfo on GameDifficulty {
  String get label => switch (this) {
        GameDifficulty.easy => Tr.pick('イージー', 'Easy'),
        GameDifficulty.normal => Tr.pick('ノーマル', 'Normal'),
        GameDifficulty.hard => Tr.pick('ハード', 'Hard'),
      };

  String get description => switch (this) {
        GameDifficulty.easy => Tr.pick('初期資金1.5倍・理事会の目標が2つ緩い',
            "1.5x starting funds, and the board's target is two places softer"),
        GameDifficulty.normal => Tr.pick('標準バランス', 'The standard balance'),
        GameDifficulty.hard => Tr.pick('初期資金0.6倍・理事会の目標が1つ厳しい',
            "0.6x starting funds, and the board's target is one place harder"),
      };

  /// 初期資金に掛ける倍率。
  double get initialBudgetFactor => switch (this) {
        GameDifficulty.easy => 1.5,
        GameDifficulty.normal => 1.0,
        GameDifficulty.hard => 0.6,
      };

  /// 理事会の目標順位への補正(正の値ほど目標が緩くなる)。
  int get boardTargetDelta => switch (this) {
        GameDifficulty.easy => 2,
        GameDifficulty.normal => 0,
        GameDifficulty.hard => -1,
      };
}

class SaveGame {
  String clubName;
  String userTeamId;
  League league;

  /// 所属リーグの表示名(例: 「アルビオン・リーグ」)。
  ///
  /// これはセーブに保存される「データ」であってUIのラベルではないため、
  /// 翻訳の対象にしない。実際の値はニューゲーム時にリーグテーマから決まり、
  /// テーマ名自体が表示言語に応じて英語になる。既定値の'リーグ'は、この
  /// フィールドが存在しなかった頃の古いセーブを読むときのフォールバック。
  String leagueName;

  /// クラブ資金（万円）
  int budget;

  /// 理事会が今シーズンに求める目標順位（1が最高位）
  int boardTargetRank;

  /// 監督への信頼度（0-100）。0になると解任される。
  int confidence;

  /// 株主の期待(0-100)。資金のマイナスが続くと下がり、黒字でシーズンを
  /// 終えると上がる。[confidence](成績・順位に由来するサポーター側の期待)
  /// と引っ張り合う、オーナー型の2つ目のメーター。
  int shareholderExpectation;

  /// 手放した球団ごとの実績(殿堂)。売却後も消えない。
  List<OwnerLegacy> ownerLegacies;

  /// いま追っているオーナーの目標。決めていなければ null。
  OwnerGoal? ownerGoal;

  /// 広告のご褒美で貯めた営業ブーストの残り(節数)。1節ごとに1減る。
  int marketingBoostWeeks;

  /// シーズンごとの収支の記録(新しい順ではなく、シーズン順)。直近
  /// [maxLedgerSeasons] 季分だけ残す。
  List<SeasonLedger> ledgers;

  static const int maxLedgerSeasons = 10;

  /// このクラブのいる国の財務規則。
  RuleSet ruleSet;

  /// お金の桁の版。1 は全部が5部の規模だった頃、2 は部ごとに桁を変えた
  /// 後(economy_scale.dart)。読み込み時に 1 なら一度だけ換算して 2 にする。
  int economyVersion;

  /// 今のお金の桁の版。新しいゲームはこの版で始まる。
  static const int currentEconomyVersion = 2;

  /// 今シーズンの景気と、来シーズンの景気(予報)。
  EconomyPhase economyPhase;

  /// 移籍市場の相場(100 が基準)。
  int marketIndex;
  EconomyPhase economyNext;

  /// オーナーが選んだクラブの方針。シーズンの開幕前にだけ変えられる。
  ClubPolicy clubPolicy;

  /// シーズンごとのクラブ価値(万円)。シーズン終了時に記録する。
  Map<int, int> clubValueHistory;

  /// 目標「クラブ価値を2倍に」を選んだときのクラブ価値。選ぶまでは 0。
  int ownerGoalStartValue;

  /// オーナーの持分(%)。外部の株主へ売ると減る。51〜100。
  int ownerShare;

  /// 宿敵との過去のシーズンの通算戦績(勝・分・敗)。
  List<int> rivalPast;

  /// 新規開始で選んだシナリオと、クラブの年表。
  StartScenario scenario;
  List<TimelineEntry> timeline;

  /// 監督からの提案(承認待ち)と、却下して今季は出さない提案の id。
  List<ManagerProposal> proposals;
  List<String> declinedProposalIds;

  /// 経営アドバイザー。名前→レベル(0〜3)。
  Map<String, int> advisors;

  /// 投資案件。名前→完成までの残り季数(0は稼働中)。
  Map<String, int> projects;

  /// 永久欠番にした殿堂の選手の id。
  List<String> retiredNumberIds;

  /// 保険に入っているか、災害基金の残高(万円)、地域貢献のレベル(0〜5)。
  bool insured;

  /// オーナーの仕事を最後に打ったシーズン(仕事のID → シーズン)。
  /// 1シーズンに1回ずつ。
  Map<String, int> ownerWorkDoneSeason;

  /// 売却条項(選手のID → 元のクラブへ渡す率%)。値切って買った選手を売るとき、
  /// 売却額のこの割合を元のクラブへ払う。
  Map<String, int> sellOnClauses;

  /// 提携しているクラブのID。いなければ null。
  String? partnerClubId;

  /// 育成の蓄積(倍率)。育成予算の効きの時間差を表す。初期の配分で 1.0。
  double youthMomentum;

  /// 施設の蓄積(倍率)。施設予算の効きの時間差(3〜5年)。初期の配分で 1.0。
  double facilityMomentum;

  /// 次の節に打つ試合日のイベントのID。無ければ null。節を終えると消える。
  String? matchdayPromoId;

  int reserveFund;
  int communityLevel;

  /// 補強が禁止されている残りのシーズン数(規則違反の罰)。
  int transferBanSeasons;

  /// 来季の開幕時に引かれる勝ち点(規則違反の罰)。
  int pendingPointsDeduction;

  /// そのシーズンの収支の記録。無ければ作る。古いものは捨てる。
  SeasonLedger ledgerFor(int season) {
    for (final l in ledgers) {
      if (l.season == season) return l;
    }
    final created = SeasonLedger(season);
    ledgers.add(created);
    ledgers.sort((a, b) => a.season.compareTo(b.season));
    while (ledgers.length > maxLedgerSeasons) {
      ledgers.removeAt(0);
    }
    return created;
  }

  /// 判断待ちの事件。無ければ null。
  OwnerEventKind? pendingOwnerEvent;

  /// 勝負の試合を数えているシーズン。シーズンが変わると回数を戻す。
  int bigMatchSeason;

  /// そのシーズンに宣言した勝負の試合の数(取り消せば戻る)。
  int bigMatchesUsed;

  /// 勝負の試合と宣言した節。宣言が無ければ -1。
  int bigMatchDeclaredMatchday;

  /// 目標を選んだシーズン(期限の数え始め)。
  int ownerGoalStartSeason;

  /// 達成した目標の記録(殿堂)。売却後も消えない。
  List<String> achievedGoals;

  /// 年の予算の配分(補強・育成・施設・営業・配当の比率)。
  BudgetPlan budgetPlan;

  /// 監督としての世間の評価（0-100）。信頼度と異なり解任されても引き継がれ、
  /// 他クラブからのオファーの受けやすさに影響する。
  int managerReputation;

  /// 他クラブから監督就任オファーが届いている場合、そのクラブのID。
  String? pendingJobOfferTeamId;

  /// ユース昇格候補・スカウトした有望株。
  List<Player> youthProspects;

  /// 移籍市場に出ている選手(海外リーグからの移籍候補)。毎節ごとに
  /// 全員を作り直すのではなく数人ずつ入れ替わる持続的な市場で、
  /// ロードしても同じ顔ぶれが維持されるようセーブに含める。
  List<Player> transferMarketPlayers;

  /// シーズン終了時に一括生成された、選抜待ちのユースインテーク候補。
  List<Player> pendingYouthIntake;

  /// ユースの年間リーグ。古いセーブには無いため null を許す
  /// (次の週次処理で作られる)。
  YouthLeague? youthLeague;

  /// 若手有望株ランキングで追跡対象に指定した選手のID一覧
  /// (自クラブ以外の選手も含む、閲覧専用のウォッチリスト)。
  List<String> watchlistPlayerIds;

  /// 他のクラブの選手がどれだけ見えているか(選手ID → 0〜100%)。スカウトを
  /// 送った地域・注目リストの選手だけが入る(同じ部の選手の30%と、自クラブの
  /// 100%は持たずに計算する。ScoutKnowledge)。
  Map<String, int> scoutKnowledge;

  /// スカウトを送っている地域('home:<部>' か 'foreign:<国>')。
  List<String> scoutRegionKeys;

  /// オーナーが監督に伝えた今季の目標の順位。0 は「戦力どおり」(自動)。
  int managerTargetRank;

  /// 監督の立場(0〜100)。目標を下回る節が続くと下がる。
  int managerStanding;

  /// SD に渡している補強の方針。
  SdBrief sdBrief;

  /// SD がこの窓で取った人数(窓が閉じると 0 に戻る)。
  int sdSignedThisWindow;

  /// 他のクラブから来ている、こちらのスタッフの引き抜きの話。
  List<StaffOffer> staffOffers;

  /// オーナー個人の資産(万円)。-1 は「まだ決めていない」(旧セーブ。
  /// GameState が初期資金の3倍で始める)。
  int ownerWealth;

  /// クラブがオーナーに借りている額(万円)。
  int ownerLoanBalance;

  /// オーナーが最後に出資した季(株主の喜びは1季に1回)。
  int ownerInjectionSeason;

  /// 株主総会の要求(AgmDemand の name)。答えるまで残る。
  String? agmDemand;

  /// 要求が「配当の上乗せ」のときの額(万円)。
  int agmPayout;

  /// 総会のときの人件費率(要求の説明と約束の基準)。
  double agmWageRatio;

  /// 「人件費を下げる」と約束した人件費率の上限(0 は約束なし)。
  double agmWageRatioPledge;

  /// 法人税の繰越欠損(万円)。赤字の年に積み、黒字の年に差し引く。
  int taxLossCarry;

  /// 大きな怪我の手当て(選手 id → 'pending' | 'surgery' | 'rest')。
  Map<String, String> injuryPlans;
  /// 育成の方針(YouthPolicy の name)。
  String youthPolicy;
  /// 買い戻し条項(選手 id → [買い戻しの額, 期限の年])。
  Map<String, List<int>> buyBacks;

  /// 他のクラブ(自国)の資金(クラブ id → 万円)。季の終わりに動く。
  Map<String, int> clubCash;

  /// 今季、破綻して選手を投げ売りしているクラブ。
  List<String> distressedClubIds;
  /// クラブの文化(ClubCulture の name)と、最後に変えた季。
  String clubCulture;
  int clubCultureChangedSeason;

  /// 最新の新聞の一面の見出しと、監督の試合後の一言(無ければ null)。
  String? frontPageHeadline;
  String? frontPageQuote;

  /// パラシュート(降格前の部・残りの季)。0 は無し。
  int parachuteFromTier;
  int parachuteSeasonsLeft;

  /// 獲得した選手の簿価(選手 id → [移籍金, 獲得した季の終わりの年, 償却の年数])。
  Map<String, List<int>> playerBook;

  /// 同じリーグで競う他のオーナー。
  List<RivalOwner> rivalOwners;

  /// 5か年計画が始まった季(0 は計画なし)と、3つの目標。
  int planStartSeason;
  int planTargetTier;
  int planTargetValue;
  int planTargetStadium;

  /// 自クラブの選手の私生活の出来事(選手 id → 起きた出来事の印)。
  /// 結婚は1回だけ、ホームシックは1季に1回、のように重ならないために持つ。
  Map<String, List<String>> lifeEvents;

  /// 今季、監督の立場が危ういと報じたか(1季に1回だけ報じる)。
  bool managerWarned;

  /// 初回ガイドで既に開いた画面のステップ名(FirstRunStep.name)。
  /// 試合数や成長のように既存のカウンタから判定できるものは記録しない。
  List<String> firstRunStepsSeen;

  /// 初回ガイドを本人が閉じたか。閉じたら二度と出さない。
  bool firstRunGuideDismissed;

  /// 現在のチケット価格戦略(観客動員率と1人あたり収入のトレードオフ)。
  TicketPricing ticketPricing;

  /// スタッフ・施設のレベル。
  ClubInfrastructure infrastructure;

  /// 今シーズン進行中の国内カップ戦。
  List<Cup> cups;

  /// 今シーズン進行中の大陸カップ(グループステージ+決勝トーナメント)。
  /// 出場資格がない間はnull。
  ContinentalCup? continentalCup;

  /// 前シーズン終了時の最終順位(大陸カップ出場資格判定に使用)。未経験の場合はnull。
  int? lastSeasonRank;

  /// 大陸カップに参加する海外クラブ(出場資格がある間のみ生成される)。
  List<Team> continentalTeams;

  /// 現在契約中のスポンサー。未契約の場合はnull。
  SponsorDeal? sponsorDeal;

  /// 契約更新・新規契約のために提示されている候補(未選択の間はスポンサー収入が発生しない)。
  List<SponsorDeal> pendingSponsorOffers;

  /// スタジアムの命名権(契約中)と、提示されている候補。
  SponsorDeal? namingDeal;
  List<SponsorDeal> pendingNamingOffers;

  /// 枠ごとのスポンサー(SponsorSlot の name → 契約)と、その提示。
  Map<String, SponsorDeal> slotSponsors;
  Map<String, SponsorDeal> slotSponsorOffers;

  /// 放映権の分配金の受け取り方と、前払いの精算で分配金が出ない残りの季数。
  TvDeal tvDeal;
  int tvHolidaySeasons;

  /// 分割払いで獲得した選手の残金支払い予定。
  List<Installment> pendingInstallments;

  /// シーズン開幕前の親善試合日程。
  List<Fixture> friendlies;

  /// 他クラブから届いている、自クラブ選手への移籍オファー。
  List<IncomingOffer> incomingOffers;

  /// 銀行から借り入れている融資。
  List<BankLoan> bankLoans;

  /// 銀行に預け入れている定期預金(資金運用)。満期まで引き出せない。
  List<FixedDeposit> fixedDeposits;

  /// 振り返りを見せ終えたシーズン。ここより新しい記録があるときだけ、
  /// ホームに「今年はどうだったか」を出す。旧セーブは0(未読)。
  int lastReviewedSeason;

  /// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴。
  List<SeasonAward> seasonAwards;

  /// 今シーズン、路線を守れていた節の数と、数えた節の数。
  ///
  /// 最終節だけ辻褄を合わせても認めないため、通しで記録する。
  int visionCompliedMatchdays;
  int visionCheckedMatchdays;

  /// 理事会がこのシーズンに求めている路線。
  ClubVision clubVision;

  /// 開幕前のキャンプで、まだ方針を選んでいなければ true。
  /// 選ぶか見送るかするまで、ホーム画面で促し続ける。
  bool preseasonCampPending;

  /// いま雇えるスタッフの候補。シーズン開始時に入れ替わる。
  List<StaffMember> staffCandidates;

  /// ライバルクラブのID・表示名(開幕時に決定し、以後固定)。
  String? rivalTeamId;
  String? rivalTeamName;

  /// 回答待ちの記者会見の質問。ない場合はnull。
  PressQuestion? pendingPressConference;

  /// ユーザーの現在の所属ディビジョン以外の各ディビジョンのリーグ。添字0が1部、
  /// 添字[totalDivisionTiers]-1が最下位ティア。ユーザーの現在の所属ティアに
  /// 対応する添字は使用しない(null)。ユーザーの節送りに合わせて同じ節番号の
  /// 試合を裏で消化しておくことで、昇格・降格に意味のある他ディビジョンの
  /// 順位表を常時閲覧できるようにする。シーズン終了時はこの順位確定順を
  /// 昇格・降格の判定にそのまま使う。
  List<League?> otherDivisionLeagues;

  /// 他の4か国の1部(国の名前 [LeagueTheme.name] ごと)。補強とスカウトの
  /// 相手として、選手を持ったクラブを置いておく。試合はまだ進めない。
  Map<String, League> foreignLeagues;

  // ここがセーブの大半を占めている(2026-09-03 実測)。
  //
  //   セーブ全体 1,090KB / うち otherDivisionLeagues 860KB (79%)
  //   3シーズン経過してもほぼ横ばい(1,171KB)
  //
  // 他ディビジョンは順位表と、そこから決まる昇降格にしか使わない。選手個々の
  // データを持たなければ 860KB → 概算16KB、セーブ全体は約230KB(1/5)になる。
  // 保存はこの JSON 化がそのまま費用なので、書き込みも読み込みも軽くなる。
  // Web版は localStorage の上限があり、スロットは3つあるので余裕も生まれる。
  //
  // ただし「選手を削るだけ」では済まない。着手する人向けに、調べた結果を
  // 残しておく。
  //
  //   1. Team.overallRating は players から計算している。空にすると 0 を返し、
  //      BackgroundMatchEngine が使うチーム強度が壊れる。保持用の値を別に
  //      持たせ、players が空のときはそちらを使う分岐が要る。
  //   2. 昇格して自ディビジョンに入ったチームは MatchEngine.simulate で
  //      分単位・選手ごとに戦う。選手が必要なので、自ディビジョンへ入る時点で
  //      保持レーティングに見合うスカッドを生成する必要がある。
  //      その結果、昇格したチームは「昇格を勝ち取った実際のスカッド」ではなく
  //      新規生成されたものになる。他ディビジョンの選手を見る画面は無いので
  //      利用者は気づけないが、内部的には別物になる。
  //   3. セーブ形式が変わる。旧形式(選手あり)も読めるようにする移行が要る。
  //
  // データは減るがコードには「保持レーティング + 昇格時に生成」という概念が
  // 増える。差し引きの判断が要る変更なので、ストア申請前には着手しない
  // (2026-09-03 時点の方針)。

  /// ユーザークラブが現在所属するディビジョン(1が最上位、[totalDivisionTiers]が最下位)。
  int currentDivisionTier;

  /// 監督としての通算成績。
  int careerWins;
  int careerDraws;
  int careerLosses;
  int careerSeasons;

  /// 実績(アチーブメント)判定に使う通算カウンター群。旧セーブには
  /// 存在しないためfromJsonでは0にフォールバックする(過去分は遡って
  /// 数えられないが、読み込んだ時点からカウントが始まる)。
  int negotiationSignings; // 値切り交渉で獲得が成立した回数
  int breakthroughCount; // 自クラブ選手の才能開花を見届けた回数
  int liveWins; // ライブ観戦(決定機の判断あり)で勝利した回数
  int careerCupPrize; // カップ戦で獲得した賞金・優勝報酬の通算(万円)
  int pkShootoutWins; // ライブ観戦のPK戦を制した回数

  /// ゲーム難易度(ニューゲーム時に選択)。
  GameDifficulty difficulty;

  /// 理事会が設定する週給総額の上限(万円/週)。0は未設定(旧セーブ)で、
  /// その場合はGameState側が現在の状況から同じ式で算出する。
  int wageBudget;

  /// 理事会が期待する国内カップの到達ラウンド(0は未設定=旧セーブ)。
  int boardCupTargetRound;

  /// 監督契約の残り年数(0は未導入=旧セーブ。次のシーズン開始時に
  /// 判定なしで2年契約が結ばれる)。
  int managerContractYears;

  /// クラブニュース(お知らせ履歴)。新しいものが先頭。SnackBar等で
  /// 一度流れて消える通知を、あとから見返せるように保存する。件数は
  /// GameState側で上限管理する。旧セーブには存在しないため空で補完する。
  List<NewsItem> newsLog;

  /// これまでに積んだお知らせの数(増える一方)。未読の数を出すのに使う。
  int newsTotal;

  /// 受信箱を最後に開いたときの[newsTotal]。
  int newsSeenTotal;

  /// 獲得したタイトルの履歴(リーグ優勝・カップ優勝など)。
  List<String> trophyHistory;

  /// これまで指揮したクラブ名の履歴(就任順)。
  List<String> clubHistory;

  /// 契約満了で放出された選手や、市場に出回っているベテランなど、
  /// 移籍金なし(週俸のみ)で獲得できるフリーエージェントのプール。
  List<Player> freeAgents;

  /// 引退した選手(殿堂)。契約満了で単に自由契約になった選手とは異なり、
  /// 高齢による正式な引退のため再契約はできない。
  List<Player> retiredLegends;

  /// シーズンごとの成績アーカイブ(最終順位・勝敗・昇降格・カップ優勝歴)。
  List<SeasonRecord> seasonHistory;

  /// シーズンごとのベストイレブン選出履歴。
  List<SeasonBestEleven> bestElevenHistory;

  /// シーズン中盤の理事会レビューを既に実施したかどうか(シーズン開始時にリセット)。
  bool boardReviewDoneThisSeason;

  /// 表示待ちのシーズン中盤レビューの講評文(ない場合はnull)。
  String? pendingBoardReviewMessage;

  /// 月間最優秀監督賞の集計済み節数(この節までの成績は既に賞の判定に使用済み)。
  /// シーズン開始時に0へリセットされる。
  int lastManagerOfMonthCheckpoint;

  /// 今週すでにトレーニングを実施済みかどうか(節が進むとリセットされる)。
  bool trainingDoneThisWeek;

  /// 進行中の契約交渉(週俸の駆け引き)。ない場合はnull。
  ContractNegotiation? pendingContractNegotiation;

  /// 新シーズン開幕前のスーパーカップ(前シーズンのリーグ王者 対 国内カップ王者)。
  /// ユーザークラブが出場する場合のみ、結果が未確定のまま保持される。
  CupMatch? pendingSuperCup;

  /// 資金がマイナスのまま連続している週数(黒字化した時点で0にリセットされる)。
  /// 一定週数を超えると理事会の信頼度にペナルティが科される。
  int consecutiveNegativeBudgetWeeks;

  /// 解除済みの実績(アチーブメント)ID→達成したシーズン番号。
  Map<String, int> unlockedAchievements;

  /// 現在のシーズン開始時点での自クラブ選手の総合力(選手ID→総合力)。
  /// シーズン終了時に、この時点からの成長を選手ごとに算出するために使う。
  Map<String, int> seasonStartOverallByPlayerId;

  /// 週の処理(収入・週給・負傷回復・ローン・分割払い・ユース)を済ませた
  /// 節。自クラブの試合の途中でアプリが終わり、同じ節を始め直すときに、
  /// 週の処理を二度かけないための印。旧セーブは0(未処理)。
  int weekProcessedSeason;
  int weekProcessedMatchday;

  /// ゲームの中の今日(日付のみ)。試合を消化するとその試合の日に進む。
  /// 旧セーブには無い(null)。読み込んだ時に GameState が作り直す。
  DateTime? today;

  /// 結ばれている仮契約(ボスマン)。7月1日に選手が移る。旧セーブは空。
  List<PreContract> preContracts;

  /// 他のクラブとの移籍金の交渉(買う側)。窓が閉じると空になる。
  List<TransferTalk> transferTalks;

  /// 1月1日の仮契約の解禁(他のクラブの更新と、AI の仮契約)を済ませた
  /// シーズン。旧セーブは0(そのシーズンの1月1日を過ぎていれば読み込み後に行う)。
  int preContractOpenedSeason;

  /// 延長オプションの期限(3月31日)を締めたシーズン。旧セーブは0。
  int optionDeadlineSeason;

  /// 給料の未払いを通告した(選手が解除できるようになる前の知らせ)か。
  /// 資金が黒字に戻ったら false に戻す。
  bool unpaidWagesNoticeGiven;

  /// 進行中の自クラブのリーグ戦の途中経過。試合中でなければ null。
  LiveMatchProgress? liveMatchProgress;

  SaveGame({
    required this.clubName,
    required this.userTeamId,
    required this.league,
    // i18n-ignore: セーブに保存されるデータの既定値(上のコメント参照)。
    this.leagueName = 'リーグ',
    this.budget = 20000, // 5部の年収の半年分ほど(GameState.initialBudgetTier5)
    this.boardTargetRank = 4,
    this.managerTargetRank = 0,
    this.managerStanding = 60,
    SdBrief? sdBrief,
    this.sdSignedThisWindow = 0,
    List<StaffOffer>? staffOffers,
    Map<String, List<String>>? lifeEvents,
    this.ownerWealth = -1,
    this.ownerLoanBalance = 0,
    this.ownerInjectionSeason = 0,
    this.agmDemand,
    this.agmPayout = 0,
    this.agmWageRatio = 0,
    this.agmWageRatioPledge = 0,
    this.taxLossCarry = 0,
    Map<String, String>? injuryPlans,
    this.youthPolicy = 'balanced',
    Map<String, int>? clubCash,
    List<String>? distressedClubIds,
    this.clubCulture = 'none',
    this.clubCultureChangedSeason = 0,
    this.frontPageHeadline,
    Map<String, List<int>>? buyBacks,
    this.frontPageQuote,
    this.parachuteFromTier = 0,
    this.parachuteSeasonsLeft = 0,
    Map<String, List<int>>? playerBook,
    this.planStartSeason = 0,
    List<RivalOwner>? rivalOwners,
    this.newsTotal = 0,
    this.newsSeenTotal = 0,
    this.planTargetTier = 0,
    this.planTargetValue = 0,
    this.planTargetStadium = 0,
    this.managerWarned = false,
    this.confidence = 60,
    this.shareholderExpectation = 60,
    List<OwnerLegacy>? ownerLegacies,
    this.ownerGoal,
    this.marketingBoostWeeks = 0,
    List<SeasonLedger>? ledgers,
    this.ruleSet = RuleSet.britain,
    this.economyVersion = currentEconomyVersion,
    this.economyPhase = EconomyPhase.normal,
    this.marketIndex = 100,
    this.economyNext = EconomyPhase.normal,
    this.clubPolicy = ClubPolicy.balanced,
    Map<int, int>? clubValueHistory,
    this.ownerGoalStartValue = 0,
    this.ownerShare = 100,
    List<String>? retiredNumberIds,
    Map<String, int>? projects,
    Map<String, int>? advisors,
    List<ManagerProposal>? proposals,
    this.scenario = StartScenario.standard,
    List<int>? rivalPast,
    List<TimelineEntry>? timeline,
    List<String>? declinedProposalIds,
    this.insured = false,
    Map<String, int>? ownerWorkDoneSeason,
    Map<String, int>? sellOnClauses,
    this.partnerClubId,
    this.youthMomentum = 1.0,
    this.facilityMomentum = 1.0,
    this.matchdayPromoId,
    this.reserveFund = 0,
    this.communityLevel = 0,
    this.transferBanSeasons = 0,
    this.pendingPointsDeduction = 0,
    this.pendingOwnerEvent,
    this.bigMatchSeason = 0,
    this.bigMatchesUsed = 0,
    this.bigMatchDeclaredMatchday = -1,
    this.ownerGoalStartSeason = 1,
    List<String>? achievedGoals,
    BudgetPlan? budgetPlan,
    this.managerReputation = 50,
    this.pendingJobOfferTeamId,
    List<Player>? youthProspects,
    List<Player>? transferMarketPlayers,
    List<Player>? pendingYouthIntake,
    this.youthLeague,
    List<String>? watchlistPlayerIds,
    Map<String, int>? scoutKnowledge,
    List<String>? scoutRegionKeys,
    List<String>? firstRunStepsSeen,
    this.firstRunGuideDismissed = false,
    this.ticketPricing = TicketPricing.standard,
    ClubInfrastructure? infrastructure,
    List<Cup>? cups,
    this.continentalCup,
    this.lastSeasonRank,
    List<Team>? continentalTeams,
    this.sponsorDeal,
    this.namingDeal,
    List<SponsorDeal>? pendingNamingOffers,
    Map<String, SponsorDeal>? slotSponsors,
    Map<String, SponsorDeal>? slotSponsorOffers,
    this.tvDeal = TvDeal.fixed,
    this.tvHolidaySeasons = 0,
    List<SponsorDeal>? pendingSponsorOffers,
    List<Installment>? pendingInstallments,
    List<Fixture>? friendlies,
    List<IncomingOffer>? incomingOffers,
    List<BankLoan>? bankLoans,
    List<FixedDeposit>? fixedDeposits,
    List<SeasonAward>? seasonAwards,
    this.lastReviewedSeason = 0,
    List<StaffMember>? staffCandidates,
    this.preseasonCampPending = false,
    this.clubVision = ClubVision.none,
    this.visionCompliedMatchdays = 0,
    this.visionCheckedMatchdays = 0,
    this.rivalTeamId,
    this.rivalTeamName,
    this.pendingPressConference,
    List<League?>? otherDivisionLeagues,
    Map<String, League>? foreignLeagues,
    this.currentDivisionTier = 1,
    this.careerWins = 0,
    this.careerDraws = 0,
    this.careerLosses = 0,
    this.careerSeasons = 0,
    this.negotiationSignings = 0,
    this.breakthroughCount = 0,
    this.liveWins = 0,
    this.careerCupPrize = 0,
    this.pkShootoutWins = 0,
    this.difficulty = GameDifficulty.normal,
    this.wageBudget = 0,
    this.boardCupTargetRound = 0,
    this.managerContractYears = 0,
    List<NewsItem>? newsLog,
    List<String>? trophyHistory,
    List<String>? clubHistory,
    List<Player>? freeAgents,
    List<Player>? retiredLegends,
    List<SeasonRecord>? seasonHistory,
    List<SeasonBestEleven>? bestElevenHistory,
    this.boardReviewDoneThisSeason = false,
    this.pendingBoardReviewMessage,
    this.lastManagerOfMonthCheckpoint = 0,
    this.trainingDoneThisWeek = false,
    this.pendingContractNegotiation,
    this.pendingSuperCup,
    this.consecutiveNegativeBudgetWeeks = 0,
    Map<String, int>? unlockedAchievements,
    Map<String, int>? seasonStartOverallByPlayerId,
    this.weekProcessedSeason = 0,
    this.weekProcessedMatchday = 0,
    this.liveMatchProgress,
    this.today,
    List<PreContract>? preContracts,
    List<TransferTalk>? transferTalks,
    this.preContractOpenedSeason = 0,
    this.optionDeadlineSeason = 0,
    this.unpaidWagesNoticeGiven = false,
  })  : preContracts = preContracts ?? [],
        transferTalks = transferTalks ?? [],
        sdBrief = sdBrief ?? SdBrief(),
        staffOffers = staffOffers ?? [],
        lifeEvents = lifeEvents ?? {},
        playerBook = playerBook ?? {},
        clubCash = clubCash ?? {},
        distressedClubIds = distressedClubIds ?? [],
        buyBacks = buyBacks ?? {},
        injuryPlans = injuryPlans ?? {},
        rivalOwners = rivalOwners ?? [],
        budgetPlan = budgetPlan ?? BudgetPlan.balanced(),
        unlockedAchievements = unlockedAchievements ?? {},
        seasonStartOverallByPlayerId = seasonStartOverallByPlayerId ?? {},
        newsLog = newsLog ?? [],
        trophyHistory = trophyHistory ?? [],
        clubHistory = clubHistory ?? [],
        ownerLegacies = ownerLegacies ?? [],
        ledgers = ledgers ?? [],
        clubValueHistory = clubValueHistory ?? {},
        achievedGoals = achievedGoals ?? [],
        freeAgents = freeAgents ?? [],
        retiredLegends = retiredLegends ?? [],
        seasonHistory = seasonHistory ?? [],
        bestElevenHistory = bestElevenHistory ?? [],
        youthProspects = youthProspects ?? [],
        transferMarketPlayers = transferMarketPlayers ?? [],
        pendingYouthIntake = pendingYouthIntake ?? [],
        watchlistPlayerIds = watchlistPlayerIds ?? [],
        scoutKnowledge = scoutKnowledge ?? {},
        scoutRegionKeys = scoutRegionKeys ?? [],
        firstRunStepsSeen = firstRunStepsSeen ?? [],
        infrastructure = infrastructure ?? ClubInfrastructure(),
        cups = cups ?? [],
        continentalTeams = continentalTeams ?? [],
        pendingSponsorOffers = pendingSponsorOffers ?? [],
        pendingNamingOffers = pendingNamingOffers ?? [],
        slotSponsors = slotSponsors ?? {},
        slotSponsorOffers = slotSponsorOffers ?? {},
        retiredNumberIds = retiredNumberIds ?? [],
        projects = projects ?? {},
        advisors = advisors ?? {},
        proposals = proposals ?? [],
        timeline = timeline ?? [],
        rivalPast = rivalPast ?? [0, 0, 0],
        declinedProposalIds = declinedProposalIds ?? [],
        ownerWorkDoneSeason = ownerWorkDoneSeason ?? {},
        sellOnClauses = sellOnClauses ?? {},
        pendingInstallments = pendingInstallments ?? [],
        friendlies = friendlies ?? [],
        incomingOffers = incomingOffers ?? [],
        bankLoans = bankLoans ?? [],
        fixedDeposits = fixedDeposits ?? [],
        seasonAwards = seasonAwards ?? [],
        staffCandidates = staffCandidates ?? [],
        otherDivisionLeagues = otherDivisionLeagues ??
            List<League?>.filled(totalDivisionTiers, null),
        foreignLeagues = foreignLeagues ?? {};

  /// 全ディビジョンの全チーム(現在の所属ディビジョンも含む)。ID再採番や
  /// スーパーカップの対戦相手検索など、所属ティアを問わず全チームが必要な
  /// 場面で使う。
  List<Team> get allTeams => [
        ...league.teams,
        for (final l in otherDivisionLeagues)
          if (l != null) ...l.teams,
      ];

  /// セーブの中にいる全選手。**選手を持つ場所を足したら、ここにも足す。**
  ///
  /// 選手IDのカウンターは起動のたびに0へ戻り、読み込んだセーブの全選手IDを
  /// 見て引き上げる。ここに漏れがあると(以前は移籍市場・大陸カップの海外
  /// クラブが漏れていた)、再起動後に作った選手が既存の選手と同じIDになる。
  Iterable<Player> get allPlayers sync* {
    for (final l in foreignLeagues.values) {
      for (final t in l.teams) {
        yield* t.players;
      }
    }
    for (final t in allTeams) {
      yield* t.players;
    }
    for (final t in continentalTeams) {
      yield* t.players;
    }
    yield* youthProspects;
    yield* retiredLegends;
    yield* pendingYouthIntake;
    yield* freeAgents;
    yield* transferMarketPlayers;
  }

  /// 重複した選手IDを振り直す。振り直した選手の数を返す。
  ///
  /// **振り直すのは、IDで参照されない場所(ユース入団候補・フリーエージェント・
  /// 移籍市場)にいる側だけ。** クラブの選手・有望株・殿堂入りは、先発・主将・
  /// キッカー・ウォッチリスト・成績などからIDで参照されているので触らない
  /// (どちらが参照先か分からなくなる)。[newId] は呼び出し側がカウンターを
  /// 全選手より上に引き上げてから渡すこと。
  int renumberDuplicatePlayerIds(String Function() newId) {
    final seen = <String>{
      for (final t in allTeams)
        for (final p in t.players) p.id,
      for (final t in continentalTeams)
        for (final p in t.players) p.id,
      for (final p in youthProspects) p.id,
      for (final p in retiredLegends) p.id,
    };
    var renumbered = 0;
    for (final pool in [pendingYouthIntake, freeAgents, transferMarketPlayers]) {
      for (var i = 0; i < pool.length; i++) {
        final p = pool[i];
        if (seen.add(p.id)) continue;
        final id = newId();
        pool[i] = Player.fromJson({...p.toJson(), 'id': id});
        seen.add(id);
        renumbered++;
      }
    }
    return renumbered;
  }

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'userTeamId': userTeamId,
        'league': league.toJson(),
        'leagueName': leagueName,
        'budget': budget,
        'boardTargetRank': boardTargetRank,
        if (managerTargetRank > 0) 'managerTargetRank': managerTargetRank,
        'managerStanding': managerStanding,
        'sdBrief': sdBrief.toJson(),
        if (sdSignedThisWindow > 0) 'sdSignedThisWindow': sdSignedThisWindow,
        if (staffOffers.isNotEmpty)
          'staffOffers': staffOffers.map((o) => o.toJson()).toList(),
        if (lifeEvents.isNotEmpty) 'lifeEvents': lifeEvents,
        if (ownerWealth >= 0) 'ownerWealth': ownerWealth,
        if (ownerLoanBalance > 0) 'ownerLoanBalance': ownerLoanBalance,
        if (ownerInjectionSeason > 0)
          'ownerInjectionSeason': ownerInjectionSeason,
        if (agmDemand != null) 'agmDemand': agmDemand,
        if (agmPayout > 0) 'agmPayout': agmPayout,
        if (agmWageRatio > 0) 'agmWageRatio': agmWageRatio,
        if (agmWageRatioPledge > 0) 'agmWageRatioPledge': agmWageRatioPledge,
        if (taxLossCarry > 0) 'taxLossCarry': taxLossCarry,
        if (parachuteSeasonsLeft > 0) ...{
          'parachuteFromTier': parachuteFromTier,
          'parachuteSeasonsLeft': parachuteSeasonsLeft,
        },
        if (playerBook.isNotEmpty) 'playerBook': playerBook,
        if (injuryPlans.isNotEmpty) 'injuryPlans': injuryPlans,
        if (youthPolicy != 'balanced') 'youthPolicy': youthPolicy,
        if (clubCash.isNotEmpty) 'clubCash': clubCash,
        if (distressedClubIds.isNotEmpty) 'distressedClubIds': distressedClubIds,
        if (clubCulture != 'none') 'clubCulture': clubCulture,
        if (clubCultureChangedSeason > 0)
          'clubCultureChangedSeason': clubCultureChangedSeason,
        if (frontPageHeadline != null) 'frontPageHeadline': frontPageHeadline,
        if (buyBacks.isNotEmpty) 'buyBacks': buyBacks,
        if (frontPageQuote != null) 'frontPageQuote': frontPageQuote,
        if (rivalOwners.isNotEmpty)
          'rivalOwners': rivalOwners.map((r) => r.toJson()).toList(),
        if (newsTotal > 0) 'newsTotal': newsTotal,
        if (newsSeenTotal > 0) 'newsSeenTotal': newsSeenTotal,
        if (planStartSeason > 0) ...{
          'planStartSeason': planStartSeason,
          'planTargetTier': planTargetTier,
          'planTargetValue': planTargetValue,
          'planTargetStadium': planTargetStadium,
        },
        if (managerWarned) 'managerWarned': true,
        'confidence': confidence,
        'shareholderExpectation': shareholderExpectation,
        'ownerLegacies': ownerLegacies.map((l) => l.toJson()).toList(),
        'ownerGoal': ownerGoal?.name,
        'marketingBoostWeeks': marketingBoostWeeks,
        'ledgers': ledgers.map((l) => l.toJson()).toList(),
        'ruleSet': ruleSet.name,
        'economyVersion': economyVersion,
        'economyPhase': economyPhase.name,
        if (marketIndex != 100) 'marketIndex': marketIndex,
        'economyNext': economyNext.name,
        'clubPolicy': clubPolicy.name,
        'clubValueHistory': clubValueHistory.map((k, v) => MapEntry('$k', v)),
        'ownerGoalStartValue': ownerGoalStartValue,
        'ownerShare': ownerShare,
        'retiredNumberIds': retiredNumberIds,
        'projects': projects,
        'advisors': advisors,
        'proposals': proposals.map((p) => p.toJson()).toList(),
        'scenario': scenario.name,
        'rivalPast': rivalPast,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'declinedProposalIds': declinedProposalIds,
        'insured': insured,
        'ownerWorkDoneSeason': ownerWorkDoneSeason,
        'sellOnClauses': sellOnClauses,
        'partnerClubId': partnerClubId,
        'youthMomentum': youthMomentum,
        'facilityMomentum': facilityMomentum,
        'matchdayPromoId': matchdayPromoId,
        'reserveFund': reserveFund,
        'communityLevel': communityLevel,
        'transferBanSeasons': transferBanSeasons,
        'pendingPointsDeduction': pendingPointsDeduction,
        'pendingOwnerEvent': pendingOwnerEvent?.name,
        'bigMatchSeason': bigMatchSeason,
        'bigMatchesUsed': bigMatchesUsed,
        'bigMatchDeclaredMatchday': bigMatchDeclaredMatchday,
        'ownerGoalStartSeason': ownerGoalStartSeason,
        'achievedGoals': achievedGoals,
        'budgetPlan': budgetPlan.toJson(),
        'managerReputation': managerReputation,
        'pendingJobOfferTeamId': pendingJobOfferTeamId,
        'youthProspects': youthProspects.map((p) => p.toJson()).toList(),
        'transferMarketPlayers':
            transferMarketPlayers.map((p) => p.toJson()).toList(),
        'pendingYouthIntake':
            pendingYouthIntake.map((p) => p.toJson()).toList(),
        'youthLeague': youthLeague?.toJson(),
        'watchlistPlayerIds': watchlistPlayerIds,
        if (scoutKnowledge.isNotEmpty) 'scoutKnowledge': scoutKnowledge,
        if (scoutRegionKeys.isNotEmpty) 'scoutRegionKeys': scoutRegionKeys,
        'firstRunStepsSeen': firstRunStepsSeen,
        'firstRunGuideDismissed': firstRunGuideDismissed,
        'ticketPricing': ticketPricing.name,
        'infrastructure': infrastructure.toJson(),
        'cups': cups.map((c) => c.toJson()).toList(),
        'continentalCup': continentalCup?.toJson(),
        'lastSeasonRank': lastSeasonRank,
        'continentalTeams': continentalTeams.map((t) => t.toJson()).toList(),
        'sponsorDeal': sponsorDeal?.toJson(),
        'namingDeal': namingDeal?.toJson(),
        'pendingNamingOffers': pendingNamingOffers.map((s) => s.toJson()).toList(),
        if (slotSponsors.isNotEmpty)
          'slotSponsors': slotSponsors.map((k, v) => MapEntry(k, v.toJson())),
        if (slotSponsorOffers.isNotEmpty)
          'slotSponsorOffers':
              slotSponsorOffers.map((k, v) => MapEntry(k, v.toJson())),
        'tvDeal': tvDeal.name,
        'tvHolidaySeasons': tvHolidaySeasons,
        'pendingSponsorOffers':
            pendingSponsorOffers.map((s) => s.toJson()).toList(),
        'pendingInstallments':
            pendingInstallments.map((i) => i.toJson()).toList(),
        'friendlies': friendlies.map((f) => f.toJson()).toList(),
        'incomingOffers': incomingOffers.map((o) => o.toJson()).toList(),
        'bankLoans': bankLoans.map((l) => l.toJson()).toList(),
        'fixedDeposits': fixedDeposits.map((d) => d.toJson()).toList(),
        'preseasonCampPending': preseasonCampPending,
        'clubVision': clubVision.name,
        'visionCompliedMatchdays': visionCompliedMatchdays,
        'visionCheckedMatchdays': visionCheckedMatchdays,
        'staffCandidates':
            staffCandidates.map((s) => s.toJson()).toList(),
        'seasonAwards': seasonAwards.map((a) => a.toJson()).toList(),
        'lastReviewedSeason': lastReviewedSeason,
        'rivalTeamId': rivalTeamId,
        'rivalTeamName': rivalTeamName,
        'pendingPressConference': pendingPressConference?.toJson(),
        // 他ディビジョンは選手データを保存しない。順位表と昇降格にしか
        // 使わないため、強度だけ retainedOverall として残す。
        'otherDivisionLeagues': otherDivisionLeagues
            .map((l) => l?.toJson(includePlayers: false))
            .toList(),
        'foreignLeagues': {
          for (final e in foreignLeagues.entries)
            e.key: e.value.toJson(includePlayers: false),
        },
        'currentDivisionTier': currentDivisionTier,
        'careerWins': careerWins,
        'careerDraws': careerDraws,
        'careerLosses': careerLosses,
        'careerSeasons': careerSeasons,
        'negotiationSignings': negotiationSignings,
        'breakthroughCount': breakthroughCount,
        'liveWins': liveWins,
        'careerCupPrize': careerCupPrize,
        'pkShootoutWins': pkShootoutWins,
        'difficulty': difficulty.name,
        'wageBudget': wageBudget,
        'boardCupTargetRound': boardCupTargetRound,
        'managerContractYears': managerContractYears,
        'newsLog': newsLog.map((n) => n.toJson()).toList(),
        'trophyHistory': trophyHistory,
        'clubHistory': clubHistory,
        'freeAgents': freeAgents.map((p) => p.toJson()).toList(),
        'retiredLegends': retiredLegends.map((p) => p.toJson()).toList(),
        'seasonHistory': seasonHistory.map((r) => r.toJson()).toList(),
        'bestElevenHistory': bestElevenHistory.map((r) => r.toJson()).toList(),
        'boardReviewDoneThisSeason': boardReviewDoneThisSeason,
        'pendingBoardReviewMessage': pendingBoardReviewMessage,
        'lastManagerOfMonthCheckpoint': lastManagerOfMonthCheckpoint,
        'trainingDoneThisWeek': trainingDoneThisWeek,
        'pendingContractNegotiation': pendingContractNegotiation?.toJson(),
        'pendingSuperCup': pendingSuperCup?.toJson(),
        'consecutiveNegativeBudgetWeeks': consecutiveNegativeBudgetWeeks,
        'unlockedAchievements': unlockedAchievements,
        'seasonStartOverallByPlayerId': seasonStartOverallByPlayerId,
        'weekProcessedSeason': weekProcessedSeason,
        'weekProcessedMatchday': weekProcessedMatchday,
        'liveMatchProgress': liveMatchProgress?.toJson(),
        'today': today == null ? null : formatSaveDate(today!),
        if (preContracts.isNotEmpty)
          'preContracts': preContracts.map((c) => c.toJson()).toList(),
        if (transferTalks.isNotEmpty)
          'transferTalks': transferTalks.map((t) => t.toJson()).toList(),
        'preContractOpenedSeason': preContractOpenedSeason,
        'optionDeadlineSeason': optionDeadlineSeason,
        if (unpaidWagesNoticeGiven) 'unpaidWagesNoticeGiven': true,
      };

  /// 読み込む前に、契約の残り年数を数える基準の年をこのセーブのシーズンに
  /// 合わせる。旧セーブの残り年数を満了の年に直すときに使う
  /// ([Player.contractEndYearFromYears])。
  factory SaveGame.fromJson(Map<String, dynamic> json) {
    final season = (json['league'] as Map?)?['season'] as int? ?? 1;
    Player.contractClockYear = Player.seasonEndYearOf(season);
    return SaveGame._fromJson(json);
  }

  factory SaveGame._fromJson(Map<String, dynamic> json) => SaveGame(
        clubName: json['clubName'] as String,
        userTeamId: json['userTeamId'] as String,
        league: League.fromJson(json['league'] as Map<String, dynamic>),
        // i18n-ignore: 同上。古いセーブを読むときのフォールバック。
        leagueName: json['leagueName'] as String? ?? 'リーグ',
        budget: json['budget'] as int? ?? 3000,
        boardTargetRank: json['boardTargetRank'] as int? ?? 4,
        managerTargetRank: json['managerTargetRank'] as int? ?? 0,
        managerStanding: json['managerStanding'] as int? ?? 60,
        sdBrief: json['sdBrief'] is Map
            ? SdBrief.fromJson((json['sdBrief'] as Map).cast<String, dynamic>())
            : null,
        sdSignedThisWindow: json['sdSignedThisWindow'] as int? ?? 0,
        ownerWealth: json['ownerWealth'] as int? ?? -1,
        ownerLoanBalance: json['ownerLoanBalance'] as int? ?? 0,
        ownerInjectionSeason: json['ownerInjectionSeason'] as int? ?? 0,
        agmDemand: json['agmDemand'] as String?,
        agmPayout: json['agmPayout'] as int? ?? 0,
        agmWageRatio: (json['agmWageRatio'] as num?)?.toDouble() ?? 0,
        agmWageRatioPledge:
            (json['agmWageRatioPledge'] as num?)?.toDouble() ?? 0,
        taxLossCarry: json['taxLossCarry'] as int? ?? 0,
        injuryPlans: (json['injuryPlans'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as String)),
        youthPolicy: json['youthPolicy'] as String? ?? 'balanced',
        clubCash: (json['clubCash'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as int)),
        distressedClubIds: (json['distressedClubIds'] as List?)
            ?.map((e) => e as String)
            .toList(),
        clubCulture: json['clubCulture'] as String? ?? 'none',
        clubCultureChangedSeason:
            json['clubCultureChangedSeason'] as int? ?? 0,
        frontPageHeadline: json['frontPageHeadline'] as String?,
        buyBacks: (json['buyBacks'] as Map?)?.map((k, v) => MapEntry(
            k as String, [for (final e in (v as List)) e as int])),
        frontPageQuote: json['frontPageQuote'] as String?,
        parachuteFromTier: json['parachuteFromTier'] as int? ?? 0,
        parachuteSeasonsLeft: json['parachuteSeasonsLeft'] as int? ?? 0,
        playerBook: (json['playerBook'] as Map?)?.map((k, v) => MapEntry(
            k as String, [for (final e in (v as List)) e as int])),
        newsTotal: json['newsTotal'] as int? ?? 0,
        newsSeenTotal: json['newsSeenTotal'] as int? ?? 0,
        rivalOwners: (json['rivalOwners'] as List?)
                ?.map((e) =>
                    RivalOwner.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        planStartSeason: json['planStartSeason'] as int? ?? 0,
        planTargetTier: json['planTargetTier'] as int? ?? 0,
        planTargetValue: json['planTargetValue'] as int? ?? 0,
        planTargetStadium: json['planTargetStadium'] as int? ?? 0,
        lifeEvents: (json['lifeEvents'] as Map?)?.map((k, v) => MapEntry(
            k as String, [for (final e in (v as List)) e as String])),
        staffOffers: (json['staffOffers'] as List?)
                ?.map((e) =>
                    StaffOffer.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        managerWarned: json['managerWarned'] as bool? ?? false,
        confidence: json['confidence'] as int? ?? 60,
        shareholderExpectation: json['shareholderExpectation'] as int? ?? 60,
        ownerGoal: OwnerGoal.values
            .where((g) => g.name == json['ownerGoal'])
            .firstOrNull,
        ownerGoalStartSeason: json['ownerGoalStartSeason'] as int? ?? 1,
        marketingBoostWeeks: json['marketingBoostWeeks'] as int? ?? 0,
        ruleSet: RuleSet.values
            .where((r) => r.name == json['ruleSet'])
            .firstOrNull ?? RuleSet.britain,
        clubValueHistory: (json['clubValueHistory'] as Map?)
            ?.map((k, v) => MapEntry(int.parse('$k'), v as int)),
        ownerGoalStartValue: json['ownerGoalStartValue'] as int? ?? 0,
        ownerShare: json['ownerShare'] as int? ?? 100,
        rivalPast: (json['rivalPast'] as List?)?.map((e) => e as int).toList() ??
            [0, 0, 0],
        scenario: StartScenario.values
                .where((s) => s.name == json['scenario'])
                .firstOrNull ??
            StartScenario.standard,
        timeline: (json['timeline'] as List?)
                ?.map((e) => TimelineEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        proposals: (json['proposals'] as List?)
                ?.map((e) => ManagerProposal.fromJson(e as Map<String, dynamic>))
                .whereType<ManagerProposal>()
                .toList() ??
            [],
        declinedProposalIds: (json['declinedProposalIds'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        advisors: (json['advisors'] as Map?)
                ?.map((k, v) => MapEntry('$k', v as int)) ??
            {},
        projects: (json['projects'] as Map?)
                ?.map((k, v) => MapEntry('$k', v as int)) ??
            {},
        retiredNumberIds: (json['retiredNumberIds'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        insured: json['insured'] as bool? ?? false,
        ownerWorkDoneSeason: (json['ownerWorkDoneSeason'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as int)),
        sellOnClauses: (json['sellOnClauses'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as int)),
        partnerClubId: json['partnerClubId'] as String?,
        youthMomentum: (json['youthMomentum'] as num?)?.toDouble() ?? 1.0,
        facilityMomentum:
            (json['facilityMomentum'] as num?)?.toDouble() ?? 1.0,
        matchdayPromoId: json['matchdayPromoId'] as String?,
        reserveFund: json['reserveFund'] as int? ?? 0,
        communityLevel: json['communityLevel'] as int? ?? 0,
        clubPolicy: ClubPolicy.values
            .where((p) => p.name == json['clubPolicy'])
            .firstOrNull ?? ClubPolicy.balanced,
        // 版が書かれていないのは、桁を変える前のセーブ。
        economyVersion: json['economyVersion'] as int? ?? 1,
        marketIndex: json['marketIndex'] as int? ?? 100,
        economyPhase: EconomyPhase.values
            .where((e) => e.name == json['economyPhase'])
            .firstOrNull ?? EconomyPhase.normal,
        economyNext: EconomyPhase.values
            .where((e) => e.name == json['economyNext'])
            .firstOrNull ?? EconomyPhase.normal,
        transferBanSeasons: json['transferBanSeasons'] as int? ?? 0,
        pendingPointsDeduction: json['pendingPointsDeduction'] as int? ?? 0,
        ledgers: (json['ledgers'] as List?)
                ?.map((e) => SeasonLedger.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingOwnerEvent: OwnerEventKind.values
            .where((k) => k.name == json['pendingOwnerEvent'])
            .firstOrNull,
        bigMatchSeason: json['bigMatchSeason'] as int? ?? 0,
        bigMatchesUsed: json['bigMatchesUsed'] as int? ?? 0,
        bigMatchDeclaredMatchday: json['bigMatchDeclaredMatchday'] as int? ?? -1,
        achievedGoals: (json['achievedGoals'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        ownerLegacies: (json['ownerLegacies'] as List?)
                ?.map((e) => OwnerLegacy.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        budgetPlan:
            BudgetPlan.fromJson(json['budgetPlan'] as Map<String, dynamic>?),
        managerReputation: json['managerReputation'] as int? ?? 50,
        pendingJobOfferTeamId: json['pendingJobOfferTeamId'] as String?,
        youthProspects: (json['youthProspects'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        transferMarketPlayers: (json['transferMarketPlayers'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingYouthIntake: (json['pendingYouthIntake'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        youthLeague: json['youthLeague'] == null
            ? null
            : YouthLeague.fromJson(
                json['youthLeague'] as Map<String, dynamic>),
        scoutKnowledge: (json['scoutKnowledge'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as int)),
        scoutRegionKeys: (json['scoutRegionKeys'] as List?)
            ?.map((e) => e as String)
            .toList(),
        watchlistPlayerIds: (json['watchlistPlayerIds'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        firstRunStepsSeen: (json['firstRunStepsSeen'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        // 旧セーブには存在しない。既に遊んでいる人にいまさらガイドを
        // 出すのは邪魔なので、試合をこなしていれば出ない導出側に任せる。
        firstRunGuideDismissed:
            json['firstRunGuideDismissed'] as bool? ?? false,
        ticketPricing: enumFromName(
          TicketPricing.values,
          json['ticketPricing'] as String?,
          TicketPricing.standard,
        ),
        infrastructure: ClubInfrastructure.fromJson(
          json['infrastructure'] as Map<String, dynamic>?,
        ),
        cups: (json['cups'] as List?)
                ?.map((e) => Cup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        continentalCup: json['continentalCup'] == null
            ? null
            : ContinentalCup.fromJson(
                json['continentalCup'] as Map<String, dynamic>,
              ),
        lastSeasonRank: json['lastSeasonRank'] as int?,
        continentalTeams: (json['continentalTeams'] as List?)
                ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        namingDeal: json['namingDeal'] == null
            ? null
            : SponsorDeal.fromJson(json['namingDeal'] as Map<String, dynamic>),
        slotSponsors: (json['slotSponsors'] as Map?)?.map((k, v) =>
            MapEntry(k as String,
                SponsorDeal.fromJson(v as Map<String, dynamic>))),
        slotSponsorOffers: (json['slotSponsorOffers'] as Map?)?.map((k, v) =>
            MapEntry(k as String,
                SponsorDeal.fromJson(v as Map<String, dynamic>))),
        pendingNamingOffers: (json['pendingNamingOffers'] as List?)
                ?.map((e) => SponsorDeal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        tvDeal: TvDeal.values
                .where((d) => d.name == json['tvDeal'])
                .firstOrNull ??
            TvDeal.fixed,
        tvHolidaySeasons: json['tvHolidaySeasons'] as int? ?? 0,
        sponsorDeal: json['sponsorDeal'] == null
            ? null
            : SponsorDeal.fromJson(json['sponsorDeal'] as Map<String, dynamic>),
        pendingSponsorOffers: (json['pendingSponsorOffers'] as List?)
                ?.map((e) => SponsorDeal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingInstallments: (json['pendingInstallments'] as List?)
                ?.map((e) => Installment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        friendlies: (json['friendlies'] as List?)
                ?.map((e) => Fixture.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        incomingOffers: (json['incomingOffers'] as List?)
                ?.map((e) => IncomingOffer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        bankLoans: (json['bankLoans'] as List?)
                ?.map((e) => BankLoan.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        fixedDeposits: (json['fixedDeposits'] as List?)
                ?.map((e) => FixedDeposit.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        seasonAwards: (json['seasonAwards'] as List?)
                ?.map((e) => SeasonAward.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastReviewedSeason: json['lastReviewedSeason'] as int? ?? 0,
        preseasonCampPending: json['preseasonCampPending'] as bool? ?? false,
        // 旧セーブは路線なし。順位だけで評価される従来の挙動。
        clubVision: ClubVision.values.firstWhere(
          (v) => v.name == json['clubVision'],
          orElse: () => ClubVision.none,
        ),
        visionCompliedMatchdays:
            json['visionCompliedMatchdays'] as int? ?? 0,
        visionCheckedMatchdays: json['visionCheckedMatchdays'] as int? ?? 0,
        staffCandidates: (json['staffCandidates'] as List?)
                ?.map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        rivalTeamId: json['rivalTeamId'] as String?,
        rivalTeamName: json['rivalTeamName'] as String?,
        pendingPressConference: json['pendingPressConference'] == null
            ? null
            : PressQuestion.fromJson(
                json['pendingPressConference'] as Map<String, dynamic>,
              ),
        otherDivisionLeagues: json['otherDivisionLeagues'] != null
            ? (json['otherDivisionLeagues'] as List)
                .map(
                  (e) => e == null
                      ? null
                      : League.fromJson(e as Map<String, dynamic>),
                )
                .toList()
            : _legacyOtherDivisionLeagues(json),
        foreignLeagues: (json['foreignLeagues'] as Map?)?.map(
              (k, v) => MapEntry(
                  k as String, League.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
        currentDivisionTier: json['currentDivisionTier'] as int? ?? 1,
        careerWins: json['careerWins'] as int? ?? 0,
        careerDraws: json['careerDraws'] as int? ?? 0,
        careerLosses: json['careerLosses'] as int? ?? 0,
        careerSeasons: json['careerSeasons'] as int? ?? 0,
        negotiationSignings: json['negotiationSignings'] as int? ?? 0,
        breakthroughCount: json['breakthroughCount'] as int? ?? 0,
        liveWins: json['liveWins'] as int? ?? 0,
        careerCupPrize: json['careerCupPrize'] as int? ?? 0,
        pkShootoutWins: json['pkShootoutWins'] as int? ?? 0,
        wageBudget: json['wageBudget'] as int? ?? 0,
        boardCupTargetRound: json['boardCupTargetRound'] as int? ?? 0,
        managerContractYears: json['managerContractYears'] as int? ?? 0,
        difficulty: GameDifficulty.values.firstWhere(
          (d) => d.name == json['difficulty'],
          orElse: () => GameDifficulty.normal,
        ),
        newsLog: (json['newsLog'] as List?)
            ?.map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        trophyHistory: (json['trophyHistory'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        clubHistory:
            (json['clubHistory'] as List?)?.map((e) => e as String).toList() ??
                [],
        freeAgents: (json['freeAgents'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        retiredLegends: (json['retiredLegends'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        seasonHistory: (json['seasonHistory'] as List?)
                ?.map((e) => SeasonRecord.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        bestElevenHistory: (json['bestElevenHistory'] as List?)
                ?.map(
                    (e) => SeasonBestEleven.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        boardReviewDoneThisSeason:
            json['boardReviewDoneThisSeason'] as bool? ?? false,
        pendingBoardReviewMessage: json['pendingBoardReviewMessage'] as String?,
        lastManagerOfMonthCheckpoint:
            json['lastManagerOfMonthCheckpoint'] as int? ?? 0,
        trainingDoneThisWeek: json['trainingDoneThisWeek'] as bool? ?? false,
        pendingContractNegotiation: json['pendingContractNegotiation'] == null
            ? null
            : ContractNegotiation.fromJson(
                json['pendingContractNegotiation'] as Map<String, dynamic>,
              ),
        pendingSuperCup: json['pendingSuperCup'] == null
            ? null
            : CupMatch.fromJson(
                json['pendingSuperCup'] as Map<String, dynamic>),
        consecutiveNegativeBudgetWeeks:
            json['consecutiveNegativeBudgetWeeks'] as int? ?? 0,
        unlockedAchievements: (json['unlockedAchievements'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as int),
            ) ??
            {},
        seasonStartOverallByPlayerId:
            (json['seasonStartOverallByPlayerId'] as Map?)?.map(
                  (k, v) => MapEntry(k as String, v as int),
                ) ??
                {},
        weekProcessedSeason: json['weekProcessedSeason'] as int? ?? 0,
        weekProcessedMatchday: json['weekProcessedMatchday'] as int? ?? 0,
        liveMatchProgress: json['liveMatchProgress'] == null
            ? null
            : LiveMatchProgress.fromJson(
                (json['liveMatchProgress'] as Map).cast<String, dynamic>()),
        today: parseSaveDate(json['today']),
        preContracts: (json['preContracts'] as List?)
                ?.map((e) =>
                    PreContract.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        transferTalks: (json['transferTalks'] as List?)
                ?.map((e) =>
                    TransferTalk.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            [],
        preContractOpenedSeason: json['preContractOpenedSeason'] as int? ?? 0,
        optionDeadlineSeason: json['optionDeadlineSeason'] as int? ?? 0,
        unpaidWagesNoticeGiven:
            json['unpaidWagesNoticeGiven'] as bool? ?? false,
      );

  /// 日付を「2026-08-15」の形で保存する(時刻は持たない)。
  static String formatSaveDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// [formatSaveDate]の逆。無い・読めないときは null。
  static DateTime? parseSaveDate(Object? raw) {
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// 5部制ピラミッド導入前の旧セーブデータ(`otherDivisionLeagues`キーが
  /// 存在しない)を読み込む際、旧来の単一`otherDivisionLeague`
  /// (`secondDivisionTeams`しかない、さらに古い世代のデータの場合はチーム
  /// 一覧のみ)を、現在のティア以外の添字がnullな[totalDivisionTiers]要素の
  /// リストへ変換する。新たに追加された下位ティア(3部以下)は、この時点では
  /// 生成できないためnullのままにし、GameState起動時のマイグレーションで
  /// 補充する。
  static List<League?> _legacyOtherDivisionLeagues(Map<String, dynamic> json) {
    final tier = json['currentDivisionTier'] as int? ?? 1;
    final result = List<League?>.filled(totalDivisionTiers, null);
    final otherTier = tier == 1 ? 2 : 1;
    if (otherTier < 1 || otherTier > totalDivisionTiers) return result;
    if (json['otherDivisionLeague'] != null) {
      result[otherTier - 1] = League.fromJson(
        json['otherDivisionLeague'] as Map<String, dynamic>,
      );
    } else if (json['secondDivisionTeams'] != null) {
      final teams = (json['secondDivisionTeams'] as List)
          .map((e) => Team.fromJson(e as Map<String, dynamic>))
          .toList();
      result[otherTier - 1] = League(teams: teams, fixtures: const []);
    }
    return result;
  }
}
