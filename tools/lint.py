#!/usr/bin/env python3
"""Convention checks for Neon Requiem (run from the project root: python3 tools/lint.py).

- every function body is at most 40 lines;
- no print() anywhere in GDScript;
- RandomNumberGenerator.new() only in autoload/GameState.gd (tools excluded);
- PURE modules (SpawnDirector, WaveDirector, DamageCalc) reference no nodes and no GameState;
- every `signal` is declared in autoload/Signals.gd, every Signals.<name> used is declared;
- no deprecated TileMap node (TileMapLayer only);
- every .gd declares its types: no `var x =` / `var x :=` without an explicit type.
Exit code 1 when something fails.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAX_FUNC_LINES = 40
PURE = ["autoload/SpawnDirector.gd", "autoload/WaveDirector.gd", "autoload/DamageCalc.gd"]
PURE_FORBIDDEN = ["GameState", "MetaState", "get_node", "get_tree", "$", "Node2D", "Signals.", "RandomNumberGenerator"]
FUNC_RE = re.compile(r"^(static\s+)?func\s+(\w+)")
UNTYPED_VAR_RE = re.compile(r"^\s*(static\s+)?var\s+\w+\s*(=|:=)")


def gd_files(include_tools: bool) -> list:
    files = sorted(ROOT.rglob("*.gd"))
    out = []
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith(".godot/") or rel.startswith("tools/tmp/"):
            continue
        if not include_tools and rel.startswith("tools/"):
            continue
        out.append(path)
    return out


def function_lengths(path: pathlib.Path) -> list:
    lines = path.read_text(encoding="utf-8").split("\n")
    problems = []
    start = None
    name = ""
    last_code = 0
    for index, line in enumerate(lines):
        match = FUNC_RE.match(line)
        if match or (line and not line[0].isspace() and not line.startswith("#") and start is not None):
            if start is not None:
                length = last_code - start
                if length > MAX_FUNC_LINES:
                    problems.append(f"{path.relative_to(ROOT)}:{start + 1} func {name} has {length} lines")
                start = None
            if match:
                start = index
                name = match.group(2)
                last_code = index
            continue
        if start is not None and line.strip() and not line.strip().startswith("#"):
            last_code = index
    if start is not None and last_code - start > MAX_FUNC_LINES:
        problems.append(f"{path.relative_to(ROOT)}:{start + 1} func {name} has {last_code - start} lines")
    return problems


def code_only(text: str) -> str:
    return "\n".join(line for line in text.split("\n") if not line.strip().startswith("#"))


def main() -> int:
    problems = []
    signals_text = (ROOT / "autoload/Signals.gd").read_text(encoding="utf-8")
    declared = set(re.findall(r"^signal\s+(\w+)", signals_text, re.M))
    for path in gd_files(include_tools=True):
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        code = code_only(text)
        problems += function_lengths(path)
        if re.search(r"\bprint(_rich|raw|err|t)?\s*\(", code):
            problems.append(f"{rel}: print() is not allowed, use push_error()")
        for number, line in enumerate(text.split("\n"), 1):
            if UNTYPED_VAR_RE.match(line):
                problems.append(f"{rel}:{number} untyped var declaration")
        if re.search(r"\bTileMap\b(?!Layer)", code):
            problems.append(f"{rel}: deprecated TileMap, use TileMapLayer")
        if rel.startswith("tools/"):
            continue
        if "RandomNumberGenerator.new()" in code and rel != "autoload/GameState.gd":
            problems.append(f"{rel}: RandomNumberGenerator.new() outside GameState")
        if rel != "autoload/Signals.gd" and re.search(r"^signal\s", code, re.M):
            problems.append(f"{rel}: signal declared outside autoload/Signals.gd")
        for used in set(re.findall(r"\bSignals\.(\w+)\.(?:emit|connect|disconnect)", code)):
            if used not in declared:
                problems.append(f"{rel}: Signals.{used} is not declared in Signals.gd")
    for rel in PURE:
        code = "\n".join(line for line in code_only((ROOT / rel).read_text(encoding="utf-8")).split("\n") if not line.startswith("extends"))
        for token in PURE_FORBIDDEN:
            if token in code:
                problems.append(f"{rel}: PURE module references '{token}'")
    for problem in problems:
        sys.stderr.write(problem + "\n")
    sys.stdout.write(f"lint: {len(problems)} problem(s) in {len(gd_files(True))} scripts\n")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
