import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/achievements.dart';
import '../game/after_career.dart';
import '../game/difficulty.dart';
import '../game/exp.dart';
import '../game/career.dart';
import '../game/characters.dart' show tipsNeeded;
import '../game/flavor.dart';
import '../game/marks.dart';
import '../game/game.dart';
import '../game/school.dart';
import '../game/invest.dart';
import '../game/life.dart';
import '../game/path.dart';
import '../game/player.dart';
import '../game/snapshot.dart';
import '../game/talent.dart';
import '../game/traits.dart';
import 'history.dart';
import 'labels.dart';
import 'backup_share.dart';
import 'sound.dart';
import '../monetization/monetization.dart';

const saveKey = 'baseball_manager_save_v1';
const historyKey = 'baseball_manager_history_v1';

/// 表示するバージョン(pubspec.yaml の version と合わせる)。
const appVersion = '0.1.0';
const adminKey = 'baseball_manager_admin_v1';
const textScaleKey = 'baseball_manager_text_scale_v1';
const themeKey = 'baseball_manager_theme_v1';
const flagsKey = 'baseball_manager_flags_v1';
const corruptKey = 'baseball_manager_corrupt_save_v1';

/// テスト用ビルド(`--dart-define=TEST_BUILD=true`)。管理者モードが最初からオンになる。
const kTestBuild = bool.fromEnvironment('TEST_BUILD');
const achievementsKey = 'baseball_manager_achievements_v1';

/// 特性図鑑(これまでに持ったことのある特性の名前)。
const traitBookKey = 'baseball_manager_traitbook_v1';

/// 継承ポイント(引退で貯まり、次の選手に特性を持たせるのに使う)。
const legacyKey = 'baseball_manager_legacy_v1';

/// 自動バックアップ(直近3件。選手を始め直す前・引退したとき・4歳ごとの節目)。
const autoBackupKey = 'baseball_manager_autobackup_v1';
const autoBackupMax = 3;

/// 自動でとった、データの控え。
class AutoBackup {
  const AutoBackup(this.at, this.why, this.text);
  final DateTime at;

  /// とった理由(画面に出す)。
  final String why;

  /// `exportBackup` の文字列。
  final String text;

  Map<String, dynamic> toJson() =>
      {'at': at.millisecondsSinceEpoch, 'why': why, 'text': text};

  static AutoBackup? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = j['at'];
    final why = j['why'];
    final text = j['text'];
    if (at is! num || why is! String || text is! String) return null;
    return AutoBackup(
        DateTime.fromMillisecondsSinceEpoch(at.toInt()), why, text);
  }
}

/// はじめてのガイドを見たか(端末単位)。
const guideKey = 'baseball_manager_guide_v1';

enum MilestoneKind {
  draft,
  champion,
  trait,
  stage,
  title,
  achievement,
  national,
  world
}

/// 人生の節目。ダイアログで大きく見せる。
class Milestone {
  const Milestone(this.kind, this.title, this.body);
  final MilestoneKind kind;
  final String title;
  final String body;
}

/// セーブの読み書き。端末ごと(クラウド同期はしない)。
class SaveStore {
  /// 直近の読み込みで、保存データが壊れていたか。
  bool loadFailed = false;

