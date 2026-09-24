#!/usr/bin/env python3
"""Copy lecture steps from grammar_rules.json into the lesson cards that teach them.

A lecture step is written once, in the grammar rule's `lecture` list
(docs/CURRICULUM_V1_2_PLAN_2026-09-24.md §5.2). A lesson shows it through a
`teaching` card with `data.style == "lecture"`, naming the rule and which of
its steps:

    {"type": "teaching", "data": {"type": "teaching", "style": "lecture",
      "grammar_rule_id": "GR-050", "rule_step": 1}}

This script fills in the card's text from the rule (heading, say, table,
examples, common_mistake), numbers the lesson's lecture cards (`step` of
`steps`), and adds plain `items` for apps that predate the lecture layout.
The Grammar reference, the lesson and the unit notebook screen therefore
never teach two versions of one rule.

    python3 tool/sync_lecture_cards.py           # rewrite cards that drifted
    python3 tool/sync_lecture_cards.py --check   # exit 1 if any card drifted

test/curriculum_v12_contract_test.dart runs the same comparison in CI.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RULES = ROOT / "assets/curriculum/grammar_rules.json"
LESSONS = ROOT / "assets/curriculum/lessons"
FIELDS = ("heading", "say", "table", "examples", "common_mistake")


def lecture_steps() -> dict[str, list[dict]]:
    rules = json.loads(RULES.read_text(encoding="utf-8"))["rules"]
    return {r["id"]: r["lecture"] for r in rules if r.get("lecture")}


def synced(card: dict, rule_step: dict, step: int, steps: int) -> dict:
    data = dict(card["data"])
    for field in FIELDS:
        if field in rule_step:
            data[field] = rule_step[field]
        else:
            data.pop(field, None)
    data["step"] = step
    data["steps"] = steps
    # What an app without the lecture layout shows: the examples as a list.
    data["items"] = [
        {"cz": e["cz"], "en": e.get("en", "")} for e in rule_step.get("examples", [])
    ]
    return {**card, "prompt": rule_step["heading"], "data": data}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    steps_by_rule = lecture_steps()
    problems, rewritten = [], []
    for path in sorted(LESSONS.glob("*.json")):
        raw = path.read_text(encoding="utf-8")
        lesson = json.loads(raw)
        cards = [
            (i, e) for i, e in enumerate(lesson["exercises"])
            if e["type"] == "teaching" and e["data"].get("style") == "lecture"
        ]
        changed = False
        for position, (index, card) in enumerate(cards, start=1):
            rule_id = card["data"].get("grammar_rule_id")
            rule_step = card["data"].get("rule_step")
            rule = steps_by_rule.get(rule_id)
            if rule is None or not isinstance(rule_step, int) or not 1 <= rule_step <= len(rule):
                problems.append(f"{path.name} exercise {card['id']}: no lecture step "
                                f"{rule_step} in {rule_id}")
                continue
            new = synced(card, rule[rule_step - 1], position, len(cards))
            if new != card:
                changed = True
                lesson["exercises"][index] = new
                if args.check:
                    problems.append(f"{path.name} exercise {card['id']}: differs from "
                                    f"{rule_id} step {rule_step}")
        if changed and not args.check:
            out = json.dumps(lesson, ensure_ascii=False, indent=2)
            path.write_text(out + ("\n" if raw.endswith("\n") else ""), encoding="utf-8")
            rewritten.append(path.name)

    for problem in problems:
        print(problem, file=sys.stderr)
    if rewritten:
        print("updated: " + ", ".join(rewritten))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
