"""トガリネズミの回の計算。python episodes/shrew/sim/calc.py → calc.txt
クライバーの式 基礎代謝 kcal/日 = 70 × 体重kg^0.75(Kleiber 1961。係数は Poczopko 1979 Acta Theriologica で確認)。
体重: コビトジャコウネズミ 2g(Jürgens ほか 1996)、ヨーロッパトガリネズミ 9g(Wołk 1969 の夏の最大 9.5g)、人 60kg、アフリカゾウのオス 6,000kg(San Diego Zoo)。"""
from pathlib import Path

lines = []


def p(s):
    print(s)
    lines.append(s)


def bmr(kg):
    return 70 * kg ** 0.75


A = {"コビトジャコウネズミ": 0.002, "ヨーロッパトガリネズミ": 0.009, "人": 60, "アフリカゾウ": 6000}
for k, m in A.items():
    p(f"{k} {m * 1000:g}g: 基礎代謝 {bmr(m):,.2f} kcal/日 / 体重1gあたり {bmr(m) / (m * 1000):.4f} kcal/日")
s, e = A["コビトジャコウネズミ"], A["アフリカゾウ"]
p(f"体重1gあたりのエネルギー: 2g は 6トンの {bmr(s) / s / (bmr(e) / e):.1f} 倍(= (6000/0.002)^0.25)")
p(f"同じ形なら体重1gあたりの表面: 2g は 6トンの {(e / s) ** (1 / 3):.0f} 倍(= (6000/0.002)^(1/3))")
p("サイコロ: 1辺1cm → 表面 6平方cm。1辺1mm に切ると 1,000 個、表面 6 × 0.01 × 1000 = 60平方cm(10倍)")
p(f"体重の6倍を食べる(Geyer ほか 2022)を 60kg の人に置きかえると {60 * 6} kg/日")
p(f"体重の45〜77%(Wołk 1969)を 60kg の人に置きかえると {60 * 0.45:.0f}〜{60 * 0.77:.0f} kg/日")
p(f"心拍 1,511 回/分 = 1秒に {1511 / 60:.1f} 回(Jürgens ほか 1996)")
(Path(__file__).resolve().parent / "calc.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
