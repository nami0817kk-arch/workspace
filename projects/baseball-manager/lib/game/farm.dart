/// 二軍・育成契約(実際の野球にもある、プロ入りの形)。
///
/// ドラフトの**6位(いちばん低い順位)は「育成契約」**で、二軍からのスタート。
/// 二軍にいる間は、タイトル・表彰・日本一の対象にならず、年俸も低い(×0.4)。
/// 2年たつか、総合評価が `promoteLine` 以上になった年の終わりに**一軍に昇格**する。
/// 5位以上は最初から一軍。
const farmDraftRound = 6;

/// 育成契約の二軍にいる最長の年数。
const farmMaxYears = 2;

/// この総合評価に届けば、年の終わりに早めに一軍へ昇格できる。
const promoteLine = 52.0;

/// 指名順位から、二軍で過ごす年数(一軍スタートなら0)。
int farmYearsFor(int round) => round >= farmDraftRound ? farmMaxYears : 0;

/// 二軍の年の終わりに、一軍へ昇格するか(残りの年数が尽きた/評価が昇格の基準に届いた)。
bool promoted({required int yearsLeft, required double overall}) =>
    yearsLeft <= 0 || overall >= promoteLine;