  Future<Map<String, dynamic>?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(saveKey);
      if (s == null) return null;
      try {
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        // 壊れたセーブは無いものとして扱うが、消さずに控えを残す。
        loadFailed = true;
        await p.setString(corruptKey, s);
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// 直近の保存に失敗したか(ブラウザの設定で保存が禁止されているときなど)。
  bool saveFailed = false;

  Future<void> save(Map<String, dynamic> json) async {
    try {
      final p = await SharedPreferences.getInstance();
      saveFailed = !await p.setString(saveKey, jsonEncode(json));
    } catch (_) {
      saveFailed = true;
    }
  }

  Future<List<HistoryEntry>> loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(historyKey);
      if (s == null) return [];
      return [
        for (final e in jsonDecode(s) as List)
          HistoryEntry.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> h) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          historyKey, jsonEncode([for (final e in h) e.toJson()]));
    } catch (_) {}
  }

  Future<Set<String>> loadAchievements() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(achievementsKey) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAchievements(Set<String> ids) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(achievementsKey, ids.toList()..sort());
    } catch (_) {}
  }

  Future<Set<String>> loadTraitBook() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(traitBookKey) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTraitBook(Set<String> names) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(traitBookKey, names.toList()..sort());
    } catch (_) {}
  }

  Future<List<AutoBackup>> loadAutoBackups() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(autoBackupKey);
      if (raw == null) return [];
      return [
        for (final e in jsonDecode(raw) as List)
          if (AutoBackup.fromJson(e) != null) AutoBackup.fromJson(e)!,
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAutoBackups(List<AutoBackup> list) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          autoBackupKey, jsonEncode([for (final b in list) b.toJson()]));
    } catch (_) {}
  }

  Future<void> clearAutoBackups() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(autoBackupKey);
    } catch (_) {}
  }

  Future<bool> loadGuideSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(guideKey) ?? false;
    } catch (_) {
      return true; // 保存できない環境では、毎回出さない
    }
  }

  Future<void> saveGuideSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(guideKey, true);
    } catch (_) {}
  }

  Future<void> clearGuide() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(guideKey);
    } catch (_) {}
  }

  Future<int> loadLegacy() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt(legacyKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveLegacy(int n) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(legacyKey, n);
    } catch (_) {}
  }

  Future<void> clearLegacy() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(legacyKey);
    } catch (_) {}
  }

  Future<void> clearTraitBook() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(traitBookKey);
    } catch (_) {}
  }

  Future<void> clearAchievements() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(achievementsKey);
    } catch (_) {}
  }

  Future<bool> loadAdmin() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(adminKey) ?? kTestBuild;
    } catch (_) {
      return false;
    }
  }

  /// 表示の設定(文字の大きさ、テーマ)。
  Future<({double scale, ThemeMode theme})> loadDisplay() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString(themeKey);
      return (
        scale: p.getDouble(textScaleKey) ?? 1.0,
        theme: ThemeMode.values
            .firstWhere((m) => m.name == t, orElse: () => ThemeMode.system),
      );
    } catch (_) {
      return (scale: 1.0, theme: ThemeMode.system);
    }
  }

  Future<void> saveDisplay(double scale, ThemeMode theme) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(textScaleKey, scale);
      await p.setString(themeKey, theme.name);
    } catch (_) {}
  }

  /// 動きを減らす・触覚・結果の知らせ(画面の下)。保存は 'm,h,t' の形。
  Future<({bool reduceMotion, bool haptics, bool toasts, bool sound})>
      loadFlags() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = (p.getString(flagsKey) ?? '').split(',');
      bool at(int i, bool d) => v.length > i ? v[i] == '1' : d;
      return (
        reduceMotion: at(0, false),
        haptics: at(1, true),
        toasts: at(2, true),
        sound: at(3, true)
      );
    } catch (_) {
      return (reduceMotion: false, haptics: true, toasts: true, sound: true);
    }
  }

  Future<void> saveFlags(bool m, bool h, bool t, [bool s = true]) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          flagsKey, '${m ? 1 : 0},${h ? 1 : 0},${t ? 1 : 0},${s ? 1 : 0}');
    } catch (_) {}
  }

  /// 読み込めなかったセーブを、消さずに別の場所へ控えておく。
  Future<void> keepCorrupt(Map<String, dynamic> json) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(corruptKey, jsonEncode(json));
    } catch (_) {}
  }

  Future<void> saveAdmin(bool on) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(adminKey, on);
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(historyKey);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(saveKey);
    } catch (_) {}
  }
}

/// 画面とゲームをつなぐ。操作のたびに保存する。
/// 今のおすすめ。疲れていれば休養、気持ちが沈んでいれば交流、それ以外は練習。
Plan recommendedPlan(Game g) {
  final c = g.condition;
  if (c.fatigue >= 70) return Plan.rest;
  if (c.morale < 35) return Plan.social;
  // コーチのコツが貯まりきっていなければ、3回に1回は教わる(特性の習得につながる)。
  final coach = g.cast.coach;
  if (coach != null && coach.tips < tipsNeeded && g.slot % 3 == 2) {
    return Plan.lesson;
  }
  return Plan.train;
}

/// おすすめの理由(画面に出す)。
String recommendReason(Game g) {
  final c = g.condition;
  if (c.fatigue >= 70) return '疲れが${c.fatigue}と高いので、休養で回復しよう。';
  if (c.morale < 35) return 'やる気が${c.morale}と低いので、交流でやる気を上げよう。';
  if (recommendedPlan(g) == Plan.lesson) {
    return 'コーチのコツを貯めると、特性を習得できる。今回は教わろう。';
  }
  return '体調は十分。練習で重点の能力を伸ばそう。';
}

/// 出来事の選択の結果を、変わったところだけ短く言葉にする。「球威 +3 / やる気 +8」。
/// 何も変わらなければ空。
String eventResultText(Player p0, Condition c0, Player p1, Condition c1,
    {int tips0 = 0, int tips1 = 0}) {
  final parts = <String>[];
  String sgn(int d) => d > 0 ? '+$d' : '$d';
  for (final a in Ability.values) {
    final d = p1.of(a) - p0.of(a);
    if (d != 0 && p1.abilities.containsKey(a)) {
      parts.add('${abilityLabel(a)} ${sgn(d)}');
    }
  }
  final m = c1.morale - c0.morale;
  if (m != 0) parts.add('やる気 ${sgn(m)}');
  final f = c1.fatigue - c0.fatigue;
  if (f != 0) parts.add('疲れ ${sgn(f)}');
  if (c1.injuredTerms > c0.injuredTerms) parts.add('怪我');
  // 才能(素質・天賦)は星5つで見せる。星が変わらない小さな上昇も知らせる。
  if (p1.potential > p0.potential) {
    final s0 = talentStarCount(p0.potential), s1 = talentStarCount(p1.potential);
    parts.add(s1 > s0 ? '才能 ${starsOf(s0)}→${starsOf(s1)}' : '才能が伸びた');
  }
  for (final a in abilitiesOf(p1.role)) {
    if (p1.gift(a) > p0.gift(a)) {
      parts.add(
          '${abilityLabel(a)}の才能 ${giftStars(p0.gift(a))}→${giftStars(p1.gift(a))}');
    }
  }
  for (final t in p1.traits) {
    if (!p0.traits.contains(t)) parts.add('特性「${t.label}」');
  }
  if (tips1 > tips0) parts.add('コーチのコツ +${tips1 - tips0}');
  return parts.join(' / ');
}

