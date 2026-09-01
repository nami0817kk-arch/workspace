/* ドル建て費用の円換算・為替感応度 */
(function () {
  const T = window.AdsiteTools;

  T.mount("usd-jpy", function (root) {
    root.innerHTML =
      '<div class="tool-grid">' +
      T.field("uj-usd", "月額費用 (USD)", 400, "API利用料やSaaSの月額") +
      T.field("uj-rate", "想定レート (円/ドル)", 150, "予算を組むときのレート", { step: 0.1 }) +
      T.field("uj-swing", "為替の変動幅 (±%)", 10, "年間の振れ幅。円建て予算はこの分だけぶれる", { max: 100, step: 1 }) +
      "</div>" +
      '<div class="tool-result" id="uj-result" aria-live="polite"></div>';

    const save = T.persist(root, "usd-jpy");
    const result = root.querySelector("#uj-result");
    const yen = function (v) { return Math.round(v).toLocaleString("ja-JP") + "円"; };

    function calc() {
      const usd = T.num(root.querySelector("#uj-usd"), 0);
      const rate = T.num(root.querySelector("#uj-rate"), 0);
      const swing = T.num(root.querySelector("#uj-swing"), 0) / 100;

      const base = usd * rate;
      const high = usd * rate * (1 + swing);
      const low = usd * rate * (1 - swing);

      result.innerHTML =
        '<div class="stat-row">' +
        '<div class="stat"><span class="stat-label">月額 (想定レート)</span><span class="stat-value">' + yen(base) + "</span></div>" +
        '<div class="stat"><span class="stat-label">年額 (想定レート)</span><span class="stat-value">' + yen(base * 12) + "</span></div>" +
        "</div>" +
        '<table class="result-table"><thead><tr><th>シナリオ</th><th>レート</th><th>月額</th><th>年額</th></tr></thead><tbody>' +
        "<tr><td>円安に振れた場合</td><td>" + (rate * (1 + swing)).toFixed(1) + "円</td><td>" + yen(high) + "</td><td>" + yen(high * 12) + "</td></tr>" +
        "<tr><td>想定どおり</td><td>" + rate.toFixed(1) + "円</td><td>" + yen(base) + "</td><td>" + yen(base * 12) + "</td></tr>" +
        "<tr><td>円高に振れた場合</td><td>" + (rate * (1 - swing)).toFixed(1) + "円</td><td>" + yen(low) + "</td><td>" + yen(low * 12) + "</td></tr>" +
        "</tbody></table>" +
        '<p class="note">年間で最大 <strong>' + yen((high - low) * 12) + "</strong> の差が出ます。" +
        "ドル建ての固定費は、この幅を見込んで予算を確保してください。レートは手入力です（自動取得はしていません）。</p>";
      save();
    }

    ["uj-usd", "uj-rate", "uj-swing"].forEach(function (id) {
      root.querySelector("#" + id).addEventListener("input", calc);
    });
    calc();
  });
})();
