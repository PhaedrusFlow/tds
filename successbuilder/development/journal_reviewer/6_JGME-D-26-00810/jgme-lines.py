#!/usr/bin/env python3
# #################################################################
# jgme-lines.py
# Qompass AI JGME Exact Manuscript Line Extractor
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Reconstructs the manuscript's *printed* 1-65 line-number grid by
# matching PDF text to the line-number gutter using PDF coordinates.
#
# Requires:
#   python
#   poppler / pdftotext
# #################################################################

from __future__ import annotations

import argparse
import shutil
import statistics
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

NS = {"x": "http://www.w3.org/1999/xhtml"}

LINE_MIN = 1
LINE_MAX = 65

# The JGME reviewer manuscript line-number gutter is at x ~= 18-30.
GUTTER_X_MAX = 40.0

# Normal manuscript content begins well to the right of the gutter.
BODY_X_MIN = 45.0

# Printed manuscript page number is in the lower-right corner.
FOOTER_X_MIN = 450.0
FOOTER_Y_MIN = 700.0


def fattr(node: ET.Element, name: str) -> float:
    return float(node.attrib[name])


def line_words(line: ET.Element) -> list[ET.Element]:
    return line.findall("x:word", NS)


def words_text(words: list[ET.Element]) -> str:
    """Rebuild one PDF text line while preserving joined superscripts."""
    if not words:
        return ""

    text = words[0].text or ""
    previous_xmax = fattr(words[0], "xMax")

    for word in words[1:]:
        value = word.text or ""
        xmin = fattr(word, "xMin")
        gap = xmin - previous_xmax

        # Superscripts such as 30 + th, footnote numerals, etc, have
        # effectively zero horizontal gap and should stay attached.
        if gap <= 0.8:
            text += value
        else:
            text += " " + value

        previous_xmax = fattr(word, "xMax")

    return text.strip()


