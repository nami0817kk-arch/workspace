"""読み違いを防ぐ4段の仕組み（10-10、chiso/reading.py・cli の reading-ok）。

10/12〜13 の4本（始皇帝・豊臣秀長・お市の方・豊臣秀吉）で、聞いて分かる誤読が約50か所あった
（点検の記録は dev/output/rekishi-chiso/research/qc_1012/reading/）。直しは readings.yaml に入っている。
ここではその1か所ずつを「この台本のこの文は、こう読む」として残す。

- CI（VOICEVOX が無い）：readings.yaml で置き換えた文に、正しい読みが入っているか
- 手元だけ（@pytest.mark.voicevox。エンジンに繋がらなければ飛ばす）：VOICEVOX のカナが正しい読みか
"""
import json
from pathlib import Path

import pytest

from chiso import cli, reading, script
from chiso.reading import yomi
from chiso.voice import apply_readings, display_text, load_readings, split_emphasis

ROOT = Path(__file__).resolve().parent.parent
READINGS = load_readings(ROOT / "readings.yaml")
needs_fugashi = pytest.mark.skipif(not yomi.available(), reason="fugashi・unidic-lite が入っていない")
_engine_up = yomi.engine_up


# --- 5. 見つけた誤読（台本, 文の一部, 置き換えたあとの文に入るもの, VOICEVOX のカナに入るもの）-----------------
# カナが「／」で始まるものは、区切りの頭にその読みが来ること（「勝家」が「〜とか／ついえ」に切れないこと）
MISREADS = [
    # 源頼朝・物語完結型ショート（yoritomo_s1〜、10-30）
    ("story/yoritomo_s1", "JBpress の記事は書く", "ジェイビープレス", "ジェイ"),
    # 始皇帝（shikoutei）
    ("shikoutei", "「正」から取った", "「セイ」から", "セイカラ"),
    ("shikoutei", "最後に残った斉", "のこったセイ", "ノコッタセイ"),
    ("shikoutei", "221年の斉まで", "ねんのセイまで", "ネンノセイマデ"),
    ("shikoutei", "戦はしない", "イクサワシナイ", "イクサワシナイ"),
    ("shikoutei", "1尺", "いっしゃく", "イッシャク"),
    ("shikoutei", "死の床", "シノトコ", "シノトコ"),
    ("shikoutei", "先物買い", "さきものがい", "サキモノガイ"),
    ("shikoutei", "民の力", "たみのちから", "タミノチカラ"),
    # 豊臣秀長（hidenaga）
    ("hidenaga", "表のことは自分が", "おもてのこと", "オモテノコト"),
    ("hidenaga", "表と内の", "おもてとうち", "オモテトウチ"),
    ("hidenaga", "表の窓口", "おもてのまどぐち", "オモテノマドグチ"),
    ("hidenaga", "表に立つ", "おもてにたつ", "オモテニタツ"),
    ("hidenaga", "表の仕事", "おもてのしごと", "オモテノシゴト"),
    ("hidenaga", "同じ人って", "おなじひとって", "オナジヒトッテ"),
    ("hidenaga", "10万石って", "10万ゴクって", "マンゴクッテ"),
    ("hidenaga", "10万石なら", "10万ゴクなら", "マンゴクナラ"),
    ("hidenaga", "約64万石", "64万ゴク", "ヨンマンゴク"),
    ("hidenaga", "100万石の大名に", "100万ゴクの", "ヒャクマンゴクノ"),
    ("hidenaga", "8年で100万石", "100万ゴク", "ヒャクマンゴク"),
    ("hidenaga", "100万石は", "100万ゴクは", "マンゴクワ"),
    ("hidenaga", "73万4千石", "73万4センゴク", "ヨンセンゴク"),
    ("hidenaga", "何て呼ばれ", "なんてよばれ", "ナンテヨバレ"),
    ("hidenaga", "豊臣方の", "トヨトミガタの", "トヨトミガタノ"),
    ("hidenaga", "長宗我部方", "ちょうそかべがた", "チョオソカベガタ"),
    ("hidenaga", "島津方の夜襲", "島津がた", "シマズガタ"),
    ("hidenaga", "寺々", "てらでら", "テラデラ"),
    ("hidenaga", "銭は、何万貫", "ぜには、何万貫", "ゼニワ"),
    ("hidenaga", "銭のほうは", "ぜにのほう", "ゼニノホオ"),
    ("hidenaga", "大和郡山の郡山城", "コオリヤマジョウ", "コオリヤマジョオ"),
    # お市の方（oichi）
    ("oichi", "妹として披露", "ひろう", "ヒロウ"),
    ("oichi", "対で伝わって", "ついで", "ツイデ"),
    ("oichi", "織田家に守られて", "おだけに", "オダケニ"),
    ("oichi", "織田家に保護", "おだけに", "オダケニ"),
    ("oichi", "織田家の娘", "おだけの", "オダケノ"),
    ("oichi", "織田家の跡継ぎ", "おだけの", "オダケノ"),
    ("oichi", "織田家は", "おだけは", "オダケワ"),
    ("oichi", "「小谷の方」と", "おだにのかた", "オダニノカタ"),
    ("oichi", "小谷の方って", "おだにのかた", "オダニノカタ"),
    ("oichi", "前の節", "まえのせつ", "マエノセツ"),
    ("oichi", "江は3度目", "ごうわさんどめ", "ゴオワサンドメ"),
    ("oichi", "お市と勝家の再婚", "カツイエ", "／カツイエ"),
    ("oichi", "秀吉と勝家が", "カツイエ", "／カツイエ"),
    ("oichi", "負けた勝家とお市", "カツイエ", "／カツイエ"),
    ("oichi", "十七回忌", "ジュウシチ回忌", "ジュウシチカイキ"),
    # 豊臣秀吉（hideyoshi）
    ("hideyoshi", "小六も", "ころくも", "コロクモ"),
    ("hideyoshi", "今川家の家臣", "イマガワケ", "イマガワケ"),
    ("hideyoshi", "松下家を", "マツシタケ", "マツシタケ"),
    ("hideyoshi", "約12万石", "12万ゴク", "マンゴク"),
    ("hideyoshi", "28万石", "28万ゴク", "マンゴク"),
    ("hideyoshi", "約1850万石", "1850万ゴク", "マンゴク"),
    ("hideyoshi", "約3200万石", "3200万ゴク", "マンゴク"),
    ("hideyoshi", "都へ向けて", "みやこへむけて", "ミヤコエ"),
    ("hideyoshi", "織田家には", "おだけには", "オダケニワ"),
    ("hideyoshi", "形だけの", "かたちだけの", "カタチダケノ"),
    ("hideyoshi", "米の量", "こめのりょう", "コメノリョオ"),
    ("hideyoshi", "お米で", "おこめで", "オコメデ"),
    ("hideyoshi", "表のことは秀長", "おもてのこと", "オモテノコト"),
    ("hideyoshi", "柴田勝家の", "カツイエ", "カツイエ"),
    ("hideyoshi", "敗れた勝家は", "カツイエ", "／カツイエ"),
    ("hideyoshi", "刀狩って", "かたながりって", "カタナガリッテ"),
    # 徳川慶喜（yoshinobu）
    ("yoshinobu", "一橋家を継ぎます", "ひとつばしけを", "ヒトツバシケオ"),
    ("yoshinobu", "家慶の「慶」", "いえよし", "イエヨシ"),
    ("yoshinobu", "家茂を助ける", "いえもち", "イエモチ"),
    ("yoshinobu", "養子の徳川家達", "いえさと", "イエサト"),
    ("yoshinobu", "老中の板倉勝静", "いたくらかつきよ", "カツキヨ"),
    ("yoshinobu", "有栖川宮織仁親王", "ありすがわのみやたるひと", "タルヒト"),
    ("yoshinobu", "鳥羽と伏見で", "とばふしみ", "トバフシミ"),
    ("yoshinobu", "艦長は榎本武揚", "えのもとたけあき", "タケアキ"),
    ("yoshinobu", "勝海舟たちに任せました", "かつかいしゅう", "カツカイシュウ"),
    ("yoshinobu", "小日向の屋敷", "こひなた", "コヒナタ"),
    ("yoshinobu", "谷中霊園", "やなか", "ヤナカ"),
    ("yoshinobu", "二心殿と", "にしんどの", "ニシンドノ"),
    ("yoshinobu", "蛤御門で", "はまぐりごもん", "ハマグリゴモン"),
    ("yoshinobu", "小御所で開かれた", "こごしょ", "コゴショ"),
    ("yoshinobu", "錦の御旗", "にしきのみはた", "ニシキノミハタ"),
    ("yoshinobu", "徳川家の墓所", "ぼしょ", "ボショ"),
    ("yoshinobu", "無血開城", "むけつかいじょう", "ムケツカイジョオ"),
    ("yoshinobu", "駿府の宝台院", "ほうだいいん", "ホオダイイン"),
    ("yoshinobu", "紺屋町にあった", "こうやちょう", "コオヤチョオ"),
    # お市の方・物語型の本編（oichi-story、10-24）
    ("oichi-story", "いちばん下の江は", "したのごうは", "ゴオワ"),
    ("oichi-story", "江は10歳", "ごうは", "ゴオワ"),
    ("oichi-story", "茶々、初、江。", "はつ、ごう。", "ゴオ"),
    ("oichi-story", "江と秀忠", "ごうとひでただ", "ゴオト"),
    ("oichi-story", "兄上と、殿が", "とのが", "トノ"),
    ("oichi-story", "市。娘たち", "いち。", "イチ"),
    ("oichi-story", "御くやしく候", "おくやしくそうろう", "オクヤシクソオロウ"),
    ("oichi-story", "生まれた、和子", "まさこ", "マサコ"),
    ("oichi-story", "その和子が", "まさこ", "マサコ"),
    ("oichi-story", "三法師", "さんぼうし", "ボオシ"),
    ("oichi-story", "天皇の位を", "くらいを", "クライオ"),
    # 伊達政宗・物語型の本編（masamune-story、10-28）
    ("masamune-story", "『治家記録』", "じけきろく", "ジケ"),
    ("masamune-story", "疱瘡、今でいう", "ほうそう", "ホオソオ"),
    ("masamune-story", "萬海上人の生まれ変わり", "まんかいしょうにん", "マンカイショオニン"),
    ("masamune-story", "「云ひ伝ふ」", "いいつたう", "イイツタウ"),
    ("masamune-story", "愧ぢたまひて", "はじたまいて", "ハジタ"),
    ("masamune-story", "李克用のあだ名", "りこくよう", "リコクヨオ"),
    ("masamune-story", "瑞鳳殿は", "ずいほうでん", "ズイホオデン"),
    ("masamune-story", "仙台の経ヶ峯", "きょうがみね", "キョオガ"),
    ("masamune-story", "2代藩主の忠宗", "ただむね", "タダ"),
    ("masamune-story", "玉眼", "ぎょくがん", "ギョクガン"),
    ("masamune-story", "東京大学の鈴木尚", "すずきひさし", "ヒサシ"),
    ("masamune-story", "伊達泰宗さんは", "だてやすむね", "ヤス"),
    ("masamune-story", "政宗公は", "まさむねこうわ", "マサムネコオワ"),
    ("masamune-story", "一分金", "いちぶきん", "イチブ"),
    ("masamune-story", "若いころの名を、愛姫", "めごひめ", "メゴヒメ"),
    ("masamune-story", "殿のお顔", "とののおかお", "トノノ"),
    # 石川数正・物語型の本編（kazumasa-story、10-26）
    ("kazumasa-story", "数正自身が", "かずまさ", "カズマサ"),
    ("kazumasa-story", "康輝の「康」は", "「やす」は", "ヤスワ"),
    ("kazumasa-story", "家中は", "かちゅうは", "カチュウワ"),
    ("kazumasa-story", "香原斗志さん", "カハラトシ", "カハラ"),
    ("kazumasa-story", "小笠原貞慶です", "サダヨシ", "サダヨシデス"),
    ("kazumasa-story", "『日本歴史』", "にほんれきし", "ニホンレキシ"),
    ("kazumasa-story", "『日本大百科全書』", "にほんだいひゃっかぜんしょ", "ニホンダイヒャッカゼンショ"),
    ("kazumasa-story", "山岡荘八", "ヤマオカソウハチ", "ハチノ"),
    ("kazumasa-story", "一柳家文書", "ひとつやなぎけもんじょ", "ヒトツ"),
    ("kazumasa-story", "鎌田浩毅さん", "かまたひろき", "ヒロキ"),
    ("kazumasa-story", "眞邊明人さん", "まなべあきひと", "アキヒト"),
    ("kazumasa-story", "出雲守、", "いずものかみ", "イズモノカミ"),
    ("kazumasa-story", "古山寺御殿", "こさんじごてん", "コサンジゴテン"),
    ("kazumasa-story", "七条河原", "しちじょうがわら", "チジョオガワラ"),
    ("kazumasa-story", "藤三郎", "とうざぶろう", "トオザブロウ"),
    ("kazumasa-story", "大久保長安の長男", "おおくぼながやす", "ナガヤス"),
    ("kazumasa-story", "豊後の佐伯", "さいき", "サイキ"),
    ("kazumasa-story", "親子の法要", "おやこのほうよう", "オヤ"),
    ("kazumasa-story", "要の人", "かなめのひと", "カナメノ"),
    ("kazumasa-story", "結城家を継ぎ", "ゆうきけ", "ユウキケ"),
    ("kazumasa-story", "ふたたび戦に", "いくさに", "イクサニ"),
    ("kazumasa-story", "小松原琢さん", "こまつばらたく", "コマツバラ"),
    ("kazumasa-story", "麓和善さん", "麓かずよし", "フモトカズヨシ"),
    ("kazumasa-story", "きた櫓です", "きたやぐらです", "ヤグラデス"),
    ("kazumasa-story", "本宗寺", "ほんしゅうじ", "ホンシュウジ"),
    ("kazumasa-story", "美合町", "みあいちょう", "ミアイチョウ"),
    ("kazumasa-story", "妙西尼", "みょうさいに", "ミョオサイニ"),
    # 旭姫・大政所・物語型の本編（asahi-story、10-26）
    ("asahi-story", "三河の池鯉鮒の", "ちりゅう", "チリュウ"),
    ("asahi-story", "『豊太閤と其家族』", "ほうたいこうとそのかぞく", "ホオタイ"),
    ("asahi-story", "『近世日本国民史』", "きんせいにほんこくみんし", "キンセイニホン"),
    ("asahi-story", "馬に乗る供も", "のるともも", "ノルトモモ"),
    ("asahi-story", "秀吉の御母", "おんハハ", "オンハハ"),
    ("asahi-story", "御越しになる", "おこしになる", "オコシニ"),
    ("asahi-story", "「御証人の体」", "ごしょうにんのてい", "ゴショオニンノテイ"),
    ("asahi-story", "秀吉が直政を", "なおまさを", "ナオマサオ"),
    ("asahi-story", "佐治日向守とする", "さじひゅうがのかみ", "ヒュウガノ"),
    ("asahi-story", "『尾張志』は", "おわりし", "オワリシ"),
    ("asahi-story", "副田については", "そえだ", "ソエダ"),
    ("asahi-story", "500石と", "ごひゃっこく", "ゴヒャッコク"),
    ("asahi-story", "八幡さんの紹介", "やわたさん", "ワタサン"),
    ("asahi-story", "三姉妹の江の", "ごうの", "ゴウノ"),
    ("asahi-story", "懇望せしめ候", "せしめそうろう", "セシメソオロウ"),
    ("asahi-story", "天守台の重なり", "かさなり", "カサナリ"),
    ("asahi-story", "御通りになった", "おとおりになった", "オトオリ"),
    ("asahi-story", "『雍州府志』", "ようしゅうふし", "ヨオシュウフシ"),
    ("asahi-story", "『駿国雑志』", "すんこくざっし", "スンコク"),
    ("asahi-story", "打敷は", "うちしき", "ウチシキ"),
    ("asahi-story", "寿塔を建てました", "じゅとう", "ジュトオ"),
    ("asahi-story", "差し出す側が", "さしだすがわが", "ワガ"),
    ("asahi-story", "戦の都合", "いくさのつごう", "ツゴオ"),
    ("asahi-story", "家忠の日記は", "いえただ", "イエタダ"),
    # 千利休（10-28 のショート story/rikyu_s1〜s5 の kana で。ショートの台本は script.load で読めないので本編の行で確かめる）
    ("rikyu-story", "大日本茶道学会", "ちゃどう", "チャドオ"),
    # 豊臣秀次（10-28 のショート story/hidetsugu_s1〜s5 の kana で。ショートの台本は _texts が storyshort で読む）
    ("story/hidetsugu_s5", "ひとつの塚から", "のつかから", "ツカカラ"),
    # 和宮（10-28 の kazunomiya-story の kana で）
    ("kazunomiya-story", "一枚のガラス板が", "ガラスイタ", "ガラスイタ"),
    ("kazunomiya-story", "嫁がされた徳川", "とつがされた", "トツガサレタ"),
    ("kazunomiya-story", "御取つぶし", "おとりつぶし", "オトリツブシ"),
    ("kazunomiya-story", "有栖川宮の熾仁親王", "ありすがわのみやの", "アリスガワノミヤノ"),
    ("kazunomiya-story", "都で育った", "みやこで", "ミヤコデ"),
    ("kazunomiya-story", "都は、もう", "みやこわ", "ミヤコワ"),
    ("kazunomiya-story", "都から来た", "みやこから", "ミヤコカラ"),
    ("kazunomiya-story", "御ケ条書", "ごかじょうがき", "ゴカジョオガキ"),
    ("kazunomiya-story", "親子といいます", "ちかこと", "チカコト"),
    ("kazunomiya-story", "荷物を運ぶ人足", "にんそく", "ニンソク"),
    ("kazunomiya-story", "桶川宿には", "おけがわしゅく", "オケガワシュク"),
    ("kazunomiya-story", "藪原宿に泊まり", "ヤブハラジュク", "ヤブハラ"),
    ("kazunomiya-story", "ここを過ぎれば", "すぎれば", "スギレバ"),
    ("kazunomiya-story", "まわり道か", "まわりみちか", "マワリミチカ"),
    ("kazunomiya-story", "元治元年", "げんじ", "ゲンジ"),
    ("kazunomiya-story", "何かせん", "なにかせん", "ナニカ"),
    ("kazunomiya-story", "橋本実梁", "さねやな", "サネヤ"),
    ("kazunomiya-story", "清水家の屋敷に", "シミズケ", "シミズケ"),
    ("kazunomiya-story", "礫石経", "れきせききょう", "レキセキ"),
    ("kazunomiya-story", "和宮様御留", "おとめ", "オトメ"),
    # 土方歳三の物語完結型ショート（10-29）
    ("story/hijikata_s1", "この一行に", "このいちぎょうに", "イチギョウ"),
    ("story/hijikata_s4", "箱館で、洋服を着て", "ハコダテで", "ダテデ"),
    ("story/hijikata_s5", "箱館で亡くなった旧幕府軍", "ハコダテで", "ダテデ"),
    # 高杉晋作の物語型の本編（10-29）
    ("takasugi-story", "望東尼", "ぼうとうに", "ボオトオニ"),
    ("takasugi-story", "千歳丸", "せんさいまる", "センサイマル"),
    ("takasugi-story", "遊清五録", "ゆうしんごろく", "ユウシンゴロク"),
    ("takasugi-story", "清国", "しんこく", "シンコク"),
    ("takasugi-story", "日録", "にちろく", "ニチロク"),
    ("takasugi-story", "抱いた", "いだいた", "イダイタ"),
    ("takasugi-story", "狂介", "きょうすけ", "キョオスケ"),
    ("takasugi-story", "80多人", "はちじゅうあまりにん", "ハチジュウアマリニン"),
    ("takasugi-story", "新地会所", "しんちかいしょ", "シンチカイショオ"),
    ("takasugi-story", "大島口", "おおしまぐち", "オオシマグチ"),
    ("takasugi-story", "小倉口", "こくらぐち", "コクラグチ"),
    ("takasugi-story", "谷家", "たにけ", "タニケ"),
    ("takasugi-story", "100石", "ひゃっこく", "ヒャッコク"),
    ("takasugi-story", "五十首", "ごじっしゅ", "ゴジッシュ"),
    ("takasugi-story", "顕助", "けんすけ", "ケンスケ"),
    ("takasugi-story", "梅処", "ばいしょ", "バイショ"),
    # 高杉晋作の物語完結型ショート（10-29）
    ("story/takasugi_s1", "西海一狂生", "さいかいいっきょうせい", "イッキョオ"),
    ("story/yodo_s4", "25人と侍女", "にほんしりょう", "ニホンシリョオ"),
    ("story/hideaki_s3", "大人たちの都合", "おとなたちのつごう", "ツゴオ"),
    ("story/hideaki_s5", "床に就いた", "とこについた", "トコニツイタ"),
    # 小早川秀秋の物語型の本編（10-29）
    ("hideaki-story", "西尾家の", "ニシオケノ", "ニシオケ"),
    ("hideaki-story", "3万4000石", "さんまんよんせんごく", "ヨンセンゴク"),
    ("hideaki-story", "藤堂家の", "トウドウケノ", "ドウケ"),
    ("hideaki-story", "小早川家は", "コバヤカワケワ", "ケワ"),
    ("hideaki-story", "巳の刻", "みのこく", "ミノ／コク"),
    ("hideaki-story", "大音新介", "おおとしんすけ", "シンスケ"),
    ("hideaki-story", "板坂卜斎", "いたさかぼくさい", "ボクサイ"),
    ("hideaki-story", "精兵", "せいへい", "セイヘイ"),
    ("hideaki-story", "大納戸櫓", "おおなんどやぐら", "ヤグラ"),
    ("hideaki-story", "杉原紀伊守", "すぎはらきいのかみ", "キイノ"),
    ("hideaki-story", "酒疸", "しゅたん", "タン"),
    ("hideaki-story", "勅により", "ちょくにより", "チョクニ"),
    ("hideaki-story", "石川康通", "いしかわやすみち", "ヤスミチ"),
    ("hideaki-story", "梵舜の日記", "ぼんしゅんのにっき", "ボンシュン"),
    ("hideaki-story", "成就寺", "じょうじゅじ", "ジョオジュジ"),
    ("hideaki-story", "払拭", "ふっしょく", "フッショク"),
    ("hideaki-story", "櫓を造った", "やぐらをつくった", "ヤグラオ"),
    ("hideaki-story", "祐忠と祐滋", "すけただとすけしげ", "スケシゲ"),
    # 曹操の物語型の本編（10-29）
    ("sosou-story", "遺令", "いれい", "イレイ"),
    ("sosou-story", "丁卯", "ていぼう", "テイボオ"),
    ("sosou-story", "疑塚", "ぎちょう", "ギチョオ"),
    ("sosou-story", "陶鼎", "とうてい", "トオテイ"),
    ("sosou-story", "西高穴", "せいこうけつ", "セイコオケツ"),
    ("sosou-story", "沈約", "しんやく", "シンヤク"),
    ("sosou-story", "礼志", "れいし", "レイシ"),
    ("sosou-story", "黄豆二升", "こうとうにしょう", "コオトオニショオ"),
    ("sosou-story", "雲母", "うんも", "ウンモ"),
    ("sosou-story", "銀の環", "ぎんのわ", "ギンノワ"),
    ("sosou-story", "楕円形", "だえんけい", "ダエンケイ"),
    ("sosou-story", "位を譲られて", "くらいをゆずられて", "クライオ"),
    ("sosou-story", "魏武王曹操高陵", "ぎぶおう曹操こうりょう", "ギブオオ"),
    ("sosou-story", "黄初3年", "こうしょ3年", "コオショ"),
    ("sosou-story", "周さんは", "しゅうさんは", "シュウ"),
    ("sosou-story", "東坡志林", "とうばしりん", "トオバシリン"),
    ("sosou-story", "孫盛", "そんせい", "ソンセイ"),
    ("sosou-story", "居易録", "きょえきろく", "キョエキロク"),
    ("sosou-story", "蒲松齢", "ほしょうれい", "ホショオレイ"),
    ("sosou-story", "紅星新聞", "こうせいしんぶん", "コオセイ"),
    ("story/sosou_s5", "石牌の書きぶり", "せきはいのかきぶり", "セキハイノカキブリ"),
    # 宮本武蔵の物語型の本編（10-29）
    ("musashi-story", "延元は", "のぶもとは", "ノブモトワ"),
    ("musashi-story", "沼田延元", "沼田のぶもと", "ヌマタノブモト"),
    ("musashi-story", "舟嶋", "フナシマ", "フナシマ"),
    ("musashi-story", "船島", "フナシマ", "フナシマ"),
    ("musashi-story", "承応3年", "しょうおう", "ショオオオ"),
    ("musashi-story", "手向山", "たむけやま", "タムケヤマ"),
    ("musashi-story", "田向山", "たむけやま", "タムケヤマ"),
    ("musashi-story", "読み下し", "よみくだし", "ヨミクダシ"),
    ("musashi-story", "岩流嶋", "がんりゅうじま", "ガンリュウジマ"),
    ("musashi-story", "岩流という", "がんりゅうという", "ガンリュウト"),
    ("musashi-story", "J-CAST", "ジェイキャスト", "ジェイキャスト"),
    ("musashi-story", "彦島", "ヒコシマ", "ヒコシマ"),
    ("musashi-story", "SAPIO", "サピオ", "サピオ"),
    ("musashi-story", "脛も立てない", "すねも立てない", "スネモ"),
    ("musashi-story", "柳生但馬守", "やぎゅうたじまのかみ", "ヤギュウタジマノカミ"),
    ("musashi-story", "津川四郎右衛門", "つがわしろうえもん", "ツガワシロウエモン"),
    ("musashi-story", "霊巌洞", "れいがんどう", "レイガンドオ"),
    ("musashi-story", "八代藩", "やつしろはん", "ヤツシロハン"),
    ("musashi-story", "兵法大祖武州玄信公伝来", "ヒョオホオダイソブシュウゲンシンコオデンライ", "ヒョオホオダイソブシュウゲンシンコオデンライ"),
    ("musashi-story", "新免武蔵守藤原玄信", "しんめんむさしのかみふじわらのはるのぶ", "ハルノブ"),
    ("musashi-story", "官途名", "かんどな", "カンドナ"),
    ("musashi-story", "紅梅鳩図", "コウバイハトズ", "コオバイハトズ"),
    ("musashi-story", "芦雁図屏風", "ろがんずびょうぶ", "ロガンズ"),
    ("musashi-story", "勝った武蔵", "かった武蔵", "カッタ"),
    ("musashi-story", "合力米", "ゴウリキマイ", "ゴオリキ"),
    ("musashi-story", "沼田家記", "ぬまたかき", "ヌマタカキ"),
    ("musashi-story", "宮本家は", "宮本けは", "ミヤモトケワ"),
    ("musashi-story", "細川家の家臣", "細川けの家臣", "ホソカワケノ"),
    ("musashi-story", "二刀の兵法", "にとうの兵法", "ニトオノ"),
    # ジャンヌ・ダルク（jeanne-story）
    ("jeanne-story", "枝の主日に", "えだのしゅじつに", "シュ"),
    ("jeanne-story", "三位一体の主日", "さんみいったいのしゅじつ", "シュジツ"),
    ("jeanne-story", "描き込みました", "かきこみました", "カキコミ"),
    ("jeanne-story", "弓兵が", "キュウヘイが", "キュウ"),
    ("jeanne-story", "村々の税", "むらむらの税", "ムラムラ"),
    ("jeanne-story", "同じ場にいた", "おなじ場にいた", "オナジ"),
    ("jeanne-story", "旧市場の広場", "きゅういちばの広場", "キュウイチバ"),
    ("jeanne-story", "ギヨーム・マション", "ギヨーム・ましょん", "マション"),
    ("jeanne-story", "ジャン・トゥトムイエが", "ジャン・とぅとむいえが", "トゥトムイエ"),
    # 源頼朝（yoritomo-story、10-29）
    ("yoritomo-story", "『吾妻鏡』が、頼朝の落馬", "あずまかがみ", "アズマカガミ"),
    ("yoritomo-story", "建暦2年", "けんりゃく", "ケンリャク"),
    ("yoritomo-story", "藤原定家の『明月記』、1月18日", "ていか", "テイカ"),
    ("yoritomo-story", "近衛家実", "コノエイエザネ", "イエザネ"),
    ("yoritomo-story", "猪隈関白記", "イノクマカンパクキ", "イノクマカンパクキ"),
    ("yoritomo-story", "飲水の病にかかって重い", "インスイの病", "インスイノ"),
    ("yoritomo-story", "息子の頼家が", "ヨリイエ", "ヨリイエ"),
    ("yoritomo-story", "西股総生", "ニシマタフサオ", "ニシマタ"),
    ("yoritomo-story", "長女、大姫", "おおひめ", "オオヒメ"),
    ("yoritomo-story", "寿永2年", "じゅえい", "ジュエイ"),
    ("yoritomo-story", "天台座主", "テンダイザス", "テンダイザス"),
    ("yoritomo-story", "京へ上ろう", "きょうへのぼろう", "ノボロオ"),
    ("yoritomo-story", "前の右大将が", "うだいしょう", "オダイショオ"),
    ("yoritomo-story", "左中将に任じられ", "サチュウジョウ", "サチュウジョオ"),
    ("yoritomo-story", "下野市の解説", "シモツケシ", "シモツケシ"),
    ("yoritomo-story", "梶原景時が", "カジワラカゲトキ", "カジワラ"),
    ("yoritomo-story", "前の征夷将軍", "せいい", "セイイショオグン"),
    ("yoritomo-story", "吉書始め", "きっしょはじめ", "キッショ"),
    ("yoritomo-story", "北条義時、大江広元", "ホウジョウヨシトキ", "ヨシトキ"),
    ("yoritomo-story", "元久2年", "げんきゅう", "ゲンキュウ"),
    ("yoritomo-story", "和田清は", "わだせい", "ワダ"),
    ("yoritomo-story", "沼田頼輔は", "ヌマタライスケ", "ヌマタ"),
    ("yoritomo-story", "『保暦間記』は", "ほうりゃくかんき", "ホオリャクカンキ"),
    ("yoritomo-story", "義経や行家ら", "ユキイエ", "ユキイエ"),
    ("yoritomo-story", "鶴嶺八幡宮", "つるみねはちまんぐう", "ツルミネ"),
    ("yoritomo-story", "考証しました", "こうしょうし", "コオショオ"),
    ("yoritomo-story", "旧い説明には", "せつめいには、", "セツメイ"),
    ("yoritomo-story", "正治2年", "しょうじ", "ショオジ"),
    ("yoritomo-story", "元仁元年", "げんにん", "ゲンニン"),
    ("yoritomo-story", "安永8年", "あんえい", "アンエイ"),
    ("yoritomo-story", "神護寺は、これに", "じんごじ", "ジンゴジ"),
    ("yoritomo-story", "甲斐善光寺", "かいぜんこうじ", "カイゼンコオジ"),
    # ジャンヌ・ダルク・物語完結型ショート（jeanne_s1〜、10-30）
    ("story/jeanne_s4", "主の祈りくらい", "しゅのいのり", "シュノイノリ"),
    # 島原の乱（shimabara-story、10-30）
    ("shimabara-story", "天草から", "あまくさから", "アマクサカラ"),
    ("shimabara-story", "同じ項には", "おなじこうには", "コオニワ"),
    ("shimabara-story", "稲葉継陽さん", "いなばつぐはる", "ツグ"),
    ("shimabara-story", "熊本日日新聞の連載", "クマモトニチニチシンブン", "ニチニチシンブン"),
    ("shimabara-story", "神田千里さん", "かんだちさと", "チサト"),
    ("shimabara-story", "寺沢堅高は", "かたたか", "カタタカ"),
    ("shimabara-story", "寺沢家の代官", "寺沢けの", "テラサワケノ"),
    ("shimabara-story", "重矩は", "しげのり", "シゲノリ"),
    ("shimabara-story", "忍の3万石", "おしの", "オシノ"),
    ("shimabara-story", "表と裏に", "おもてとうら", "オモテト"),
    ("shimabara-story", "大きな聖杯", "せいはい", "セイハイ"),
    ("shimabara-story", "細川三斎", "さんさい", "サンサイ"),
    ("shimabara-story", "総攻め仕り", "そうぜめつかまつり", "ツカマツリ"),
    ("shimabara-story", "攻め損じ候", "せめそんじそうろう", "ソンジソオロウ"),
    ("shimabara-story", "承り候に", "うけたまわりそうろうに", "ウケタマワリソオロウニ"),
    ("shimabara-story", "兵糧尽き候はば", "つきそうらわば", "ツキソオラワバ"),
    ("shimabara-story", "出で申すべし", "いでもうすべし", "イデモオスベシ"),
    ("shimabara-story", "農民の怒り", "のうみんのいかり", "イカリ"),
    ("shimabara-story", "「四郎首」", "しろう", "シロオ"),
    ("shimabara-story", "嶋原天草日記", "しまばらあまくさにっき", "シマバラ"),
    # 元寇・もしも台風が来なかったら（genkou-if-story、10-30）
    ("genkou-if-story", "錨も粗い二石式", "にせきしき", "ニセキシキ"),
    ("genkou-if-story", "熊本の大矢野家に", "おおやのけ", "オオヤノケ"),
    ("genkou-if-story", "范文虎ら将軍たち", "はんぶんこ", "ハンブンコ"),
    ("genkou-if-story", "池田榮史さんによると", "いけだよしふみ", "イケダヨシフミ"),
    ("genkou-if-story", "霜月騒動。平頼綱", "しもつきそうどう", "シモツキソオドオ"),
    ("genkou-if-story", "竜口で首", "たつのくち", "タツノクチ"),
    ("genkou-if-story", "季長が作らせた", "すえながが", "スエナガガ"),
    ("genkou-if-story", "てつはうは、鷹島", "てっぽうは", "テッポオワ"),
]


