/// 現実に寄せた作り（1.1.0+25 から。社長の時間と体力・本物の経済・借金と銀行・横向きの画面・お金・世界・街）の英語。鍵は日本語の文。
library;

const Map<String, String> realEn = {
  // ===== 社長の時間と体力 =====
  '社長は倒れて休んでいます（あと{0}か月）': "The CEO is out sick ({0} more months)",
  '今月の社長の時間が足りません（{0}時間かかります・残り{1}時間）': "Not enough CEO time this month (needs {0}h, {1}h left)",
  '社長が仕事に戻りました': "The CEO is back at work",
  '社長が働きすぎで倒れました。{0}か月は仕事ができません（任せた事業と会議は部下が回します）':
      "The CEO collapsed from overwork and is out for {0} months (delegated businesses and meetings carry on)",
  '社長が働きすぎで倒れ、{0}か月休んだ': "The CEO collapsed from overwork and was out for {0} months",
  '社長の体力が残り{0}です。無理が続くと倒れます': "CEO stamina is down to {0}. Keep overworking and they'll collapse",
  '休みを取りました。体力 {0} → {1}': "Took time off. Stamina {0} → {1}",

  // ===== 借金と銀行 =====
  '借りる額がありません': "Nothing to borrow",
  '銀行が経営に口を出している間は、新しく借りられません': "No new loans while the bank is overseeing the company",
  '格付けが低く、銀行に断られました': "The bank turned you down: your rating is too low",
  '銀行がこれ以上は貸してくれません': "The bank won't lend any more",
  '{0}を借りました（年{1}%・{2}年で返す・毎月の返済 約{3}）': "Borrowed {0} ({1}% a year, repaid over {2} years, about {3} a month)",
  '返すお金がありません': "No cash to repay with",
  '{0}を返しました': "Repaid {0}",
  '今は社債を出せません': "You can't issue bonds right now",
  '社債で{0}を集めました（年{1}%・5年後にまとめて返す）': "Raised {0} in bonds ({1}% a year, repaid in full in 5 years)",
  '資金が足りず、銀行からつなぎの融資{0}を受けました（年{1}%・1年で返す）': "Short of cash, you took a {0} bridge loan ({1}% a year, repaid within a year)",
  '銀行の管理が終わりました。また自分で借りられます': "The bank's oversight has ended. You can borrow on your own again",
  '【景気後退】{0}の今年の成長率は{1}%の見込みです': "[Recession] {0}'s growth this year is expected at {1}%",
  '不況で銀行が貸しはがしに来ました。格付け{0}のため、借金の2割（{1}）をすぐ返すよう求められ、返しました':
      "With the downturn the bank called in loans. At rating {0} you had to repay 20% of your debt ({1}) at once",
  '返すお金が足りず、「{0}」を{1}で手放しました': "Unable to meet repayments, you sold {0} for {1}",
  '資金が尽きかけ、メインバンクが経営に口を出してきました。返す期限はのびましたが、2年のあいだ新しく借りられません':
      "With cash nearly gone, your main bank stepped in. Repayments were extended, but you can't borrow anew for 2 years",
  '資金繰りに行き詰まり、メインバンクの管理下に入った': "Ran out of cash and came under the main bank's oversight",
  '景気が大きく上向いています': "The economy is booming",
  '景気が大きく崩れています': "The economy is falling apart",
  '{0}年の{1}の経済：成長率 {2}%・物価 {3}%・金利 {4}%・1ドル {5}': "{1}'s economy in {0}: growth {2}%, inflation {3}%, interest {4}%, 1 USD = {5}",
  '{0}円': "¥{0}",
  'メインバンク': "Main bank",
  '二番手の銀行': "Second bank",
  '地元の信用金庫': "Local credit union",
  'つなぎの融資': "Bridge loan",
  '社債': "Bonds",
};
