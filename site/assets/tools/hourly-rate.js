/* 年収・時給 換算ツール */
(function () {
  const T = window.AdsiteTools;

  T.mount("hourly-rate", function (root) {
    root.innerHTML =
      '<div class="tool-grid">' +
      T.field("hr-annual", "年収 (万円)", 600, "額面。手取りではない") +
      T.field("hr-hours", "年間労働時間", 1800, "月160時間×12か月 ≒ 1,920。有給を引くと1,800前後") +
      T.field("hr-overhead", "間接費の率 (%)", 40, "社会保険料の会社負担・設備・管理費。30〜50%が目安", { max: 200, step: 1 }) +
      "</div>" +
      '<div class="tool-result" id="hr-result" aria-live="polite"></div>';

    const save = T.persist(root, "hourly-rate");
    const result = root.querySelector("#hr-result");
    const yen = function (v) { return Math.round(v).toLocaleString("ja-JP") + "円"; };

    function calc() {
      const annual = T.num(root.querySelector("#hr-annual"), 0) * 10000;
      const hours = Math.max(T.num(root.querySelector("#hr-hours"), 0), 1);
      const overhead = T.num(root.querySelector("#hr-overhead"), 0) / 100;

      const nominal = annual / hours;
      const loaded = (annual * (1 + overhead)) / hours;

      result.innerHTML =
        '<div class="stat-row">' +
        '<div class="stat"><span class="stat-label">額面ベースの時給</span><span class="stat-value">' + yen(nominal) + "</span></div>" +
        '<div class="stat"><span class="stat-label">間接費込みの時間単価</span><span class="stat-value">' + yen(loaded) + "</span></div>" +
        "</div>" +
        '<table class="result-table"><tbody>' +
        "<tr><td>1日(8時間)あたり</td><td>" + yen(loaded * 8) + "</td></tr>" +
        "<tr><td>1か月(160時間)あたり</td><td>" + yen(loaded * 160) + "</td></tr>" +
        "<tr><td>会社が負担する年間総額</td><td>" + yen(annual * (1 + overhead)) + "</td></tr>" +
        "</tbody></table>" +
        '<p class="note"><strong>費用対効果の計算には、間接費込みの時間単価を使ってください。</strong>' +
        "額面の時給で計算すると、削減効果を3〜4割過小評価します。</p>";
      save();
    }

    ["hr-annual", "hr-hours", "hr-overhead"].forEach(function (id) {
      root.querySelector("#" + id).addEventListener("input", calc);
    });
    calc();
  });
})();