def _texts(stem: str, phrase: str) -> list[str]:
    if stem.startswith("story/"):                 # 物語完結型ショート（scripts/story/*.yaml、10-28）
        from chiso import storyshort
        doc = storyshort.load(ROOT / "scripts" / f"{stem}.yaml")
        return [l.text for l in storyshort.lines_of(doc) if phrase in display_text(l.text)]
    sc = script.load(ROOT / "scripts" / f"{stem}.yaml")
    return [t for _, t in reading.items(sc) if phrase in display_text(t)]


@pytest.mark.parametrize("stem,phrase,said,_kana", MISREADS, ids=[f"{m[0]}-{m[1]}" for m in MISREADS])
def test_misread_fixed_by_readings(stem, phrase, said, _kana):
    texts = _texts(stem, phrase)
    assert texts, f"{stem} に「{phrase}」の行がありません"
    cases = [yomi.Case(reading.strip(t), said=said, note=f"{stem}「{phrase}」") for t in texts]
    assert yomi.check(cases, READINGS) == []


@pytest.mark.voicevox
@pytest.mark.skipif(not _engine_up(), reason="VOICEVOX が動いていない（手元だけで回す）")
@pytest.mark.parametrize("stem,phrase,_said,kana", MISREADS, ids=[f"{m[0]}-{m[1]}" for m in MISREADS])
def test_misread_kana(stem, phrase, _said, kana):
    cases = [yomi.Case(reading.strip(t), kana=kana, note=f"{stem}「{phrase}」") for t in _texts(stem, phrase)]
    assert yomi.check_kana(cases, READINGS, yomi.voicevox_kana) == []


