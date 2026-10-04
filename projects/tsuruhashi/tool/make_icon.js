// アプリのアイコン（1024×1024・透明なし）を描く。Gemini の絵が届くまでの仮のアイコン。
//   node tool/make_icon.js   → app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }
const path = require('path');
const OUT = path.join(__dirname, '..', 'app', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'Icon-1024.png');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="62%" cy="66%" r="85%"><stop offset="0" stop-color="#8a4fd0"/><stop offset=".28" stop-color="#4a2a6e"/><stop offset=".6" stop-color="#2a1a2e"/><stop offset="1" stop-color="#140c10"/></radialGradient>
    <linearGradient id="head" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#dfe6ee"/><stop offset="1" stop-color="#8f9aa8"/></linearGradient>
    <linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8a5326"/><stop offset=".5" stop-color="#d08a45"/><stop offset="1" stop-color="#7a4520"/></linearGradient>
    <linearGradient id="gem" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f3e6ff"/><stop offset=".4" stop-color="#b88cff"/><stop offset="1" stop-color="#5b2fb0"/></linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff4c8" stop-opacity="1"/><stop offset=".35" stop-color="#ffd27a" stop-opacity=".7"/><stop offset="1" stop-color="#ffb347" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <!-- 光の筋（掘り当てた瞬間） -->
  <g transform="translate(650 690)" fill="#ffe7a8" opacity=".22">
    ${Array.from({ length: 14 }, (_, i) => `<path d="M0 0 L${Math.cos(i / 14 * 6.283 - 0.11) * 900} ${Math.sin(i / 14 * 6.283 - 0.11) * 900} L${Math.cos(i / 14 * 6.283 + 0.11) * 900} ${Math.sin(i / 14 * 6.283 + 0.11) * 900}Z"/>`).join('')}
  </g>
  <!-- 地層（下の岩） -->
  <path d="M0 830 Q220 790 470 812 T1024 790 V1024 H0Z" fill="#5a3a24" stroke="#2a180c" stroke-width="10"/>
  <path d="M0 910 Q300 880 620 904 T1024 890 V1024 H0Z" fill="#3e2718"/>
  <circle cx="650" cy="690" r="260" fill="url(#glow)"/>
  <!-- 紫の結晶の群れ -->
  <g stroke="#2a1440" stroke-width="12" stroke-linejoin="round">
    <path d="M560 820 L580 640 L640 590 L670 650 L650 820Z" fill="url(#gem)"/>
    <path d="M640 820 L680 560 L740 500 L780 570 L750 820Z" fill="url(#gem)"/>
    <path d="M740 822 L790 680 L840 650 L860 700 L830 822Z" fill="url(#gem)"/>
  </g>
  <path d="M700 580 L728 540" stroke="#ffffff" stroke-width="16" stroke-linecap="round" opacity=".9"/>
  <path d="M598 660 L612 630" stroke="#ffffff" stroke-width="12" stroke-linecap="round" opacity=".8"/>
  <!-- 飛び散る金の粒 -->
  <g fill="#ffd34d" stroke="#8a5a00" stroke-width="8">
    <path d="M470 560 l34 -12 22 26 -14 32 -36 2 -14 -28Z"/>
    <path d="M880 520 l26 -6 14 22 -12 22 -26 -2 -8 -22Z"/>
    <path d="M520 470 l18 -6 12 14 -8 18 -20 0 -8 -14Z"/>
  </g>
  <!-- つるはし（大きく斜めに、刃先が結晶へ） -->
  <g transform="rotate(-32 470 450)">
    <rect x="440" y="250" width="66" height="600" rx="24" fill="url(#wood)" stroke="#20140a" stroke-width="16"/>
    <path d="M90 350 Q473 70 856 350 L826 410 Q473 190 120 410Z" fill="url(#head)" stroke="#20160e" stroke-width="20" stroke-linejoin="round"/>
    <rect x="418" y="258" width="110" height="100" rx="16" fill="#5b6470" stroke="#20160e" stroke-width="16"/>
    <path d="M180 330 Q473 150 760 320" stroke="#ffffff" stroke-width="14" fill="none" stroke-linecap="round" opacity=".75"/>
  </g>
  <!-- きらめき -->
  <path d="M250 190 l18 52 52 18 -52 18 -18 52 -18 -52 -52 -18 52 -18Z" fill="#fff6d8"/>
  <path d="M900 380 l11 32 32 11 -32 11 -11 32 -11 -32 -32 -11 32 -11Z" fill="#fff6d8" opacity=".9"/>
</svg>`;
(async () => {
  const b = await pw.chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  await p.setContent(`<html><body style="margin:0">${svg}</body></html>`);
  await p.screenshot({ path: OUT, omitBackground: false, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await b.close();
  console.log('icon →', OUT);
})();