class GameController extends ChangeNotifier {
  GameController(
      {SaveStore? store,
      Random? rng,
      SoundPlayer? sound,
      this.autoGuide = false,
      this.sharer,
      this.money})
      : store = store ?? SaveStore(),
        _rng = rng ?? Random(),
        sound = sound ?? const NullSound();

  /// 最初の選手を始めたときに、はじめてのガイドを自動で出すか(アプリ本体は true、テストは false)。
  final bool autoGuide;

  /// 広告と「広告を消す」(アプリ本体だけ。テストは null で、広告も購入の表示も出ない)。
  final Monetization? money;

  /// 疲れを取る動画を見た歳(同じ歳には1度だけ)。
  int _recoveredAge = -1;

  /// 前の操作のときの歳(年が変わった瞬間を見つける)。
  int _adAge = -1;

  /// 動画で疲れを取れる状態か(疲れが70以上・怪我でない・その歳にまだ使っていない)。
  bool get canRecoverByAd {
    final g = game;
    if (money == null || g == null || g.phase == Phase.retired) return false;
    return g.condition.fatigue >= 70 &&
        g.condition.injuredTerms == 0 &&
        g.player.age != _recoveredAge;
  }

  /// 動画を見て疲れを取る。結果は「いまの結果」の文面(取れなかった理由を含む)で返す。
  Future<String> recoverByAd({void Function()? onWaiting}) async {
    final m = money;
    final g = game;
    if (m == null || g == null || !canRecoverByAd) return '今は使えません。';
    final age = g.player.age;
    _recoveredAge = age; // 重ねて押されても二重に渡さない
    final r = await m.beforeRecovery(onWaiting: onWaiting);
    // 広告を見ている間に画面を離れても渡す(見終えているのに何も入らない、を防ぐ)
    if (r != RecoveryGate.granted) {
      _recoveredAge = -1;
      return switch (r) {
        RecoveryGate.declined => '最後まで見ると疲れが取れます。',
        RecoveryGate.showFailed => '動画を出せませんでした。しばらくしてからもう一度どうぞ。',
        _ => '今は動画を読み込めません。通信を確かめて、あとでもう一度どうぞ。',
      };
    }
    if (!identical(game, g)) return '選手が替わったので、疲れは取れませんでした。';
    final start = g.log.length;
    g.relieveFatigue();
    recent = g.log.sublist(start);
    _cue(Sfx.rankup);
    _commit();
    return '疲れが大きく抜けました。';
  }

  /// バックアップを共有メニューに渡す係(アプリ本体だけ。テストは null で、ボタンも出ない)。
  final BackupSharer? sharer;

  /// 自動バックアップ(新しい順、最大 `autoBackupMax` 件)。
  List<AutoBackup> autoBackups = [];
  int _backedAge = -1;

  /// いまのデータの控えを1件とる。同じ内容がすぐ前にあれば足さない。
  void autoBackup(String why) {
    final text = exportBackup();
    if (autoBackups.isNotEmpty && autoBackups.first.text == text) return;
    autoBackups = [AutoBackup(DateTime.now(), why, text), ...autoBackups]
        .take(autoBackupMax)
        .toList();
    store.saveAutoBackups(autoBackups);
  }

  /// 自動バックアップ `i` に戻す。戻す前のデータも控えに残す(戻しすぎても、やり直せる)。
  Future<bool> restoreAutoBackup(int i) async {
    if (i < 0 || i >= autoBackups.length) return false;
    final text = autoBackups[i].text;
    autoBackup('戻す前');
    return importBackup(text);
  }

  /// 次の画面でガイドを出したいか。見せたら `markGuideSeen` で false に戻す。
  bool guidePending = false;
  bool guideSeen = false;

  void markGuideSeen() {
    guidePending = false;
    guideSeen = true;
    store.saveGuideSeen();
  }

  final SaveStore store;

  /// 効果音を鳴らす係(テストでは何もしない)。鳴らすかどうかは `soundOn`。
  final SoundPlayer sound;
  final Random _rng;
  Game? game;

  /// まだ見せていない節目。画面が1つずつ取り出して見せる。
  final List<Milestone> pending = [];

  /// 直前の操作で増えた記録(画面の「いまの結果」に出す)。
  List<String> recent = const [];

  /// 直前の行動の結果を、短く知らせる文(画面の下に一瞬出す)。出したら null に戻す。
  String? toast;

