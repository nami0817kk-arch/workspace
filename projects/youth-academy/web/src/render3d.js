// 見せ方（本物の3D）：three.js で、ピッチ・スタンド・選手を立体で描く。
// 選手とボールの動き（update）は render.js の Renderer をそのまま使い、絵（draw）だけを差し替える。
// WebGL が使えない端末と画面の点検（jsdom）では、render.js の2Dに戻る（YA.makeRenderer）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const W = 68;
  const L = 105;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  YA.webglOK = function () {
    try {
      const c = document.createElement('canvas');
      const g = c.getContext('webgl2') || c.getContext('webgl');
      return !!(g && typeof g.getParameter === 'function' && g.getParameter(g.VERSION));
    } catch (e) {
      return false;
    }
  };
  YA.makeRenderer = function (cv) {
    if (globalThis.THREE && YA.Renderer3D && !YA.force2D && YA.webglOK()) {
      try {
        return new YA.Renderer3D(cv);
      } catch (e) {
        if (globalThis.console) console.warn('3Dの準備に失敗。2Dで描きます', e);
      }
    }
    return new YA.Renderer(cv);
  };
  if (!globalThis.THREE || !YA.Renderer) return;
  const T = globalThis.THREE;
  // 色を sRGB として正しく扱う（そのままだとユニフォームの色がくすむ）
  if (T.ColorManagement) T.ColorManagement.legacyMode = false;

  // 絵の素（キャンバスに描いて貼る）
  const canvasTex = (w, h, draw) => {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    draw(c.getContext('2d'), w, h);
    const t = new T.CanvasTexture(c);
    t.encoding = T.sRGBEncoding;
    return t;
  };
  const rnd = (seed) => () => (seed = (seed * 16807) % 2147483647) / 2147483647;

  // ピッチ（タッチラインの外 7m・ゴールラインの外 6m まで1枚に描く）
  const PX = 7, PY = 6;
  function pitchTexture() {
    const TW = 1024, TH = 1536;
    return canvasTex(TW, TH, (x) => {
      const sx = (v) => ((v + PX) / (W + PX * 2)) * TW;
      const sy = (v) => (1 - (v + PY) / (L + PY * 2)) * TH;
      const m = TW / (W + PX * 2); // 1m の画素
      x.fillStyle = '#3a8534';
      x.fillRect(0, 0, TW, TH);
      // 刈り目：ゴールラインと平行の帯
      const bands = 18;
      for (let i = 0; i < bands; i++) {
        const y0 = (L / bands) * i, y1 = (L / bands) * (i + 1);
        x.fillStyle = i % 2 ? '#3f923a' : '#4aa043';
        x.fillRect(0, sy(y1), TW, sy(y0) - sy(y1));
      }
      // 芝の目
      const r = rnd(7);
      for (let i = 0; i < 26000; i++) {
        x.fillStyle = r() > 0.5 ? 'rgba(255,255,255,0.05)' : 'rgba(0,30,0,0.07)';
        x.fillRect(r() * TW, r() * TH, 1, 2 + r() * 7);
      }
      // 線
      x.strokeStyle = 'rgba(255,255,255,0.92)';
      x.lineWidth = 0.12 * m;
      const line = (pts, close) => {
        x.beginPath();
        pts.forEach((p, i) => (i ? x.lineTo(sx(p[0]), sy(p[1])) : x.moveTo(sx(p[0]), sy(p[1]))));
        if (close) x.closePath();
        x.stroke();
      };
      const arc = (cx, cy, rr, a0, a1) => {
        x.beginPath();
        x.arc(sx(cx), sy(cy), rr * m, -a1, -a0);
        x.stroke();
      };
      const dot = (cx, cy, rr) => {
        x.fillStyle = 'rgba(255,255,255,0.92)';
        x.beginPath();
        x.arc(sx(cx), sy(cy), rr * m, 0, Math.PI * 2);
        x.fill();
      };
      line([[0, 0], [W, 0], [W, L], [0, L]], true);
      line([[0, L / 2], [W, L / 2]]);
      arc(34, L / 2, 9.15, 0, Math.PI * 2);
      dot(34, L / 2, 0.25);
      const a = Math.acos(5.5 / 9.15);
      for (const sgn of [0, 1]) {
        const y = (v) => (sgn ? L - v : v);
        line([[13.84, y(0)], [13.84, y(16.5)], [54.16, y(16.5)], [54.16, y(0)]]);
        line([[24.84, y(0)], [24.84, y(5.5)], [43.16, y(5.5)], [43.16, y(0)]]);
        dot(34, y(11), 0.2);
        if (sgn) arc(34, y(11), 9.15, -Math.PI / 2 - a, -Math.PI / 2 + a);
        else arc(34, y(11), 9.15, Math.PI / 2 - a, Math.PI / 2 + a);
      }
      for (const [cx, cy, a0] of [[0, 0, 0], [W, 0, Math.PI / 2], [W, L, Math.PI], [0, L, -Math.PI / 2]]) arc(cx, cy, 1, a0, a0 + Math.PI / 2);
    });
  }
  function crowdTexture(cols) {
    const t = canvasTex(256, 256, (x, w, h) => {
      const r = rnd(11);
      x.fillStyle = '#1b2030';
      x.fillRect(0, 0, w, h);
      for (let yy = 0; yy < h; yy += 8) {
        x.fillStyle = 'rgba(255,255,255,0.05)';
        x.fillRect(0, yy + 7, w, 1);
        for (let xx = 0; xx < w; xx += 4) {
          if (r() < 0.16) continue;
          x.fillStyle = cols[Math.floor(r() * cols.length)];
          x.fillRect(xx + r(), yy + 1 + r(), 3, 3);
          x.fillStyle = 'rgba(240,200,170,0.9)';
          x.fillRect(xx + 0.5 + r(), yy, 2, 1.5);
        }
      }
    });
    t.wrapS = T.RepeatWrapping;
    t.wrapT = T.RepeatWrapping;
    return t;
  }
  function netTexture() {
    const t = canvasTex(64, 64, (x, w, h) => {
      x.clearRect(0, 0, w, h);
      x.strokeStyle = 'rgba(255,255,255,0.75)';
      x.lineWidth = 2;
      x.strokeRect(0, 0, w, h);
    });
    t.wrapS = T.RepeatWrapping;
    t.wrapT = T.RepeatWrapping;
    return t;
  }
  function ballTexture() {
    return canvasTex(128, 64, (x, w, h) => {
      x.fillStyle = '#f4f4f4';
      x.fillRect(0, 0, w, h);
      x.fillStyle = '#222';
      for (const [cx, cy] of [[16, 16], [48, 40], [80, 16], [112, 40], [16, 56], [80, 56], [48, 8], [112, 8]]) {
        x.beginPath();
        for (let k = 0; k < 5; k++) {
          const an = (k / 5) * Math.PI * 2;
          k ? x.lineTo(cx + Math.cos(an) * 8, cy + Math.sin(an) * 8) : x.moveTo(cx + Math.cos(an) * 8, cy + Math.sin(an) * 8);
        }
        x.fill();
      }
    });
  }
  function numberTexture(num, ink) {
    return canvasTex(64, 64, (x, w, h) => {
      x.clearRect(0, 0, w, h);
      x.fillStyle = ink;
      x.font = '900 40px system-ui, sans-serif';
      x.textAlign = 'center';
      x.textBaseline = 'middle';
      x.fillText(String(num), w / 2, h / 2 + 2);
    });
  }

  const mat = {};
  const lam = (hex) => mat[hex] || (mat[hex] = new T.MeshLambertMaterial({ color: new T.Color(hex) }));
  // 立てた円柱（three は Y が上。この世界は Z が上なので倒して使う）
  const cylZ = (r0, r1, len, m) => {
    const g = new T.CylinderGeometry(r0, r1, len, 10);
    g.rotateX(Math.PI / 2);
    const o = new T.Mesh(g, m);
    o.castShadow = true;
    return o;
  };

  // 選手の人形：胴・パンツ・頭と髪・腕と脚（肩と股で振る）。1.0 = 実寸
  const BODY = 1.22;
  // カメラ：後ろへ back m・高さ up m から、ボールの ahead m 先を見る
  YA.CAM3D = { back: 30, up: 22, ahead: 9 };
  YA.CAM3D_NEAR = { back: 17, up: 9.5, ahead: 8 };
  YA.CAM3D_GOAL = { back: 11, up: 5.5, ahead: 0 };
  // 足元の接地の影（ふちがぼけた丸）
  let blobTex = null;
  const blob = () => blobTex || (blobTex = canvasTex(64, 64, (x, w, h) => {
    const g = x.createRadialGradient(w / 2, h / 2, 2, w / 2, h / 2, w / 2);
    g.addColorStop(0, 'rgba(0,0,0,0.55)');
    g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g;
    x.fillRect(0, 0, w, h);
  }));
  // 人の体の素材：少しつやのある布と肌（陰影がなめらかに出る）
  const smat = {};
  const std = (hex, rough) => smat[hex + (rough || '')] || (smat[hex + (rough || '')] = new T.MeshStandardMaterial({ color: new T.Color(hex), roughness: rough || 0.78, metalness: 0 }));
  // 縦（Z）向きのカプセル：腕・脚の丸い棒
  const capZ = (r, len, m, seg) => {
    const g = new T.CapsuleGeometry(r, len, 6, seg || 14);
    g.rotateX(Math.PI / 2);
    const o = new T.Mesh(g, m);
    o.castShadow = true;
    return o;
  };
  // 回転体（胴・パンツ）：[半径, 高さ] の輪郭を Z のまわりに回す。depth で前後の厚みを薄くする
  const lathe = (pts, m, depth) => {
    const g = new T.LatheGeometry(pts.map((p) => new T.Vector2(p[0], p[1])), 24);
    g.rotateX(Math.PI / 2);
    const o = new T.Mesh(g, m);
    o.scale.set(1, depth, 1);
    o.castShadow = true;
    return o;
  };
  // 髪型（名前から決まる）：0 ふつう・1 立てた短髪・2 長め・3 坊主・4 ヘアバンド
  function addHair(body, hairM, style) {
    const cap = (r, th, z, tilt, sx) => {
      const g = new T.SphereGeometry(r, 24, 14, 0, Math.PI * 2, 0, Math.PI * th);
      g.rotateX(Math.PI / 2);
      const m = new T.Mesh(g, hairM);
      m.position.set(0, -0.012, z);
      m.rotation.x = tilt;
      m.scale.set(sx || 0.95, 1.02, 1.05);
      m.castShadow = true;
      body.add(m);
      return m;
    };
    if (style === 3) { cap(0.119, 0.52, 1.672, -0.25); return; }
    cap(0.125, style === 2 ? 0.66 : 0.56, 1.682, -0.4, 0.97);
    if (style === 1) {
      // 立てた短髪：上の小さな房
      for (let i = 0; i < 9; i++) {
        const c = new T.Mesh(new T.ConeGeometry(0.028, 0.07, 8), hairM);
        const an = (i / 9) * Math.PI * 2;
        c.rotation.x = Math.PI / 2;
        c.rotation.y = Math.cos(an) * 0.35;
        c.rotation.z = an;
        c.position.set(Math.cos(an) * 0.055, Math.sin(an) * 0.055 - 0.015, 1.79);
        body.add(c);
      }
    }
    if (style === 2) {
      // 長め：後ろ髪が襟足まで
      const back = new T.Mesh(new T.SphereGeometry(0.11, 18, 12), hairM);
      back.scale.set(1.05, 0.55, 0.9);
      back.position.set(0, -0.075, 1.6);
      back.castShadow = true;
      body.add(back);
    }
    if (style === 4) {
      const band = new T.Mesh(new T.TorusGeometry(0.118, 0.016, 8, 32), std('#f4f4f4'));
      band.scale.set(0.97, 1.02, 1);
      band.position.z = 1.71;
      body.add(band);
    }
  }
  // 選手の人形：回転体の胴（腰が細く胸が厚い）・肩と膝の丸み・先が細くなる手足・首・耳つきの頭。1.0 = 実寸
  function makePlayer(kit, look, gk, num, style) {
    const shirt = std(gk ? kit.gk : kit.shirt);
    const shorts = std(gk ? '#1b1b1b' : kit.shorts);
    const socks = std(gk ? kit.gk : kit.socks);
    const skin = std(look.skin, 0.62);
    const hair = std(look.hair, 0.9);
    const boot = std('#151515', 0.45);
    const glove = gk ? std('#f4f4f4') : skin;
    const root = new T.Group();
    const shadow = new T.Mesh(new T.PlaneGeometry(0.9, 0.9), new T.MeshBasicMaterial({ map: blob(), transparent: true, depthWrite: false }));
    shadow.position.z = 0.02;
    root.add(shadow);
    const body = new T.Group();
    body.scale.setScalar(BODY);
    root.add(body);
    // 胴：腰からわき・胸・肩へ。前後は薄く
    body.add(lathe([[0, 0.93], [0.15, 0.93], [0.152, 0.99], [0.142, 1.07], [0.15, 1.16], [0.172, 1.26], [0.186, 1.35], [0.175, 1.42], [0.13, 1.47], [0.07, 1.5], [0, 1.505]], shirt, 0.64));
    // パンツ：腰まわり
    body.add(lathe([[0, 0.76], [0.14, 0.76], [0.162, 0.83], [0.16, 0.9], [0.152, 0.96], [0, 0.96]], shorts, 0.7));
    // 肩の丸み
    for (const sd of [-1, 1]) {
      const sh = new T.Mesh(new T.SphereGeometry(0.068, 18, 12), shirt);
      sh.position.set(0.19 * sd, 0, 1.39);
      sh.scale.set(1, 0.9, 0.85);
      sh.castShadow = true;
      body.add(sh);
    }
    // 襟の差し色
    const trim = new T.Mesh(new T.TorusGeometry(0.062, 0.014, 8, 28), std(gk ? '#ffffff' : kit.acc));
    trim.scale.set(1, 0.85, 1);
    trim.position.z = 1.5;
    body.add(trim);
    // 背番号（背中 = -y 側）
    const ink = YA.colorDist && YA.colorDist(gk ? kit.gk : kit.shirt, '#ffffff') < 120 ? '#1b2438' : '#ffffff';
    const nm = new T.Mesh(new T.PlaneGeometry(0.24, 0.24), new T.MeshBasicMaterial({ map: numberTexture(num, ink), transparent: true }));
    nm.rotation.x = Math.PI / 2; // 背中（-y）を向く。後ろから見て字が正しく読める
    nm.position.set(0, -0.122, 1.24);
    body.add(nm);
    // 首と頭（あごが少し細い卵形）と耳
    const neck = capZ(0.048, 0.07, skin, 12);
    neck.position.z = 1.54;
    body.add(neck);
    const head = new T.Mesh(new T.SphereGeometry(0.112, 28, 20), skin);
    head.scale.set(0.9, 1, 1.12);
    head.position.z = 1.665;
    head.castShadow = true;
    body.add(head);
    const jaw = new T.Mesh(new T.SphereGeometry(0.075, 18, 12), skin);
    jaw.scale.set(1, 1.05, 0.85);
    jaw.position.set(0, 0.025, 1.6);
    body.add(jaw);
    for (const sd of [-1, 1]) {
      const ear = new T.Mesh(new T.SphereGeometry(0.024, 10, 8), skin);
      ear.scale.set(0.5, 1, 1.3);
      ear.position.set(0.1 * sd, -0.005, 1.66);
      body.add(ear);
    }
    // 顔（前 = +y）：目・眉・鼻・口。遠目にも顔の向きがわかる
    const eyeM = std('#1b1b1b', 0.3);
    for (const sd of [-1, 1]) {
      const eye = new T.Mesh(new T.SphereGeometry(0.0125, 10, 8), eyeM);
      eye.scale.set(1, 0.6, 1.2);
      eye.position.set(0.036 * sd, 0.097, 1.682);
      const brow = new T.Mesh(new T.BoxGeometry(0.036, 0.01, 0.009), hair);
      brow.position.set(0.037 * sd, 0.1, 1.707);
      brow.rotation.y = -0.12 * sd;
      body.add(eye, brow);
    }
    const nose = new T.Mesh(new T.SphereGeometry(0.016, 10, 8), skin);
    nose.scale.set(0.8, 1, 1.3);
    nose.position.set(0, 0.108, 1.655);
    const mouth = new T.Mesh(new T.BoxGeometry(0.034, 0.006, 0.007), std('#8a4a3a'));
    mouth.position.set(0, 0.096, 1.618);
    body.add(nose, mouth);
    addHair(body, hair, style);
    // 脚：股（hip）→ 膝（knee）。もも・膝の丸み・ふくらはぎ（ソックス）・スパイク
    const legs = [];
    for (const sd of [-1, 1]) {
      const hip = new T.Group();
      hip.position.set(0.088 * sd, 0, 0.82);
      const leg = capZ(0.084, 0.1, shorts);
      leg.position.z = -0.06;
      const thigh = capZ(0.079, 0.23, skin);
      thigh.position.z = -0.22;
      const knee = new T.Group();
      knee.position.z = -0.42;
      const kc = new T.Mesh(new T.SphereGeometry(0.06, 14, 10), skin);
      const calf = capZ(0.063, 0.19, socks);
      calf.position.set(0, -0.008, -0.15);
      calf.scale.set(1, 1.05, 1);
      const ankle = capZ(0.042, 0.08, socks);
      ankle.position.z = -0.3;
      const bg = new T.CapsuleGeometry(0.044, 0.15, 6, 12);
      bg.rotateX(0); // Y（前）向きのまま
      const bt = new T.Mesh(bg, boot);
      bt.scale.set(0.95, 1, 0.75);
      bt.position.set(0, 0.045, -0.385);
      bt.castShadow = true;
      knee.add(kc, calf, ankle, bt);
      hip.add(leg, thigh, knee);
      body.add(hip);
      legs.push({ hip, knee });
    }
    // 腕：肩（sho）→ 肘（elb）。半袖・二の腕・前腕・手
    const arms = [];
    for (const sd of [-1, 1]) {
      const sho = new T.Group();
      sho.position.set(0.2 * sd, 0, 1.385);
      const sleeve = capZ(0.064, 0.09, shirt);
      sleeve.position.z = -0.07;
      const up = capZ(0.054, 0.14, skin);
      up.position.z = -0.17;
      const elb = new T.Group();
      elb.position.z = -0.28;
      const fo = capZ(0.047, 0.17, skin);
      fo.position.z = -0.12;
      const hand = new T.Mesh(new T.SphereGeometry(0.042, 14, 10), glove);
      hand.scale.set(0.75, 0.55, 1.15);
      hand.position.z = -0.27;
      elb.add(fo, hand);
      sho.add(sleeve, up, elb);
      sho.rotation.y = 0.1 * sd;
      body.add(sho);
      arms.push({ sho, elb });
    }
    root.userData = { legs, arms, body, kick: 0, ph: Math.random() * 6, run: 0, yaw: null };
    return root;
  }

  class Renderer3D extends YA.Renderer {
    constructor(cv) {
      super(cv); // cv は名前の札を描く2Dの重ね板として使う
      const gl = document.createElement('canvas');
      gl.className = 'gl3d';
      gl.style.cssText = 'position:absolute;inset:0;width:100%;height:100%';
      if (cv.parentNode) cv.parentNode.insertBefore(gl, cv);
      this.gl = gl;
      this.three = new T.WebGLRenderer({ canvas: gl, antialias: true, powerPreference: 'high-performance' });
      this.three.outputEncoding = T.sRGBEncoding;
      // 映画のような色の出方（明るい所が飛ばず、芝の緑が深くなる）
      this.three.toneMapping = T.ACESFilmicToneMapping;
      this.three.toneMappingExposure = 1.05;
      this.three.shadowMap.enabled = true;
      this.three.shadowMap.type = T.PCFSoftShadowMap;
      this.three.setClearColor(0x1b2030);
      this.camera = new T.PerspectiveCamera(40, 2, 1, 400);
      this.camera.up.set(0, 0, 1);
      this.is3D = true;
      YA._r3 = this; // 点検用
      this.resize();
    }
    resize() {
      super.resize();
      if (!this.three) return;
      this.three.setPixelRatio(Math.min(2, globalThis.devicePixelRatio || 1));
      this.three.setSize(this.w, this.h, false);
      // 2D と同じ写り方：横の画角は 2*atan(0.5/0.92)
      const vf = 2 * Math.atan(this.h / 2 / (this.w * 0.92));
      this.camera.fov = (vf * 180) / Math.PI;
      this.camera.aspect = this.w / this.h;
      this.camera.updateProjectionMatrix();
    }
    setMatch(m) {
      super.setMatch(m);
      this.built = false;
      this.meshes = {};
    }
    dispose() {
      try {
        this.three.dispose();
        this.three.forceContextLoss();
      } catch (e) {
        /* もう無い */
      }
      if (this.gl && this.gl.parentNode) this.gl.parentNode.removeChild(this.gl);
    }

    build() {
      const kits = this.kitsOf();
      const sc = new T.Scene();
      sc.fog = new T.Fog(0x1b2030, 140, 260);
      this.scene3 = sc;
      sc.add(new T.HemisphereLight(0xdfeaff, 0x2c5426, 0.55));
      const sun = new T.DirectionalLight(0xfff1d8, 0.85);
      sun.castShadow = true;
      sun.shadow.mapSize.set(2048, 2048);
      const sc2 = sun.shadow.camera;
      sc2.left = -45; sc2.right = 45; sc2.top = 45; sc2.bottom = -45; sc2.near = 1; sc2.far = 220;
      sun.shadow.bias = -0.0006;
      sun.shadow.normalBias = 0.02;
      sc.add(sun, sun.target);
      this.sun = sun;
      // ピッチ
      const tex = pitchTexture();
      tex.anisotropy = this.three.capabilities.getMaxAnisotropy();
      const pitch = new T.Mesh(new T.PlaneGeometry(W + PX * 2, L + PY * 2), new T.MeshLambertMaterial({ map: tex }));
      pitch.position.set(W / 2, L / 2, 0);
      pitch.receiveShadow = true;
      sc.add(pitch);
      // スタンドのすそ（コンクリート）
      const apron = new T.Mesh(new T.PlaneGeometry(W + 60, L + 60), lam('#2a3040'));
      apron.position.set(W / 2, L / 2, -0.02);
      sc.add(apron);
      // 広告板
      const cols = [kits.home.shirt, '#f4f4f4', '#1d2a4d', '#f2c200'];
      const board = (x, y, len, rotZ, idx) => {
        // LED の広告板：自分で光るので日陰でも暗くならない
        const b = new T.Mesh(new T.BoxGeometry(len, 0.12, 0.9), new T.MeshBasicMaterial({ color: new T.Color(cols[idx % cols.length]) }));
        b.position.set(x, y, 0.45);
        b.rotation.z = rotZ;
        b.castShadow = true;
        sc.add(b);
      };
      for (let i = 0; i < 10; i++) {
        const y = -4 + i * 11.3 + 5.65;
        board(-PX + 0.5, y, 11.2, Math.PI / 2, i);
        board(W + PX - 0.5, y, 11.2, Math.PI / 2, i + 2);
      }
      for (let i = 0; i < 6; i++) board(-4 + i * 12.6 + 6.3, L + PY - 0.5, 12.5, 0, i + 1);
      // スタンド（観客の模様を貼った斜面）
      this.crowdTex = [];
      const crowd = crowdTexture([kits.home.shirt, kits.home.shirt, kits.home.shirt, '#e8e8e8', '#2a2f3d', kits.away.shirt]);
      // 横のスタンドは「斜面の幅 × 長さ（y）」の板を y 軸まわりに、奥のスタンドは「長さ（x）× 斜面の幅」の板を x 軸まわりに傾ける
      const stand = (cx, cy, cz, gw, gh, rx, ry) => {
        const t = crowd.clone();
        t.needsUpdate = true;
        t.repeat.set(gw / 4, gh / 4);
        this.crowdTex.push(t);
        const p = new T.Mesh(new T.PlaneGeometry(gw, gh), new T.MeshLambertMaterial({ map: t }));
        p.position.set(cx, cy, cz);
        p.rotation.set(rx, ry, 0);
        p.receiveShadow = true;
        sc.add(p);
      };
      const slope = Math.atan2(14, 22);
      const span = Math.hypot(14, 22);
      stand(-PX - 2 - 11, L / 2, 7.5, span, L + 40, 0, slope);
      stand(W + PX + 2 + 11, L / 2, 7.5, span, L + 40, 0, -slope);
      stand(W / 2, L + PY + 2 + 11, 7.5, W + 40, span, slope, 0);
      // スタンドの前の壁
      for (const [x, y, lx, ly] of [[-PX - 1.5, L / 2, 0.6, L + 30], [W + PX + 1.5, L / 2, 0.6, L + 30], [W / 2, L + PY + 1.5, W + 30, 0.6]]) {
        const wall = new T.Mesh(new T.BoxGeometry(lx, ly, 1.6), lam('#202636'));
        wall.position.set(x, y, 0.8);
        sc.add(wall);
      }
      // ゴール
      const post = lam('#f7f7f7');
      this.nets = [];
      const netM = new T.MeshLambertMaterial({ map: netTexture(), transparent: true, side: T.DoubleSide, depthWrite: false });
      for (const [yy, dir] of [[0, -1], [L, 1]]) {
        const g = new T.Group();
        for (const xx of [34 - 3.66, 34 + 3.66]) {
          const p = cylZ(0.06, 0.06, 2.44, post);
          p.position.set(xx, yy, 1.22);
          g.add(p);
        }
        const bar = new T.Mesh(new T.CylinderGeometry(0.06, 0.06, 7.32, 10), post);
        bar.rotation.z = Math.PI / 2;
        bar.position.set(34, yy, 2.44);
        bar.castShadow = true;
        g.add(bar);
        const net = (w, h, px, py, pz, kind) => {
          const t = netM.map.clone();
          t.needsUpdate = true;
          t.repeat.set(w / 0.25, h / 0.25);
          const m = netM.clone();
          m.map = t;
          const n = new T.Mesh(new T.PlaneGeometry(w, h), m);
          n.position.set(px, py, pz);
          if (kind === 'back') { n.rotation.x = Math.PI / 2; this.nets.push({ back: n, y0: py, yy, dir, bulge: 0 }); } // x と z に広がる
          if (kind === 'side') { n.rotation.x = Math.PI / 2; n.rotateOnWorldAxis(new T.Vector3(0, 0, 1), Math.PI / 2); } // y と z
          g.add(n);
        };
        net(7.32, 2.2, 34, yy + dir * 2.0, 1.1, 'back');
        net(7.32, 2.0, 34, yy + dir * 1.0, 2.3, 'top');
        net(2.0, 2.44, 34 - 3.66, yy + dir * 1.0, 1.22, 'side');
        net(2.0, 2.44, 34 + 3.66, yy + dir * 1.0, 1.22, 'side');
        sc.add(g);
      }
      // ボール
      const ball = new T.Mesh(new T.SphereGeometry(0.2, 18, 12), new T.MeshLambertMaterial({ map: ballTexture() }));
      ball.castShadow = true;
      sc.add(ball);
      this.ball3 = ball;
      // 場面の主役の輪
      this.rings = [];
      for (let i = 0; i < 6; i++) {
        const r = new T.Mesh(new T.RingGeometry(0.75, 0.92, 36), new T.MeshBasicMaterial({ color: 0x5cff6a, transparent: true, opacity: 0.95, depthWrite: false, toneMapped: false }));
        r.position.z = 0.03;
        r.visible = false;
        sc.add(r);
        this.rings.push(r);
      }
      // パスの軌跡
      const tg = new T.BufferGeometry();
      tg.setAttribute('position', new T.BufferAttribute(new Float32Array(30 * 3), 3));
      this.trail3 = new T.Line(tg, new T.LineBasicMaterial({ color: 0x78ff6e, transparent: true, opacity: 0.85, toneMapped: false }));
      this.trail3.frustumCulled = false;
      sc.add(this.trail3);
      // コーナーフラッグ
      for (const [x, y] of [[0, 0], [W, 0], [0, L], [W, L]]) {
        const pole = cylZ(0.025, 0.025, 1.5, lam('#f4f4f4'));
        pole.position.set(x, y, 0.75);
        sc.add(pole);
        const flag = new T.Mesh(new T.PlaneGeometry(0.45, 0.32), new T.MeshLambertMaterial({ color: new T.Color('#f2c200'), side: T.DoubleSide }));
        flag.rotation.x = Math.PI / 2;
        flag.position.set(x + (x ? -0.23 : 0.23), y, 1.32);
        sc.add(flag);
      }
      // ベンチ（左のタッチラインの外。透明の屋根と座った控え）
      for (const [yc, kit] of [[L / 2 - 9, kits.home], [L / 2 + 9, kits.away]]) {
        const g = new T.Group();
        const base = new T.Mesh(new T.BoxGeometry(1.6, 6, 0.5), lam('#2a3040'));
        base.position.set(0, 0, 0.25);
        const back = new T.Mesh(new T.BoxGeometry(0.15, 6, 1.6), lam('#3a4256'));
        back.position.set(-0.8, 0, 0.8);
        const roof = new T.Mesh(new T.BoxGeometry(1.9, 6.2, 0.06), new T.MeshLambertMaterial({ color: 0xbfd8ff, transparent: true, opacity: 0.35 }));
        roof.position.set(0, 0, 1.75);
        roof.rotation.y = -0.15;
        g.add(base, back, roof);
        for (let i = 0; i < 5; i++) {
          const sub = new T.Mesh(new T.CapsuleGeometry(0.17, 0.35, 3, 8), lam(kit.shirt));
          sub.rotation.x = Math.PI / 2;
          sub.position.set(-0.3, -2.2 + i * 1.1, 0.95);
          const hd = new T.Mesh(new T.SphereGeometry(0.12, 10, 8), lam('#e9b98c'));
          hd.position.set(-0.3, -2.2 + i * 1.1, 1.38);
          g.add(sub, hd);
        }
        g.position.set(-PX + 2.2, yc, 0);
        g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
        sc.add(g);
      }
      // 屋根（スタンドの上にかかるひさし）と照明の塔
      const roofM = lam('#141824');
      for (const [x, y, lx, ly] of [[-PX - 21, L / 2, 16, L + 44], [W + PX + 21, L / 2, 16, L + 44], [W / 2, L + PY + 21, W + 44, 16]]) {
        const r = new T.Mesh(new T.BoxGeometry(lx, ly, 0.5), roofM);
        r.position.set(x, y, 17);
        sc.add(r);
      }
      const lightM = new T.MeshBasicMaterial({ color: 0xfff6d8 });
      for (const [x, y] of [[-PX - 14, -PY - 6], [W + PX + 14, -PY - 6], [-PX - 14, L + PY + 14], [W + PX + 14, L + PY + 14]]) {
        const mast = cylZ(0.35, 0.6, 30, lam('#3a4256'));
        mast.position.set(x, y, 15);
        sc.add(mast);
        const panel = new T.Mesh(new T.BoxGeometry(5, 0.4, 3), lightM);
        panel.position.set(x, y, 31);
        panel.lookAt(W / 2, L / 2, 0);
        sc.add(panel);
      }
      // 主審（黒のユニフォーム・背番号なし）
      const refKit = { shirt: '#161616', shorts: '#161616', socks: '#161616', acc: '#f2c200', gk: '#161616' };
      const ro = makePlayer(refKit, { skin: '#e9b98c', hair: '#1a1410' }, false, '', 3);
      sc.add(ro);
      this.ref3 = { o: ro, pos: [26, 46] };
      this.built = true;
    }

    // 1人ぶんの姿勢：走り（膝・肘）、蹴る、GKの飛びつき、得点の喜び
    pose(o, id, d, dir, sp, opt) {
      const u = o.userData;
      const dt = this._dt || 0.016;
      // 走りの強さはなめらかに変える。脚の振りの拍は、時間 × 速さで積み上げる（速さが変わっても拍が飛ばない）
      u.run += (clamp(sp / 5.5, 0, 1) - u.run) * (1 - Math.exp(-dt * 5));
      const run = u.run;
      u.ph += dt * (6.5 + run * 5.5);
      const ph = u.ph;
      const sw = Math.sin(ph) * 0.72 * run;
      // 向きもなめらかに回す（いきなり振り向かない）
      const yaw = Math.atan2(-dir[0], dir[1]);
      if (u.yaw == null) u.yaw = yaw;
      let dy = yaw - u.yaw;
      while (dy > Math.PI) dy -= Math.PI * 2;
      while (dy < -Math.PI) dy += Math.PI * 2;
      u.yaw += dy * (1 - Math.exp(-dt * 7));
      o.rotation.z = u.yaw;
      if (opt.kick) u.kick = 0.38;
      u.kick = Math.max(0, u.kick - this._dt);
      const kk = u.kick > 0 ? Math.sin(((0.38 - u.kick) / 0.38) * Math.PI) : 0;
      if (opt.dive) { u.dive = 0.9; u.diveSide = opt.dive; }
      u.dive = Math.max(0, (u.dive || 0) - this._dt);
      const dv = u.dive > 0 ? Math.min(1, Math.sin(((0.9 - u.dive) / 0.9) * Math.PI) * 1.6) : 0;
      const cheer = opt.cheer && !dv;
      for (let i = 0; i < 2; i++) {
        // 脚：前に出すほど股を前へ。後ろへ蹴り上げるときに膝が曲がる
        let fwd = i ? -sw : sw;
        let bend = Math.max(0, -Math.sin(ph + (i ? Math.PI : 0))) * 1.1 * run + 0.08;
        if (i === 1 && kk > 0) { fwd = 1.25 * kk - 0.5 * (1 - kk); bend = 0.9 * (1 - kk); }
        if (cheer) { fwd = i ? 0.15 : -0.15; bend = 0.35 + Math.abs(Math.sin((this.clock || 0) * 8)) * 0.4; }
        if (dv) { fwd = 0.2 * dv; bend = 0.5 * dv; }
        u.legs[i].hip.rotation.x = fwd;
        u.legs[i].knee.rotation.x = -bend;
        // 腕は脚と逆に振り、肘を曲げる。喜び・飛びつきでは両手を上へ
        u.arms[i].sho.rotation.x = cheer ? 2.75 + Math.sin((this.clock || 0) * 8 + i) * 0.2 : dv ? 2.8 * dv : -fwd * 0.8;
        u.arms[i].elb.rotation.x = cheer || dv ? 0.15 : 0.25 + run * 0.9;
      }
      const side = u.diveSide || 1;
      u.body.position.x = side * 0.75 * dv;
      u.body.position.z = cheer ? Math.abs(Math.sin((this.clock || 0) * 8)) * 0.28 : Math.abs(Math.cos(ph)) * 0.06 * run + 0.28 * dv;
      u.body.rotation.x = cheer ? 0 : -run * 0.14 + kk * 0.15; // 走るときは前かがみ、蹴るときは少し反る
      u.body.rotation.y = side * 1.35 * dv;
    }

    syncPlayers() {
      const m = this.match;
      const kits = this.kitsOf();
      const seen = new Set();
      const ball = this.ball;
      // ボールが急に速くなった瞬間を「蹴った」とみなす
      const bv = this._lastBall ? Math.hypot(ball[0] - this._lastBall[0], ball[1] - this._lastBall[1]) / Math.max(1e-3, this._dt) : 0;
      let kickBy = null;
      if (this.scene && bv > 9 && (this._lastBv || 0) < 6) {
        let best = 2.2;
        for (const id of Object.keys(this.base)) {
          const d = this.disp[id];
          if (!d || !this._lastBall) continue;
          const dist = Math.hypot(d[0] - this._lastBall[0], d[1] - this._lastBall[1]);
          if (dist < best) { best = dist; kickBy = id; }
        }
      }
      this._bv = bv;
      this._lastBv = bv;
      this._lastBall = ball.slice();
      // 得点：ボールがゴールラインを越えたら、決めた子のチームが喜ぶ
      let cheer = null;
      if (this.scene && this.scene.outcome === 'goal' && (ball[1] > L + 0.05 || ball[1] < -0.05)) {
        const scorer = (this.focus || [])[0];
        cheer = { team: scorer && this.base[scorer] ? this.base[scorer][2] : null, scorer };
      }
      this._cheer = cheer;
      for (const id of Object.keys(this.base)) {
        const b = this.base[id];
        const t = b[2];
        const p = t.players[id];
        const gk = b[3] === 0;
        const key = id + (gk ? 'g' : 'f');
        seen.add(key);
        let o = this.meshes[key];
        if (!o) {
          const look = YA.lookOf ? YA.lookOf(p) : { skin: '#f1c9a5', hair: '#2b2118' };
          o = this.meshes[key] = makePlayer(t === m.home ? kits.home : kits.away, look, gk, p.num, YA.hash ? YA.hash(String(p.name || id) + 'h') % 5 : 0);
          this.scene3.add(o);
        }
        const d = this.disp[id] || b;
        o.position.set(d[0], d[1], 0);
        const dir = this.dirOf({ id, d });
        const sp = (this.speed && this.speed[id]) || 0;
        // GK：速いボールが近くに来たら、ボールの側へ飛びつく
        let dive = 0;
        if (gk && this.scene && bv > 8 && !(o.userData.dive > 0) && Math.hypot(ball[0] - d[0], ball[1] - d[1]) < 5) {
          const rx = ball[0] - d[0], ry = ball[1] - d[1];
          dive = rx * dir[1] - ry * dir[0] >= 0 ? 1 : -1;
        }
        const near = cheer && cheer.team === t && (!cheer.scorer || !this.disp[cheer.scorer] || Math.hypot(d[0] - this.disp[cheer.scorer][0], d[1] - this.disp[cheer.scorer][1]) < 28);
        this.pose(o, id, d, dir, sp, { kick: kickBy === id, dive, cheer: !!near && !gk });
      }
      for (const k of Object.keys(this.meshes)) if (!seen.has(k)) { this.scene3.remove(this.meshes[k]); delete this.meshes[k]; }
      // 主審：ボールの斜め後ろを、少し遅れてついて走る
      if (this.ref3) {
        const r = this.ref3;
        const tx = clamp(ball[0] - 9 * Math.sign(ball[0] - 34 || 1), 4, W - 4);
        const ty = clamp(ball[1] - 7, 3, L - 3);
        const k = 1 - Math.exp(-this._dt * 1.2);
        const nx = r.pos[0] + (tx - r.pos[0]) * k, ny = r.pos[1] + (ty - r.pos[1]) * k;
        const sp = Math.hypot(nx - r.pos[0], ny - r.pos[1]) / Math.max(1e-3, this._dt);
        r.pos = [nx, ny];
        r.o.position.set(nx, ny, 0);
        const dx = ball[0] - nx, dy = ball[1] - ny, n = Math.hypot(dx, dy) || 1;
        const dir = [dx / n, dy / n];
        this.pose(r.o, 'ref', r.pos, dir, sp, {});
      }
    }

    draw() {
      if (!this.match) return;
      if (!this.built) this.build();
      const now = (globalThis.performance && performance.now()) || Date.now();
      this._dt = this._lastT ? clamp((now - this._lastT) / 1000, 0, 0.1) : 0.016;
      this._lastT = now;
      if (this._snapCam) { this._cam = null; this._snapCam = false; } // 場面の切り替え：カメラもその場へ
      this.syncPlayers();
      const cheer = this._cheer;
      const sd = cheer && cheer.scorer && this.disp[cheer.scorer];
      // カメラ：ふだんは中継の高さ、見どころの場面では寄る、得点のあとは決めた子に寄る。ボールに合わせて横にも振る
      const want = sd ? YA.CAM3D_GOAL : this.scene ? YA.CAM3D_NEAR : YA.CAM3D;
      const cc = (this._cam = this._cam || Object.assign({}, YA.CAM3D, { x: 34, y: this.camY }));
      const k = 1 - Math.exp(-this._dt * (sd ? 2.4 : 1.8));
      for (const key of ['back', 'up', 'ahead']) cc[key] += (want[key] - cc[key]) * k;
      cc.x += ((sd ? sd[0] : 34 + (this.ball[0] - 34) * 0.4) - cc.x) * k;
      cc.y += ((sd ? sd[1] : this.camY) - cc.y) * (sd ? k : 1);
      this.camera.position.set(cc.x, cc.y - cc.back, cc.up);
      this.camera.lookAt(cc.x + (sd ? 0 : (cc.x - 34) * 0.3), cc.y + cc.ahead, sd ? 1 : 0);
      if (YA._camOverride) { const co = YA._camOverride; this.camera.position.set(co.pos[0], co.pos[1], co.pos[2]); this.camera.lookAt(co.look[0], co.look[1], co.look[2]); } // 点検用
      // 影は見えている辺りだけ細かく
      this.sun.position.set(cc.x - 40, cc.y + 55, 70);
      this.sun.target.position.set(cc.x, cc.y + 4, 0);
      const b = this.ball;
      this.ball3.position.set(b[0], b[1], Math.max(0, b[2]) + 0.2);
      this.ball3.rotation.x = -b[1] * 1.8;
      this.ball3.rotation.y = b[0] * 1.8;
      // ネット：ボールが入るとふくらみ、ゆっくり戻る
      for (const nt of this.nets || []) {
        const inside = b[0] > 34 - 3.7 && b[0] < 34 + 3.7 && Math.max(0, b[2]) < 2.5 && (b[1] - nt.yy) * nt.dir > 0.2;
        nt.bulge += ((inside ? 0.75 : 0) - nt.bulge) * (1 - Math.exp(-this._dt * (inside ? 14 : 2.5)));
        nt.back.position.y = nt.y0 + nt.dir * nt.bulge;
        nt.back.scale.set(1 + nt.bulge * 0.06, 1, 1 - nt.bulge * 0.08);
      }
      // 観客：得点のあとは跳ねる
      for (const t of this.crowdTex || []) t.offset.y = cheer ? Math.abs(Math.sin((this.clock || 0) * 9)) * 0.05 : 0;
      // 輪：主役は緑、守る側の主役は白
      const fo = (this.focus || []).map((id) => [id, 0x5cff6a]).concat((this.defFocus || []).map((id) => [id, 0xffffff]));
      this.rings.forEach((r, i) => {
        const f = fo[i];
        const d = f && this.disp[f[0]];
        r.visible = !!d && !cheer;
        if (d) { r.position.set(d[0], d[1], 0.03); r.material.color.setHex(f[1]); }
      });
      // 軌跡：ボールの高さに沿う（浮き球・シュートは宙に弧を描く）
      if (this.scene !== this._tr3Scene) { this._tr3Scene = this.scene; this.tr3 = []; }
      const tr = (this.tr3 = this.tr3 || []);
      if (this.scene) {
        const last = tr[tr.length - 1];
        if (!last || Math.hypot(b[0] - last[0], b[1] - last[1]) > 0.35) tr.push([b[0], b[1], Math.max(0.05, b[2] + 0.2)]);
        if (last && Math.hypot(b[0] - last[0], b[1] - last[1]) < 0.04 && tr.length) tr.shift();
        if (tr.length > 30) tr.shift();
      } else tr.length = 0;
      const pos = this.trail3.geometry.attributes.position;
      const n = tr.length;
      const moving = n > 2 && Math.hypot(tr[n - 1][0] - tr[0][0], tr[n - 1][1] - tr[0][1]) > 4;
      for (let i = 0; i < n; i++) pos.setXYZ(i, tr[i][0], tr[i][1], tr[i][2]);
      pos.needsUpdate = true;
      this.trail3.geometry.setDrawRange(0, moving && !cheer ? n : 0);
      this.three.render(this.scene3, this.camera);
      this.drawOverlay();
    }

    // 重ね板：名前の札と得点の光（2D）。札は場面の見出し・特性の札と重ならないようにずらす
    drawOverlay() {
      const ctx = this.ctx;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      ctx.clearRect(0, 0, this.w, this.h);
      if (this.scene) {
        const blocks = [];
        const base = this.cv.getBoundingClientRect();
        const par = this.cv.parentNode;
        if (par) for (const el of par.querySelectorAll('.scene-title, .tagrow .tag, .ctl > *, .banner')) {
          const r = el.getBoundingClientRect();
          if (r.width > 0 && r.height > 0) blocks.push([r.left - base.left - 3, r.top - base.top - 3, r.right - base.left + 3, r.bottom - base.top + 3]);
        }
        const hit = (x, y, w, h) => blocks.some((b) => x < b[2] && x + w > b[0] && y < b[3] && y + h > b[1]);
        const v = new T.Vector3();
        for (const id of this.focus || []) {
          const d = this.disp[id];
          const b = this.base[id];
          if (!d || !b) continue;
          const p = b[2].players[id];
          v.set(d[0], d[1], 2.35).project(this.camera);
          const x0 = ((v.x + 1) / 2) * this.w;
          const y0 = ((1 - v.y) / 2) * this.h;
          const label = p.num + ' ' + p.name.split(' ')[0];
          ctx.font = '800 11px system-ui, sans-serif';
          const tw = ctx.measureText(label).width + 10;
          let x = clamp(x0 - tw / 2, 2, this.w - tw - 2);
          let y = clamp(y0 - 18, 2, this.h - 18);
          // 重なるなら、頭の右・左・下の順に逃がす
          if (hit(x, y, tw, 16)) {
            const tries = [[x0 + 14, y0 - 8], [x0 - tw - 14, y0 - 8], [x - 0, y0 + 26]];
            for (const [tx, ty] of tries) {
              const xx = clamp(tx, 2, this.w - tw - 2), yy = clamp(ty, 2, this.h - 18);
              if (!hit(xx, yy, tw, 16)) { x = xx; y = yy; break; }
            }
          }
          blocks.push([x, y, x + tw, y + 16]);
          ctx.fillStyle = 'rgba(15,25,40,.82)';
          this.rr(ctx, x, y, tw, 16, 5);
          ctx.fill();
          ctx.fillStyle = '#ffffff';
          ctx.textAlign = 'left';
          ctx.fillText(label, x + 5, y + 12);
        }
      }
      if (this.flash > 0) {
        ctx.fillStyle = 'rgba(255,255,255,' + 0.25 * Math.sin(this.flash * 3) + ')';
        ctx.fillRect(0, 0, this.w, this.h);
      }
      if (this.cut > 0) {
        ctx.fillStyle = 'rgba(8,12,20,' + clamp(this.cut / 0.3, 0, 1) + ')';
        ctx.fillRect(0, 0, this.w, this.h);
      }
    }
  }
  YA.Renderer3D = Renderer3D;
})();
