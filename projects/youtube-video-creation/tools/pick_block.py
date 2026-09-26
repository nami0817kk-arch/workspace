# 題材の採否（○作る／△保留／✖却下）を書き込む仕掛け。make_topics_page.py から差し込む。
PICK_CSS = """
<style>
.card{position:relative}
.card.p-o{border-left:5px solid var(--pitch)}
.card.p-t{border-left:5px solid #a8761b}
.card.p-x{border-left:5px solid #b03a2e;opacity:.5}
.picks{display:flex;gap:.4rem;flex-wrap:wrap;align-items:center;
  border-top:1px dashed var(--line);margin-top:.7rem;padding-top:.6rem}
.picks .lab{font-size:.72rem;color:var(--ink-faint);margin-right:.2rem}
.picks button{font:inherit;font-size:.95rem;line-height:1;padding:.4rem .85rem;
  border:1px solid var(--line);background:var(--panel);color:var(--ink-soft);
  border-radius:4px;cursor:pointer;min-width:3.2rem}
.picks button:focus-visible{outline:2px solid var(--pitch);outline-offset:2px}
.picks button small{font-size:.66rem;display:block;margin-top:.15rem;font-weight:400}
.picks button[aria-pressed="true"]{font-weight:800;color:#fff}
.picks button.o[aria-pressed="true"]{background:var(--pitch);border-color:var(--pitch)}
.picks button.t[aria-pressed="true"]{background:#a8761b;border-color:#a8761b}
.picks button.x[aria-pressed="true"]{background:#b03a2e;border-color:#b03a2e}
.picks input{flex:1;min-width:10rem;font:inherit;font-size:.82rem;padding:.4rem .55rem;
  border:1px solid var(--line);border-radius:4px;background:var(--paper);color:var(--ink)}
.pickbar{position:sticky;top:0;z-index:5;background:var(--paper);
  border-bottom:1px solid var(--line);padding:.55rem 0;margin:.6rem 0 0;
  font-size:.82rem;color:var(--ink-soft);display:flex;gap:.9rem;flex-wrap:wrap}
.pickbar b{font-weight:800}
.pickbar .o{color:var(--pitch)} .pickbar .t{color:#a8761b} .pickbar .x{color:#b03a2e}
.pickbar .off{color:var(--ink-faint)}
</style>"""

PICK_JS = """
<script>
(async () => {
  const bar = document.getElementById('pickbar');
  const say = (h) => { bar.innerHTML = h; };
  say('<span class="off">採否の保存先につないでいます…</span>');
  const db = await claude.use('db');
  if (!db) { say('<span class="off">この画面では採否を保存できません（読むだけ）</span>'); return; }

  const KEY = window.PICK_KEY;
  const ref = db.collection('picks').doc(KEY);
  let items = {};

  function paint() {
    let o = 0, t = 0, x = 0;
    document.querySelectorAll('.card[data-num]').forEach(card => {
      const v = (items[card.dataset.num] || {}).pick || '';
      card.classList.toggle('p-o', v === 'o');
      card.classList.toggle('p-t', v === 't');
      card.classList.toggle('p-x', v === 'x');
      card.querySelectorAll('.picks button').forEach(b => {
        b.setAttribute('aria-pressed', String(b.dataset.v === v));
      });
      const memo = card.querySelector('.picks input');
      if (memo && document.activeElement !== memo) memo.value = (items[card.dataset.num] || {}).memo || '';
      if (v === 'o') o++; else if (v === 't') t++; else if (v === 'x') x++;
    });
    const n = document.querySelectorAll('.card[data-num]').length;
    say('<span class="o">○ 作る <b>' + o + '</b></span>'
      + '<span class="t">△ 保留 <b>' + t + '</b></span>'
      + '<span class="x">✖ 却下 <b>' + x + '</b></span>'
      + '<span class="off">未記入 ' + (n - o - t - x) + '</span>');
  }

  async function write(num, patch) {
    items = { ...items, [num]: { ...(items[num] || {}), ...patch } };
    paint();
    try { await ref.set({ items, at: new Date().toISOString() }); }
    catch (err) { say('<span class="off">保存できませんでした（' + (err.code || 'エラー') + '）</span>'); }
  }

  document.querySelectorAll('.card[data-num]').forEach(card => {
    const num = card.dataset.num;
    card.querySelectorAll('.picks button').forEach(b => {
      b.onclick = () => {
        const now = (items[num] || {}).pick || '';
        write(num, { pick: now === b.dataset.v ? '' : b.dataset.v });
      };
    });
    const memo = card.querySelector('.picks input');
    if (memo) {
      let timer;
      memo.oninput = () => { clearTimeout(timer); timer = setTimeout(() => write(num, { memo: memo.value.trim() }), 700); };
      memo.onblur = () => { clearTimeout(timer); write(num, { memo: memo.value.trim() }); };
    }
  });

  ref.onSnapshot(
    snap => { items = (snap.exists && snap.data().items) || {}; paint(); },
    err => say('<span class="off">採否を読めません（' + err.code + '）</span>')
  );
})();
</script>"""
