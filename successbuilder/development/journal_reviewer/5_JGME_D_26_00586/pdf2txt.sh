#!/usr/bin/env bash
# #################################################################
# /qompassai/.GH/PF/tds/successbuilder/development/journal_reviewer/5_JGME_D_26_00586/pdf2txt.sh
# Qompass AI Pdf2txt
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
pdftotext -layout -f 4 -l 32 \
  JGME-D-26-00586_reviewer.pdf - |
perl -pe '
  s/[ \t]+$//;
  s/^[ \t]+//;
  s/[ \t]{2,}/ /g;
' |
awk '
BEGIN {
  pdf_page = 4
  printf "============================================================\n"
  printf " PAGE %d\n", pdf_page
  printf "============================================================\n\n"
}
{
  if (index($0, "\f")) {
    sub(/\f/, "")
    pdf_page++
    printf "\n\n============================================================\n"
    printf " PAGE %d\n", pdf_page
    printf "============================================================\n\n"
  }
  print
}
' > JGME-D-26-00586_reviewable.txt
