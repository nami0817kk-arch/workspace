import '../l10n/tr.dart';

/// オーナーの仕事の分野。
enum OwnerWorkCategory { sales, finance, fans, org, community }

extension OwnerWorkCategoryInfo on OwnerWorkCategory {
  String get label => switch (this) {
        OwnerWorkCategory.sales => Tr.pick('営業・収入', 'Sales & revenue'),
        OwnerWorkCategory.finance => Tr.pick('財務・資本', 'Finance & capital'),
        OwnerWorkCategory.fans => Tr.pick('広報・ファン', 'Fans & PR'),
        OwnerWorkCategory.org => Tr.pick('組織・人事', 'People & organisation'),
        OwnerWorkCategory.community => Tr.pick('地域・社会', 'Community'),
      };
}

/// オーナーが自分の判断で打てる1つの手。1シーズンに1回ずつ。
///
/// 効きは3つだけ: 資金(万円)、サポーターの期待、株主の期待。どの手も
/// 何かを得て何かを払う(ただで済む手は無い)。
class OwnerWork {
  const OwnerWork({
    required this.id,
    required this.category,
    required this.funds,
    required this.supporters,
    required this.shareholders,
    this.onlyInRed = false,
  });

  /// 保存に使う名前。変えると既存セーブの「今季やった」記録が外れる。
  final String id;
  final OwnerWorkCategory category;

  /// 資金の増減(万円)。負なら支出。
  final int funds;

  /// サポーターの期待の増減。
  final int supporters;

  /// 株主の期待の増減。
  final int shareholders;

  /// 資金がマイナスのときだけ打てる(経営危機の手)。
  final bool onlyInRed;

  String get title => ownerWorkTexts[id]!.$1;
  String get description => ownerWorkTexts[id]!.$2;

  /// 支出が要る手か。資金が足りないと打てない。
  int get cost => funds < 0 ? -funds : 0;
}