def test_misread_list_covers_the_four_episodes():
    # 約50か所（4本）を残している
    assert len(MISREADS) >= 50
    # 10-28 から回ごとに足すので、最初の8本が入っていることだけを見る（== だと新しい回を足すたびに落ちる）
    assert {"shikoutei", "hidenaga", "oichi", "hideyoshi", "yoshinobu", "oichi-story", "kazumasa-story", "asahi-story"} <= {m[0] for m in MISREADS}


# --- 置き換え ------------------------------------------------------------------

def test_apply_tracked_is_the_same_replacement():
    for _, text in reading.all_scripts():
        plain = split_emphasis(text)[0]
        out, origin = yomi.apply_tracked(plain, READINGS)
        assert out == apply_readings(plain, READINGS)
        assert len(origin) == len(out)
        kept = [o for o in origin if o is not None]
        assert all(plain[o] == out[i] for i, o in enumerate(origin) if o is not None)
        assert kept == sorted(kept)


# --- 2. 読みが割れる字と型 --------------------------------------------------------------

def _rule(text: str):
    toks = yomi.tokens(text)
    lex = reading.lexicon()
    return [yomi.rule_of(toks, i, lex)[0] for i in range(len(toks)) if yomi.rule_of(toks, i, lex)]


@needs_fugashi
def test_channel_rule_miyako():
    # 歴史の地層だけの型（yomi.yaml）。「都へ向けて」をトエと読んだ（秀吉の回）
    assert _rule("都へ向けて引き返す") == ["都＋助詞"]
    assert _rule("首都に戻る") == []
    assert _rule("京都の町") == []
    assert _rule("織田家の娘") == ["名字＋家"]                     # 共通の型も効いている


