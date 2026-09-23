# Reusable Instruction Addendum: <capability>

Use this for the reusable half of the Astra/Fable handoff. Replace placeholders
and remove author notes. Keep it brief; do not append task transcripts or results
that will become stale. Propose changes before replacing an existing policy.

## Trigger and scope

Use when <specific task or failure pattern>. Do not use for <adjacent non-example>.
Prerequisites: <runtime/tool/access assumptions that must be checked>.

## Procedure

1. Inspect <specific source of truth>; finish when <observable condition>.
2. Establish <contract/invariant/limit>; finish when <observable condition>.
3. Apply <bounded transformation>; finish when <observable condition>.
4. Run <verified gate or method for selecting it>; finish when <pass condition>.
5. Report <evidence and exception fields>; stop on <failure or missing evidence>.

## Failure and remedy

- <Observed failure>: <specific remedy; do not guess a tool/API>.
- <Resource or security hazard>: <enforced bound or permission boundary>.
- <Tempting false success>: <evidence required instead>.

## Example

- Input: <small concrete input>
- Required output: <exact behavior/schema>
- Rejected output: <concrete incorrect behavior and reason>

## Packaging

For `AGENTS.md`, retain only relevant durable rules and the source of truth.
For a standalone Agent Skill, put the instructions into `<skill-name>/SKILL.md`
with valid frontmatter, then validate the complete directory:

```yaml
---
name: <lowercase-hyphenated-name-matching-directory>
description: "<what this does, when to use it, and adjacent exclusion>"
---
```

The frontmatter above is a fill-in template, not an installable finished skill.
Keep exact task paths, model versions, machine credentials, and old test counts
out of reusable policy unless they are stable, necessary, and independently checked.
