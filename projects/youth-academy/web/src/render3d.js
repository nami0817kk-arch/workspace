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
  // 足元の接地の影（ふちがぼけた丸）
  let blobTex = null;
  const blob = () => blobTex || (blobTex = canvasTex(64, 64, (x, w, h) => {
    const g = x.createRadialGradient(w / 2, h / 2, 2, w / 2, h / 2, w / 2);
    g.addColorStop(0, 'rgba(0,0,0,0.55)');
    g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g;
    x.fillRect(0, 0, w, h);
  }));
  // 髪型（名前から決まる）：0 ふつう・1 立てた短髪・2 長め・3 坊主・4 ヘアバンド
  function addHair(body, hairM, skinM, style) {
    const cap = (r, th, z, tilt) => {
      const g = new T.SphereGeometry(r, 16, 8, 0, Math.PI * 2, 0, Math.PI * th);
      g.rotateX(Math.PI / 2);
      const m = new T.Mesh(g, hairM);
      m.position.set(0, -0.012, z);
      m.rotation.x = tilt;
      m.castShadow = true;
      body.add(m);
      return m;
    };
    if (style === 3) { cap(0.128, 0.5, 1.625, -0.25); return; }
    cap(0.134, style === 2 ? 0.62 : 0.55, 1.635, -0.35);
    if (style === 1) {
      for (let i = 0; i < 7; i++) {
        const c = new T.Mesh(new T.ConeGeometry(0.035, 0.09, 5), hairM);
        c.rotation.x = Math.PI / 2 - 0.5 + (i % 3) * 0.2;
        const an = (i / 7) * Math.PI * 2;
        c.position.set(Math.cos(an) * 0.07, Math.sin(an) * 0.07 - 0.02, 1.75);
        body.add(c);
      }
    }
    if (style === 2) {
      const back = new T.Mesh(new T.BoxGeometry(0.24, 0.07, 0.2), hairM);
      back.position.set(0, -0.1, 1.55);
      back.castShadow = true;
      body.add(back);
    }
    if (style === 4) {
      const band = new T.Mesh(new T.TorusGeometry(0.128, 0.018, 6, 20), lam('#f4f4f4'));
      band.position.z = 1.67;
      body.add(band);
    }
  }
  // 選手の人形：胴・首・パンツ・頭と髪・腕（肩と肘）・脚（股と膝）。1.0 = 実寸
  function makePlayer(kit, look, gk, num, style) {
    const shirt = lam(gk ? kit.gk : kit.shirt);
    const shorts = lam(gk ? '#1b1b1b' : kit.shorts);
    const socks = lam(gk ? kit.gk : kit.socks);
    const skin = lam(look.skin);
    const hair = lam(look.hair);
    const boot = lam('#151515');
    const glove = lam(gk ? '#f4f4f4' : look.skin);
    const root = new T.Group();
    const shadow = new T.Mesh(new T.PlaneGeometry(0.9, 0.9), new T.MeshBasicMaterial({ map: blob(), transparent: true, depthWrite: false }));
    shadow.position.z = 0.02;
    root.add(shadow);
    const body = new T.Group();
    body.scale.setScalar(BODY);
    root.add(body);
    // 胴（胸を厚く、腰を細く）
    const tg = new T.CapsuleGeometry(0.19, 0.3, 4, 12);
    tg.rotateX(Math.PI / 2);
    const torso = new T.Mesh(tg, shirt);
    torso.scale.set(1.15, 0.7, 1);
    torso.position.z = 1.17;
    torso.castShadow = true;
    body.add(torso);
    const chest = new T.Mesh(new T.SphereGeometry(0.2, 12, 8), shirt);
    chest.scale.set(1.25, 0.72, 0.55);
    chest.position.z = 1.36;
    chest.castShadow = true;
    body.add(chest);
    // 襟と肩の差し色
    const trim = new T.Mesh(new T.TorusGeometry(0.075, 0.018, 6, 16), lam(gk ? '#ffffff' : kit.acc));
    trim.position.z = 1.48;
    body.add(trim);
    // 首
    const neck = cylZ(0.055, 0.06, 0.1, skin);
    neck.position.z = 1.5;
    body.add(neck);
    // 背番号（背中 = -y 側）
    const ink = YA.colorDist && YA.colorDist(gk ? kit.gk : kit.shirt, '#ffffff') < 120 ? '#1b2438' : '#ffffff';
    const nm = new T.Mesh(new T.PlaneGeometry(0.3, 0.3), new T.MeshBasicMaterial({ map: numberTexture(num, ink), transparent: true }));
    nm.rotation.x = Math.PI / 2; // 背中（-y）を向く。後ろから見て字が正しく読める
    nm.position.set(0, -0.15, 1.2);
    body.add(nm);
    // パンツ
    const sh = new T.Mesh(new T.CapsuleGeometry(0.12, 0.12, 3, 10), shorts);
    sh.rotation.z = Math.PI / 2;
    sh.scale.set(1, 1.55, 1);
    sh.position.z = 0.84;
    sh.castShadow = true;
    body.add(sh);
    // 頭
    const head = new T.Mesh(new T.SphereGeometry(0.122, 16, 12), skin);
    head.scale.set(0.95, 1, 1.08);
    head.position.z = 1.63;
    head.castShadow = true;
    body.add(head);
    addHair(body, hair, skin, style);
    // 脚：股（hip）→ 膝（knee）の2つの関節
    const legs = [];
    for (const sd of [-1, 1]) {
      const hip = new T.Group();
      hip.position.set(0.1 * sd, 0, 0.8);
      const thigh = cylZ(0.08, 0.065, 0.4, skin);
      thigh.position.z = -0.2;
      const knee = new T.Group();
      knee.position.z = -0.4;
      const shin = cylZ(0.062, 0.048, 0.36, socks);
      shin.position.z = -0.18;
      const bt = new T.Mesh(new T.CapsuleGeometry(0.045, 0.14, 3, 8), boot);
      bt.rotation.x = Math.PI / 2;
      bt.position.set(0, 0.05, -0.37);
      bt.castShadow = true;
      knee.add(shin, bt);
      hip.add(thigh, knee);
      body.add(hip);
      legs.push({ hip, knee });
    }
    // 腕：肩（sho）→ 肘（elb）
    const arms = [];
    for (const sd of [-1, 1]) {
      const sho = new T.Group();
      sho.position.set(0.25 * sd, 0, 1.4);
      const up = cylZ(0.062, 0.052, 0.26, shirt);
      up.position.z = -0.12;
      const elb = new T.Group();
      elb.position.z = -0.26;
      const fo = cylZ(0.048, 0.04, 0.24, skin);
      fo.position.z = -0.12;
      const hand = new T.Mesh(new T.SphereGeometry(0.045, 8, 6), glove);
      hand.position.z = -0.27;
      elb.add(fo, hand);
      sho.add(up, elb);
      sho.rotation.y = 0.14 * sd;
      body.add(sho);
      arms.push({ sho, elb });
    }
    root.userData = { legs, arms, body, kick: 0 };
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
      const crowd = crowdTexture([kits.home.shirt, kits.home.shirt, kits.home.shirt, '#e8e8e8', '#2a2f3d', kits.away.shirt]);
      // 横のスタンドは「斜面の幅 × 長さ（y）」の板を y 軸まわりに、奥のスタンドは「長さ（x）× 斜面の幅」の板を x 軸まわりに傾ける
      const stand = (cx, cy, cz, gw, gh, rx, ry) => {
        const t = crowd.clone();
        t.needsUpdate = true;
        t.repeat.set(gw / 4, gh / 4);
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
          if (kind === 'back') n.rotation.x = Math.PI / 2; // x と z に広がる
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
      this.built = true;
    }

    syncPlayers() {
      const m = this.match;
      const kits = this.kitsOf();
      const seen = new Set();
      // ボールが急に速くなった瞬間を「蹴った」とみなす
      const bv = this._lastBall ? Math.hypot(this.ball[0] - this._lastBall[0], this.ball[1] - this._lastBall[1]) / Math.max(1e-3, this._dt) : 0;
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
      this._lastBv = bv;
      this._lastBall = this.ball.slice();
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
        const it = { id, d };
        const dir = this.dirOf(it);
        o.rotation.z = Math.atan2(-dir[0], dir[1]);
        const sp = (this.speed && this.speed[id]) || 0;
        const run = clamp(sp / 5.5, 0, 1);
        const ph = (this.clock || 0) * (7 + run * 5) + (YA.hash ? YA.hash(String(id)) % 7 : 0);
        const sw = Math.sin(ph) * 0.75 * run;
        const u = o.userData;
        // 蹴る：ボールが急に動き出したとき、いちばん近くにいた子が右脚を振る
        if (kickBy === id) u.kick = 0.38;
        u.kick = Math.max(0, u.kick - this._dt);
        const kk = u.kick > 0 ? Math.sin(((0.38 - u.kick) / 0.38) * Math.PI) : 0;
        for (let i = 0; i < 2; i++) {
          // 脚：前に出すほど股を前へ。後ろへ蹴り上げるときに膝が曲がる
          let fwd = i ? -sw : sw;
          let bend = Math.max(0, -Math.sin(ph + (i ? Math.PI : 0))) * 1.1 * run + 0.08;
          if (i === 1 && kk > 0) { fwd = 1.25 * kk - 0.5 * (1 - kk); bend = 0.9 * (1 - kk); }
          u.legs[i].hip.rotation.x = fwd;
          u.legs[i].knee.rotation.x = -bend;
          // 腕は脚と逆に振り、肘を曲げる
          u.arms[i].sho.rotation.x = -fwd * 0.8;
          u.arms[i].elb.rotation.x = 0.25 + run * 0.9;
        }
        u.body.position.z = Math.abs(Math.cos(ph)) * 0.06 * run;
        u.body.rotation.x = -run * 0.14 + kk * 0.15; // 走るときは前かがみ、蹴るときは少し反る
      }
      for (const k of Object.keys(this.meshes)) if (!seen.has(k)) { this.scene3.remove(this.meshes[k]); delete this.meshes[k]; }
    }

    draw() {
      if (!this.match) return;
      if (!this.built) this.build();
      const now = (globalThis.performance && performance.now()) || Date.now();
      this._dt = this._lastT ? clamp((now - this._lastT) / 1000, 0, 0.1) : 0.016;
      this._lastT = now;
      const cy = this.camY;
      // カメラ：ふだんは中継の高さ、見どころの場面では寄る。ボールに合わせて少し横にも振る
      const want = this.scene ? YA.CAM3D_NEAR : YA.CAM3D;
      const cc = (this._cam = this._cam || Object.assign({}, YA.CAM3D, { x: 34 }));
      const k = 1 - Math.exp(-this._dt * 1.8);
      for (const key of ['back', 'up', 'ahead']) cc[key] += (want[key] - cc[key]) * k;
      cc.x += (34 + (this.ball[0] - 34) * 0.4 - cc.x) * k;
      this.camera.position.set(cc.x, cy - cc.back, cc.up);
      this.camera.lookAt(34 + (cc.x - 34) * 1.3, cy + cc.ahead, 0);
      // 影は見えている辺りだけ細かく
      this.sun.position.set(34 - 40, cy + 55, 70);
      this.sun.target.position.set(34, cy + 4, 0);
      this.syncPlayers();
      const b = this.ball;
      this.ball3.position.set(b[0], b[1], Math.max(0, b[2]) + 0.2);
      this.ball3.rotation.x = -b[1] * 1.8;
      this.ball3.rotation.y = b[0] * 1.8;
      // 輪：主役は緑、守る側の主役は白
      const fo = (this.focus || []).map((id) => [id, 0x5cff6a]).concat((this.defFocus || []).map((id) => [id, 0xffffff]));
      this.rings.forEach((r, i) => {
        const f = fo[i];
        const d = f && this.disp[f[0]];
        r.visible = !!d;
        if (d) { r.position.set(d[0], d[1], 0.03); r.material.color.setHex(f[1]); }
      });
      // 軌跡
      const tr = this.trail || [];
      const pos = this.trail3.geometry.attributes.position;
      const n = Math.min(30, tr.length);
      const moving = n > 2 && Math.hypot(tr[n - 1][0] - tr[0][0], tr[n - 1][1] - tr[0][1]) > 4;
      for (let i = 0; i < n; i++) pos.setXYZ(i, tr[tr.length - n + i][0], tr[tr.length - n + i][1], 0.05);
      pos.needsUpdate = true;
      this.trail3.geometry.setDrawRange(0, moving ? n : 0);
      this.three.render(this.scene3, this.camera);
      this.drawOverlay();
    }

    // 重ね板：名前の札と得点の光（2D）
    drawOverlay() {
      const ctx = this.ctx;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      ctx.clearRect(0, 0, this.w, this.h);
      if (this.scene) {
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
          const x = clamp(x0 - tw / 2, 2, this.w - tw - 2);
          const y = y0 - 18;
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
    }
  }
  YA.Renderer3D = Renderer3D;
})();