/// 仕事の名前と説明(日英)。getter にして、言語の切り替えに追従させる。
Map<String, (String, String)> get ownerWorkTexts => {
      'merch_drive': (
        Tr.pick('限定グッズの企画', 'Limited merchandise drive'),
        Tr.pick('今季限りのグッズを出して、売り上げの土台を作る。',
            'Release season-only items to build the revenue base.')
      ),
      'stadium_food': (
        Tr.pick('スタジアムグルメの増設', 'More stadium food stalls'),
        Tr.pick('屋台を増やして、観戦の楽しみと客単価を上げる。',
            'Add stalls to lift the matchday experience and spend per fan.')
      ),
      'season_ticket_promo': (
        Tr.pick('年間チケットの早割', 'Early-bird season tickets'),
        Tr.pick('先にお金が入る。ただし割引で、ファンの目には安売りに映る。',
            'Cash comes in early, but the discount looks cheap to fans.')
      ),
      'sponsor_roadshow': (
        Tr.pick('スポンサー回り', 'Sponsor roadshow'),
        Tr.pick('主要スポンサーを訪ねて関係を固める。株主が安心する。',
            'Visit key sponsors to firm up ties. Shareholders feel safer.')
      ),
      'asia_tour': (
        Tr.pick('アジアツアー', 'Asia tour'),
        Tr.pick('遠征で海外のファンと市場を開く。費用は大きい。',
            'Win fans and open markets abroad. Expensive.')
      ),
      'naming_survey': (
        Tr.pick('命名権の打診', 'Sound out naming rights'),
        Tr.pick('スタジアムの命名権を企業に打診する。サポーターは複雑な顔をする。',
            'Test naming-rights interest. Fans have mixed feelings.')
      ),
      'digital_content': (
        Tr.pick('動画配信の強化', 'Boost video content'),
        Tr.pick('舞台裏の動画を配信して、広告と会員を増やす。',
            'Stream behind-the-scenes video for ads and members.')
      ),
      'bond_issue': (
        Tr.pick('社債の発行', 'Issue bonds'),
        Tr.pick('まとまった資金がすぐ入る。借金が増えて、株主は渋い。',
            'A lump sum right now. More debt makes shareholders uneasy.')
      ),
      'cost_review': (
        Tr.pick('経費の見直し', 'Cost review'),
        Tr.pick('無駄を削って資金を作る。現場の士気とサポーターの目は厳しくなる。',
            'Cut waste for cash. Morale and fans take a hit.')
      ),
      'dividend_cut': (
        Tr.pick('配当の見送り', 'Skip the dividend'),
        Tr.pick('今季の配当を出さず、資金を残す。株主は怒る。',
            'Keep the cash by skipping the dividend. Shareholders are angry.')
      ),
      'dividend_bonus': (
        Tr.pick('特別配当', 'Special dividend'),
        Tr.pick('株主に報いる。資金は減り、サポーターは使い道に不満を持つ。',
            'Reward shareholders. Funds drop and fans question the priority.')
      ),
      'asset_sale': (
        Tr.pick('遊休地の売却', 'Sell idle land'),
        Tr.pick('使っていない土地を売る。資金は入るが、地元は良い顔をしない。',
            'Cash from unused land. Locals are not pleased.')
      ),
      'credit_talk': (
        Tr.pick('借り入れ条件の交渉', 'Renegotiate credit terms'),
        Tr.pick('銀行と条件を詰め直し、利払いの負担を軽くする。',
            'Reset terms with the bank to ease interest costs.')
      ),
      'auditor': (
        Tr.pick('会計監査の強化', 'Stronger audit'),
        Tr.pick('外部の監査を入れて、数字の信頼を高める。',
            'Bring in outside auditors to raise trust in the numbers.')
      ),
      'fan_thanks': (
        Tr.pick('ファン感謝祭', 'Fan appreciation day'),
        Tr.pick('選手と触れ合う一日。サポーターは喜ぶが、費用は株主に響く。',
            'A day with the players. Fans love it; shareholders watch the bill.')
      ),
      'supporter_dinner': (
        Tr.pick('サポーター代表との会食', 'Dinner with fan leaders'),
        Tr.pick('代表の声を直接聞く。安く済む。',
            'Hear the fan leaders directly. Cheap to do.')
      ),
      'vision_press': (
        Tr.pick('ビジョン発表の会見', 'Vision press conference'),
        Tr.pick('夢を語って期待を集める。数字の裏付けが薄いと株主は冷める。',
            'Sell the dream. Shareholders cool if the numbers are thin.')
      ),
      'legend_match': (
        Tr.pick('OBレジェンド招待試合', 'Legends exhibition match'),
        Tr.pick('往年の名選手を招く。古参のファンが沸く。',
            'Bring back old heroes. Long-time fans light up.')
      ),
      'kids_clinic': (
        Tr.pick('子ども向けサッカー教室', 'Kids football clinic'),
        Tr.pick('将来のファンを育てる。地道だが効く。',
            'Grow the next generation of fans. Slow but sure.')
      ),
      'fan_survey': (
        Tr.pick('ファン調査', 'Fan survey'),
        Tr.pick('不満の声を拾う。聞いてもらえたと感じるファンが増える。',
            'Collect complaints. Fans feel heard.')
      ),
      'chant_contest': (
        Tr.pick('応援歌コンテスト', 'Chant contest'),
        Tr.pick('スタンドの一体感を高める企画。',
            'Build unity in the stands.')
      ),
      'hire_analyst': (
        Tr.pick('データ分析担当を雇う', 'Hire a data analyst'),
        Tr.pick('数字で経営と強化を支える体制を作る。株主が評価する。',
            'Back the club with numbers. Shareholders approve.')
      ),
      'manager_dinner': (
        Tr.pick('監督との食事会', 'Dinner with the manager'),
        Tr.pick('現場の考えを聞く。ささやかだが信頼が深まる。',
            'Hear the manager out. Small, but it builds trust.')
      ),
      'staff_bonus': (
        Tr.pick('スタッフへの特別手当', 'Staff bonus'),
        Tr.pick('裏方に報いる。現場とファンは喜ぶが、コストが増える。',
            'Reward the backroom. Popular, but costs more.')
      ),
      'exec_retreat': (
        Tr.pick('経営合宿', 'Executive retreat'),
        Tr.pick('幹部と中長期の計画を詰める。株主に前向きに映る。',
            'Plan the mid-term with executives. Looks good to shareholders.')
      ),
      'finance_advisor': (
        Tr.pick('財務アドバイザーへの相談', 'Consult a finance advisor'),
        Tr.pick('専門家の目で財務を点検してもらう。',
            'Have an expert review the finances.')
      ),
      'charity_match': (
        Tr.pick('チャリティーマッチ', 'Charity match'),
        Tr.pick('収益を寄付する試合。クラブの評判が上がる。',
            'Donate the proceeds. The club\'s name improves.')
      ),
      'school_visit': (
        Tr.pick('学校訪問', 'School visits'),
        Tr.pick('選手が地元の学校を回る。安上がりで好感度が高い。',
            'Players visit local schools. Cheap and well liked.')
      ),
      'eco_stadium': (
        Tr.pick('環境配慮の取り組み', 'Eco-friendly stadium'),
        Tr.pick('省エネとごみ削減。ファンにも株主にも悪くない。',
            'Save energy and cut waste. Good for fans and shareholders.')
      ),
      'restructuring': (
        Tr.pick('再建計画(人員整理)', 'Restructuring plan'),
        Tr.pick('資金がマイナスのときの非常手段。人員を整理して資金を作るが、ファンの反発は大きい。',
            'An emergency step when in the red. Trim staff for cash; fans push back hard.')
      ),
      'emergency_loan': (
        Tr.pick('緊急融資', 'Emergency loan'),
        Tr.pick('資金がマイナスのとき、銀行から急ぎで借りる。株主は条件の悪さを責める。',
            'When in the red, borrow in a hurry. Shareholders resent the terms.')
      ),
      'fire_sale': (
        Tr.pick('資産の投げ売り', 'Fire sale'),
        Tr.pick('資金がマイナスのとき、設備やグッズ在庫を急いで現金化する。',
            'When in the red, cash out equipment and stock in a hurry.')
      ),
      'town_festival': (
        Tr.pick('地元の祭りに出店', 'Join the town festival'),
        Tr.pick('祭りに屋台を出して、地域に溶け込む。',
            'Run a stall and blend into the town.')
      ),
    };

