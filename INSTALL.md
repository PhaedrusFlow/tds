# Pretest C GitHub Pages integration

This overlay keeps every existing quiz in practice mode and adds Pretest C in
mock mode. Practice tests continue to reveal feedback immediately. Pretest C
records each answer without feedback and reveals correctness on the final
results and review screens.

## Install the overlay

From the root of the `tds` repository, back up the affected files:

```bash
cp scripts/build-quiz-manifest.mjs scripts/build-quiz-manifest.mjs.bak
cp scripts/q.sh scripts/q.sh.bak
cp ta/quizzes/app.js ta/quizzes/app.js.bak
cp .github/workflows/pages.yml .github/workflows/pages.yml.bak
```

Copy the overlay into the repository:

```bash
cp -R /path/to/tds-mock-pages-bundle/. .
chmod 755 scripts/q.sh
```

The overlay places files at:

```text
.github/workflows/pages.yml
scripts/build-quiz-manifest.mjs
scripts/q.sh
ta/mock/pretest-c.json
ta/quizzes/app.js
```

It does not replace `ta/quizzes/index.html`, `ta/quizzes/styles.css`, or any
existing practice-test JSON file.

## Configure the Pages access-code hash

Run this from the repository root:

```bash
read -rsp 'Pretest C password: ' pretest_c_password
printf '\n'
pretest_c_hash="$(
    printf '%s' "${pretest_c_password}" |
        sha256sum |
        cut -d' ' -f1
)"
unset pretest_c_password
printf '%s' "${pretest_c_hash}" |
    gh secret set PRETEST_C_PASSWORD_SHA256
unset pretest_c_hash
```

The workflow publishes only the SHA-256 hash, not the entered plaintext
password.

## Validate locally

```bash
node --check scripts/build-quiz-manifest.mjs
node --check ta/quizzes/app.js
scripts/q.sh
jq '.[] | select(.id == "pretest-c")' \
    ta/quizzes/data/manifest.json
git diff --check
```

Commit and push only after reviewing the changes:

```bash
git status --short
git diff
```

## Security boundary

GitHub Pages is static hosting. The password dialog is a convenience gate, not
access control: a visitor can inspect the deployed files and retrieve
`data/pretest-c.json` directly. Real protection requires keeping the mock JSON
and grading data on a server-side API rather than publishing them to Pages.