  /// 結果の調子: 1=好調・大成功 / -1=失敗・怪我 / 0=ふつう。トーストの色と印に使う。
  int toastTone = 0;

  /// 殿堂から、選手を1人消す。
  void deleteHistory(HistoryEntry e) {
    history = [
      for (final h in history)
        if (!identical(h, e)) h
    ];
    store.saveHistory(history);
    notifyListeners();
  }

  /// 引退した選手の子(二世)として、すぐ次の選手を始める。
  void continueAsHeir() {
    final g = game;
    if (g == null || g.phase != Phase.retired) return;
    final parent = PlayerSnapshot.fromGame(g);
    final role = g.player.role == Role.twoWay ? Role.batter : g.player.role;
    newGame(randomNameOf(_rng), role, g.difficulty, parent);
  }

  /// いま重点にしている能力。
  Ability focus = Ability.contact;

  /// 殿堂(過去の選手)。新しい順。
  List<HistoryEntry> history = const [];

  /// 海外のリーグへ移籍する / 日本に戻る(プロの年の最初だけ)。
  void moveOverseas() {
    final g = game!;
    final start = g.log.length;
    g.moveOverseas();
    recent = g.log.sublist(start);
    _detect(g.stage, g, recent);
    _commit();
  }

  void useFa(FaChoice c) {
    final g = game!;
    final start = g.log.length;
    g.useFa(c);
    recent = g.log.sublist(start);
    _commit();
  }

  void returnHome() {
    final g = game!;
    final start = g.log.length;
    g.returnHome();
    recent = g.log.sublist(start);
    _commit();
  }

  /// 投資する(プロの間)。買えたら true。
  bool buyInvest(Invest i) {
    final ok = game!.buyInvest(i);
    if (ok) _commit();
    return ok;
  }

  /// 今年の目標のむずかしさを選ぶ(年の最初の行動の前だけ)。
  void chooseGoalLevel(int level) {
    game!.chooseGoalLevel(level);
    _commit();
  }

  /// オフの過ごし方を決める(プロの年のはじめ)。
  void chooseOffseason(Offseason o) {
    final g = game!;
    final start = g.log.length;
    g.chooseOffseason(o, focus);
    recent = g.log.sublist(start);
    _commit();
  }

  /// 進学先を決める(入学の年だけ)。
  void chooseSchool(School sc) {
    final g = game!;
    final start = g.log.length;
    g.chooseSchool(sc);
    recent = g.log.sublist(start);
    _commit();
  }

  /// ポジションを決める(決められる時だけ)。
  void choosePosition(Pos pos) {
    final g = game!;
    final start = g.log.length;
    g.choosePosition(pos);
    recent = g.log.sublist(start);
    _commit();
  }

  /// 管理者モード(素質・特性・コツなどを自由に編集できる)。端末ごとに覚える。
  bool adminMode = false;

  /// 文字の大きさ(1.0が標準)とテーマ。端末ごとに覚える。
  double textScale = 1.0;
  ThemeMode themeMode = ThemeMode.system;

  /// 動きを減らす(アニメーションを止める)・触覚・結果の知らせ。端末ごとに覚える。
  bool reduceMotion = false;
  bool haptics = true;
  bool toasts = true;
  bool soundOn = true;

  void setFlags(
      {bool? reduceMotion, bool? haptics, bool? toasts, bool? sound}) {
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.haptics = haptics ?? this.haptics;
    this.toasts = toasts ?? this.toasts;
    soundOn = sound ?? soundOn;
    store.saveFlags(this.reduceMotion, this.haptics, this.toasts, soundOn);
    notifyListeners();
  }

  /// 効果音を1つ鳴らす(設定でオフなら鳴らさない)。
  void _cue(Sfx s) {
    _cuedThisTick = true;
    if (soundOn) sound.play(s);
  }

  /// この操作ですでに音を鳴らしたか(出来事・引退の音は、ほかの音が無いときだけ)。
  bool _cuedThisTick = false;
  Phase? _soundPhase;

  /// 節目に合う効果音。
  Sfx _sfxOfMilestone(MilestoneKind k) => switch (k) {
        MilestoneKind.draft => Sfx.draft,
        MilestoneKind.champion => Sfx.champion,
        MilestoneKind.title => Sfx.title,
        MilestoneKind.achievement => Sfx.achievement,
        MilestoneKind.trait => Sfx.trait,
        MilestoneKind.national || MilestoneKind.world => Sfx.champion,
        MilestoneKind.stage => Sfx.stage,
      };

  void setTextScale(double v) {
    textScale = v;
    store.saveDisplay(textScale, themeMode);
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    store.saveDisplay(textScale, themeMode);
    notifyListeners();
  }

  /// 解除した実績の id(何度遊んでも残る)。
  Set<String> unlocked = {};

  /// 特性図鑑: これまでに持ったことのある特性(何度遊んでも残る)。
  Set<String> seenTraits = {};

  /// 継承ポイント(貯まったぶん)と、直前の一生で増えたぶん(エンディングに出す)。
  int legacyPoints = 0;
  int lastLegacyGain = 0;