/// 全33件(30件の通常の手と、資金がマイナスのときだけの危機の手3件)。表示は分野ごとにまとめて出す。
const List<OwnerWork> ownerWorks = [
  // 営業・収入
  OwnerWork(id: 'merch_drive', category: OwnerWorkCategory.sales, funds: -150, supporters: 1, shareholders: 3),
  OwnerWork(id: 'stadium_food', category: OwnerWorkCategory.sales, funds: -300, supporters: 3, shareholders: 3),
  OwnerWork(id: 'season_ticket_promo', category: OwnerWorkCategory.sales, funds: 400, supporters: -2, shareholders: 2),
  OwnerWork(id: 'sponsor_roadshow', category: OwnerWorkCategory.sales, funds: -100, supporters: 0, shareholders: 5),
  OwnerWork(id: 'asia_tour', category: OwnerWorkCategory.sales, funds: -800, supporters: 2, shareholders: 4),
  OwnerWork(id: 'naming_survey', category: OwnerWorkCategory.sales, funds: 0, supporters: -1, shareholders: 3),
  OwnerWork(id: 'digital_content', category: OwnerWorkCategory.sales, funds: -200, supporters: 2, shareholders: 3),
  // 財務・資本
  OwnerWork(id: 'bond_issue', category: OwnerWorkCategory.finance, funds: 1500, supporters: 0, shareholders: -6),
  OwnerWork(id: 'cost_review', category: OwnerWorkCategory.finance, funds: 300, supporters: -3, shareholders: 5),
  OwnerWork(id: 'dividend_cut', category: OwnerWorkCategory.finance, funds: 500, supporters: 1, shareholders: -6),
  OwnerWork(id: 'dividend_bonus', category: OwnerWorkCategory.finance, funds: -600, supporters: -1, shareholders: 8),
  OwnerWork(id: 'asset_sale', category: OwnerWorkCategory.finance, funds: 1000, supporters: -2, shareholders: 2),
  OwnerWork(id: 'credit_talk', category: OwnerWorkCategory.finance, funds: -100, supporters: 0, shareholders: 3),
  OwnerWork(id: 'auditor', category: OwnerWorkCategory.finance, funds: -150, supporters: 0, shareholders: 5),
  // 広報・ファン
  OwnerWork(id: 'fan_thanks', category: OwnerWorkCategory.fans, funds: -400, supporters: 7, shareholders: -2),
  OwnerWork(id: 'supporter_dinner', category: OwnerWorkCategory.fans, funds: -50, supporters: 4, shareholders: 0),
  OwnerWork(id: 'vision_press', category: OwnerWorkCategory.fans, funds: 0, supporters: 3, shareholders: -1),
  OwnerWork(id: 'legend_match', category: OwnerWorkCategory.fans, funds: -350, supporters: 5, shareholders: 1),
  OwnerWork(id: 'kids_clinic', category: OwnerWorkCategory.fans, funds: -200, supporters: 4, shareholders: 1),
  OwnerWork(id: 'fan_survey', category: OwnerWorkCategory.fans, funds: -80, supporters: 2, shareholders: 1),
  OwnerWork(id: 'chant_contest', category: OwnerWorkCategory.fans, funds: -120, supporters: 4, shareholders: 0),
  // 組織・人事
  OwnerWork(id: 'hire_analyst', category: OwnerWorkCategory.org, funds: -300, supporters: 0, shareholders: 4),
  OwnerWork(id: 'manager_dinner', category: OwnerWorkCategory.org, funds: -60, supporters: 1, shareholders: 0),
  OwnerWork(id: 'staff_bonus', category: OwnerWorkCategory.org, funds: -250, supporters: 2, shareholders: -2),
  OwnerWork(id: 'exec_retreat', category: OwnerWorkCategory.org, funds: -400, supporters: 0, shareholders: 5),
  OwnerWork(id: 'finance_advisor', category: OwnerWorkCategory.org, funds: -200, supporters: 0, shareholders: 6),
  // 地域・社会
  OwnerWork(id: 'charity_match', category: OwnerWorkCategory.community, funds: -300, supporters: 5, shareholders: 0),
  OwnerWork(id: 'school_visit', category: OwnerWorkCategory.community, funds: -80, supporters: 3, shareholders: 0),
  OwnerWork(id: 'eco_stadium', category: OwnerWorkCategory.community, funds: -350, supporters: 2, shareholders: 3),
  // 経営危機(資金がマイナスのときだけ)
  OwnerWork(id: 'restructuring', category: OwnerWorkCategory.finance, funds: 1500, supporters: -6, shareholders: 4, onlyInRed: true),
  OwnerWork(id: 'emergency_loan', category: OwnerWorkCategory.finance, funds: 2500, supporters: 0, shareholders: -5, onlyInRed: true),
  OwnerWork(id: 'fire_sale', category: OwnerWorkCategory.finance, funds: 800, supporters: -3, shareholders: 0, onlyInRed: true),
  OwnerWork(id: 'town_festival', category: OwnerWorkCategory.community, funds: -150, supporters: 3, shareholders: 1),
];
