/* トークン数 見積もりツール */
(function () {
  const T = window.AdsiteTools;

  /* 文字種の構成比から推定する概算。正確な値はトークナイザに依存する。 */
  function estimateTokens(text) {
    let cjk = 0;
    let latin = 0;
    let other = 0;
    for (const ch of text) {
      const code = ch.codePointAt(0);
      if ((code >= 0x3040 && code <= 0x30ff) || (code >= 0x4e00 && code <= 0x9fff) || (code >= 0xff00 && code <= 0xffef)) {
        cjk++;
      } else if (/[A-Za-z0-9]/.test(ch)) {
        latin++;
      } else if (!/\s/.test(ch)) {
        other++;
      }
    }
    /* 日本語は概ね1文字1トークン、英数は4文字1トークン、記号類は2文字1トークン */
    return Math.ceil(cjk * 1.0 + latin / 4 + other / 2);
  }

  T.mount("token-estimate", function (root) {
    root.innerHTML =
      '<div class="field"><label for="te-text">テキストを貼り付け</label>' +
      '<textarea id="te-text" rows="8" placeholder="ここに実際に送るテキストを貼り付けてください"></textarea>' +
      "<small>入力内容は送信されません。ブラウザ内でのみ計算しています。</small></div>" +
      '<div class="tool-result" id="te-result" aria-live="polite"></div>';

    const area = root.querySelector("#te-text");
    const result = root.querySelector("#te-result");

    T.loadPrices().then(function (prices) {
      const models = Object.keys(prices);

      function calc() {
        const text = area.value;
        const tokens = estimateTokens(text);
        const chars = Array.from(text).length;

        if (!tokens) {
          result.innerHTML = '<p class="note">テキストを入力すると、推定トークン数と費用が表示されます。</p>';
          return;
        }

        const rows = models
          .map(function (m) {
            return { model: m, cost: (tokens * prices[m].input) / 1e6 };
          })
          .sort(function (a, b) {
            return a.cost - b.cost;
          });

        result.innerHTML =
          '<div class="stat-row">' +
          '<div class="stat"><span class="stat-label">文字数</span><span class="stat-value">' + chars.toLocaleString("ja-JP") + "</span></div>" +
          '<div class="stat"><span class="stat-label">推定トークン数</span><span class="stat-value">' + tokens.toLocaleString("ja-JP") + "</span></div>" +
          '<div class="stat"><span class="stat-label">1トークンあたり</span><span class="stat-value">' + (chars / tokens).toFixed(2) + "文字</span></div>" +
          "</div>" +
          (models.length
            ? '<table class="result-table"><thead><tr><th>モデル</th><th>入力1回あたりの費用</th></tr></thead><tbody>' +
              rows
                .map(function (r) {
                  return "<tr><td>" + r.model + "</td><td>" + T.usd(r.cost) + "</td></tr>";
                })
                .join("") +
              "</tbody></table>"
            : "") +
          '<p class="note">文字種の構成比からの概算です。実際の値はモデルごとのトークナイザで決まり、数%〜十数%の誤差が出ます。' +
          "安全側に見るなら1.2倍して見積もってください。</p>";
      }

      area.addEventListener("input", calc);
      calc();
    });
  });
})();