# 型に当たる所（今の readings.yaml で）。予約・公開済みの全部の回に流して確かめた。OK は VOICEVOX が正しく読めている所
# （止めない）、NG は実際に読み違えている所（10-10 に kana で確かめた。公開済みなので台本・辞書は触っていない）
RULE_HITS = {
    ("hidenaga", "148行目", "徳川家の"): "OK",
    ("akechi", "58行目", "都の"): "NG",              # 都の両側 → トノ
    ("akechi", "148行目", "都の"): "NG",             # 都の人たち → トノ
    ("kira", "33行目", "4200石"): "NG",              # セキ
    ("kira", "34行目", "4200石って"): "NG",
    ("nobunaga", "164行目", "や都の"): "NG",
    ("oichi", "60行目", "朝倉家記"): "NG",           # 書名の読みは要確認（カキ／ケキ）
}
POSTED = ("akechi", "cixi", "hidenaga", "hideyoshi", "kira", "marie-antoinette", "napoleon", "nobunaga", "oichi",
          "sakoku", "shikoutei")


@needs_fugashi
def test_rules_on_posted_episodes():
    """型は、正しく読めている所で止めない（当たる所が増えたら、VOICEVOX の読みを kana で確かめてここに足す）。"""
    got = set()
    for stem in POSTED:
        sc = script.load(ROOT / "scripts" / f"{stem}.yaml")
        for label, text in reading.items(sc):
            for h in yomi.ambiguous_hits(label, reading.spoken(text, READINGS), None, reading.lexicon()):
                if h.rule:
                    got.add((stem, label, h.word))
    assert got == set(RULE_HITS)


