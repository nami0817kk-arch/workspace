// 計算機の結果に出す図。src/charts.py（ページに埋め込む図）と同じ見た目・同じ class で作る。
// 片方の見た目を変えたら、もう片方もそろえる。
(function (root) {
  "use strict";

  function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }
  function yen(n) { return n.toLocaleString("ja-JP") + "円"; }

  // 月収の行き先の横帯（100%）。parts: [[名前, 金額, 's1'..], ...]
  function breakdownBar(parts, total, caption) {
    var w = 640, h = 44, gap = 2, x = 0, rects = "", legend = "";
    parts.forEach(function (p) {
      var name = p[0], value = p[1], color = p[2];
      if (value <= 0) return;
      var width = w * value / total, pct = value / total * 100;
      rects += '<rect x="' + x.toFixed(1) + '" y="0" width="' + Math.max(width - gap, 1).toFixed(1) + '" height="' + h
        + '" rx="4" class="fill-' + color + '"><title>' + esc(name) + " " + yen(value) + "（" + pct.toFixed(1) + "%）</title></rect>";
      if (width >= 56) {
        rects += '<text x="' + (x + width / 2 - gap / 2).toFixed(1) + '" y="' + (h / 2 + 5) + '" text-anchor="middle" class="in-' + color + '">'
          + Math.round(pct) + "%</text>";
      }
      legend += '<li><span class="sw fill-' + color + '"></span>' + esc(name) + " <strong>" + yen(value) + "</strong></li>";
      x += width;
    });
    return '<figure class="viz"><svg viewBox="0 0 ' + w + " " + h + '" role="img" aria-label="' + esc(caption) + '" class="bar100">'
      + rects + '</svg><ul class="legend">' + legend + "</ul><figcaption>" + esc(caption) + "</figcaption></figure>";
  }

  // 週の時間ごとの手取りの縦棒。rows: [{short, label, net, base, labelValue}]、baseline: 週19時間の手取り
  function wallColumns(rows, baseline, caption) {
    var w = 640, h = 300, left = 50, right = 8, top = 28, bottom = 62;
    var pw = w - left - right, ph = h - top - bottom, step = 20000;
    var max = Math.max.apply(null, rows.map(function (r) { return r.net; }));
    var hi = Math.ceil(max * 1.05 / step) * step, lo = 0;
    var band = pw / rows.length, bw = Math.min(40, band * 0.6);
    function y(v) { return top + ph * (hi - v) / (hi - lo); }
    var out = '<svg viewBox="0 0 ' + w + " " + h + '" role="img" aria-label="' + esc(caption) + '" class="cols">';
    for (var t = lo; t <= hi; t += step) {
      out += '<line x1="' + left + '" x2="' + (w - right) + '" y1="' + y(t).toFixed(1) + '" y2="' + y(t).toFixed(1) + '" class="grid"/>';
      if (t) out += '<text x="' + (left - 6) + '" y="' + (y(t) + 4).toFixed(1) + '" text-anchor="end" class="axis">' + (t / 10000) + "万</text>";
    }
    rows.forEach(function (r, i) {
      var cx = left + band * (i + 0.5);
      var color = r.base ? "base" : (r.net >= baseline ? "s1" : "s2");
      var ty = y(r.net), by = y(lo), l = cx - bw / 2, rr = cx + bw / 2;
      var diff = r.net - baseline;
      out += '<path d="M' + l.toFixed(1) + "," + by.toFixed(1) + " V" + (ty + 4).toFixed(1) + " Q" + l.toFixed(1) + "," + ty.toFixed(1) + " " + (l + 4).toFixed(1) + "," + ty.toFixed(1)
        + " H" + (rr - 4).toFixed(1) + " Q" + rr.toFixed(1) + "," + ty.toFixed(1) + " " + rr.toFixed(1) + "," + (ty + 4).toFixed(1) + " V" + by.toFixed(1) + ' Z" class="fill-' + color + '">'
        + "<title>" + esc(r.label) + ": 手取り " + yen(r.net) + "（週19時間より" + (diff >= 0 ? "+" : "−") + yen(Math.abs(diff)) + "）</title></path>";
      if (r.labelValue) out += '<text x="' + cx.toFixed(1) + '" y="' + (ty - 8).toFixed(1) + '" text-anchor="middle" class="val">' + (r.net / 10000).toFixed(1) + "万</text>";
      out += '<text x="' + cx.toFixed(1) + '" y="' + (h - bottom + 22) + '" text-anchor="middle" class="axis">' + esc(r.short) + "</text>";
    });
    out += '<line x1="' + left + '" x2="' + (w - right) + '" y1="' + y(baseline).toFixed(1) + '" y2="' + y(baseline).toFixed(1) + '" class="ref"/>';
    out += '<text x="' + (w / 2) + '" y="' + (h - 4) + '" text-anchor="middle" class="axis">週の労働時間（時間）</text></svg>';
    var legend = '<ul class="legend"><li><span class="sw fill-base"></span>週19時間（加入なし）</li>'
      + '<li><span class="sw fill-s2"></span>週19時間より少ない</li><li><span class="sw fill-s1"></span>週19時間以上に戻った</li>'
      + '<li><span class="sw-line"></span>週19時間の手取り（' + yen(baseline) + "）</li></ul>";
    return '<figure class="viz">' + out + legend + "<figcaption>" + esc(caption) + "</figcaption></figure>";
  }

  root.ShahoCharts = { breakdownBar: breakdownBar, wallColumns: wallColumns };
})(this);
