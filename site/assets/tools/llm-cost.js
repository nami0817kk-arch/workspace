/* LLM API料金 計算ツール */
(function () {
  const T = window.AdsiteTools;

  T.mount("llm-cost", function (root) {
    root.innerHTML =
      '<div class="tool-grid">' +
      T.field("lc-in", "入力トークン / リクエスト", 4000, "システムプロンプト・履歴・参照文書をすべて含めた値") +
      T.field("lc-out", "出力トークン / リクエスト", 800, "モデルが生成する分。推論トークンもここに含まれる") +
      T.field("lc-req", "リクエスト数 / 月", 10000, "ユーザー数ではなく処理件数") +
      T.field("lc-cache", "入力のうちキャッシュ再利用の割合 (%)", 0, "同じ前置きを繰り返す場合のみ。不明なら0", { max: 100, step: 1 }) +
      "</div>" +
      '<div class="tool-result" id="lc-result" aria-live="polite"></div>';

    const ids = ["lc-in", "lc-out", "lc-req", "lc-cache"];
    const save = T.persist(root, "llm-cost");
    const result = root.querySelector("#lc-result");

    T.loadPrices().then(function (prices) {
      const models = Object.keys(prices);
      if (!models.length) {
        result.innerHTML = '<p class="error">料金表を読み込めませんでした。時間をおいて再読み込みしてください。</p>';
        return;
      }

      function calc() {
        const inTok = T.num(root.querySelector("#lc-in"), 0);
        const outTok = T.num(root.querySelector("#lc-out"), 0);
        const reqs = T.num(root.querySelector("#lc-req"), 0);
        const cacheRatio = Math.min(T.num(root.querySelector("#lc-cache"), 0), 100) / 100;

        const rows = models
          .map(function (model) {
            const p = prices[model];
            /* キャッシュ読み出しは入力単価の10%として概算する */
            const effectiveIn = inTok * (1 - cacheRatio) + inTok * cacheRatio * 0.1;
            const perReq = (effectiveIn * p.input + outTok * p.output) / 1e6;
            return { model: model, perReq: perReq, monthly: perReq * reqs };
          })
          .sort(function (a, b) {
            return a.monthly - b.monthly;
          });

        const cheapest = rows[0];
        result.innerHTML =
          '<table class="result-table"><thead><tr>' +
          "<th>モデル</th><th>1リクエスト</th><th>月額</th><th>年額</th><th>最安比</th>" +
          "</tr></thead><tbody>" +
          rows
            .map(function (r) {
              const ratio = cheapest.monthly > 0 ? (r.monthly / cheapest.monthly).toFixed(1) + "倍" : "—";
              return (
                "<tr><td>" + r.model + "</td>" +
                "<td>" + T.usd(r.perReq) + "</td>" +
                "<td><strong>" + T.usd(r.monthly) + "</strong><br><small>" + T.jpy(r.monthly) + "</small></td>" +
                "<td>" + T.usd(r.monthly * 12) + "</td>" +
                "<td>" + ratio + "</td></tr>"
              );
            })
            .join("") +
          "</tbody></table>" +
          '<p class="note">キャッシュ読み出しは入力単価の10%として概算しています。リトライ・エラー分は含みません。' +
          "予算を組む際は1.5倍程度の安全率を見込んでください。</p>";
        save();
      }

      ids.forEach(function (id) {
        root.querySelector("#" + id).addEventListener("input", calc);
      });
      calc();
    });
  });
})();
