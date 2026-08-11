# #################################################################
# /qompassai/.GH/PF/tds/successbuilder/development/journal_reviewer/5_JGME_D_26_00586/pdf2md.py
# Qompass AI Pdf2md
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
#!/usr/bin/env python3
"""Convert a text-based PDF to reviewer-friendly, page-anchored Markdown.

Every extracted visual line receives a stable reference:
  [P006 L023] Text on PDF page 6, line 23

When a PDF has a line-number gutter, the script detects numeric gutter labels and
uses them as LNNN. Otherwise it numbers the extracted visual lines on each page.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path
from statistics import median

try:
    import pymupdf as fitz
except ImportError:
    try:
        import fitz  # PyMuPDF <= 1.24
    except ImportError:
        sys.exit("PyMuPDF is required: install with `uv tool install pymupdf` or `pip install PyMuPDF`.")


ONLY_NUMBER = re.compile(r"^\s*(\d{1,4})\s*$")
WHITESPACE = re.compile(r"\s+")


def text_from_line(line: dict) -> str:
    return "".join(span.get("text", "") for span in line.get("spans", [])).strip()


def extracted_lines(page: fitz.Page) -> list[dict]:
    lines: list[dict] = []
    for block in page.get_text("dict", sort=True).get("blocks", []):
        if block.get("type") != 0:
            continue
        for line in block.get("lines", []):
            text = text_from_line(line)
            if not text:
                continue
            x0, y0, x1, y1 = line["bbox"]
            lines.append({"text": text, "x0": x0, "y0": y0, "x1": x1, "y1": y1})
    return sorted(lines, key=lambda item: (round(item["y0"], 1), item["x0"]))


def gutter_numbers(lines: list[dict], page_width: float) -> list[dict]:
    """Return numeric-only lines likely placed in a left or right line-number gutter."""
    candidates = []
    for item in lines:
        match = ONLY_NUMBER.match(item["text"])
        if not match:
            continue
        in_left_gutter = item["x1"] <= page_width * 0.22
        in_right_gutter = item["x0"] >= page_width * 0.78
        if in_left_gutter or in_right_gutter:
            candidates.append({**item, "number": int(match.group(1))})

    # A real line-number gutter has a sequence, not merely an isolated page number.
    return candidates if len(candidates) >= 5 else []


def nearest_gutter_number(item: dict, numbers: list[dict]) -> int | None:
    center_y = (item["y0"] + item["y1"]) / 2
    line_height = max(1.0, item["y1"] - item["y0"])
    close = [
        number
        for number in numbers
        if abs(((number["y0"] + number["y1"]) / 2) - center_y) <= max(4.0, line_height * 0.8)
    ]
    if not close:
        return None
    return min(close, key=lambda number: abs(((number["y0"] + number["y1"]) / 2) - center_y))["number"]


def probable_manuscript_page(lines: list[dict], page_width: float, page_height: float) -> str | None:
    """Find a centered, bottom-of-page printed page number when present."""
    centered = []
    for item in lines:
        match = ONLY_NUMBER.match(item["text"])
        if not match or item["y0"] < page_height * 0.80:
            continue
        midpoint = (item["x0"] + item["x1"]) / 2
        if abs(midpoint - page_width / 2) <= page_width * 0.18:
            centered.append(match.group(1))
    return centered[-1] if centered else None


def markdown_for_page(page: fitz.Page, pdf_page_number: int) -> str:
    width, height = page.rect.width, page.rect.height
    lines = extracted_lines(page)
    numbers = gutter_numbers(lines, width)
    gutter_ids = {(item["x0"], item["y0"], item["text"]) for item in numbers}
    manuscript_page = probable_manuscript_page(lines, width, height)

    heading = f"## PDF page {pdf_page_number}"
    if manuscript_page and manuscript_page != str(pdf_page_number):
        heading += f" (printed manuscript page {manuscript_page})"

    output = [heading, "", "<!-- Reference format: PDF page / line number. -->", ""]
    generated_line = 0
    used_source_numbers: defaultdict[int, int] = defaultdict(int)

    for item in lines:
        key = (item["x0"], item["y0"], item["text"])
        if key in gutter_ids:
            continue

        # Ignore a lone centered footer page number; it is represented in the heading.
        if (
            ONLY_NUMBER.match(item["text"])
            and item["y0"] >= height * 0.80
            and abs(((item["x0"] + item["x1"]) / 2) - width / 2) <= width * 0.18
        ):
            continue

        generated_line += 1
        source_line = nearest_gutter_number(item, numbers)
        if source_line is not None:
            used_source_numbers[source_line] += 1
            # Split text fragments on the same visual source line retain a unique suffix.
            label = f"L{source_line:03d}"
            if used_source_numbers[source_line] > 1:
                label += chr(96 + used_source_numbers[source_line])
        else:
            label = f"L{generated_line:03d}"

        text = WHITESPACE.sub(" ", item["text"])
        anchor = f"pdf-{pdf_page_number:03d}-{label.lower()}"
        output.append(f'<a id="{anchor}"></a>[P{pdf_page_number:03d} {label}] {text}')

    return "\n".join(output).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create page- and line-referenced Markdown for peer review."
    )
    parser.add_argument("pdf", type=Path, help="Input PDF")
    parser.add_argument(
        "-o", "--output", type=Path, help="Output .md path (default: <pdf-stem>.review.md)"
    )
    parser.add_argument(
        "--pages",
        help="1-based PDF page selection, for example: 4-32 or 4,6-10 (default: all pages)",
    )
    args = parser.parse_args()

    if not args.pdf.is_file():
        parser.error(f"PDF not found: {args.pdf}")
    if args.pdf.suffix.lower() != ".pdf":
        parser.error("Input must be a PDF.")

    doc = fitz.open(args.pdf)
    selected = list(range(len(doc)))
    if args.pages:
        selected = []
        for part in args.pages.split(","):
            part = part.strip()
            if not part:
                continue
            if "-" in part:
                start, end = (int(value) for value in part.split("-", 1))
                selected.extend(range(start - 1, end))
            else:
                selected.append(int(part) - 1)
        selected = sorted(set(selected))
        if any(index < 0 or index >= len(doc) for index in selected):
            parser.error(f"--pages must be within 1-{len(doc)}.")

    output_path = args.output or args.pdf.with_suffix(".review.md")
    title = args.pdf.stem.replace("_", " ")
    document = [
        f"# Reviewer copy: {title}",
        "",
        "Use citations such as `PDF p. 7, line 24` when writing review comments.",
        "Line labels use the PDF's printed gutter numbers when detected; otherwise they are generated from visual text lines on that PDF page.",
        "",
    ]
    for index in selected:
        document.append(markdown_for_page(doc[index], index + 1))

    output_path.write_text("\n".join(document).rstrip() + "\n", encoding="utf-8")
    print(f"Wrote {output_path} ({len(selected)} PDF pages).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
