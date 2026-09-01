/* 文字数カウント */
(function () {
  const T = window.AdsiteTools;

  function count(text) {
    const chars = Array.from(text);
    const noSpace = chars.filter(function (c) { return !/\s/.test(c); });
    const words = (text.match(/[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*/g) || []).length;
    const cjk = chars.filter(function (c) {
      const code = c.codePointAt(0);
      return (code >= 0x3040 && code <= 0x30ff) || (code >= 0x4e00 && code <= 0x9fff);
    }).length;
    const lines = text === "" ? 0 : text.split(/\r\n|\r|\n/).length;
    const paragraphs = text.split(/(?:\r?\n\s*){2,}/).filter(function (p) { return p.trim(); }).length;
    return {
      chars: chars.length,
      noSpace: noSpace.length,
      words: words + cjk, // 日本語は1文字を1語として数える
      lines: lines,
      paragraphs: paragraphs,
      manuscript: Math.ceil(noSpace.length / 400), // 原稿用紙(400字)換算
    };
  }

  T.mount("text-count", function (root) {
    root.innerHTML =
      '<div class="field"><label for="tc-text">テキストを貼り付け</label>' +
      '<textarea id="tc-text" rows="10" placeholder="ここにテキストを貼り付けてください"></textarea>' +
      "<small>入力内容は送信されません。ブラウザ内でのみ計算しています。</small></div>" +
      '<div class="tool-result" id="tc-result" aria-live="polite"></div>';

    const area = root.querySelector("#tc-text");
    const result = root.querySelector("#tc-result");

    function render() {
      const c = count(area.value);
      const n = function (v) { return v.toLocaleString("ja-JP"); };
      result.innerHTML =
        '<div class="stat-row">' +
        '<div class="stat"><span class="stat-label">文字数(空白込み)</span><span class="stat-value">' + n(c.chars) + "</span></div>" +
        '<div class="stat"><span class="stat-label">文字数(空白除く)</span><span class="stat-value">' + n(c.noSpace) + "</span></div>" +
        '<div class="stat"><span class="stat-label">単語数</span><span class="stat-value">' + n(c.words) + "</span></div>" +
        "</div>" +
        '<table class="result-table"><tbody>' +
        "<tr><td>行数</td><td>" + n(c.lines) + "</td></tr>" +
        "<tr><td>段落数</td><td>" + n(c.paragraphs) + "</td></tr>" +
        "<tr><td>原稿用紙(400字)換算</td><td>" + n(c.manuscript) + "枚</td></tr>" +
        "</tbody></table>" +
        '<p class="note">単語数は、英数字の連なりと日本語1文字をそれぞれ1語として数えています。' +
        "文字数の数え方は提出先によって定義が異なるため、規定がある場合はそちらを優先してください。</p>";
    }

    area.addEventListener("input", render);
    render();
  });
})();
