import '../l10n/tr.dart';
import '../models/league_theme.dart';

/// 国ごとの選手の名前。日本語はカタカナ、英語は英字で、同じ番号が同じ名前。
///
/// リーグはすべて欧州の国を模しているので、日本の姓名で選手を作ると
/// 「全員が日本人」に見えてしまう(1.2.0 の試遊で指摘)。国籍に合った
/// 名前を作り、同じ番号を使えば表示言語を変えても同じ人だと分かる。
class NationNames {
  // i18n-ignore: 選手の名前のデータ。UIの文言ではないので訳さない。
  static const Map<LeagueTheme, List<(String, String)>> _given = {
    LeagueTheme.england: [
      // i18n-ignore
      ('ジャック', 'Jack'), ('ハリー', 'Harry'), ('オリバー', 'Oliver'),
      // i18n-ignore
      ('ジョージ', 'George'), ('チャーリー', 'Charlie'), ('トーマス', 'Thomas'),
      // i18n-ignore
      ('ジェームズ', 'James'), ('ウィリアム', 'William'), ('ダニエル', 'Daniel'),
      // i18n-ignore
      ('ルーク', 'Luke'), ('ベン', 'Ben'), ('サム', 'Sam'),
      // i18n-ignore
      ('ジョー', 'Joe'), ('ライアン', 'Ryan'), ('ルイス', 'Lewis'),
      // i18n-ignore
      ('カラム', 'Callum'), ('メイソン', 'Mason'), ('アルフィー', 'Alfie'),
      // i18n-ignore
      ('ネイサン', 'Nathan'), ('マーカス', 'Marcus'),
    ],
    LeagueTheme.spain: [
      // i18n-ignore
      ('アレハンドロ', 'Alejandro'), ('パブロ', 'Pablo'), ('ハビエル', 'Javier'),
      // i18n-ignore
      ('セルヒオ', 'Sergio'), ('ダビド', 'David'), ('カルロス', 'Carlos'),
      // i18n-ignore
      ('ミゲル', 'Miguel'), ('アドリアン', 'Adrian'), ('ディエゴ', 'Diego'),
      // i18n-ignore
      ('マルコス', 'Marcos'), ('イケル', 'Iker'), ('ラウル', 'Raul'),
      // i18n-ignore
      ('アルバロ', 'Alvaro'), ('ホルヘ', 'Jorge'), ('フェルナンド', 'Fernando'),
      // i18n-ignore
      ('イバン', 'Ivan'), ('ルベン', 'Ruben'), ('ゴンサロ', 'Gonzalo'),
      // i18n-ignore
      ('マリオ', 'Mario'), ('ダニ', 'Dani'),
    ],
    LeagueTheme.germany: [
      // i18n-ignore
      ('ルーカス', 'Lukas'), ('ヨナス', 'Jonas'), ('レオン', 'Leon'),
      // i18n-ignore
      ('フェリックス', 'Felix'), ('マクシミリアン', 'Maximilian'), ('ニクラス', 'Niklas'),
      // i18n-ignore
      ('ティモ', 'Timo'), ('ユリアン', 'Julian'), ('セバスティアン', 'Sebastian'),
      // i18n-ignore
      ('トビアス', 'Tobias'), ('ヤニク', 'Jannik'), ('マルコ', 'Marco'),
      // i18n-ignore
      ('ケビン', 'Kevin'), ('フロリアン', 'Florian'), ('ダニエル', 'Daniel'),
      // i18n-ignore
      ('ニコ', 'Nico'), ('クリスティアン', 'Christian'), ('マティアス', 'Matthias'),
      // i18n-ignore
      ('シュテファン', 'Stefan'), ('ラース', 'Lars'),
    ],
    LeagueTheme.italy: [
      // i18n-ignore
      ('ロレンツォ', 'Lorenzo'), ('アレッサンドロ', 'Alessandro'), ('フランチェスコ', 'Francesco'),
      // i18n-ignore
      ('マッテオ', 'Matteo'), ('アンドレア', 'Andrea'), ('ジョヴァンニ', 'Giovanni'),
      // i18n-ignore
      ('フェデリコ', 'Federico'), ('ダヴィデ', 'Davide'), ('リッカルド', 'Riccardo'),
      // i18n-ignore
      ('ニコロ', 'Nicolo'), ('ステファノ', 'Stefano'), ('ルカ', 'Luca'),
      // i18n-ignore
      ('ファビオ', 'Fabio'), ('シモーネ', 'Simone'), ('ジャコモ', 'Giacomo'),
      // i18n-ignore
      ('マルコ', 'Marco'), ('アントニオ', 'Antonio'), ('ピエトロ', 'Pietro'),
      // i18n-ignore
      ('クラウディオ', 'Claudio'), ('ガブリエーレ', 'Gabriele'),
    ],
    LeagueTheme.france: [
      // i18n-ignore
      ('ユーゴ', 'Hugo'), ('テオ', 'Theo'), ('ルーカス', 'Lucas'),
      // i18n-ignore
      ('アントワーヌ', 'Antoine'), ('マキシム', 'Maxime'), ('ジュリアン', 'Julien'),
      // i18n-ignore
      ('バンジャマン', 'Benjamin'), ('クレマン', 'Clement'), ('トマ', 'Thomas'),
      // i18n-ignore
      ('ニコラ', 'Nicolas'), ('ピエール', 'Pierre'), ('ロマン', 'Romain'),
      // i18n-ignore
      ('アドリアン', 'Adrien'), ('ヤニス', 'Yanis'), ('ウスマン', 'Ousmane'),
      // i18n-ignore
      ('ケビン', 'Kevin'), ('マティス', 'Mathis'), ('ラファエル', 'Raphael'),
      // i18n-ignore
      ('ルイ', 'Louis'), ('ナタン', 'Nathan'),
    ],
  };