  /// いま継承できる特性(図鑑にあり、役割に合い、ポイントが足りるもの)。
  List<Trait> carryCandidates(Role role) => [
        for (final t in Trait.values)
          if (seenTraits.contains(t.name) &&
              canCarry(t, role) &&
              legacyCost(t) <= legacyPoints)
            t,
      ];

  /// 持っている特性を図鑑に足す(増えたときだけ保存)。
  void _recordTraits(Game g) {
    final names = {for (final t in g.player.traits) t.name};
    if (seenTraits.containsAll(names)) return;
    seenTraits = {...seenTraits, ...names};
    store.saveTraitBook(seenTraits);
  }

  /// 直前の一生で、新しく解除した実績。エンディングに出す。
  List<Achievement> newlyUnlocked = const [];

  Future<bool> loadSaved() async {
    unlocked = await store.loadAchievements();
    seenTraits = await store.loadTraitBook();
    guideSeen = await store.loadGuideSeen();
    autoBackups = await store.loadAutoBackups();
    legacyPoints = await store.loadLegacy();
    adminMode = await store.loadAdmin();
    final disp = await store.loadDisplay();
    textScale = disp.scale;
    themeMode = disp.theme;
    final fl = await store.loadFlags();
    reduceMotion = fl.reduceMotion;
    haptics = fl.haptics;
    toasts = fl.toasts;
    soundOn = fl.sound;
    history = await store.loadHistory();
    final j = await store.load();
    if (store.loadFailed) {
      toast = '保存データを読み込めませんでした。控えは残してあります。';
    }
    if (j == null) return false;
    try {
      game = Game.fromJson(j, _rng);
      focus = abilitiesOf(game!.player.role).first;
      notifyListeners();
      return true;
    } catch (_) {
      // 壊れたセーブは消さずに控えを残し、知らせる。
      await store.keepCorrupt(j);
      toast = '保存データを読み込めませんでした。控えは残してあります。';
      return false;
    }
  }

  /// 育成中の選手・殿堂・実績を1つの文字列にまとめる(別の端末や、消える前の控えに)。
  String exportBackup() => jsonEncode({
        'app': 'baseball-manager',
        'v': 1,
        'game': game?.toJson(),
        'history': [for (final e in history) e.toJson()],
        'achievements': unlocked.toList()..sort(),
        'traitBook': seenTraits.toList()..sort(),
        'legacy': legacyPoints,
      });

