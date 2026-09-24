#!/usr/bin/env python3
"""Compare the app's A1/A2 vocabulary with the official Czech word list.

The official list is the appendix *Soupis lexikálních jednotek úrovně A1, A2* of
the NÚV 2016 reference description (docs/sources/official_sources.json). It is
the vocabulary the permanent-residence exam is built on.

  fetch    download the official PDFs into a cache and verify their SHA-256
  extract  reference PDF -> docs/sources/official_lexicon_a1_a2.csv
           (+ the plain text, kept in the cache, for `compare`)
  compare  app vocabulary vs the official list -> docs/sources/*.csv + summary

    python3 tool/official_lexicon.py fetch
    python3 tool/official_lexicon.py extract
    python3 tool/official_lexicon.py compare

Needs `pdftotext` (poppler) for `extract`.

Matching is deliberately simple and reported as such: an app entry is looked up
by headword (and by each "/"-separated alternative); anything not listed is then
searched for in the full reference text by word stem. Stem matches over-count,
so coverage figures are upper bounds and "absent" lists can contain a few false
hits (inflected or derived forms). Every list is for a person to review, not an
automatic verdict.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import http.client
import json
import re
import subprocess
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "docs/sources/official_sources.json"
OUT_DIR = ROOT / "docs/sources"
LEXICON_CSV = OUT_DIR / "official_lexicon_a1_a2.csv"
CACHE = ROOT / "build/official_sources"
REFERENCE_KEY = "reference_description_2016"

APP_VOCAB = {
    "A1": ROOT / "assets/vocabulary/a1_vocabulary.json",
    "A2": ROOT / "assets/vocabulary/a2_vocabulary.json",
}
LESSONS = ROOT / "assets/curriculum/lessons"
GRAMMAR = ROOT / "assets/curriculum/grammar_rules.json"
UNITS = [ROOT / "assets/curriculum/a1_units.json", ROOT / "assets/curriculum/a2_units.json"]

# Chapter numbers in the word list point at the topic that uses the word.
TOPICS = {
    "4.1": "Existence", "4.2": "Quantity", "4.3": "Size and measures",
    "4.4": "Space", "4.5": "Time", "4.6": "Qualities", "4.7": "Evaluation",
    "4.8": "Logical relations",
    "5.1": "Giving information", "5.2": "Attitudes to information",
    "5.3": "Emotions", "5.4": "Influencing others", "5.5": "Social rituals",
    "5.6": "Discourse", "5.7": "Communication strategies",
    "6.1": "Personal details, family", "6.2": "Housing", "6.3": "Food",
    "6.4": "Daily routine", "6.5": "Free time", "6.6": "Work",
    "6.7": "Health care", "6.8": "Shopping and services", "6.9": "Travel",
    "6.10": "Education", "6.11": "Offices", "6.12": "Police and emergencies",
    "6.13": "Environment and weather", "6.14": "Contact with Czech society",
}

LETTERS = "a-záčďéěíňóřšťúůýž"
ROW = re.compile(r"^(\S.*?)\s{2,}(A1|A2)\s+(slovo|fráze|sousloví|vazba)\b(.*)$")
REF = re.compile(r"\b\d{1,2}\.\d{1,2}(?:\.\d{1,2})?\b")
POS = ("substantivum", "verbum", "adjektivum", "adverbium", "pronomen",
       "numerale", "prepozice", "konjunkce", "partikule", "interjekce")
GENDER = ("maskulinum", "femininum", "neutrum")
NUMBER = ("singulár", "plurál")
ASPECT = ("imperfektivní", "perfektivní")


# ── fetch ────────────────────────────────────────────────────────────────────

def load_sources() -> list[dict]:
    return json.loads(SOURCES.read_text(encoding="utf-8"))["sources"]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def cached_pdf(source: dict) -> Path:
    return CACHE / f"{source['key']}.pdf"


def download(url: str, path: Path) -> None:
    """Download with resume: these servers drop the connection near the end of
    a transfer now and then, so keep asking for the remaining byte range."""
    with urllib.request.urlopen(url, timeout=60) as response:
        total = int(response.headers["Content-Length"])
    with path.open("wb") as handle:
        while (done := handle.tell()) < total:
            request = urllib.request.Request(url, headers={"Range": f"bytes={done}-"})
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    if done and response.status != 206:
                        raise OSError("server ignored the byte range")
                    while block := response.read(1 << 16):
                        handle.write(block)
            except (OSError, http.client.IncompleteRead) as error:
                if handle.tell() == done:  # no progress at all: give up this attempt
                    raise OSError(f"stalled at {done} of {total} bytes: {error}") from error


def cmd_fetch(_: argparse.Namespace) -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    failed = False
    for source in load_sources():
        path = cached_pdf(source)
        for attempt in range(1, 4):
            if path.exists() and sha256(path) == source["sha256"]:
                break
            print(f"downloading {source['key']} (attempt {attempt}) …")
            try:
                download(source["url"], path)
            except OSError as error:  # these servers drop long transfers now and then
                print(f"  {error}")
                path.unlink(missing_ok=True)
        actual = sha256(path) if path.exists() else "nothing downloaded"
        ok = actual == source["sha256"]
        failed |= not ok
        print(f"{'ok  ' if ok else 'FAIL'} {source['key']}"
              + ("" if ok else f"  (got {actual}; the publisher may have replaced the file)"))
    return 1 if failed else 0


# ── extract ──────────────────────────────────────────────────────────────────

def reference_text_path() -> Path:
    return CACHE / f"{REFERENCE_KEY}.txt"


def cmd_extract(args: argparse.Namespace) -> int:
    source = next(s for s in load_sources() if s["key"] == REFERENCE_KEY)
    pdf = Path(args.pdf) if args.pdf else cached_pdf(source)
    if not pdf.exists():
        sys.exit(f"{pdf} not found — run `fetch` first or pass --pdf")
    if sha256(pdf) != source["sha256"]:
        sys.exit(f"{pdf} is not the edition in official_sources.json (checksum differs)")
    text_path = reference_text_path()
    text_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["pdftotext", "-layout", str(pdf), str(text_path)], check=True)

    lines = text_path.read_text(encoding="utf-8").splitlines()
    starts = [i for i, line in enumerate(lines)
              if "SOUPIS LEXIKÁLNÍCH JEDNOTEK ÚROVNĚ A1, A2" in line]
    if not starts:
        sys.exit("word-list appendix not found in the PDF text")

    rows, pending_refs = [], []
    for line in lines[starts[-1]:]:
        match = ROW.match(line)
        if not match:
            # In the PDF layout a long reference list wraps onto the line
            # *above* its entry; carry it forward.
            if line.strip() and REF.sub("", line).strip(" ;,") == "":
                pending_refs += REF.findall(line)
            continue
        headword, level, kind, rest = match.groups()
        words = rest.split()
        refs = pending_refs + REF.findall(rest)
        pending_refs = []
        rows.append({
            "headword": headword.strip(),
            "level": level,
            "type": kind,
            "pos": next((w for w in words if w in POS), ""),
            "gender": next((w for w in words if w in GENDER), ""),
            "number": next((w for w in words if w in NUMBER), ""),
            "aspect": next((w for w in words if w in ASPECT), ""),
            "chapters": "; ".join(dict.fromkeys(refs)),
            "topics": "; ".join(dict.fromkeys(
                TOPICS[t] for t in (".".join(r.split(".")[:2]) for r in refs) if t in TOPICS)),
        })

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with LEXICON_CSV.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    counts = Counter((r["level"], r["type"]) for r in rows)
    print(f"{len(rows)} rows, {len({r['headword'].lower() for r in rows})} distinct headwords "
          f"-> {LEXICON_CSV.relative_to(ROOT)}")
    for key in sorted(counts):
        print(f"  {key[0]} {key[1]:9s} {counts[key]}")
    return 0


# ── compare ──────────────────────────────────────────────────────────────────

def norm(text: str) -> str:
    text = re.sub(r"\(.*?\)", "", text.lower())
    return re.sub(r"\s+", " ", text).strip(" .!?,…")


def alternatives(text: str) -> list[str]:
    whole = norm(text)
    parts = [norm(p) for p in re.split(r"[/;,]", text) if norm(p)]
    return list(dict.fromkeys([whole, *parts]))


def stem_found(word: str, corpus: str) -> bool:
    # Short words inflect in their last letter (noha → nohy, pero → pera).
    stem = word[: max(3, len(word) - 1)] if len(word) <= 5 else word[: len(word) - 2]
    return re.search(rf"(?<![{LETTERS}]){re.escape(stem)}", corpus) is not None


def strings(node) -> list[str]:
    if isinstance(node, dict):
        return [s for v in node.values() for s in strings(v)]
    if isinstance(node, list):
        return [s for v in node for s in strings(v)]
    return [node] if isinstance(node, str) else []


def load_entries(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, list) else next(iter(data.values()))


def cmd_compare(_: argparse.Namespace) -> int:
    if not LEXICON_CSV.exists():
        sys.exit("run `extract` first")
    text_path = reference_text_path()
    if not text_path.exists():
        sys.exit(f"{text_path} missing — run `fetch` and `extract` first")

    official = list(csv.DictReader(LEXICON_CSV.open(encoding="utf-8")))
    level_of: dict[str, str] = {}
    for row in official:
        for alt in alternatives(row["headword"]):
            # A word listed at both levels counts at the lower one.
            if level_of.get(alt) != "A1":
                level_of[alt] = row["level"]
    reference = re.sub(r"\s+", " ", text_path.read_text(encoding="utf-8").lower())

    unit_titles = {u["id"]: u["title"] for p in UNITS
                   for u in json.loads(p.read_text(encoding="utf-8"))["units"]}

    # 1. Every app vocabulary entry, classified.
    app_rows, app_corpus_parts = [], []
    for app_level, path in APP_VOCAB.items():
        for entry in load_entries(path):
            word = entry["word_cz"]
            app_corpus_parts += [word, entry.get("example_cz") or ""]
            alts = alternatives(word)
            listed = next((level_of[a] for a in alts if a in level_of), "")
            if listed:
                status = f"official_{listed}"
            elif any(stem_found(a, reference) for a in alts):
                status = "reference_text_only"
            elif " " in alts[0] and all(stem_found(w, reference) for w in alts[0].split() if len(w) > 2):
                status = "phrase_of_known_words"
            else:
                status = "absent"
            app_rows.append({
                "unit_id": entry.get("unit_id"),
                "unit_title": unit_titles.get(entry.get("unit_id"), ""),
                "app_level": app_level,
                "word_cz": word,
                "word_en": entry.get("word_en", ""),
                "official_level": listed,
                "status": status,
                "early": "yes" if app_level == "A1" and listed == "A2" else "",
            })

    # 2. Official words the app never uses (vocabulary, lessons, grammar notes).
    for lesson in sorted(LESSONS.glob("*.json")):
        app_corpus_parts += strings(json.loads(lesson.read_text(encoding="utf-8")))
    app_corpus_parts += strings(json.loads(GRAMMAR.read_text(encoding="utf-8")))
    app_corpus = re.sub(r"\s+", " ", " ".join(app_corpus_parts).lower())

    missing, coverage = [], defaultdict(lambda: [0, 0])
    for row in official:
        if row["type"] != "slovo" or "/" in row["headword"]:
            continue
        found = stem_found(norm(row["headword"]), app_corpus)
        coverage[row["level"]][0] += found
        coverage[row["level"]][1] += 1
        if not found:
            missing.append({k: row[k] for k in ("headword", "level", "pos", "gender", "aspect", "topics")})

    with (OUT_DIR / "app_vocabulary_vs_official.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(app_rows[0]))
        writer.writeheader()
        writer.writerows(app_rows)
    with (OUT_DIR / "official_words_missing_from_app.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(missing[0]))
        writer.writeheader()
        writer.writerows(sorted(missing, key=lambda r: (r["level"], r["topics"], r["headword"])))

    write_summary(app_rows, missing, coverage)
    return 0


def write_summary(app_rows: list[dict], missing: list[dict], coverage) -> None:
    by_unit = defaultdict(Counter)
    for row in app_rows:
        by_unit[(row["unit_id"], row["unit_title"])][row["status"]] += 1
        by_unit[(row["unit_id"], row["unit_title"])]["early"] += bool(row["early"])
    lines = [
        "# App vocabulary vs the official A1/A2 word list",
        "",
        "Generated by `tool/official_lexicon.py compare`. Do not edit by hand.",
        "Source: NÚV 2016 reference description, *Soupis lexikálních jednotek*",
        "(`docs/sources/official_sources.json`).",
        "",
        "**How to read it.** `official A1/A2` = listed in the official word list.",
        "`reference text only` = not listed, but the word stem appears somewhere in the",
        "reference description (often an inflected form such as *kávu*, a function word,",
        "or a form used in an example). `phrase of known words` = a multiword entry that",
        "isn't listed, but each of its words is (e.g. *Je mi zima*); usually fine, but",
        "technical compounds (*krevní test*) land here too. `absent` = the stem appears nowhere in the",
        "312-page description: the main candidates for moving to *Towards B1* extensions",
        "(plan §7.2). Stem matching over-counts, so treat every list as a review list.",
        "",
        "## Official coverage (single words, upper bound)",
        "",
        "| Level | Official words | Found in the app | Share |",
        "|---|---|---|---|",
    ]
    for level in ("A1", "A2"):
        found, total = coverage[level]
        lines.append(f"| {level} | {total} | {found} | {100 * found // total}% |")
    lines += [
        "",
        "## App vocabulary by unit",
        "",
        "| Unit | Entries | Official A1 | Official A2 | Reference text only | Phrase of known words | Absent | A1 unit, officially A2 |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for (unit_id, title), c in sorted(by_unit.items(), key=lambda kv: kv[0][0] or 0):
        total = sum(v for k, v in c.items() if k != "early")
        lines.append(f"| {unit_id} {title} | {total} | {c['official_A1']} | {c['official_A2']} | "
                     f"{c['reference_text_only']} | {c['phrase_of_known_words']} | {c['absent']} | "
                     f"{c['early'] or ''} |")
    for status, heading in (("absent", "Absent words by unit (review for the A2 extensions)"),
                            ("phrase_of_known_words", "Phrases of known words by unit (check technical compounds)")):
        lines += ["", f"## {heading}", ""]
        grouped = defaultdict(list)
        for row in app_rows:
            if row["status"] == status:
                grouped[(row["unit_id"], row["unit_title"])].append(row["word_cz"])
        for (unit_id, title), words in sorted(grouped.items(), key=lambda kv: kv[0][0] or 0):
            unique = list(dict.fromkeys(words))
            lines.append(f"- **U{unit_id} {title}** ({len(unique)}): " + ", ".join(unique))
    by_topic = Counter(t.strip() for row in missing for t in (row["topics"] or "—").split(";"))
    lines += ["", "## Official words the app never uses, by topic", "",
              "Full list: `official_words_missing_from_app.csv`.", "",
              "| Topic | Missing words |", "|---|---|"]
    lines += [f"| {topic} | {n} |" for topic, n in by_topic.most_common()]
    (OUT_DIR / "app_vs_official_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {len(app_rows)} app rows, {len(missing)} missing official words, summary "
          f"-> {OUT_DIR.relative_to(ROOT)}/")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("fetch").set_defaults(run=cmd_fetch)
    extract = sub.add_parser("extract")
    extract.add_argument("--pdf", help="reference PDF (default: the fetched copy)")
    extract.set_defaults(run=cmd_extract)
    sub.add_parser("compare").set_defaults(run=cmd_compare)
    args = parser.parse_args()
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
