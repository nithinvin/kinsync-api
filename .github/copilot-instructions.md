# Repository Guidelines & AI Context: kinsync-api

The primary AI/contributor guide for this repo is [`CLAUDE.md`](../CLAUDE.md) — read it first.

## Governance
- **CONSTITUTION FIRST**: All code, architectural choices, refactoring, and AI responses MUST
  strictly adhere to `CONSTITUTION.md` at the repository root, which builds on the
  [KinSync Common Engineering Principles](https://github.com/nithinvin/kinsync-docs/blob/main/engineering/common-principles.md).

## Development Workflow
Specs, design and plans live in [nithinvin/kinsync-docs](https://github.com/nithinvin/kinsync-docs),
not in this repo. When the user requests a new feature, enhancement, or fix:
1. Check the current phase in `plan/roadmap.md` and its `plan/phase-N.md`.
2. Update requirements (`specs/requirements.md`, `specs/acceptance-criteria.md`) and, for any
   endpoint change, `design/api-contract.md` **before** implementing.
3. After implementing, update the phase file and `specs/traceability.md` with status and commit SHA.
