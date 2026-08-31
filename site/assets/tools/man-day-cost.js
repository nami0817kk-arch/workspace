/* 工数見積もりツール (人日 → 金額) */
(function () {
  const T = window.AdsiteTools;

  T.mount("man-day-cost", function (root) {
    root.innerHTML =
      '<div class="tool-grid">' +
      T.field("md-days", "見積工数 (人日)", 40, "設計・実装・テストの合計") +
      T.field("md-rate", "人日単価 (円)", 60000, "外注なら契約単価、社内なら間接費込みの日額") +
      T.field("md-buffer", "バッファ (%)", 30, "見積は下振れしない。20〜40%が実務的", { max: 200, step: 1 }) +
      T.field("md-review", "レビュー・調整の割合 (%)", 15, "打ち合わせ、仕様調整、手戻り", { max: 100, step: 1 }) +
      "</div>" +
      '<div class="tool-result" id="md-result" aria-live="polite"></div>';

    const save = T.persist(root, "man-day-cost");
    const result = root.querySelector("#md-result");
    const yen = function (v) { return Math.round(v).toLocaleString("ja-JP") + "円"; };

    function calc() {
      const days = T.num(root.querySelector("#md-days"), 0);
      const rate = T.num(root.querySelector("#md-rate"), 0);
      const buffer = T.num(root.querySelector("#md-buffer"), 0) / 100;
      const review = T.num(root.querySelector("#md-review"), 0) / 100;

      const withReview = days * (1 + review);
      const total = withReview * (1 + buffer);
      const months = total / 20; // 1人月 = 20人日

      result.innerHTML =
        '<div class="stat-row">' +
        '<div class="stat"><span class="stat-label">総工数</span><span class="stat-value">' + total.toFixed(1) + "人日</span></div>" +
        '<div class="stat"><span class="stat-label">概算金額</span><span class="stat-value">' + yen(total * rate) + "</span></div>" +
        '<div class="stat"><span class="stat-label">人月換算</span><span class="stat-value">' + months.toFixed(1) + "人月</span></div>" +
        "</div>" +
        '<table class="result-table"><tbody>' +
        "<tr><td>素の見積</td><td>" + days.toFixed(1) + "人日 / " + yen(days * rate) + "</td></tr>" +
        "<tr><td>+ レビュー・調整</td><td>" + withReview.toFixed(1) + "人日 / " + yen(withReview * rate) + "</td></tr>" +
        "<tr><td>+ バッファ</td><td>" + total.toFixed(1) + "人日 / " + yen(total * rate) + "</td></tr>" +
        "<tr><td>1人で進めた場合の期間</td><td>約 " + months.toFixed(1) + "か月</td></tr>" +
        "</tbody></table>" +
        '<p class="note">人数を増やしても期間は比例して縮みません。' +
        "分割できない作業と、増員による調整コストが残るためです。</p>";
      save();
    }

    ["md-days", "md-rate", "md-buffer", "md-review"].forEach(function (id) {
      root.querySelector("#" + id).addEventListener("input", calc);
    });
    calc();
  });
})();