@pytest.mark.voicevox
@pytest.mark.skipif(not _engine_up() or not yomi.available(), reason="VOICEVOX が動いていない（手元だけで回す）")
def test_rules_on_posted_episodes_with_voicevox():
    src = yomi.VoicevoxKana()
    for stem in POSTED:
        sc = script.load(ROOT / "scripts" / f"{stem}.yaml")
        for label, text in reading.items(sc):
            sp = reading.spoken(text, READINGS)
            for h in yomi.ambiguous_hits(label, sp, src.kana(sp), reading.lexicon()):
                if h.rule:
                    assert RULE_HITS[(stem, label, h.word)] == ("OK" if h.ok else "NG"), (stem, label, h.word, h.got)


# --- 3. readings.yaml の巻き込み --------------------------------------------------------------

@needs_fugashi
def test_no_collisions_in_scripts():
    """今の readings.yaml は、これから作る回（scripts/ のうち予約・公開済みでないもの）の長い語を巻き込まない
    （足したキーが他の回を壊したら CI で止まる）。予約・公開済みの回は作り直さないので見ない（10-10「過去は修正不要」）。"""
    assert reading.collision_lines(READINGS, reading.all_scripts(skip=POSTED)) == []


@needs_fugashi
def test_collision_in_a_posted_episode_is_only_reported():
    # 公開済みの信長の回 63行目「京都のまわり」に「都のまわり: ミヤコのまわり」が当たる（10-10 に見つけた。直さない）
    rows = reading.collision_lines(READINGS, reading.all_scripts(skip=[s for s in POSTED if s != "nobunaga"]))
    assert len(rows) == 1 and "京都のまわり" in rows[0]


