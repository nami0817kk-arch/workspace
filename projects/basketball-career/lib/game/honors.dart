import 'season.dart';

/// 実世界のバスケットボールにある個人タイトル・表彰を、大会(1年分)の成績から判定する。
///
/// 名前は一般的な呼び名(得点王・新人王・オールスターなど)だけを使い、実在のリーグ・大会・
/// 賞の固有名詞は使わない(このアプリのリーグ・チーム・大会は架空という決まり)。
/// 判定は、他の選手を作らずに「このくらい取れば、そのリーグで一番」という目安の数字で行う。
class Honor {
  Honor._();

  static const scoringKing = '得点王';
  static const reboundKing = 'リバウンド王';
  static const assistKing = 'アシスト王';
  static const stealKing = 'スティール王';
  static const blockKing = 'ブロック王';
  static const defensivePlayer = '最優秀守備選手';
  static const rookie = '新人王';
  static const finalMvp = 'ファイナルMVP';
  static const allStar = 'オールスター選出';
  static const tripleDouble = 'トリプルダブル';

  /// 並べる順番(画面・文章で使う)。
  static const all = [
    finalMvp,
    scoringKing,
    reboundKing,
    assistKing,
    stealKing,
    blockKing,
    defensivePlayer,
    rookie,
    allStar,
    tripleDouble,
  ];

  /// 説明(殿堂・実績の画面で使う)。
  static const descriptions = {
    scoringKing: 'そのリーグで、1試合の平均得点がいちばん多い選手。',
    reboundKing: '1試合の平均リバウンドがいちばん多い選手。',
    assistKing: '1試合の平均アシストがいちばん多い選手。',
    stealKing: '1試合の平均スティールがいちばん多い選手。',
    blockKing: '1試合の平均ブロックがいちばん多い選手。',
    defensivePlayer: '守りでチームを引っ張った選手に贈られる賞(スティールとブロックの合計が多い)。',
    rookie: 'プロ1年目でいちばん活躍した選手に贈られる賞。',
    finalMvp: '優勝を決める決勝で、いちばん活躍した選手。',
    allStar: 'ファン投票と監督推薦で選ばれる、リーグを代表する選手。',
    tripleDouble: '1試合で得点・リバウンド・アシストのすべてが10以上。',
  };
}

/// リーグごとの目安の強さ(プロを1としたときの数字の大きさ)。
double _scale(League l) => switch (l) {
      League.proDomestic || League.proAbroad => 1.0,
      League.university || League.corporate => 0.9,
      League.highSchool || League.juniorHigh || League.minibasket => 0.0,
      League.national => 0.0,
    };

bool _isPro(League l) => l == League.proDomestic || l == League.proAbroad;

extension TournamentHonors on TournamentResult {
  /// 1試合あたりのスティール・ブロック。
  double get spg => games == 0 ? 0 : steals / games;
  double get bpg => games == 0 ? 0 : blocks / games;

  /// この大会で受けた表彰の一覧(`Honor.all` の順)。
  /// `rookie` はプロ1年目か。日本代表の大会(4試合の短期戦)は個人タイトルの対象外。
  List<String> honors({required bool rookie}) {
    // 個人タイトルはプロ・大学・実業団の大会だけ(学生の大会は個人賞=最優秀選手・ベスト5)。
    if (games < 4 || _scale(league) == 0) return const [];
    final s = _scale(league);
    final out = <String>{};

    if (champion && _isPro(league) && matches.isNotEmpty && matches.last.points >= (18 * league.scoreScale).round()) {
      out.add(Honor.finalMvp);
    }
    if (ppg >= 22 * s * league.scoreScale) out.add(Honor.scoringKing);
    if (rpg >= 10.5 * s) out.add(Honor.reboundKing);
    if (apg >= 7.5 * s) out.add(Honor.assistKing);
    if (spg >= 2.0 * s) out.add(Honor.stealKing);
    if (bpg >= 1.1 * s) out.add(Honor.blockKing);
    if (spg + bpg >= 2.8 * s && wins * 2 >= games) out.add(Honor.defensivePlayer);
    if (rookie && _isPro(league) && individual >= 78) out.add(Honor.rookie);
    if (_isPro(league) && individual >= 86) out.add(Honor.allStar);
    if (matches.any((m) => m.points >= 10 && m.rebounds >= 10 && m.assists >= 10)) {
      out.add(Honor.tripleDouble);
    }
    return [
      for (final h in Honor.all)
        if (out.contains(h)) h,
    ];
  }
}