def bbox_document(pdf: Path) -> ET.Element:
    proc = subprocess.run(
        ["pdftotext", "-bbox-layout", str(pdf), "-"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        return ET.fromstring(proc.stdout)
    except ET.ParseError as exc:
        print(f"Unable to parse pdftotext bbox XML: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


def official_grid(page: ET.Element) -> dict[int, float]:
    """
    Return {printed_line_number: vertical_center} for the actual
    1-65 line-number gutter printed in the manuscript PDF.
    """
    grid: dict[int, float] = {}

    for line in page.findall(".//x:line", NS):
        words = line_words(line)
        if len(words) != 1:
            continue

        value = (words[0].text or "").strip()
        if not value.isdigit():
            continue

        number = int(value)
        if not LINE_MIN <= number <= LINE_MAX:
            continue

        if fattr(line, "xMax") > GUTTER_X_MAX:
            continue

        # Compare vertical centers, not pdftotext text rows.
        #
        # This is important because the body font and gutter-number font
        # have different bounding-box heights. Center-to-center matching
        # tracks the number visually printed beside the manuscript text.
        grid[number] = (fattr(line, "yMin") + fattr(line, "yMax")) / 2.0

    return grid


def manuscript_page_number(page: ET.Element) -> int | None:
    """Read the manuscript's own printed page number from the footer."""
    candidates: list[tuple[float, int]] = []

    for line in page.findall(".//x:line", NS):
        words = line_words(line)
        if len(words) != 1:
            continue

        value = (words[0].text or "").strip()
        if not value.isdigit():
            continue

        if fattr(line, "xMin") < FOOTER_X_MIN:
            continue

        if fattr(line, "yMin") < FOOTER_Y_MIN:
            continue

        candidates.append((fattr(line, "yMin"), int(value)))

    if not candidates:
        return None

    candidates.sort()
    return candidates[-1][1]


def line_pitch(grid: dict[int, float]) -> float:
    diffs = [
        grid[number + 1] - grid[number]
        for number in range(LINE_MIN, LINE_MAX)
        if number in grid and number + 1 in grid
    ]

    return statistics.median(diffs) if diffs else 11.34


def reconstruct_page(
    page: ET.Element,
    grid: dict[int, float],
) -> dict[int, str]:
    """
    Match every PDF body line to the nearest printed manuscript
    line number by vertical center.
    """
    pitch = line_pitch(grid)
    tolerance = pitch * 0.56

    top = min(grid.values()) - tolerance
    bottom = max(grid.values()) + tolerance

    fragments: dict[int, list[tuple[float, float, str]]] = defaultdict(list)

    for line in page.findall(".//x:line", NS):
        words = line_words(line)
        if not words:
            continue

        xmin = fattr(line, "xMin")
        xmax = fattr(line, "xMax")
        ymin = fattr(line, "yMin")
        ymax = fattr(line, "yMax")
        ycenter = (ymin + ymax) / 2.0

        # Do not copy the printed line-number gutter into the body.
        if xmax <= GUTTER_X_MAX:
            continue

        text = words_text(words)

        # Do not treat the printed manuscript page number as line text.
        if (
            xmin >= FOOTER_X_MIN
            and ymin >= FOOTER_Y_MIN
            and text.isdigit()
        ):
            continue

        # Ignore submission-system artifacts outside the numbered grid.
        if ycenter < top or ycenter > bottom:
            continue

        if xmax < BODY_X_MIN:
            continue

        number, distance = min(
            (
                (candidate, abs(ycenter - grid_y))
                for candidate, grid_y in grid.items()
            ),
            key=lambda item: item[1],
        )

        if distance > tolerance:
            continue

        fragments[number].append((xmin, xmax, text))

    result: dict[int, str] = {}

    for number in range(LINE_MIN, LINE_MAX + 1):
        parts = sorted(
            fragments.get(number, []),
            key=lambda item: item[0],
        )

        if not parts:
            result[number] = ""
            continue

        merged = parts[0][2]
        previous_xmax = parts[0][1]

        for xmin, xmax, text in parts[1:]:
            gap = xmin - previous_xmax

            # Large gaps usually mean separate table/column fragments.
            merged += ("    " if gap > 18.0 else " ") + text
            previous_xmax = max(previous_xmax, xmax)

        result[number] = merged.strip()

    return result


def extract(
    pdf: Path,
) -> list[tuple[int, int, dict[int, str]]]:
    root = bbox_document(pdf)
    pages = root.findall(".//x:page", NS)

    records: list[tuple[int, int, dict[int, str]]] = []

    for pdf_page, page in enumerate(pages, start=1):
        grid = official_grid(page)

        # The actual numbered manuscript pages in this JGME PDF have
        # essentially the complete 1-65 gutter. This automatically skips
        # PDF page 1 (submission sheet) and page 2 (cover letter).
        if (
            len(grid) < 60
            or LINE_MIN not in grid
            or LINE_MAX not in grid
        ):
            continue

        manuscript_page = manuscript_page_number(page)

        if manuscript_page is None:
            # Defensive fallback only; the uploaded manuscript has footers.
            manuscript_page = len(records) + 1

        records.append(
            (
                pdf_page,
                manuscript_page,
                reconstruct_page(page, grid),
            )
        )

    return records


def render_txt(
    records: list[tuple[int, int, dict[int, str]]],
) -> str:
    output: list[str] = []

    for pdf_page, manuscript_page, lines in records:
        output.append(
            "==================== "
            f"MANUSCRIPT PAGE {manuscript_page:03d} "
            f"/ PDF PAGE {pdf_page:03d} "
            "===================="
        )
        output.append("")

        for number in range(LINE_MIN, LINE_MAX + 1):
            text = lines[number]
            output.append(
                f"{number:2d}  {text}" if text else f"{number:2d}"
            )

        output.append("")

    return "\n".join(output).rstrip() + "\n"


def render_md(
    records: list[tuple[int, int, dict[int, str]]],
    title: str,
) -> str:
    output: list[str] = [
        f"# {title}",
        "",
        (
            "> Line numbers below are the manuscript's printed line numbers, "
            "reconstructed from PDF coordinates rather than generated text rows."
        ),
        "",
    ]

    for pdf_page, manuscript_page, lines in records:
        output.extend(
            [
                (
                    f"## Manuscript Page {manuscript_page} "
                    f"(PDF Page {pdf_page})"
                ),
                "",
                "```text",
            ]
        )

        for number in range(LINE_MIN, LINE_MAX + 1):
            text = lines[number]
            output.append(
                f"{number:2d}  {text}" if text else f"{number:2d}"
            )

        output.extend(["```", ""])

    return "\n".join(output).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Reconstruct exact printed JGME manuscript line numbers "
            "from PDF coordinates."
        )
    )

    parser.add_argument("pdf", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--format",
        choices=("txt", "md"),
        required=True,
    )
    parser.add_argument(
        "--title",
        default="JGME-D-26-00810 Reviewer Manuscript",
    )

    args = parser.parse_args()

    if not args.pdf.is_file():
        raise SystemExit(f"PDF not found: {args.pdf}")

    if shutil.which("pdftotext") is None:
        raise SystemExit(
            "pdftotext not found; install Poppler first"
        )

    records = extract(args.pdf)

    if not records:
        raise SystemExit(
            "No pages containing the official 1-65 manuscript "
            "line-number gutter were detected."
        )

    if args.format == "txt":
        content = render_txt(records)
    else:
        content = render_md(records, args.title)

    args.output.write_text(content, encoding="utf-8")

    print(
        f"Wrote {len(records)} numbered manuscript pages "
        f"to {args.output}"
    )


if __name__ == "__main__":
    main()
