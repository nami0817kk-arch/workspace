/// 受信箱のお知らせの1件。SnackBarやダイアログで一度だけ流れて消えていた
/// 通知を、あとから時系列で見返せるようにセーブデータへ保存する。[context]は
/// 発生時点の文脈ラベル(「第12節」「シーズン開始」「カップ戦」など)。
class NewsItem {
  final int season;
  final String context;
  final String text;

  /// 届いた日(ゲームの中の日付)。2026-11-25 に足した。それより前のセーブの
  /// お知らせは null(季と文脈だけを出す)。
  final DateTime? date;

  const NewsItem({
    required this.season,
    required this.context,
    required this.text,
    this.date,
  });

  /// 受信箱の分類(5つ)。
  NewsCategory get category => NewsCategory.of(context);

  Map<String, dynamic> toJson() => {
        'season': season,
        'context': context,
        'text': text,
        if (date != null)
          'date': '${date!.year.toString().padLeft(4, '0')}-'
              '${date!.month.toString().padLeft(2, '0')}-'
              '${date!.day.toString().padLeft(2, '0')}',
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        season: json['season'] as int? ?? 1,
        context: json['context'] as String? ?? '',
        text: json['text'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? ''),
      );
}

/// 受信箱の分類。FM の受信箱のように、届いたものを5つに分ける
/// (2026-11-25。以前は文脈の札が40種類以上あり、絞り込みの札が並びきらなかった)。
///
/// 分類は保存しない。文脈の札([NewsItem.context])の言葉から決める
/// (札は届いた時点の言語で残るので、日本語と英語の両方の言葉で見る)。
enum NewsCategory {
  /// 移籍・契約・ローン・スカウト。
  transfers,

  /// 試合・大会・表彰・代表・他のリーグ。
  matches,

  /// 選手・スタッフ・ユース・医療。
  people,

  /// お金・事業(スポンサー・放映権・施設・投資・決算)。
  money,

  /// オーナー・理事会・株主・サポーター・街。
  board;

  // 札の言葉そのもの(画面に出す文言ではない)。i18n-ignore
  static const _words = <NewsCategory, List<String>>{
    NewsCategory.transfers: [
      '移籍', '契約', 'ローン', 'スカウト', '仮契約', '選手登録',
      'Transfer', 'Contract', 'Loan', 'Scout', 'Pre-contract', 'Registration',
    ],
    NewsCategory.people: [
      'スタッフ', 'ユース', '医療', '負傷', '選手', 'キャンプ', '殿堂', 'SD',
      'Staff', 'Youth', 'Academy', 'Medical', 'Injur', 'Player', 'Camp',
      'Pre-season', 'Hall of fame', 'DoF',
    ],
    NewsCategory.money: [
      '放映権', 'スポンサー', '提携', '系列クラブ', '施設', '投資', '決算', '景気',
      '命名権', '年間シート', 'メディア', 'ライセンス', '規則', '相場',
      'Broadcast', 'TV', 'Sponsor', 'Partner', 'Affiliate', 'Facilit',
      'Invest', 'Accounts', 'Economy', 'Naming', 'Season ticket', 'Media',
      'Licen', 'Rules', 'Projects',
    ],
    NewsCategory.board: [
      'オーナー', '株主', '理事会', '最後通告', '自治体', 'サポーター', '方針',
      '時代', '突発', '手放した', '締切',
      'Owner', 'owner', 'Shareholder', 'Board', 'Final warning', 'Council',
      'Supporter', 'Policy', 'Era', 'Incident', 'Former club', 'Deadline',
    ],
  };

  static NewsCategory of(String context) {
    // 「他のオーナー」は移籍の話(他のクラブの補強)ではなく、オーナーの世界。
    for (final c in [
      NewsCategory.board,
      NewsCategory.transfers,
      NewsCategory.money,
      NewsCategory.people,
    ]) {
      for (final w in _words[c]!) {
        if (context.contains(w)) return c;
      }
    }
    // 「第12節」「カップ戦」「表彰」「代表」「他国のリーグ」「実績」など。
    return NewsCategory.matches;
  }
}
