---
name: tiger-efficient-engineering
description: "Apply Karpathy-inspired simplicity and Tiger Style safety to coding, debugging, refactoring, strict Lua checks and model handoffs. Use for bounded software changes and reusable agent instructions; not for unrelated writing or model rankings."
metadata:
  version: "2.0"
---
# Tiger-Efficient Engineering

Follow these guidelines directly; do not require Flow, Diver or Rose as workflow tools.
Read `references/engineering-policy.md` before substantive code changes or reviews.
For a trivial edit, use the short checklist below without manufacturing planning overhead.

## Execution checklist

1. Inspect relevant code and scoped instructions. State material assumptions and ask about
   ambiguity that would change the implementation. Done when scope and constraints are clear.
2. Define observable acceptance criteria and a brief step-to-check plan. Prefer a simpler
   solution where possible. Done when another model could distinguish a pass from a failure.
3. Make the minimum surgical change and relevant regression tests. Preserve repo formatting
   and unrelated work. Done when each changed line serves the requested result.
4. Check internal invariants, resource bounds, nullable results and cleanup. In Lua, preserve
   strict nil/union/table-shape checking; never silence diagnostics to pass.
   Done when failure paths are tested or explicitly documented as unverified.
5. Run focused then affected regression/static checks on the final diff. Review scope and
   Tiger deviations separately. Done only with command results and honest coverage.
6. For substantive work using explicitly selected Astra6/Fable5.1, or requested model transfer,
   provide both the task handoff and reusable instructions described below.

## Conditional resources

- When delegating or producing a handoff, fill `templates/HANDOFF.md` and
  `templates/REUSABLE_INSTRUCTIONS.md`. Use only inspected symbols and actual commands.
- When a receiving model needs a worked example, read `references/handoff-example.md`.
  Its sample results are illustrative, not evidence from this task.

## Output

Return the change, actual verification, skipped checks, exceptions and remaining risks.
Measure before claiming performance gains. Do not infer model identity or promise that
instructions make models equally capable. Keep process proportional to the task.
