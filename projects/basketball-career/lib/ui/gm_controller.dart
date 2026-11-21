import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gm/potential_view.dart';
import '../gm/block_report.dart';
import '../gm/career.dart';
import '../gm/skills.dart';
import '../sound/sound.dart';
import '../gm/difficulty.dart';
import '../gm/draft.dart';
import '../gm/game_sim.dart';
import '../gm/league.dart';
import '../gm/player.dart';
import '../gm/profile.dart';
import '../gm/scenario.dart';
import '../gm/trade.dart';
import '../monetization/monetization.dart';

/// 画面と任期の間を取り持つ。保存・記録・広告の番もここで扱う(画面が閉じられていても受け取れるように)。
class GmController extends ChangeNotifier {
  GmController({this.money, SharedPreferences? prefs, Random? seedSource}) : _seeds = seedSource ?? Random(), _sp = prefs;

  final Monetization? money;
  SharedPreferences? _sp;
  final Random _seeds;

  static const _careerKey = 'gmCareer';
  static const _profileKey = 'gmProfile';
  static const _howtoKey = 'gmHowtoSeen';

  Profile profile = Profile();
  Career? _career;

  /// いまのキャリア。変えると、伸びしろの見立て([viewingCareer])もこのキャリアで見る。
  Career? get career => _career;
  set career(Career? c) {
    _career = c;
    viewingCareer = c;
  }

  /// 新しく達成した実績(画面がダイアログで見せて消す)。
  final pending = <Achievement>[];

  /// 「広告を消す」の案内を出す番(全画面広告のあと、ときどき)。
  bool offerRemoveAds = false;

  /// 広告を待っている間(ボタンを止める)。
  bool busy = false;

  /// ドラフトくじの結果を見せたシーズン(画面を開き直したら、もう一度見せてよい)。
  int lotteryShownSeason = -1;

  /// はじめの画面を出しているか(起動したときは、続きがあってもはじめの画面から)。
  bool atHome = true;

  void goHome() {
    atHome = true;
    notifyListeners();
  }

  void resume() {
    if (career == null) return;
    atHome = false;
    notifyListeners();
  }

  bool get howtoSeen => _sp?.getBool(_howtoKey) ?? false;

  Future<void> markHowtoSeen() async {
    await _sp?.setBool(_howtoKey, true);
    notifyListeners();
  }

  /// 保存を読み込む。続きがあれば true。
  ///
  /// 読むのは最初の1回だけ。読む前に手元で始めた・変えたもの(テストや掲載画像の生成器が作った局面)は上書きしない。
  Future<bool> load() async {
    _sp ??= await SharedPreferences.getInstance();
    if (!_loadedOnce) {
      _loadedOnce = true;
      final p = _sp!;
      final ps = p.getString(_profileKey);
      if (ps != null && !_dirty) {
        try {
          profile = Profile.fromJson(jsonDecode(ps));
        } catch (_) {
          // 読めなかった記録は、上書きされる前に別の場所へ残す
          p.setString('$_profileKey.broken', ps);
        }
      }
      final cs = p.getString(_careerKey);
      if (cs != null && career == null && !_dirty) {
        try {
          career = Career.fromJson(jsonDecode(cs));
        } catch (_) {
          career = null;
          // 読めなかった任期は、新しく始めて消える前に別の場所へ残す
          p.setString('$_careerKey.broken', cs);
        }
      }
    }
    notifyListeners();
    return career != null;
  }

  bool _loadedOnce = false;
  bool _dirty = false;

  Future<void> _save() async {
    final p = _sp;
    if (p == null) return;
    await p.setString(_profileKey, jsonEncode(profile.toJson()));
    final c = career;
    if (c == null) {
      await p.remove(_careerKey);
    } else {
      await p.setString(_careerKey, jsonEncode(c.toJson()));
    }
  }

  /// 画面の中で直に変えた分(代理人との往復など)を保存する。
  void touch() => _changed();

  void _changed() {
    _dirty = true;
    notifyListeners();
    _save();
  }

  /// チームを選ぶ前に見せるリーグの種(選ぶ画面と、任されたあとで同じリーグになる)。
  int newSeed() => _seeds.nextInt(0x7fffffff);

