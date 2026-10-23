#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["pymupdf>=1.24"]
# ///
"""Convert a reviewer PDF into markdown with citable page and line numbers.

Purpose: research manuscripts under peer review arrive as PDFs (often
Editorial Manager bundles: cover page, figure placeholders, manuscript,
letters). Review comments need stable citations ("page 4, line 23"), and
markdown has no page concept, so this tool injects the structure itself:

    ## Page N            one section per PDF page, in order
    ```text               the page's text lines, numbered from 1
       1 | <line>
       2 | <line>
    ```

./pdf_to_markdown.py 11_NEXT_MANUSCRIPT_DIR     # converts every PDF inside
./pdf_to_markdown.py some-paper.pdf             # or a single file
./pdf_to_markdown.py some-paper.pdf -o out.md   # or name the output


Line numbers restart on every page and count text lines only; blank
lines mark paragraph breaks and carry no number. A citation "p.4 L.23"
therefore means: the 23rd numbered line under "## Page 4" of the
generated file. The conversion is deterministic: same PDF in, same
markdown out.

Input is one PDF file or a directory (every *.pdf directly inside it is
converted). Output lands beside each PDF as <stem>.md unless -o names a
single output file. Existing outputs are overwritten and reported.

Failure behavior: a missing input, a non-PDF file, or a directory with
no PDFs exits non-zero with a message and writes nothing. A PDF whose
pages carry no extractable text (scanned images) still converts, with a
warning that OCR is out of scope for this tool.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pymupdf

MAX_PDF_BYTES = 200 * 1024 * 1024  # reviewer bundles are a few MB; refuse absurd inputs
MAX_PAGES = 10_000


class ConversionError(Exception):
    """An input problem the operator can fix (bad path, unreadable PDF)."""


MARGIN_BAND_FRACTION = 0.06  # top/bottom band where a printed folio lives


def _is_margin_folio(text: str, y0: float, y1: float, page_height: float) -> bool:
    """True when a line is a lone page number sitting in a page margin.

    Editorial Manager stamps the printed folio in the footer (or
    header); the content stream often emits it first, which would make
    it line 1 of the page. Such lines are relocated, never deleted.
    """
    if not text.isdigit() or len(text) > 3:
        return False
    band = page_height * MARGIN_BAND_FRACTION
    return y0 < band or y1 > page_height - band


def page_lines(page: pymupdf.Page) -> list[str]:
    """Return one page's text lines in reading order, blanks preserved.

    Lines come from PyMuPDF's block/line structure, which follows the
    PDF's own content order -- reliable for the single-column layouts
    journals use for review copies. Consecutive blank lines collapse to
    one, and leading/trailing blanks are dropped, so a page's first
    numbered line is its first real text line. A margin folio found at
    either end of the page is moved to the end of the page's lines.
    """
    raw: list[tuple[str, float, float]] = []
    for block in page.get_text('dict')['blocks']:
        if block['type'] != 0:
            continue
        for line in block['lines']:
            text = ''.join(span['text'] for span in line['spans']).strip()
            if text:
                raw.append((text, line['bbox'][1], line['bbox'][3]))
            elif raw and raw[-1][0] != '':
                raw.append(('', 0.0, 0.0))
    while raw and raw[-1][0] == '':
        raw.pop()

    height = page.rect.height
    folios: list[str] = []
    for edge in ('first', 'last'):
        while raw:
            text, y0, y1 = raw[0] if edge == 'first' else raw[-1]
            if text == '' or not _is_margin_folio(text, y0, y1, height):
                break
            folios.append(text)
            raw.pop(0 if edge == 'first' else -1)
    return [text for text, _, _ in raw] + folios


def convert_pdf(pdf_path: Path) -> tuple[str, int, int]:
    """Convert one PDF to markdown text.

    Returns (markdown, page_count, numbered_line_count). Raises
    ConversionError when the file cannot be opened as a PDF.
    """
    try:
        doc = pymupdf.open(pdf_path)
    except pymupdf.FileNotFoundError:
        raise ConversionError(f'no such file: {pdf_path}') from None
    except RuntimeError as exc:
        raise ConversionError(f'cannot open {pdf_path} as a PDF: {exc}') from exc
    if doc.page_count > MAX_PAGES:
        raise ConversionError(
            f'{pdf_path}: {doc.page_count} pages exceeds limit {MAX_PAGES}'
        )

    parts: list[str] = [
        f'# {pdf_path.stem}',
        '',
        f'Source: `{pdf_path.name}` | PDF pages: {doc.page_count}',
        'Line numbers restart each page and count text lines only;',
        'cite as p.<page> L.<line> (e.g. p.4 L.23).',
        "A printed folio in a page margin is moved to the end of that page's lines.",
        '',
    ]
    numbered_total = 0
    for index, page in enumerate(doc, start=1):
        lines = page_lines(page)
        parts.append(f'## Page {index}')
        parts.append('')
        parts.append('```text')
        number = 0
        for line in lines:
            if line == '':
                parts.append('')
            else:
                number += 1
                parts.append(f'{number:>4} | {line}')
        numbered_total += number
        parts.append('```')
        parts.append('')
    return '\n'.join(parts), doc.page_count, numbered_total


def collect_inputs(target: Path) -> list[Path]:
    """Resolve the CLI input to the list of PDFs to convert."""
    if target.is_dir():
        pdfs = sorted(target.glob('*.pdf'))
        if not pdfs:
            raise ConversionError(f'no PDF files in directory: {target}')
        return pdfs
    if target.is_file():
        if target.suffix.lower() != '.pdf':
            raise ConversionError(f'not a PDF file: {target}')
        if target.stat().st_size > MAX_PDF_BYTES:
            raise ConversionError(f'{target}: exceeds {MAX_PDF_BYTES} bytes')
        return [target]
    raise ConversionError(f'no such file or directory: {target}')


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description='Convert reviewer PDFs to markdown with page/line numbers.',
    )
    parser.add_argument('input', type=Path, help='a PDF file, or a directory of PDFs')
    parser.add_argument(
        '-o',
        '--output',
        type=Path,
        help='output file (single-PDF input only); default: <stem>.md beside the PDF',
    )
    args = parser.parse_args(argv)

    try:
        pdfs = collect_inputs(args.input)
        if args.output is not None and len(pdfs) != 1:
            raise ConversionError('-o/--output requires a single PDF input')
        for pdf_path in pdfs:
            markdown, pages, numbered = convert_pdf(pdf_path)
            out_path = (
                args.output if args.output is not None else pdf_path.with_suffix('.md')
            )
            out_path.write_text(markdown, encoding='utf-8')
            print(
                f'{pdf_path.name} -> {out_path} ({pages} pages, {numbered} numbered lines)'
            )
            if numbered == 0:
                print(
                    f'warning: {pdf_path.name} has no extractable text '
                    '(scanned images?); OCR is out of scope',
                    file=sys.stderr,
                )
    except ConversionError as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
