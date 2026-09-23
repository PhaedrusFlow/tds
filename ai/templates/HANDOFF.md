# Engineering Handoff: <task name>

Delete these author notes after filling the template. Target at most 8,000
characters for a bounded task packet; this is a workflow target, not a universal
model limit. Split larger work into independent packets instead of omitting
critical invariants. Do not embed secrets or an entire conversation.

## Mission

- Outcome: <observable result>
- Non-goals: <explicit exclusions>
- Acceptance criteria: <behavior and required gates>
- Execution mode: <read-only review / approved implementation>
- Author model: <reliably identified model or unknown>
- Receiving model: <configured model or unspecified; no inferred identity>

## Pinned context

- Repository and branch: <URL, branch>
- Commit and dirty-diff identity: <full SHA plus diff hash or clean>
- Approved instructions: <paths and version/hash>
- Workspace and machine: <absolute path, machine alias, OS/architecture>
- Runtime/tool versions: <actual versions>
- Relevant files and symbols: <verified paths, symbols, short purpose>
- Sources/fixtures: <paths or URLs; what each establishes>
- Unknowns: <must be resolved before implementation>

## Contract

- Inputs: <types, units, trust, valid range and maximum size>
- Outputs: <schema and examples>
- Errors: <operating errors versus invariant failures>
- State/ownership: <who owns resources, cleanup and cancellation>
- Invariants: <specific checkable properties, paired boundaries>
- Limits: <named values, units, derivation, overflow behavior>
- Compatibility: <public names/protocols to preserve>
- Security boundaries: <allowed files, tools, network, credentials>

## Ordered implementation

1. <Inspect/reproduce one specific fact; expected observation>
2. <Add or update the boundary/regression test; expected failure on baseline>
3. <Make the smallest specified change; exact files/symbols>
4. <Run the focused gate; exact expected behavior>
5. <Run required regression/static gates and inspect the final diff>

## Verification

For each gate fill:

| Gate | Working directory | Exact authorized argv/check name | Pass condition |
| --- | --- | --- | --- |
| Focused behavior | <cwd> | <argv> | <exit code and assertions> |
| Static coverage | <cwd> | <argv> | <coverage, zero relevant errors> |
| Regression | <cwd> | <argv> | <scope> |
| Tiger audit | <cwd> | <approved checker + manual review scope> | <no unapproved deviations> |
| Performance | <cwd> | <benchmark argv or not required> | <threshold or NOT_BENCHMARKED> |

Include applicable cases: empty/minimum/maximum/maximum-plus-one, malformed input,
missing dependencies, timeout, cancellation, stale state, and exact-once cleanup.
Specify which checks execute project code or may access network and require trust.

## Budgets and stop rules

- Time/tool/context/file-size budgets: <explicit limits>
- Retry budget: <after two attempts at one hypothesis, reduce the case or escalate>
- Stop on: missing permissions, stale base, conflicting instructions, absent
  required tool, unsafe command, changed API requirement, or exhausted budget.
- Escalate with: minimal reproducer, observed error, changed files, attempted
  fixes, remaining uncertainty, and the precise decision needed.
- Do not: change public contracts, expand scope, install dependencies, download
  models, send data externally, or commit/publish without authorization.

## Receiver result

- Changed files and final commit/diff identity:
- Behavior status and exact gate evidence:
- Static coverage:
- Tiger status and deviations:
- Performance evidence or NOT_BENCHMARKED:
- Risks, limitations, and next action:

If a tool requires its own result schema, use that schema exactly and put this
summary in a separate permitted artifact; do not break the tool's protocol.
