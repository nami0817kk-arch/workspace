/// 大きな岐路の印（2026-11-25）。
///
/// 世を変えうる岐路（史実の分岐点で `history_*` の旗を立てうる場面）と、一生の向きを変える場面のうち、
/// 選んだ少数に、岐路のカードで「大きな分かれ道」の印を付ける（`Prompt.major`。数字は出さない）。
/// `Game.ask` が、いま進めている場面の id でこの表を引く（`sceneCauseFor` と同じ形）。
const kMajorScenes = <String, String>{
  // ---- 世を変えうる（`history_*` の旗を立てうる） ----
  'okehazama': '桶狭間（義元を守る）',
  'h_x_okehazama_warn': '桶狭間（今川に知らせる）',
  'honnoji': '本能寺（信長を救う）',
  'h_x_honnoji_warn': '本能寺（京で走る）',
  'h_yamazaki': '山崎（光秀につく）',
  'h_x_tennozan': '天王山（秀吉の軍に偽りの道）',
  'h_sekigahara': '関ヶ原（西軍につく）',
  'h_nagashino': '長篠（武田の騎馬）',
  'h_odawara': '小田原（北条の家）',
  'h_kawanakajima': '川中島（信玄を討つ）',
  // ---- 一生の向きを変える ----
  'gekokujo': '下剋上の誘い',
  'late_shukke': '出家の思い',
  'master_return': '師との再会（推挙状か仏門か）',
  'merchant_start': '商いの誘い',
  'outlaw_join': '野盗の頭',
};

/// その場面が「大きな分かれ道」か。
bool isMajorScene(String? id) => id != null && kMajorScenes.containsKey(id);
