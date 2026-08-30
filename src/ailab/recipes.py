"""レシピ実行。「集める → 作る → 送る」を1つのYAMLにまとめて再実行できるようにする。

レシピは手順（steps）の並びで、各手順は1つの動詞を持つ。
前の手順の結果は `{{ 手順id.0.フィールド }}` で参照できる。
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from . import assets as assets_module
from . import imagegen
from .config import output_dir
from .core import registry
from .core.errors import ConfigError
from .utils import slugify

#: {{ ... }} の中身
PLACEHOLDER_RE = re.compile(r"\{\{\s*([^{}]+?)\s*\}\}")
#: レシピを名前で指定されたときに探す場所
RECIPE_DIR = "recipes"


@dataclass
class StepResult:
    """1手順の実行結果。中身は必ず辞書のリストにして、参照方法を揃える。"""

    id: str
    verb: str
    items: list[dict] = field(default_factory=list)

    @property
    def summary(self) -> str:
        if not self.items:
            return "0件"
        first = self.items[0]
        label = first.get("path") or first.get("url") or first.get("title") or first.get("detail") or ""
        more = f" ほか{len(self.items) - 1}件" if len(self.items) > 1 else ""
        return f"{len(self.items)}件{f': {label}' if label else ''}{more}"


@dataclass
class RunResult:
    name: str
    steps: list[StepResult] = field(default_factory=list)

    def files(self) -> list[str]:
        """レシピが作ったファイルのパス。"""
        return [item["path"] for step in self.steps for item in step.items if item.get("path")]

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "steps": [{"id": s.id, "verb": s.verb, "items": s.items} for s in self.steps],
        }


# --- 読み込み ---------------------------------------------------------
def find_recipe(name_or_path: str) -> Path:
    """レシピのパスを解決する。名前だけなら recipes/ から探す。"""
    candidates = [Path(name_or_path)]
    if not Path(name_or_path).suffix:
        candidates += [
            Path(RECIPE_DIR) / f"{name_or_path}{ext}" for ext in (".yaml", ".yml", ".json")
        ]
    else:
        candidates.append(Path(RECIPE_DIR) / name_or_path)

    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise ConfigError(f"レシピが見つかりません: {name_or_path}")


def load_recipe(name_or_path: str) -> dict:
    """YAML または JSON のレシピを読み込む。"""
    path = find_recipe(name_or_path)
    text = path.read_text(encoding="utf-8")

    if path.suffix == ".json":
        data = json.loads(text)
    else:
        try:
            import yaml
        except ImportError as exc:  # pragma: no cover - 環境依存
            raise ConfigError("YAML を読むには PyYAML が必要です: pip install PyYAML") from exc
        data = yaml.safe_load(text)

    if not isinstance(data, dict) or not isinstance(data.get("steps"), list):
        raise ConfigError(f"{path}: steps のリストが必要です")
    data.setdefault("name", path.stem)
    return data


# --- テンプレート -----------------------------------------------------
def lookup(path: str, context: dict) -> Any:
    """'releases.0.title' のような参照を解決する。

    リストに対して数字以外のキーを指定した場合は先頭要素を見る
    （1件しか使わない場面が多いため）。
    """
    current: Any = context
    for segment in path.split("."):
        segment = segment.strip()
        if isinstance(current, list):
            if segment.lstrip("-").isdigit():
                index = int(segment)
                if not current:
                    raise ConfigError(
                        f"参照できません: {{{{ {path} }}}} … 前の手順の結果が0件です"
                    )
                if not -len(current) <= index < len(current):
                    raise ConfigError(
                        f"参照できません: {{{{ {path} }}}} … 結果は{len(current)}件しかありません"
                    )
                current = current[index]
                continue
            if not current:
                raise ConfigError(f"参照できません（結果が0件）: {{{{ {path} }}}}")
            current = current[0]

        if isinstance(current, dict):
            if segment not in current:
                raise ConfigError(f"参照できません（{segment} がない）: {{{{ {path} }}}}")
            current = current[segment]
        else:
            if not hasattr(current, segment):
                raise ConfigError(f"参照できません（{segment} がない）: {{{{ {path} }}}}")
            current = getattr(current, segment)
    return current


def render(value: Any, context: dict) -> Any:
    """文字列・リスト・辞書の中の {{ }} を再帰的に埋める。"""
    if isinstance(value, str):
        whole = PLACEHOLDER_RE.fullmatch(value.strip())
        if whole:  # 値全体が参照なら型を保ったまま返す
            return lookup(whole.group(1), context)
        return PLACEHOLDER_RE.sub(lambda m: str(lookup(m.group(1), context)), value)
    if isinstance(value, list):
        return [render(item, context) for item in value]
    if isinstance(value, dict):
        return {key: render(item, context) for key, item in value.items()}
    return value


# --- 各手順 -----------------------------------------------------------
def _step_feed(options: dict, _state: dict) -> list[dict]:
    source = options.get("source")
    if not source:
        raise ConfigError("feed には source が必要です")
    connector = registry.get(source)
    items = connector.fetch_items(options.get("query", ""), limit=int(options.get("limit", 5)))
    return [item.to_dict() for item in items]


def _step_search(options: dict, _state: dict) -> list[dict]:
    found = assets_module.search(
        options.get("query", ""),
        source=options.get("source", "all"),
        limit=int(options.get("limit", 5)),
    )
    return [asset.to_dict() for asset in found]


def _step_fetch(options: dict, _state: dict) -> list[dict]:
    found = assets_module.search(
        options.get("query", ""),
        source=options.get("source", "all"),
        limit=int(options.get("limit", 3)),
    )[: int(options.get("limit", 3))]
    destination = options.get("out") or output_dir("illust")
    saved = assets_module.download_all(found, destination)
    return [dict(asset.to_dict(), path=str(path)) for asset, path in saved]


def _step_gen(options: dict, _state: dict) -> list[dict]:
    prompt = options.get("prompt")
    if not prompt:
        raise ConfigError("gen には prompt が必要です")
    provider = imagegen.get_provider(options.get("provider", "auto"))
    images = provider.generate(
        prompt,
        size=str(options.get("size", "1024x1024")),
        n=int(options.get("n", 1)),
        model=options.get("model"),
    )
    destination = Path(options.get("out") or output_dir("images"))
    results = []
    for index, image in enumerate(images):
        name = options.get("filename")
        if name:
            # 複数枚のときに同じ名前で上書きしないよう連番を付ける
            suffix = f"_{index + 1}" if len(images) > 1 else ""
            filename = f"{slugify(name)}{suffix}{image.ext}"
        else:
            filename = image.default_name(index)
        path = image.save(destination / filename)
        results.append(
            {
                "path": str(path),
                "provider": image.provider,
                "model": image.model,
                "prompt": image.prompt,
            }
        )
    return results


def _step_publish(options: dict, state: dict) -> list[dict]:
    target = options.get("to", "github")
    file_path = options.get("file") or state.get("last_file")
    if not file_path:
        raise ConfigError("publish には file が必要です（前の手順がファイルを作っていません）")

    passthrough = {
        key: value
        for key, value in options.items()
        if key not in {"to", "file", "dry_run"} and value is not None
    }
    dry_run = bool(options.get("dry_run", state.get("dry_run", True)))
    result = registry.get(target).publish(file_path, dry_run=dry_run, **passthrough)
    return [
        {
            "target": result.target,
            "url": result.url,
            "detail": result.detail,
            "dry_run": result.dry_run,
            "file": str(file_path),
        }
    ]


STEP_HANDLERS: dict[str, Callable[[dict, dict], list[dict]]] = {
    "feed": _step_feed,
    "search": _step_search,
    "fetch": _step_fetch,
    "gen": _step_gen,
    "publish": _step_publish,
}


# --- 実行 -------------------------------------------------------------
def run(
    recipe: dict,
    *,
    dry_run: bool = True,
    variables: dict | None = None,
    on_step: Callable[[int, int, StepResult], None] | None = None,
) -> RunResult:
    """レシピを順に実行する。publish は既定でドライラン。"""
    steps = recipe.get("steps") or []
    context: dict = {
        "vars": {**(recipe.get("vars") or {}), **(variables or {})},
        "now": datetime.now().isoformat(timespec="seconds"),
        "today": datetime.now().strftime("%Y-%m-%d"),
    }
    state: dict = {"dry_run": dry_run, "last_file": None}
    result = RunResult(name=str(recipe.get("name", "recipe")))

    for index, raw_step in enumerate(steps, 1):
        step_id, verb, options = _parse_step(raw_step, index)
        rendered = render(options, context)
        try:
            items = STEP_HANDLERS[verb](rendered, state)
        except ConfigError as exc:
            raise ConfigError(f"手順{index}（{verb}）: {exc}") from exc

        step_result = StepResult(id=step_id, verb=verb, items=items)
        result.steps.append(step_result)
        context[step_id] = items
        for item in items:
            if item.get("path"):
                state["last_file"] = item["path"]
        if on_step:
            on_step(index, len(steps), step_result)

    return result


def _parse_step(raw_step: Any, index: int) -> tuple[str, str, dict]:
    """手順1つを (id, 動詞, 設定) に分解する。"""
    if not isinstance(raw_step, dict):
        raise ConfigError(f"手順{index}: 辞書で書いてください")

    verbs = [key for key in raw_step if key in STEP_HANDLERS]
    if len(verbs) != 1:
        known = ", ".join(STEP_HANDLERS)
        raise ConfigError(f"手順{index}: 動詞を1つだけ指定してください（{known}）")

    verb = verbs[0]
    options = raw_step[verb] or {}
    if not isinstance(options, dict):
        raise ConfigError(f"手順{index}（{verb}）: 設定は辞書で書いてください")
    return str(raw_step.get("id") or f"step{index}"), verb, options