# --- check の知らせ -----------------------------------------------------------------------

class _Kana:
    available = True

    def __init__(self, table):
        self.table = table

    def kana(self, text):
        return self.table.get(text, "")

    def save(self):
        pass


@needs_fugashi
def test_notes_without_engine_stops_rule_hits():
    sc = script.parse({"title": "t", "sections": [{"title": "一", "lines": [{"語り": "織田家の娘です。"}]}]})
    errors, warns = reading.notes(sc, {}, None)
    assert any("名字＋家" in e and "確かめられません" in e for e in errors)
    assert any("動いていない" in w for w in warns)


@needs_fugashi
def test_notes_with_kana():
    sc = script.parse({"title": "t", "sections": [{"title": "一", "lines": [
        {"語り": "織田家の娘です。"}, {"語り": "栗や柿や瓜をかじる。"}, {"語り": "上を見た。"}]}]})
    src = _Kana({"織田家の娘です。": "オダケノ／ムスメデス", "栗や柿や瓜をかじる。": "クリヤ／カキヤ／フリオ／カジル",
                 "上を見た。": "ジョオオ／ミタ"})
    errors, warns = reading.notes(sc, {}, src)
    assert errors == []                                          # 織田家はケと読めている
    assert "読み：2行目「瓜」エンジン フリ／辞書 ウリ" in warns
    assert any(w.startswith("読みが割れる語") and "上＝ジョオ（3）" in w for w in warns)


