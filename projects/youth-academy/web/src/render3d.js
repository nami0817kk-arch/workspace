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
  function makePlayer(kit, look, gk, num) {
    const shirt = lam(gk ? kit.gk : kit.shirt);
    const shorts = lam(gk ? '#1b1b1b' : kit.shorts);
    const socks = lam(gk ? kit.gk : kit.socks);
    const skin = lam(look.skin);
    const hair = lam(look.hair);
    const boot = lam('#151515');
    const root = new T.Group();
    const body = new T.Group();
    body.scale.setScalar(BODY);
    root.add(body);
    // 胴
    const tg = new T.CapsuleGeometry(0.19, 0.3, 4, 10);
    tg.rotateX(Math.PI / 2);
    const torso = new T.Mesh(tg, shirt);
    torso.scale.set(1.15, 0.72, 1);
    torso.position.z = 1.17;
    torso.castShadow = true;
    body.add(torso);
    // 肩の差し色
    const trim = new T.Mesh(new T.BoxGeometry(0.46, 0.2, 0.04), lam(gk ? '#ffffff' : kit.acc));
    trim.position.z = 1.43;
    body.add(trim);
    // 背番号（背中 = -y 側）
    const ink = YA.colorDist && YA.colorDist(gk ? kit.gk : kit.shirt, '#ffffff') < 120 ? '#1b2438' : '#ffffff';
    const nm = new T.Mesh(new T.PlaneGeometry(0.3, 0.3), new T.MeshBasicMaterial({ map: numberTexture(num, ink), transparent: true }));
    nm.rotation.x = Math.PI / 2; // 背中（-y）を向く。後ろから見て字が正しく読める
    nm.position.set(0, -0.15, 1.2);
    body.add(nm);
    // パンツ
    const sh = new T.Mesh(new T.BoxGeometry(0.42, 0.26, 0.26), shorts);
    sh.position.z = 0.83;
    sh.castShadow = true;
    body.add(sh);
    // 頭
    const head = new T.Mesh(new T.SphereGeometry(0.125, 14, 10), skin);
    head.position.z = 1.62;
    head.castShadow = true;
    body.add(head);
    const hg = new T.SphereGeometry(0.133, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.55);
    hg.rotateX(Math.PI / 2);
    const hr = new T.Mesh(hg, hair);
    hr.position.set(0, -0.015, 1.635);
    hr.rotation.x = -0.35;
    body.add(hr);
    // 脚
    const legs = [];
    for (const sd of [-1, 1]) {
      const hip = new T.Group();
      hip.position.set(0.1 * sd, 0, 0.78);
      const thigh = cylZ(0.075, 0.065, 0.4, skin);
      thigh.position.z = -0.18;
      const shin = cylZ(0.062, 0.05, 0.36, socks);
      shin.position.z = -0.55;
      const bt = new T.Mesh(new T.BoxGeometry(0.1, 0.22, 0.07), boot);
      bt.position.set(0, 0.04, -0.75);
      bt.castShadow = true;
      hip.add(thigh, shin, bt);
      body.add(hip);
      legs.push(hip);
    }
    // 腕
    const arms = [];
    for (const sd of [-1, 1]) {
      const sho = new T.Group();
      sho.position.set(0.26 * sd, 0, 1.38);
      const up = cylZ(0.06, 0.055, 0.28, shirt);
      up.position.z = -0.12;
      const fo = cylZ(0.05, 0.042, 0.28, skin);
      fo.position.z = -0.38;
      sho.add(up, fo);
      sho.rotation.y = 0.12 * sd;
      body.add(sho);
      arms.push(sho);
    }
    root.userData = { legs, arms, body };
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
        const r = new T.Mesh(new T.RingGeometry(0.75, 0.92, 36), new T.MeshBasicMaterial({ color: 0x6eff78, transparent: true, opacity: 0.95, depthWrite: false }));
        r.position.z = 0.03;
        r.visible = false;
        sc.add(r);
        this.rings.push(r);
      }
      // パスの軌跡
      const tg = new T.BufferGeometry();
      tg.setAttribute('position', new T.BufferAttribute(new Float32Array(30 * 3), 3));
      this.trail3 = new T.Line(tg, new T.LineBasicMaterial({ color: 0x78ff6e, transparent: true, opacity: 0.85 }));
      this.trail3.frustumCulled = false;
      sc.add(this.trail3);
      this.built = true;
    }

    syncPlayers() {
      const m = this.match;
      const kits = this.kitsOf();
      const seen = new Set();
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
          o = this.meshes[key] = makePlayer(t === m.home ? kits.home : kits.away, look, gk, p.num);
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
        u.legs[0].rotation.x = sw;
        u.legs[1].rotation.x = -sw;
        u.arms[0].rotation.x = -sw * 0.8;
        u.arms[1].rotation.x = sw * 0.8;
        u.body.position.z = Math.abs(Math.cos(ph)) * 0.06 * run;
        u.body.rotation.x = run * 0.12;
      }
      for (const k of Object.keys(this.meshes)) if (!seen.has(k)) { this.scene3.remove(this.meshes[k]); delete this.meshes[k]; }
    }

    draw() {
      if (!this.match) return;
      if (!this.built) this.build();
      const cy = this.camY;
      // カメラは2Dと同じ位置（中継の高いカメラ）
      const cam = YA.CAM3D;
      this.camera.position.set(34, cy - cam.back, cam.up);
      this.camera.lookAt(34, cy + cam.ahead, 0);
      // 影は見えている辺りだけ細かく
      this.sun.position.set(34 - 40, cy + 55, 70);
      this.sun.target.position.set(34, cy + 4, 0);
      this.syncPlayers();
      const b = this.ball;
      this.ball3.position.set(b[0], b[1], Math.max(0, b[2]) + 0.2);
      this.ball3.rotation.x = -b[1] * 1.8;
      this.ball3.rotation.y = b[0] * 1.8;
      // 輪：主役は緑、守る側の主役は白
      const fo = (this.focus || []).map((id) => [id, 0x6eff78]).concat((this.defFocus || []).map((id) => [id, 0xffffff]));
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