  /// `exportBackup` の文字列から復元する。読めなければ何も変えず false。
  Future<bool> importBackup(String text) async {
    try {
      final m = jsonDecode(text.trim()) as Map<String, dynamic>;
      if (m['app'] != 'baseball-manager') return false;
      final gj = m['game'];
      final g = gj == null
          ? null
          : Game.fromJson((gj as Map).cast<String, dynamic>(), _rng);
      final h = [
        for (final e in (m['history'] as List?) ?? const [])
          HistoryEntry.fromJson((e as Map).cast<String, dynamic>()),
      ];
      final a = {
        for (final x in (m['achievements'] as List?) ?? const []) x as String,
      };
      game = g;
      history = h;
      unlocked = a;
      seenTraits = {
        ...seenTraits,
        for (final x in (m['traitBook'] as List?) ?? const []) x as String,
      };
      store.saveTraitBook(seenTraits);
      legacyPoints = (m['legacy'] as num?)?.toInt() ?? legacyPoints;
      store.saveLegacy(legacyPoints);
      pending.clear();
      newlyUnlocked = const [];
      recent = const [];
      if (g != null) {
        focus = abilitiesOf(g.player.role).first;
        await store.save(g.toJson());
      } else {
        await store.clear();
      }
      await store.saveHistory(h);
      await store.saveAchievements(a);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void newGame(String name, Role role,
      [Difficulty difficulty = Difficulty.normal,
      PlayerSnapshot? parent,
      Trait? carry]) {
    newlyUnlocked = const [];
    lastLegacyGain = 0;
    // 育成中の選手がいるなら、始め直す前に控えをとる。
    if (game != null && game!.phase != Phase.retired) {
      autoBackup('${game!.player.name}を始め直す前');
    }
    _backedAge = -1;
    _adAge = -1;
    _recoveredAge = -1;
    // 継承: 図鑑にあり、ポイントが足りる特性だけ。持たせたぶんのポイントを使う。
    Trait? use;
    if (carry != null && carryCandidates(role).contains(carry)) {
      use = carry;
      legacyPoints -= legacyCost(carry);
      store.saveLegacy(legacyPoints);
    }
    game = Game.newGame(
        difficulty: difficulty,
        parent: parent,
        carry: use,
        name: name.trim().isEmpty ? '名無し' : name.trim(),
        role: role,
        rng: _rng);
    recent = birthTalentNotes(game!.player);
    if (autoGuide && !guideSeen) guidePending = true;
    focus = abilitiesOf(role).first;
    _commit();
  }

  /// 進行中のゲームを差し込む(続きから・テスト用)。
  void adopt(Game g) {
    game = g;
    focus = abilitiesOf(g.player.role).first;
    notifyListeners();
  }

  int _titleTaps = 0;
  DateTime _lastTitleTap = DateTime.fromMillisecondsSinceEpoch(0);

  /// タイトルを素早く7回タップすると管理者モードの入/切が切り替わる。切り替えたら true。
  bool tapTitle({DateTime? now}) {
    final t = now ?? DateTime.now();
    _titleTaps = t.difference(_lastTitleTap) > const Duration(seconds: 2)
        ? 1
        : _titleTaps + 1;
    _lastTitleTap = t;
    if (_titleTaps < 7) return false;
    _titleTaps = 0;
    toggleAdmin();
    return true;
  }

  void toggleAdmin() {
    adminMode = !adminMode;
    store.saveAdmin(adminMode);
    notifyListeners();
  }

  /// 管理者機能の操作。ゲームを書き換えて保存する。
  void admin(void Function(Game g) edit) {
    final g = game;
    if (g == null || g.phase == Phase.retired) return;
    edit(g);
    _commit();
  }

  void setFocus(Ability a) {
    focus = a;
    notifyListeners();
  }

  /// このターンの始まりの能力値。いまとの差が「今回の上昇」(次の行動で更新)。
  Map<Ability, int>? _turnBase;

  /// 今回(前の行動から今まで)に上がった能力と、その上昇値。
  Map<Ability, int> get abilityGains {
    final g = game;
    final base = _turnBase;
    if (g == null || base == null) return const {};
    return {
      for (final a in abilitiesOf(g.player.role))
        if (base.containsKey(a) && g.player.of(a) > base[a]!)
          a: g.player.of(a) - base[a]!,
    };
  }

  void act(Plan a) {
    final g = game!;
    if (!abilitiesOf(g.player.role).contains(focus)) {
      focus = abilitiesOf(g.player.role).first;
    }
    if (haptics) HapticFeedback.selectionClick();
    _turnBase = {for (final x in abilitiesOf(g.player.role)) x: g.player.of(x)};
    final start = g.log.length;
    final before = g.stage;
    final n0 = pending.length;
    g.choose(a, focus);
    recent = [_summary(a, g), ...g.log.sublist(start)];
    toast = toasts ? recent.first : null;
    toastTone = g.condition.injured || g.lastOutcome == Outcome.bad
        ? -1
        : (g.lastOutcome == Outcome.good || g.lastOutcome == Outcome.great
            ? 1
            : 0);
    _detect(before, g, g.log.sublist(start));
    if (g.condition.injured) {
      _cue(Sfx.injury);
    } else if (g.lastOutcome == Outcome.bad) {
      _cue(Sfx.bad);
    } else if (g.phase == Phase.event && pending.length == n0) {
      // 出来事が起きた(節目の音が鳴らないとき)。
      _cue(Sfx.event);
    } else if (g.lastOutcome == Outcome.good ||
        g.lastOutcome == Outcome.great) {
      _cue(Sfx.great);
    } else {
      _cue(Sfx.tap);
    }
    _commit();
  }

  /// 「練習: 打撃経験点 +25 / …」のような、直前のターンの一行まとめ。
  String _summary(Plan a, Game g) {
    final gains = [
      for (final c in Category.values)
        if ((g.lastGain[c] ?? 0) > 0) '${c.label}経験点 +${g.lastGain[c]}',
    ];
    final o = g.lastOutcome.label.isEmpty
        ? ''
        : '(${g.lastOutcome.label}${g.lastOutcome == Outcome.bad ? '…' : '!'})';
    final name = planTitle(a, focus);
    return gains.isEmpty ? '$nameをした' : '$name$o: ${gains.join(' / ')}';
  }

  /// 今回のできごとから、見せる価値のある節目を拾う。
  void _detect(Stage before, Game g, List<String> lines) {
    final n0 = pending.length;
    _detectMilestones(before, g, lines);
    // 新しい節目があれば、その音(いちばん最後に足されたもの = 大きな出来事)を鳴らす。
    if (pending.length > n0) _cue(_sfxOfMilestone(pending.last.kind));
  }

  void _detectMilestones(Stage before, Game g, List<String> lines) {
    final name = g.player.name;
    final pick = lines.where((l) => l.contains('ドラフトで指名された')).firstOrNull;
    if (pick != null) {
      // 「ドラフトで指名された! ○○ から3位指名。」の後ろ(球団と順位)を添える。
      final detail = pick.replaceFirst('ドラフトで指名された!', '').trim();
      pending.add(Milestone(MilestoneKind.draft, 'ドラフト指名!',
          '$nameは、プロの世界へ飛び込む。${detail.isEmpty ? '' : '\n$detail'}'));
    }
    // 世界大会: 日本代表に選ばれた / 世界一になった
    for (final l in lines) {
      if (l.contains('の日本代表に選ばれた')) {
        pending.add(Milestone(MilestoneKind.national, '日本代表に選出!',
            '$nameは、${l.replaceFirst('の日本代表に選ばれた!', '')}の日本代表に選ばれた。'));
      } else if (l.contains('海を渡った')) {
        pending.add(Milestone(MilestoneKind.world, '海を渡る!', l));
      } else if (l.contains('世界一になった')) {
        pending.add(Milestone(MilestoneKind.world, '世界一!', l));
      }
    }
    final after = g.stage;
    if (after != before &&
        g.phase != Phase.retired &&
        after != Stage.pro &&
        after != Stage.pathChoice) {
      pending.add(Milestone(MilestoneKind.stage, '${stageLabel(after)}へ',
          '${g.player.age}歳。新しい仲間とコーチが待っている。'));
    }
    if (lines.any((l) => l.contains('優勝'))) {
      pending.add(Milestone(MilestoneKind.champion, '優勝!', '夏の大会を制した。'));
    }
    for (final l in lines.where((l) => l.startsWith('タイトル獲得'))) {
      pending.add(Milestone(
          MilestoneKind.title, 'タイトル獲得!', l.replaceFirst('タイトル獲得: ', '')));
    }
    for (final l in lines.where((l) => l.contains('を習得'))) {
      pending.add(Milestone(MilestoneKind.trait, 'コツをつかんだ!', l));
    }
    if (lines.any((l) => l.contains('一軍に昇格した'))) {
      pending.add(Milestone(
          MilestoneKind.stage, '一軍昇格!', '$name は二軍での努力が実り、一軍の舞台に立つ。'));
    }
    for (final l in lines.where((l) => l.contains('に覚醒した'))) {
      pending.add(Milestone(MilestoneKind.trait, '才能が覚醒!', l));
    }
  }

  /// 一生が終わったとき、新しい実績を解除して保存し、ダイアログで知らせる。
  void _unlockAchievements(Game g, {bool append = false}) {
    final earned = earnedBy(PlayerSnapshot.fromGame(g));
    final fresh = [
      for (final a in achievements)
        if (earned.contains(a.id) && !unlocked.contains(a.id)) a,
    ];
    newlyUnlocked = append ? [...newlyUnlocked, ...fresh] : fresh;
    if (fresh.isEmpty) return;
    unlocked = {...unlocked, ...fresh.map((a) => a.id)};
    store.saveAchievements(unlocked);
    for (final a in fresh) {
      pending.add(Milestone(
          MilestoneKind.achievement, '実績解除!', '${a.title}\n${a.description}'));
    }
  }

  /// 引退後の道を選ぶ(エンディングの画面から)。殿堂の記録も更新し、新しい実績があれば知らせる。
  void chooseAfterPath(AfterPath p) {
    final g = game;
    if (g == null) return;
    g.chooseAfterPath(p);
    // 殿堂の最新の記録(この一生のもの)を、選んだ道を含む内容に差し替える。
    if (g.archived && history.isNotEmpty) {
      history = [HistoryEntry.of(g), ...history.skip(1)];
      store.saveHistory(history);
    }
    _unlockAchievements(g, append: true);
    _commit();
  }

  /// 見せ終わった節目を1つ取り除く。
  void dismissMilestone() {
    if (pending.isNotEmpty) pending.removeAt(0);
    notifyListeners();
  }

  void spend(Ability a) {
    final before = _ranks();
    if (game!.spend(a)) {
      if (haptics) HapticFeedback.selectionClick();
      _cue(Sfx.gain);
      _noteRankUps(before);
      _commit();
    }
  }

  void autoSpend() {
    final before = _ranks();
    game!.autoSpend();
    _noteRankUps(before);
    _commit();
  }

  Map<Ability, String> _ranks() => {
        for (final a in abilitiesOf(game!.player.role))
          a: rankOf(game!.player.of(a)),
      };

  /// ランクが上がった能力を「いまの結果」に足す(パワプロのランクアップの気持ちよさ)。
  void _noteRankUps(Map<Ability, String> before) {
    final g = game!;
    final ups = [
      for (final a in abilitiesOf(g.player.role))
        if (before[a] != null && before[a] != rankOf(g.player.of(a)))
          '${abilityLabel(a)}が ${rankOf(g.player.of(a))}ランクに上がった!',
    ];
    if (ups.isNotEmpty) {
      recent = [...recent, ...ups];
      _cue(Sfx.rankup);
    }
  }

  /// おすすめの過ごし方で、今年(年が変わるまで)を進める。
  /// 出来事・進路の選択・節目の演出が出たらそこで止まる(選ぶのは本人)。
  void autoYear() {
    final g = game;
    if (g == null) return;
    final age = g.player.age;
    final lines = <String>[];
    final gained = <Category, int>{};
    var turns = 0;
    for (var i = 0; i < g.slotsInYear; i++) {
      if (game!.phase != Phase.term || game!.player.age != age) break;
      if (pending.isNotEmpty) break;
      act(recommendedPlan(game!));
      turns++;
      for (final e in g.lastGain.entries) {
        gained[e.key] = (gained[e.key] ?? 0) + e.value;
      }
      // 各ターンの「練習: …」の一行まとめ以外(怪我・大会・目標など)を集める。
      lines.addAll(recent.skip(1));
    }
    if (turns > 1) {
      recent = [
        'おすすめの過ごし方で$turns回進めた。'
            '${gained.values.any((v) => v > 0) ? '(経験点 ${[
                for (final e in gained.entries)
                  if (e.value > 0) '${e.key.label}+${e.value}'
              ].join(' / ')})' : ''}',
        ...lines.reversed.take(8).toList().reversed,
      ];
      toast = recent.first;
      notifyListeners();
    }
  }

  void chooseEvent(int i) {
    final start = game!.log.length;
    final before = game!.stage;
    final p0 = game!.player;
    final c0 = game!.condition;
    final tips0 = game!.cast.coach?.tips ?? 0;
    game!.resolveEvent(i);
    final result = eventResultText(p0, c0, game!.player, game!.condition,
        tips0: tips0, tips1: game!.cast.coach?.tips ?? 0);
    recent = [
      if (result.isNotEmpty) '選んだ結果: $result',
      ...game!.log.sublist(start),
    ];
    _detect(before, game!, recent);
    _commit();
  }

  void chooseRoute(Course r) {
    game!.chooseRoute(r);
    _commit();
  }

  void giveUp() {
    game!.giveUp();
    _commit();
  }

  void retire() {
    game!.retire();
    _commit();
  }

  void changeRole(Role r) {
    game!.changeRole(r);
    if (!abilitiesOf(r).contains(focus)) focus = abilitiesOf(r).first;
    _commit();
  }

  /// 育成中の選手と殿堂の記録をすべて消す(設定画面から)。管理者モードの設定は残す。
  Future<void> eraseAll() async {
    game = null;
    history = const [];
    unlocked = {};
    seenTraits = {};
    legacyPoints = 0;
    lastLegacyGain = 0;
    newlyUnlocked = const [];
    recent = const [];
    pending.clear();
    await store.clear();
    await store.clearHistory();
    await store.clearAchievements();
    await store.clearTraitBook();
    await store.clearLegacy();
    await store.clearGuide();
    await store.clearAutoBackups();
    autoBackups = [];
    guideSeen = false;
    notifyListeners();
  }

  Future<void> reset() async {
    if (game != null && game!.phase != Phase.retired) {
      autoBackup('${game!.player.name}をやめる前');
    }
    game = null;
    await store.clear();
    notifyListeners();
  }

  /// 最後に保存した時刻(設定に出す)。
  DateTime? lastSaved;
  bool _saveWarned = false;

  void _commit() {
    final g = game;
    // 年が1つ進んだ瞬間に、全画面広告(間隔・年齢の決まりは Monetization)。
    final m = money;
    if (m != null && g != null && g.phase != Phase.retired) {
      final age = g.player.age;
      if (_adAge >= 0 && age == _adAge + 1) {
        // 年を進めたタップの指が広告に当たらないよう、少し置いてから出す
        Future<void>.delayed(const Duration(milliseconds: 900), () async {
          if (identical(game, g) && g.phase != Phase.retired) {
            await m.afterYear(age);
          }
        });
      }
      _adAge = age;
    } else if (g == null || g.phase == Phase.retired) {
      _adAge = -1;
    }
    // 4歳ごとの節目で、自動バックアップ(同じ歳では1度だけ)。
    if (g != null && g.phase != Phase.retired && g.player.age != _backedAge) {
      _backedAge = g.player.age;
      if (g.player.age % 4 == 0) {
        autoBackup('${g.player.name} ${g.player.age}歳');
      }
    }
    // 出来事が起きた・引退したときの音(ほかに鳴らした音が無いときだけ)。
    if (g != null && g.phase != _soundPhase) {
      if (!_cuedThisTick && _soundPhase != null) {
        if (g.phase == Phase.event) _cue(Sfx.event);
        if (g.phase == Phase.retired) _cue(Sfx.retire);
      }
      _soundPhase = g.phase;
    }
    _cuedThisTick = false;
    if (g != null) _recordTraits(g);
    // 引退したら、殿堂に1度だけ書き込む。
    if (g != null && g.phase == Phase.retired && !g.archived) {
      g.archived = true;
      history = [HistoryEntry.of(g), ...history].take(historyLimit).toList();
      store.saveHistory(history);
      _unlockAchievements(g);
      autoBackup('${g.player.name}が引退したとき');
      final e = g.ending;
      if (e != null) {
        lastLegacyGain = legacyPointsOf(madePro: e.madePro, title: e.title);
        legacyPoints += lastLegacyGain;
        store.saveLegacy(legacyPoints);
      }
    }
    notifyListeners();
    if (g != null) {
      store.save(g.toJson()).then((_) {
        if (!store.saveFailed) lastSaved = DateTime.now();
        if (store.saveFailed && !_saveWarned) {
          _saveWarned = true;
          toast = '保存できませんでした。この環境では続きから遊べないかもしれません。';
          notifyListeners();
        }
      });
    }
  }
}