  // i18n-ignore: 選手の名前のデータ。
  static const Map<LeagueTheme, List<(String, String)>> _surnames = {
    LeagueTheme.england: [
      // i18n-ignore
      ('スミス', 'Smith'), ('ジョーンズ', 'Jones'), ('テイラー', 'Taylor'),
      // i18n-ignore
      ('ブラウン', 'Brown'), ('ウィルソン', 'Wilson'), ('エヴァンズ', 'Evans'),
      // i18n-ignore
      ('ウォーカー', 'Walker'), ('ライト', 'Wright'), ('ロバーツ', 'Roberts'),
      // i18n-ignore
      ('トンプソン', 'Thompson'), ('ホワイト', 'White'), ('ヒューズ', 'Hughes'),
      // i18n-ignore
      ('グリーン', 'Green'), ('ホール', 'Hall'), ('ウッド', 'Wood'),
      // i18n-ignore
      ('ハリス', 'Harris'), ('クラーク', 'Clarke'), ('ジャクソン', 'Jackson'),
      // i18n-ignore
      ('ターナー', 'Turner'), ('ベネット', 'Bennett'), ('クーパー', 'Cooper'),
      // i18n-ignore
      ('ヒル', 'Hill'), ('ワード', 'Ward'), ('モリス', 'Morris'),
    ],
    LeagueTheme.spain: [
      // i18n-ignore
      ('ガルシア', 'Garcia'), ('ロドリゲス', 'Rodriguez'), ('マルティネス', 'Martinez'),
      // i18n-ignore
      ('ロペス', 'Lopez'), ('サンチェス', 'Sanchez'), ('ペレス', 'Perez'),
      // i18n-ignore
      ('ゴメス', 'Gomez'), ('フェルナンデス', 'Fernandez'), ('ディアス', 'Diaz'),
      // i18n-ignore
      ('モレノ', 'Moreno'), ('ムニョス', 'Munoz'), ('アロンソ', 'Alonso'),
      // i18n-ignore
      ('ロメロ', 'Romero'), ('ナバロ', 'Navarro'), ('トーレス', 'Torres'),
      // i18n-ignore
      ('ドミンゲス', 'Dominguez'), ('ルイス', 'Ruiz'), ('ヒル', 'Gil'),
      // i18n-ignore
      ('セラーノ', 'Serrano'), ('ブランコ', 'Blanco'), ('カスティージョ', 'Castillo'),
      // i18n-ignore
      ('オルテガ', 'Ortega'), ('ルビオ', 'Rubio'), ('モリーナ', 'Molina'),
    ],
    LeagueTheme.germany: [
      // i18n-ignore
      ('ミュラー', 'Muller'), ('シュミット', 'Schmidt'), ('シュナイダー', 'Schneider'),
      // i18n-ignore
      ('フィッシャー', 'Fischer'), ('ヴェーバー', 'Weber'), ('マイヤー', 'Meyer'),
      // i18n-ignore
      ('ヴァーグナー', 'Wagner'), ('ベッカー', 'Becker'), ('シュルツ', 'Schulz'),
      // i18n-ignore
      ('ホフマン', 'Hoffmann'), ('コッホ', 'Koch'), ('リヒター', 'Richter'),
      // i18n-ignore
      ('クライン', 'Klein'), ('ヴォルフ', 'Wolf'), ('ノイマン', 'Neumann'),
      // i18n-ignore
      ('シュヴァルツ', 'Schwarz'), ('ブラウン', 'Braun'), ('ツィンマーマン', 'Zimmermann'),
      // i18n-ignore
      ('クリューガー', 'Kruger'), ('ハルトマン', 'Hartmann'), ('ランゲ', 'Lange'),
      // i18n-ignore
      ('ヴェルナー', 'Werner'), ('クラウス', 'Krause'), ('ケーラー', 'Kohler'),
    ],
    LeagueTheme.italy: [
      // i18n-ignore
      ('ロッシ', 'Rossi'), ('ルッソ', 'Russo'), ('フェラーリ', 'Ferrari'),
      // i18n-ignore
      ('エスポージト', 'Esposito'), ('ビアンキ', 'Bianchi'), ('ロマーノ', 'Romano'),
      // i18n-ignore
      ('コロンボ', 'Colombo'), ('リッチ', 'Ricci'), ('マリーノ', 'Marino'),
      // i18n-ignore
      ('グレコ', 'Greco'), ('ブルーノ', 'Bruno'), ('ガッロ', 'Gallo'),
      // i18n-ignore
      ('コンティ', 'Conti'), ('デルカ', 'De Luca'), ('マンチーニ', 'Mancini'),
      // i18n-ignore
      ('コスタ', 'Costa'), ('ジョルダーノ', 'Giordano'), ('リッツォ', 'Rizzo'),
      // i18n-ignore
      ('ロンバルディ', 'Lombardi'), ('モレッティ', 'Moretti'), ('バルビエリ', 'Barbieri'),
      // i18n-ignore
      ('フォンターナ', 'Fontana'), ('サントーロ', 'Santoro'), ('マリーニ', 'Marini'),
    ],
    LeagueTheme.france: [
      // i18n-ignore
      ('マルタン', 'Martin'), ('ベルナール', 'Bernard'), ('デュボワ', 'Dubois'),
      // i18n-ignore
      ('トマ', 'Thomas'), ('ロベール', 'Robert'), ('リシャール', 'Richard'),
      // i18n-ignore
      ('プティ', 'Petit'), ('デュラン', 'Durand'), ('ルロワ', 'Leroy'),
      // i18n-ignore
      ('モロー', 'Moreau'), ('シモン', 'Simon'), ('ローラン', 'Laurent'),
      // i18n-ignore
      ('ルフェーブル', 'Lefebvre'), ('ミシェル', 'Michel'), ('ガルニエ', 'Garnier'),
      // i18n-ignore
      ('フォール', 'Faure'), ('アンドレ', 'Andre'), ('メルシエ', 'Mercier'),
      // i18n-ignore
      ('ブラン', 'Blanc'), ('ゲラン', 'Guerin'), ('ボワイエ', 'Boyer'),
      // i18n-ignore
      ('ジロー', 'Girard'), ('ボネ', 'Bonnet'), ('ディアロ', 'Diallo'),
    ],
  };

  /// 名と姓の間の中黒(U+30FB)。文字を直接書くと翻訳漏れの点検に掛かる。
  static final _dot = String.fromCharCode(0x30FB);

  /// [nation]の名前を[seed]から作る。同じ seed なら同じ名前(言語だけ変わる)。
  static String nameFor(LeagueTheme nation, int seed) {
    final given = _given[nation]!;
    final surnames = _surnames[nation]!;
    final s = seed.abs();
    final g = given[s % given.length];
    final f = surnames[(s ~/ given.length) % surnames.length];
    return Tr.isEnglish ? '${g.$2} ${f.$2}' : '${g.$1}$_dot${f.$1}';
  }

  /// 組み合わせの数(重複を避けて引き直すときの上限に使う)。
  static int combinations(LeagueTheme nation) =>
      _given[nation]!.length * _surnames[nation]!.length;

  /// [name]が[nation]の名前の一覧から作られたものか(どちらの言語でも)。
  static bool fits(String name, LeagueTheme nation) {
    final surnames = _surnames[nation]!;
    for (final f in surnames) {
      if (name.endsWith('$_dot${f.$1}') || name.endsWith(' ${f.$2}')) return true;
    }
    return false;
  }
}
