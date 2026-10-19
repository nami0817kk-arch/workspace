import 'difficulty.dart';
import 'epilogue.dart';
import 'game.dart';
import 'player.dart';

/// 殿堂に残る、1人ぶんの記録。引退したときに1度だけ書く。
class HistoryEntry {
  const HistoryEntry({
    required this.name,
    required this.age,
    required this.heightCm,
    required this.position,
    required this.overall,
    required this.titles,
    required this.careerPpg,
    required this.abroad,
    required this.pro,
    required this.reason,
    this.difficulty = '',
    this.title = '',
    this.rivalName = '',
    this.rivalWins = 0,
    this.rivalLosses = 0,
  });

  final String name;
  final int age;
  final double heightCm;
  final String position;
  final int overall;
  final int titles;
  final double careerPpg;
  final bool abroad;
  final bool pro;
  final String reason;
  final String difficulty;
  final String title;
  final String rivalName;
  final int rivalWins;
  final int rivalLosses;

  factory HistoryEntry.of(Game g) => HistoryEntry(
        name: g.player.name,
        age: g.player.age,
        heightCm: g.player.heightCm,
        position: g.player.position.label,
        overall: g.player.overall.round(),
        titles: g.titles,
        careerPpg: g.careerPpg,
        abroad: g.abroad,
        pro: g.records.any((r) => r.league.name.startsWith('pro')),
        reason: g.retiredReason ?? '',
        difficulty: g.difficulty.label,
        title: careerTitle(g),
        rivalName: g.rival.name,
        rivalWins: g.rival.wins,
        rivalLosses: g.rival.losses,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'heightCm': heightCm,
        'position': position,
        'overall': overall,
        'titles': titles,
        'careerPpg': careerPpg,
        'abroad': abroad,
        'pro': pro,
        'reason': reason,
        'difficulty': difficulty,
        'title': title,
        'rivalName': rivalName,
        'rivalWins': rivalWins,
        'rivalLosses': rivalLosses,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        name: (j['name'] as String?) ?? '名無し',
        age: (j['age'] as num?)?.toInt() ?? 0,
        heightCm: (j['heightCm'] as num?)?.toDouble() ?? 0,
        position: (j['position'] as String?) ?? '',
        overall: (j['overall'] as num?)?.toInt() ?? 0,
        titles: (j['titles'] as num?)?.toInt() ?? 0,
        careerPpg: (j['careerPpg'] as num?)?.toDouble() ?? 0,
        abroad: (j['abroad'] as bool?) ?? false,
        pro: (j['pro'] as bool?) ?? false,
        reason: (j['reason'] as String?) ?? '',
        difficulty: (j['difficulty'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        rivalName: (j['rivalName'] as String?) ?? '',
        rivalWins: (j['rivalWins'] as num?)?.toInt() ?? 0,
        rivalLosses: (j['rivalLosses'] as num?)?.toInt() ?? 0,
      );
}

/// 実績。一生が終わったときに判定し、解除したら端末に残す。
class Achievement {
  const Achievement(this.id, this.title, this.description, this.earned);
  final String id;
  final String title;
  final String description;
  final bool Function(Game g) earned;
}

bool _wentPro(Game g) => g.records.any((r) => r.league.name.startsWith('pro'));

final achievements = <Achievement>[
  Achievement('first_title', '初優勝', '大会で優勝した。', (g) => g.titles >= 1),
  Achievement('three_titles', '常勝', '大会で3回優勝した。', (g) => g.titles >= 3),
  Achievement('pro', 'プロの扉', 'プロ契約を勝ち取った。', _wentPro),
  Achievement('abroad', '世界へ', '海外プロに挑戦した。', (g) => g.abroad),
  Achievement('late_pro', '回り道の末に', '大学・実業団を経てプロになった。',
      (g) => g.secondChance && _wentPro(g)),
  Achievement('sniper', '3Pの名手', '3Pシュートを90以上にした。',
      (g) => g.player.of(Ability.threePoint) >= 90),
  Achievement('wall', '鉄壁', 'ディフェンスを90以上にした。',
      (g) => g.player.of(Ability.defense) >= 90),
  Achievement('giant', '巨人', '身長が205cmを超えた。', (g) => g.player.heightCm >= 205),
  Achievement('guard', '小さな司令塔', '身長180cm以下でプロになった。',
      (g) => g.player.heightCm <= 180 && _wentPro(g)),
  Achievement('allround', 'オールラウンダー', '全ての能力を70以上にした。',
      (g) => Ability.values.every((a) => g.player.of(a) >= 70)),
  Achievement('scorer', 'エース', '通算の平均得点が15点以上。',
      (g) => g.totalGames >= 10 && g.careerPpg >= 15),
  Achievement('rival_beat', '宿敵に勝ち越し', 'ライバルとの通算で勝ち越した(3戦以上)。',
      (g) => g.rival.games >= 3 && g.rival.wins > g.rival.losses),
  Achievement('mini_king', 'ミニバスの王者', 'ミニバスの大会で優勝した。',
      (g) => g.records.any((r) => r.league.name == 'minibasket' && r.champion)),
  Achievement('jh_king', '中学の王者', '中学の大会で優勝した。',
      (g) => g.records.any((r) => r.league.name == 'juniorHigh' && r.champion)),
  Achievement('hs_king', '高校の王者', '高校の大会で優勝した。',
      (g) => g.records.any((r) => r.league.name == 'highSchool' && r.champion)),
  Achievement('grand_slam', '全制覇', 'ミニバス・中学・高校のすべてで優勝した。', (g) {
    bool king(String l) => g.records.any((r) => r.league.name == l && r.champion);
    return king('minibasket') && king('juniorHigh') && king('highSchool');
  }),
  Achievement('rebounder', 'ボードの支配者', '大会の平均リバウンドが8以上の年があった。',
      (g) => g.records.any((r) => r.rpg >= 8)),
  Achievement('playmaker', '名司令塔', '大会の平均アシストが7以上の年があった。',
      (g) => g.records.any((r) => r.apg >= 7)),
  Achievement('underdog', '小さな巨人', '身長175cm以下で海外に挑戦した。',
      (g) => g.abroad && g.player.heightCm <= 175),
  Achievement('hard_pro', '険しい道を', 'むずかしいでプロになった。',
      (g) => g.difficulty == Difficulty.hard && _wentPro(g)),
  Achievement('mvp', '最優秀選手', '大会で最優秀選手に選ばれた。',
      (g) => g.records.any((r) => r.award == '最優秀選手')),
  Achievement('best5_x3', 'ベスト5の常連', '個人賞(最優秀選手・ベスト5)を3回受けた。',
      (g) => g.records.where((r) => r.award != null).length >= 3),
  Achievement('big_game', '一夜の爆発', '1試合で30得点以上を取った。',
      (g) => (g.careerHigh?.points ?? 0) >= 30),
  Achievement('skills5', '技の百貨店', '得意技を5つ身につけた。',
      (g) => g.player.skills.length >= 5),
  Achievement('veteran', '息の長い選手', '35歳までプロで戦った。',
      (g) => g.player.age >= 35 && _wentPro(g)),
];

/// 解除した実績の数から、次の選手に引き継ぐ初期能力の加算(5個で+1、最大+5)。
int legacyBonusFor(int unlockedCount) => (unlockedCount ~/ 5).clamp(0, 5);

/// 一生が終わった `g` が満たす実績の id。
Set<String> earnedBy(Game g) => {
      for (final a in achievements)
        if (a.earned(g)) a.id,
    };
