#!/usr/bin/env fish
# #################################################################
# /qompassai/.GH/PF/tds/successbuilder/development/journal_reviewer/6_JGME-D-26-00810/md.sh
# Qompass AI Md
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
# #################################################################

set -l script_dir (dirname (status --current-filename))
set -l pdf "$script_dir/JGME-D-26-00810_reviewer.pdf"
set -l out "$script_dir/JGME-D-26-00810_reviewer-lines.md"
set -l extractor "$script_dir/jgme-lines.py"

if not type -q python
    echo 'error: python is required' >&2
    exit 127
end

if not type -q pdftotext
    echo 'error: pdftotext is required; install poppler' >&2
    exit 127
end

if not test -f "$pdf"
    echo "error: PDF not found: $pdf" >&2
    exit 1
end

if not test -f "$extractor"
    echo "error: extractor not found: $extractor" >&2
    exit 1
end

python "$extractor" \
    --format md \
    --title 'JGME-D-26-00810 Reviewer Manuscript' \
    "$pdf" \
    "$out"

or exit $status

echo "wrote: $out"
