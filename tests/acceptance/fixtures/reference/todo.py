#!/usr/bin/env python3
"""Known-good reference implementation of fixtures/REQUIREMENTS.md.

Used only by `run.sh --self-test` to validate the grader (acceptance.sh). It is
deliberately minimal and is NOT the software under test — the point of the
acceptance test is that a harness-driven session produces its own implementation.
"""
import json
import sys
from pathlib import Path

STATE_FILE = Path("todo.json")
USAGE = """usage: python3 todo.py <command>

commands:
  add "text"    add a new pending item, print its id
  list [--all]  list pending items (--all includes completed)
  done <id>     mark an item completed
"""


def load() -> list[dict]:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return []


def save(items: list[dict]) -> None:
    STATE_FILE.write_text(json.dumps(items, indent=2))


def main(argv: list[str]) -> int:
    if not argv:
        print(USAGE, file=sys.stderr)
        return 2

    command, args = argv[0], argv[1:]
    items = load()

    if command == "add" and len(args) == 1:
        new_id = max((item["id"] for item in items), default=0) + 1
        items.append({"id": new_id, "text": args[0], "done": False})
        save(items)
        print(new_id)
        return 0

    if command == "list" and args in ([], ["--all"]):
        show_all = args == ["--all"]
        for item in items:
            if item["done"] and not show_all:
                continue
            marker = "[x]" if item["done"] else "[ ]"
            print(f"{marker} {item['id']} {item['text']}")
        return 0

    if command == "done" and len(args) == 1:
        for item in items:
            if str(item["id"]) == args[0] and not item["done"]:
                item["done"] = True
                save(items)
                return 0
        print(f"error: no pending item with id {args[0]}", file=sys.stderr)
        return 1

    print(USAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