  /// [seed] のリーグで、[team] のGMに任される。
  /// シナリオで始める(チームはお題に合わせて選ぶ)。
  void newScenario(Scenario s, {int? seed, Difficulty difficulty = Difficulty.normal}) {
    final sd = seed ?? newSeed();
    final team = scenarioTeam(Career.start(seed: sd), s);
    newCareer(team, seed: sd, difficulty: difficulty);
    career!.startScenario(s);
    _changed();
  }

  void newCareer(int team, {int? seed, Difficulty difficulty = Difficulty.normal}) {
    // 終わった任期の上に始めるときも、終わった任期を記録に数える
    final old = career;
    if (old != null && old.phase == Phase.over) pending.addAll(profile.recordCareerEnd(old));
    career = Career.start(seed: seed ?? newSeed(), team: team, difficulty: difficulty);
    atHome = false;
    _changed();
  }

  /// 任期を閉じて、はじめの画面へ。終わった任期はここで数える。
  void closeCareer() {
    final c = career;
    if (c != null && c.phase == Phase.over) pending.addAll(profile.recordCareerEnd(c));
    career = null;
    atHome = true;
    _changed();
  }

  /// 試合を進める前に、全画面広告の番なら出す。
  Future<void> _maybeInterstitial() async {
    final m = money;
    if (m == null || !m.interstitialDue) return;
    busy = true;
    notifyListeners();
    try {
      final shown = await m.beforeAction();
      if (shown && m.removeAdsOfferDue) {
        offerRemoveAds = (await m.canBuy) && await m.price != null;
        await m.markRemoveAdsOffered();
      }
    } catch (_) {
    } finally {
      busy = false;
    }
  }

  void startSeason() => _act((c) => c.startSeason());

  /// 次の区切り(20〜21試合)を進める。
  Future<BlockReport?> playBlock() async {
    final c = career;
    if (c == null || c.phase != Phase.season || busy) return null;
    if (c.roundAt == blockStart(c.block)) await _maybeInterstitial();
    final snap = _blockSnapOf(c);
    c.playBlock();
    unawaited(Sfx.play(SoundEffect.buzzer));
    await money?.tournamentPlayed();
    _record(c);
    _changed();
    return BlockReport.make(c, snap);
  }

  /// 1週間進める。全画面広告の番は、区切りの初めから進めるときだけ見る(週ごとに広告を出さない)。
  /// 試合をまとめて進める([toDeadline] ならトレードの締め切りまで、でなければレギュラーシーズンの終わりまで)。
  /// 全画面広告の番は最初に1回だけ見る。申し込みが届いたら、そこで止める(返事をしてもらうため)。
  Future<BlockReport?> simAhead({required bool toDeadline}) async {
    final c = career;
    if (c == null || c.phase != Phase.season || busy) return null;
    await _maybeInterstitial();
    final snap = BlockSnapshot.of(c);
    final games = <GameResult>[];
    injuryStop = null;
    simStopReason = null;
    while (c.phase == Phase.season && (!toDeadline || c.block < tradeDeadlineBlock)) {
      final before = c.lastGames.length;
      final fromStart = c.roundAt == blockStart(c.block);
      final starters = _healthyStarters(c);
      final asked = {
        for (final m in c.inbox)
          if (m.needsAnswer) m.id,
      };
      c.playBlock();
      games.addAll(fromStart ? c.lastGames : c.lastGames.sublist(before));
      await money?.tournamentPlayed();
      if (c.phase != Phase.season) break;
      final reason = _stopReason(c, asked);
      if (reason != null) {
        simStopReason = reason;
        break;
      }
      // 先発がけがをしたら止めて聞く(2K でも、けがのたびにシムが止まり組み直すかを聞かれる)
      if (c.stopsOn(SimStop.injury)) {
        injuryStop = _newlyHurt(c, starters);
        if (injuryStop != null) break;
      }
    }
    _record(c);
    _changed();
    return BlockReport.make(c, snap, games);
  }

