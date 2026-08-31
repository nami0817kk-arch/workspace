/* 業務自動化 ROI計算ツール */
(function () {
  const T = window.AdsiteTools;

  T.mount("automation-roi", function (root) {
    root.innerHTML =
      '<div class="tool-grid">' +
      T.field("roi-hours", "月間作業時間 (時間)", 80, "対象業務に実際にかかっている時間。実測を推奨") +
      T.field("roi-rate", "時間単価 (円)", 4500, "社会保険料・間接費込み。年収÷1800×1.3〜1.5が目安") +
      T.field("roi-auto", "自動化率 (%)", 70, "例外処理と確認が残るため60〜80%が現実的", { max: 100, step: 1 }) +
      T.field("roi-init", "初期開発コスト (円)", 1200000, "外注費に加え、社内工数も金額換算して含める") +
      T.field("roi-run", "月額運用費 (円)", 45000, "API費用・監視・精度検証・保守の合計") +
      "</div>" +
      '<div class="tool-result" id="roi-result" aria-live="polite"></div>';

    const save = T.persist(root, "automation-roi");
    const result = root.querySelector("#roi-result");
    const yen = function (v) {
      return Math.round(v).toLocaleString("ja-JP") + "円";
    };

    function calc() {
      const hours = T.num(root.querySelector("#roi-hours"), 0);
      const rate = T.num(root.querySelector("#roi-rate"), 0);
      const auto = Math.min(T.num(root.querySelector("#roi-auto"), 0), 100) / 100;
      const init = T.num(root.querySelector("#roi-init"), 0);
      const run = T.num(root.querySelector("#roi-run"), 0);

      const savedHours = hours * auto;
      const grossMonthly = savedHours * rate;
      const netMonthly = grossMonthly - run;
      const year1 = netMonthly * 12 - init;
      const year3 = netMonthly * 36 - init;

      let verdict;
      let payback;
      if (netMonthly <= 0) {
        payback = "回収できません";
        verdict = ["bad", "運用費が削減額を上回っています。対象業務か運用体制を見直してください。"];
      } else {
        const months = init / netMonthly;
        payback = months.toFixed(1) + "か月";
        if (months <= 3) {
          verdict = ["warn", "回収が早すぎます。作業時間か自動化率を高く見積もっていないか確認してください。"];
        } else if (months <= 12) {
          verdict = ["good", "12か月以内の回収。社内投資として通しやすい水準です。"];
        } else if (months <= 24) {
          verdict = ["warn", "回収に1〜2年。技術の陳腐化リスクを織り込んで判断してください。"];
        } else {
          verdict = ["bad", "24か月超。投資額を削るか、対象業務を変えるほうが健全です。"];
        }
      }

      result.innerHTML =
        '<div class="stat-row">' +
        '<div class="stat"><span class="stat-label">削減時間 / 月</span><span class="stat-value">' + savedHours.toFixed(1) + "時間</span></div>" +
        '<div class="stat"><span class="stat-label">純効果 / 月</span><span class="stat-value">' + yen(netMonthly) + "</span></div>" +
        '<div class="stat"><span class="stat-label">投資回収</span><span class="stat-value">' + payback + "</span></div>" +
        "</div>" +
        '<table class="result-table"><tbody>' +
        "<tr><td>粗い削減額 / 月</td><td>" + yen(grossMonthly) + "</td></tr>" +
        "<tr><td>運用費 / 月</td><td>-" + yen(run) + "</td></tr>" +
        "<tr><td>1年後の累積</td><td>" + yen(year1) + "</td></tr>" +
        "<tr><td>3年後の累積</td><td>" + yen(year3) + "</td></tr>" +
        "</tbody></table>" +
        '<p class="verdict verdict-' + verdict[0] + '">' + verdict[1] + "</p>" +
        '<p class="note">削減した時間は、担当者が別の業務に移れて初めて効果になります。' +
        "人員数が変わらず空き時間が使われない場合、会計上の削減は発生しません。</p>";
      save();
    }

    ["roi-hours", "roi-rate", "roi-auto", "roi-init", "roi-run"].forEach(function (id) {
      root.querySelector("#" + id).addEventListener("input", calc);
    });
    calc();
  });
})();