# --- 4. 読みの確認の関門 --------------------------------------------------------------------

SCRIPT = "title: {}\nsections:\n  - title: 一\n    lines:\n      - 語り: こんにちは。\n"


def _root(tmp_path, posted=()):
    (tmp_path / "scripts").mkdir(parents=True)
    (tmp_path / "approvals").mkdir()
    (tmp_path / "readings.yaml").write_text("露: つゆ\n", encoding="utf-8")
    (tmp_path / "posted.json").write_text(json.dumps([{"key": k} for k in posted]), encoding="utf-8")
    f = tmp_path / "scripts" / "x.yaml"
    f.write_text(SCRIPT.format("t"), encoding="utf-8")
    return f


def _ok(tmp_path, f):
    (tmp_path / "approvals" / "x.reading.json").write_text(json.dumps({
        "script": f.name, "sha256": script.digest(f),
        "readings_sha256": cli._file_sha(tmp_path / "readings.yaml")}), encoding="utf-8")


def test_gate_needs_reading_ok(tmp_path):
    f = _root(tmp_path)
    assert "reading-ok" in cli.reading_ok_problem(f, tmp_path)
    _ok(tmp_path, f)
    assert cli.reading_ok_problem(f, tmp_path) is None


def test_gate_breaks_when_script_or_readings_change(tmp_path):
    f = _root(tmp_path)
    _ok(tmp_path, f)
    f.write_text(SCRIPT.format("t2"), encoding="utf-8")
    assert "台本が変わって" in cli.reading_ok_problem(f, tmp_path)
    _ok(tmp_path, f)
    (tmp_path / "readings.yaml").write_text("露: つゆ\n披露: ひろう\n", encoding="utf-8")
    assert "readings.yaml が変わって" in cli.reading_ok_problem(f, tmp_path)