  /// [n] 節を1節ずつ進める(区切りをまたいでよい)。1節ごとに [onRound] を待つ(画面が結果を流して見せる)。
  /// 申し込み・返事の要る知らせ・連敗/連勝に入った・疲れ・先発のけがで止まる(止まる場面の設定どおり)。
  /// [simCancel] を立てると、その節で止まる。[stops] が false なら止まる場面では止まらない(区切りを進めるボタン)。全画面広告の番は最初に1回だけ見る。
  Future<BlockReport?> simRounds(int n, {Future<void> Function(List<GameResult> games)? onRound, bool stops = true}) async {
    final c = career;
    if (c == null || c.phase != Phase.season || busy || n <= 0) return null;
    await _maybeInterstitial();
    final snap = BlockSnapshot.of(c);
    final games = <GameResult>[];
    injuryStop = null;
    simStopReason = null;
    simCancel = false;
    busy = true;
    try {
      for (var left = n; left > 0 && c.phase == Phase.season; left--) {
        final starters = _healthyStarters(c);
        final asked = {
          for (final m in c.inbox)
            if (m.needsAnswer) m.id,
        };
        final streak = c.me.streak;
        final tired = c.me.roster.any((p) => p.wear > wearSlumpLine);
        final before = c.lastGames.length;
        final fromStart = c.roundAt == blockStart(c.block);
        final ended = c.playDays(1);
        final got = fromStart ? [...c.lastGames] : c.lastGames.sublist(before);
        games.addAll(got);
        if (ended) await money?.tournamentPlayed();
        // 1節ごとは画面を描き直すだけ(保存は最後に1回。毎節すべてを保存すると「一気に」で固まる)
        notifyListeners();
        if (onRound != null) await onRound(got);
        if (c.phase != Phase.season) break;
        // 先発のけがは、最後の1節でも聞く
        if (stops && c.stopsOn(SimStop.injury)) {
          injuryStop = _newlyHurt(c, starters);
          if (injuryStop != null) break;
        }
        if (left == 1 || simCancel) break;
        if (!stops) continue;
        // トレードの締め切りを、気づかないまま越えない(締め切り前の最後の1試合の手前で止まる)
        if (c.block == tradeDeadlineBlock - 1 && c.roundAt == blockStart(tradeDeadlineBlock) - 1) {
          simStopReason = SimStop.deadline;
          break;
        }
        final reason = _stopReasonNew(c, asked, streak, tired);
        if (reason != null) {
          simStopReason = reason;
          break;
        }
      }
    } finally {
      busy = false;
    }
    simCancel = false;
    _record(c);
    _changed();
    return BlockReport.make(c, snap, games);
  }

  /// [simRounds] を途中で止める(画面の「止める」)。
  bool simCancel = false;

  /// 1節ずつ進めるときの止まる場面。連敗・連勝・疲れは、その節で新しく入ったときだけ止まる(続いているあいだ毎節止まらない)。
  static SimStop? _stopReasonNew(Career c, Set<int> asked, int streakBefore, bool tiredBefore) {
    if (c.stopsOn(SimStop.offer) && c.incoming != null) return SimStop.offer;
    if (c.stopsOn(SimStop.mail) && c.inbox.any((m) => m.needsAnswer && !asked.contains(m.id))) return SimStop.mail;
    if (c.stopsOn(SimStop.slump) && c.me.streak == -4 && streakBefore == -3) return SimStop.slump;
    if (c.stopsOn(SimStop.hot) && c.me.streak == 5 && streakBefore == 4) return SimStop.hot;
    if (c.stopsOn(SimStop.tired) && !tiredBefore && c.me.roster.any((p) => p.wear > wearSlumpLine)) return SimStop.tired;
    return null;
  }

  /// まとめて進めている途中で、先発の選手が長めのけがをした(画面が止めて「組み直すか」を聞く)。聞いたら null に戻す。
  Player? injuryStop;

  /// まとめて進めるのを止めた場面(けが以外。画面が知らせる)。
  SimStop? simStopReason;

  static SimStop? _stopReason(Career c, Set<int> asked) {
    if (c.stopsOn(SimStop.offer) && c.incoming != null) return SimStop.offer;
    if (c.stopsOn(SimStop.mail) && c.inbox.any((m) => m.needsAnswer && !asked.contains(m.id))) return SimStop.mail;
    if (c.stopsOn(SimStop.slump) && c.me.streak <= -4) return SimStop.slump;
    if (c.stopsOn(SimStop.hot) && c.me.streak >= 5) return SimStop.hot;
    if (c.stopsOn(SimStop.tired) && c.me.roster.any((p) => p.wear > wearSlumpLine)) return SimStop.tired;
    return null;
  }

