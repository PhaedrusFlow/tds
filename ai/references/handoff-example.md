# Worked Handoff Example

This is an illustrative Python task, not a patch to Flow, Rose, or Diver.
The paths, commands, and outcomes below are a teaching fixture and were not run.
An author must replace them with inspected facts for a real repository.

## Mission and contract

Implement `decode_frame(payload: bytes) -> dict` in the hypothetical
`src/example/frame.py`. Do not add networking, streaming, retries, or a new API.
The existing hypothetical API raises `ValueError` for invalid external frames.

- Define `FRAME_BYTES_MAX = 4096`; reject larger frames before UTF-8 decoding or JSON
  parsing. The limit is a task requirement, not an inferred provider/protocol limit.
- Accept only a JSON object with exactly `{"message": <string>}`. The message length
  must be 1 through 1024 Unicode code points. Duplicate JSON keys are invalid.
- Reject empty bytes, malformed UTF-8, malformed JSON, non-object roots, extra keys,
  duplicate keys, wrong value types, and out-of-range lengths with `ValueError`.
- Do not log payload contents. Do not silently truncate input or normalize output.
- Assert trusted internal invariants after validation; do not use an assertion
  to validate user-controlled bytes. No recursion in application code.
- Delegated standard-library JSON parsing is not a proof of allocation-free or
  recursion-free execution; record this dependency/runtime adaptation explicitly.

## Steps for the receiving model

1. Inspect the real equivalent of `src/example/frame.py` and its tests. If its API
   differs from this hypothetical contract, stop and ask rather than rename it.
2. Add boundary tests with exactly 4096 bytes and 4097 bytes. Use legal trailing
   JSON whitespace to reach the allowed byte size without violating message limits.
3. Test message lengths 0, 1, 1024, and 1025 independently of byte-size bounds.
   Test multibyte UTF-8 because byte length and Unicode code-point length differ.
4. Add malformed/duplicate-key/root-type cases. Verify overflow rejection occurs
   before parsing using an existing test seam; do not build a new framework for it.
5. Implement small helpers with a single ownership/control path. Keep functions
   at most 70 lines and source at most 100 columns.
6. Run focused tests, lint/type checks, then the affected regression suite on the
   final diff. Do not add dependencies just to satisfy the illustrative commands.

## Illustrative gates, to verify before use

From the hypothetical repository root, with already installed project tools:

```sh
python -m pytest -q tests/test_frame.py
python -m ruff check src/example/frame.py tests/test_frame.py
python -m pytest -q
```

Expected behavior, not observed results: required tests pass and lint reports no
relevant errors. No performance improvement is claimed; this is a correctness and
resource-bound change, with parsing work capped by the byte-size limit.

## Escalation

After two failed repairs of the same hypothesis, reduce the case or escalate.
Return the failing input, observed exception, diff and unresolved contract question.
Do not accept duplicate keys, raise the byte cap, or weaken tests to obtain a pass.

## Reusable lesson

For parsers, distinguish raw-byte bounds from decoded semantic bounds. Enforce
the byte bound before decoding/allocation-heavy parsing; then validate schema
and semantic ranges. Tests must independently exercise each bound and the
valid-to-invalid transition. These are actionable instructions, not a request
to reveal or imitate another model's hidden reasoning.
