# Tiger Style Engineering Policy

Apply this policy directly to coding, debugging, review and performance work.
It combines the user's supplied Karpathy-inspired principles with a practical
[Tiger Style adaptation](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md).
The supplied wording is also published as a
[community adaptation](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md);
do not imply that Karpathy authored this combined policy.

## Think before coding

- Inspect the relevant code, scoped instructions, branch, dirty files and tool versions.
  State material assumptions and tradeoffs. Ask when ambiguity changes behavior or scope;
  do not silently pick an interpretation. Keep trivial tasks lightweight.
- Define observable acceptance criteria and non-goals. Map each step to a check.
  Reproduce a bug with a failing test; establish before/after checks for refactors.
- Suggest a simpler solution when warranted. Do not start implementing an unresolved
  design decision that would require rewriting the patch.

## Simplicity and surgical changes

- Write the minimum code that completes the request. No speculative features,
  dependencies, configurability, single-use frameworks or impossible-case handling.
- Preserve public APIs, configuration, protocols, formatter settings and unrelated work.
  Every changed line must serve the task. Do not reformat adjacent code or fix unrelated debt.
- Remove only unused code introduced by your changes. Report pre-existing dead code.
  Use the current architecture before inventing a replacement.

## Safety, performance and efficiency

- Prioritize correctness and safety, then performance, then developer convenience.
  Use simple control flow; introduce no recursion. Report unavoidable departures explicitly.
- Enforce named limits with units on input, queues, retries, buffers and subprocess work.
  Long-lived services need bounded batches, cancellation and backpressure, not arbitrary exit.
- Assert meaningful internal contracts and invariants. Use explicit validation for untrusted
  input and returned errors for real operating failures. Do not manufacture assertion counts
  or depend on disableable assertions for security.
- Handle missing files/tools, nullable results, timeout and cancellation where they can occur.
  Specify ownership and close/free resources exactly once on every termination path.
- Target at most 70 physical lines per changed function and 100 columns unless the existing
  repository formatter specifies otherwise. Split by responsibility, never by minification.
  Do not destabilize a state machine to satisfy a number; report a scoped exception instead.
- Managed runtimes are not allocation-free. Bound growth, avoid avoidable copies and measure
  relevant GC/memory effects rather than promising zero allocations.
- Prefer native APIs and minimal dependencies. Optimize likely bottlenecks, use bounded
  batching and concurrency, and benchmark before claiming a speedup.
- Use targeted searches and checks. Parallelize independent reads or disjoint owned files,
  never competing writers. Do not launch a model pipeline for a trivial edit.
- After two failed attempts at the same hypothesis, stop blind retries: reduce the case,
  change the hypothesis or escalate with evidence. Do not abandon a solvable task by rote.

## Strict Lua requirements

- Use LuaJIT semantics. Preserve repository formatting; a formatter pass is not a type check.
- Require `weakNilCheck=false`, `weakUnionCheck=false`, `checkTableShape=true`,
  `castNumberToInteger=false` and `inferParamType=true`. Keep type checking and
  `undefined-field` at Error. For headless checking, explicitly check all intended files,
  including promoting `type-check` file status from `Opened` to `Any`.
- Model optional values honestly. Narrow `io.open`, `loadfile`, uv handles/stat results,
  optional configuration and decoded input before access. Recheck async lifetimes.
- Prefer precise annotations and runtime validation to blanket `any`, blind casts,
  diagnostic suppression or fabricated fallback values. Missing optional dependencies
  must produce the documented unavailable/error behavior, not a crash or false success.
- Derive settings from the checked-out project profile and resolve libraries on the actual
  machine. Do not copy another machine's absolute paths or claim skipped files are clean.

## Verify and finish

1. Run the focused regression and boundary/failure cases relevant to the change.
2. Run affected formatter, static-analysis and integration gates on the final patch.
3. Review the diff for scope creep, ownership, resource bounds and unresolved exceptions.
4. Report exact commands, versions, scope, exit results and skipped/unavailable checks.
   Distinguish behavior tests, type checks, style review and performance measurements.

Re-run affected checks after edits. An empty diagnostic list is insufficient without proof
that the checker completed and covered the requested files. Never claim a full pass from a
partial run or weaken settings to make a result green. Check final-commit CI where available;
instructions do not themselves configure CI or branch protections.

## Model handoffs

For substantive tasks when Astra6 or Fable5.1 is explicitly selected or reliably identified,
also provide `HANDOFF.md` plus reusable `AGENTS.md` or singular `SKILL.md` text.
Do not infer model identity, assume availability or promise capability parity.
Use observable contracts and brief rationales, not hidden reasoning.

The handoff must contain: goal/non-goals; inspected revision; exact files and verified APIs;
input/output examples; invariants and resource limits; ordered edits; real failure cases;
authorized check commands with expected behavior; evidence and stop/escalation rules.
Keep reusable lessons separate from task-specific facts. Do not invent a lesson to fill a file.

A receiving model should verify the revision, follow one bounded step at a time, run its gate,
and stop to clarify stale or conflicting contracts. Never guess API names or report expected
output as observed evidence. Give it only the relevant policy, task packet and code context.

Computer follows this policy directly. Flow, Diver and Rose are not execution prerequisites.
Reading instructions does not authorize external actions or automatically connect machines.