  void toggleSimStop(SimStop s) => _act((c) => c.toggleSimStop(s));

  static Set<int> _healthyStarters(Career c) => {
    for (final p in c.me.order.take(5))
      if (p.injured == 0) p.id,
  };

  /// [before] で元気だった先発のうち、3試合以上休むけがをした選手(力の高い順の1人)。
  static Player? _newlyHurt(Career c, Set<int> before) {
    final hurt = [
      for (final p in c.me.roster)
        if (before.contains(p.id) && p.injured >= 3) p,
    ]..sort((a, b) => b.ovr.compareTo(a.ovr));
    return hurt.firstOrNull;
  }

  /// 「自動で組み直す」: けが人を後ろへ回し、出場時間を自動に戻す。
  void benchInjured() {
    injuryStop = null;
    _act((c) => c.benchInjured());
  }

  void keepRotation() {
    injuryStop = null;
    _changed();
  }

  void toggleTradeBlock(int id) => _act((c) => c.toggleTradeBlock(id));
  void toggleRest(int id) => _act((c) => c.toggleRest(id));
  void setRestWhenSettled(bool v) => _act((c) => c.restWhenSettled = v);
  void signAndTrade(int id) => _act((c) => c.signAndTrade(id));

  /// トレードブロックの申し込みを受ける。成立したら true。
  bool acceptBlockOffer(TradeOffer o) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.acceptBlockOffer(o);
    _record(c);
    _changed();
    return ok;
  }

  /// 区切りの初めの様子((シーズン, 区切り, 様子))。区切りの途中から進めても、報告は区切りの初めと比べる。
  (int, int, BlockSnapshot)? _blockSnap;

  BlockSnapshot _blockSnapOf(Career c) {
    final s = _blockSnap;
    if (s != null && s.$1 == c.season && s.$2 == c.block && c.roundAt != blockStart(c.block)) return s.$3;
    final now = BlockSnapshot.of(c);
    // 控えが無い(アプリを開き直した)ときは、今の様子を区切りの初めの代わりにする
    _blockSnap = (c.season, c.block, now);
    return now;
  }

  /// 1週間進める。区切りの終わりに着いたときだけ報告を返す。
  Future<BlockReport?> playWeek() async {
    final c = career;
    if (c == null || c.phase != Phase.season || busy) return null;
    if (c.roundAt == blockStart(c.block)) await _maybeInterstitial();
    final snap = _blockSnapOf(c);
    final starters = _healthyStarters(c);
    final ended = c.playWeek();
    injuryStop = c.phase == Phase.season ? _newlyHurt(c, starters) : null;
    if (ended) await money?.tournamentPlayed();
    _record(c);
    _changed();
    // 区切りの全部の試合でまとめる(週ごとの分ではなく)
    return ended ? BlockReport.make(c, snap, c.lastGames) : null;
  }

  /// 采配した試合のある1節を進める。区切りの終わりに着いたときだけ報告を返す。
  Future<BlockReport?> playLive(List<LiveCall> calls) async {
    final c = career;
    if (c == null || c.phase != Phase.season || busy || c.nextMyGame == null) return null;
    final snap = _blockSnapOf(c);
    final starters = _healthyStarters(c);
    final ended = c.playLiveDay(calls);
    injuryStop = c.phase == Phase.season ? _newlyHurt(c, starters) : null;
    if (ended) await money?.tournamentPlayed();
    _record(c);
    _changed();
    return ended ? BlockReport.make(c, snap, c.lastGames) : null;
  }

  Future<void> playPlayoffs() async {
    final c = career;
    if (c == null || c.phase != Phase.playoffs || busy) return;
    if (!c.poLive) await _maybeInterstitial();
    c.playPlayoffs();
    await _afterPlayoffStep(c);
  }

  /// プレーオフを始める(自分の最初の試合の手前まで進む)。
  Future<void> startPlayoffs() async {
    final c = career;
    if (c == null || c.phase != Phase.playoffs || c.poLive || busy) return;
    await _maybeInterstitial();
    c.startPlayoffs();
    await _afterPlayoffStep(c);
  }

  /// プレーオフの自分の次の1試合を戦う([calls] は采配したとき)。
  Future<void> playPlayoffGame({List<LiveCall>? calls}) async {
    final c = career;
    if (c == null || c.phase != Phase.playoffs || !c.poLive || busy) return;
    c.playPlayoffGame(calls: calls);
    unawaited(Sfx.play(SoundEffect.buzzer));
    await _afterPlayoffStep(c);
  }

  /// 今のシリーズが決まるまで戦う。
  Future<void> playPlayoffSeries() async {
    final c = career;
    if (c == null || c.phase != Phase.playoffs || !c.poLive || busy) return;
    c.playPlayoffSeries();
    await _afterPlayoffStep(c);
  }

  /// プレーオフが終わっていれば、音・広告の数・記録を済ませる。
  Future<void> _afterPlayoffStep(Career c) async {
    if (c.phase == Phase.seasonEnd) {
      unawaited(Sfx.play(c.myResult >= 5 ? SoundEffect.fanfare : SoundEffect.buzzer));
      await money?.tournamentPlayed();
      pending.addAll(profile.recordSeason(c));
    }
    _record(c);
    _changed();
  }

  void toOffseason() => _act((c) => c.toOffseason());

  /// 解任されたあと、ほかのチームの誘いを受ける。
  void takeJob(int team) {
    _act((c) => c.takeJob(team));
    unawaited(Sfx.play(SoundEffect.chime));
  }

  void exerciseOption(int id) => _act((c) => c.exerciseOption(id));

  /// オフの電話の申し込みを受ける。成立したら true。
  bool acceptCall(int i) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.acceptCall(i);
    _record(c);
    _changed();
    return ok;
  }

  void declineCall(int i) => _act((c) => c.declineCall(i));

  /// 大物に会いに行く(話すことは [Career.pitchLines] の番号)。
  void pitch(int id, int kind) => _act((c) => c.pitch(id, kind));

  /// 若手の指導役を付ける・外す。
  void setMentor(int vet, int young) => _act((c) => c.setMentor(vet, young));
  void clearMentor() => _act((c) => c.clearMentor());

  /// 夏の個人練習で伸ばす能力を決める(null で外す)。
  void setCamp(int id, Attr? a) => _act((c) => c.setCamp(id, a));

  /// サマーリーグを開く(オフの契約の時期に1回)。
  void playSummerLeague() {
    _act((c) => c.playSummerLeague());
    unawaited(Sfx.play(SoundEffect.chime));
  }

  void declineOption(int id) => _act((c) => c.declineOption(id));

  /// 任期を自分で終える(任期に上限は無い)。
  void endCareer() => _act((c) => c.endCareer());
  void pickProspect(Prospect p) {
    _act((c) => c.pickProspect(p));
    unawaited(Sfx.play(SoundEffect.tick));
  }

  void passPick() => _act((c) => c.passPick());
  void workout(Prospect p) => _act((c) => c.workout(p));

  void scoutProspect(Prospect p) {
    _act((c) => c.scoutProspect(p));
    unawaited(Sfx.play(SoundEffect.chime));
  }

  void toggleBoard(Prospect p) => _act((c) => c.toggleBoard(p));
  void resign(int id, int years) {
    _act((c) => c.resign(id, years));
    unawaited(Sfx.play(SoundEffect.chime));
  }

  void letGo(int id) => _act((c) => c.letGo(id));
  void matchSheet() => _act((c) => c.matchSheet());
  void declineSheet() => _act((c) => c.declineSheet());
  void signFreeAgent(int id, int years) {
    _act((c) => c.signFreeAgent(id, years));
    unawaited(Sfx.play(SoundEffect.chime));
  }

  void release(int id, {ReleaseMode mode = ReleaseMode.full}) => _act((c) => c.release(id, mode: mode));
  void signTwoWay(int id) => _act((c) => c.signTwoWay(id));
  void signTenDay(int id) => _act((c) => c.signTenDay(id));
  void toTwoWay(int id) => _act((c) => c.toTwoWay(id));
  void promoteTwoWay(int id) => _act((c) => c.promoteTwoWay(id));
  void waiveTwoWay(int id) => _act((c) => c.waiveTwoWay(id));
  void finishContracts() => _act((c) => c.finishContracts());
  void nextFaDay() => _act((c) => c.nextFaDay());
  void setTraining(int level) => _act((c) => c.setTraining(level));
  void setPolicy(int axis, int choice) => _act((c) => c.setPolicy(axis, choice));
  void setFocus(int id, Attr? a) => _act((c) => c.setFocus(id, a));
  void withdrawBid(int id) => _act((c) => c.withdrawBid(id));

  /// 大物に申し込む。申し込めたら true。
  bool bid(int id, int years, double factor) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.bid(id, years, factor);
    _changed();
    return ok;
  }

  void setRotation(List<int> ids) => _act((c) => c.setRotation(ids));
  void readMessage(int id) => _act((c) => c.readMessage(id));
  void readAllMessages() => _act((c) => c.readAllMessages());
  void clearReadMessages() => _act((c) => c.clearReadMessages());
  void answer(int id, int choice) => _act((c) => c.answer(id, choice));
  void setPrice(int level) => _act((c) => c.setPrice(level));
  void learnSkill(Skill s) => _act((c) => c.learnSkill(s));
  void ownerMeeting(int level) => _act((c) => c.ownerMeeting(level));
  void setConcession(int level) => _act((c) => c.setConcession(level));

  void upgradeFacility(Facility f) => _act((c) => c.upgradeFacility(f));
  void hireCoach(int poolIndex) => _act((c) => c.hireCoach(poolIndex));
  void setMinutes(Map<int, int> m) => _act((c) => c.setMinutes(m));

  /// 契約の延長を申し出る。受けたら true。
  bool extend(int id, int years, double factor) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.extend(id, years, factor);
    _changed();
    return ok;
  }

  /// 契約を申し出る(交渉)。受けたら true。
  void setPartial(bool v) {
    final car = career;
    if (car != null) car.partialNext = v;
  }

  bool offer(int id, int years, double factor, {bool agreed = false}) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.offer(id, years, factor, agreed: agreed);
    _record(c);
    _changed();
    return ok;
  }

  void acceptIncoming() => _act((c) => c.acceptIncoming());
  void declineIncoming() => _act((c) => c.declineIncoming());

  /// トレードを申し込む。成立したら true。
  bool propose(TradeOffer o) {
    final c = career;
    if (c == null || busy) return false;
    final ok = c.propose(o);
    if (ok) unawaited(Sfx.play(SoundEffect.chime));
    _record(c);
    _changed();
    return ok;
  }

  void _record(Career c) => pending.addAll(profile.recordProgress(c));

  void _act(void Function(Career c) f) {
    final c = career;
    if (c == null || busy) return;
    f(c);
    _record(c);
    _changed();
  }

  /// 広告を消した人は、動画なしで受け取れる。
  bool get needsAd => money?.recoverNeedsAd ?? false;

  /// 動画を見て、スカウトを2回増やす(ドラフトごとに1度)。
  Future<RecoverGate> scoutsWithAd({void Function()? onWaiting}) => _withAd((c) => c.canAddScouts, (c) => c.addScouts(), onWaiting);

  /// 動画を見て、オーナーを説得する(解任を1度だけ取り消す)。
  Future<RecoverGate> rescueWithAd({void Function()? onWaiting}) => _withAd((c) => c.canRescue, (c) => c.rescue(), onWaiting);

  Future<RecoverGate> _withAd(bool Function(Career c) allowed, void Function(Career c) grant, void Function()? onWaiting) async {
    final c = career;
    if (c == null || busy || !allowed(c)) return RecoverGate.unavailable;
    final m = money;
    busy = true;
    notifyListeners();
    RecoverGate gate;
    try {
      // 広告の無い環境(テスト・Web)では、タダでは受け取らせない
      gate = m == null ? RecoverGate.unavailable : await m.beforeRecover(onWaiting: onWaiting);
    } catch (_) {
      gate = RecoverGate.unavailable;
    } finally {
      busy = false;
    }
    // 受け取りは画面に依らずここで(動画の間に画面が閉じられても受け取れる。app-pitfalls #2)
    if (gate == RecoverGate.granted && career == c && allowed(c)) {
      grant(c);
    }
    _changed();
    return gate;
  }

  void dismissAchievement() {
    if (pending.isNotEmpty) pending.removeAt(0);
    notifyListeners();
  }

  void dismissRemoveAdsOffer() {
    offerRemoveAds = false;
    notifyListeners();
  }

  /// テスト・掲載画像の生成器用: 任期を差し替える。
  @visibleForTesting
  void setCareer(Career c) {
    career = c;
    atHome = false;
    _changed();
  }
}