def test_gate_skips_posted_episodes(tmp_path):
    f = _root(tmp_path, posted=["x:main"])
    assert cli.reading_ok_problem(f, tmp_path) is None
    f2 = _root(tmp_path / "b", posted=["x:s1"])                 # ショートだけの控えは本編の公開ではない
    assert cli.reading_ok_problem(f2, tmp_path / "b") is not None


def test_approve_refuses_without_reading_ok(tmp_path, monkeypatch, capsys):
    f = _root(tmp_path)
    monkeypatch.setattr(cli, "ROOT", tmp_path)
    assert cli.main(["approve", str(f)]) == 2
    assert "reading-ok" in capsys.readouterr().out
    assert cli.main(["reading-ok", str(f)]) == 0
    assert cli.main(["approve", str(f)]) == 0
    assert (tmp_path / "approvals" / "x.json").exists()


def test_reading_ok_files_for_the_four_episodes():
    """10/12〜13 の4本は readings の直しを確かめたので控えがある（今の台本と readings.yaml のハッシュ）。"""
    for stem in ("shikoutei", "hidenaga", "oichi", "hideyoshi"):
        assert cli.reading_ok_problem(ROOT / "scripts" / f"{stem}.yaml", ROOT) is None
        assert (ROOT / "approvals" / f"{stem}.reading.json").exists()


def test_template_and_showcase_mention_reading_ok():
    for name in ("_template.yaml", "_showcase.yaml"):
        assert "reading-ok" in (ROOT / "scripts" / name).read_text(encoding="utf-8")
