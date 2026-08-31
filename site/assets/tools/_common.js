/* ツール共通のヘルパー。ビルド時に生成される料金表を読み、入力の永続化と整形を担う。 */
window.AdsiteTools = (function () {
  const JPY_PER_USD = 150; // 表示用の概算レート。厳密な換算が要る用途では使わない。
  let pricesPromise = null;

  function loadPrices() {
    if (!pricesPromise) {
      pricesPromise = fetch("/assets/data/model-prices.json")
        .then((r) => (r.ok ? r.json() : Promise.reject(new Error(r.status))))
        .catch(() => ({}));
    }
    return pricesPromise;
  }

  function usd(value) {
    if (value >= 1000) return "$" + value.toLocaleString("en-US", { maximumFractionDigits: 0 });
    if (value >= 1) return "$" + value.toFixed(2);
    return "$" + value.toFixed(4);
  }

  function jpy(value) {
    return "約" + Math.round(value * JPY_PER_USD).toLocaleString("ja-JP") + "円";
  }

  function num(el, fallback) {
    const v = parseFloat(String(el.value).replace(/,/g, ""));
    return Number.isFinite(v) && v >= 0 ? v : fallback;
  }

  /* 入力欄を組み立てる。ラベルとhelpを必ず伴わせ、単位を明示する。 */
  function field(id, label, value, help, attrs) {
    const a = attrs || {};
    return (
      '<div class="field"><label for="' + id + '">' + label + "</label>" +
      '<input id="' + id + '" type="number" inputmode="decimal" value="' + value + '"' +
      ' min="' + (a.min !== undefined ? a.min : 0) + '"' +
      (a.max !== undefined ? ' max="' + a.max + '"' : "") +
      (a.step !== undefined ? ' step="' + a.step + '"' : "") +
      ">" +
      (help ? '<small>' + help + "</small>" : "") +
      "</div>"
    );
  }

  /* 入力値をブラウザ内に保持する。サーバーには送らない。 */
  function persist(root, key) {
    const storageKey = "adsite:" + key;
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey) || "{}");
      Object.keys(saved).forEach(function (id) {
        const el = root.querySelector("#" + CSS.escape(id));
        if (el) el.value = saved[id];
      });
    } catch (e) {
      /* プライベートモード等では保存を諦めて続行する */
    }
    return function save() {
      try {
        const data = {};
        root.querySelectorAll("input,select,textarea").forEach(function (el) {
          if (el.id) data[el.id] = el.value;
        });
        localStorage.setItem(storageKey, JSON.stringify(data));
      } catch (e) {
        /* 保存できなくても計算は続く */
      }
    };
  }

  function mount(name, render) {
    const root = document.querySelector('[data-tool="' + name + '"]');
    if (root) render(root);
  }

  return { loadPrices: loadPrices, usd: usd, jpy: jpy, num: num, field: field, persist: persist, mount: mount, JPY_PER_USD: JPY_PER_USD };
})();
