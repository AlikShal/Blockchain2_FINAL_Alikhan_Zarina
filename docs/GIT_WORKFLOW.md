# Git Workflow

The exam explicitly cares about Git discipline, commit quality, and milestone timing. This is the workflow to follow.

## Branch Strategy
- `main`: always releasable, always green
- `feat/...`: new functionality
- `fix/...`: bug fixes
- `test/...`: test expansion
- `docs/...`: report and README work
- `ci/...`: workflow and automation changes

## Commit Format
Use Conventional Commits only:
- `feat:`
- `fix:`
- `test:`
- `docs:`
- `refactor:`
- `chore:`
- `ci:`

Examples:
- `feat(governance): add ERC20Votes token base`
- `feat(vault): scaffold ERC4626 reserve vault`
- `fix(amm): enforce minimum output slippage check`
- `test(fuzz): add deposit withdrawal roundtrip fuzz cases`
- `ci(foundry): add build test and coverage workflow`

## What To Commit First, Second, Third
1. First commit:
   - repo cleanup
   - new docs
   - folder skeleton
   - deployment script skeleton
   - CI skeleton

Suggested message:
`chore(repo): replace legacy handout files with exam project skeleton`

2. Second commit:
   - architecture lock
   - ownership file filled in
   - README update
   - environment example

Suggested message:
`docs(architecture): lock rwa platform scope and ownership`

3. Third commit:
   - governance token and timelock scaffolding
   - remove prototype governance

Suggested message:
`feat(governance): scaffold votes token governor and timelock stack`

4. Fourth commit:
   - ERC4626 vault scaffold
   - issuer roles
   - asset registry

Suggested message:
`feat(vault): add reserve vault and issuer-controlled rwa registry`

5. Fifth commit:
   - oracle adapter
   - stale price checks
   - mocks

Suggested message:
`feat(oracle): integrate chainlink adapter with stale feed guard`

6. Sixth commit:
   - CREATE / CREATE2 factory
   - upgradeable V1

Suggested message:
`feat(factory): add deterministic market deployment factory`

7. Seventh commit:
   - UUPS V2 upgrade path
   - upgrade tests

Suggested message:
`feat(upgrade): add v2 upgrade path and storage safety tests`

8. Eighth commit onward:
   - tests
   - frontend
   - subgraph
   - deployment
   - docs

## PR Workflow
1. Create branch from `main`.
2. Keep scope tight.
3. Push branch early.
4. Open PR with:
   - goal
   - files changed
   - risk notes
   - test evidence
5. Merge only after CI is green.

## Milestone Workflow
- End of Week 6:
  - `main` must already exist on GitHub
- End of Week 7:
  - CI must be green on `main`
- End of Week 8:
  - coverage checkpoint commit
- End of Week 9:
  - deployment and subgraph commits
- End of Week 10:
  - final documentation and presentation commits

## Minimum Git Hygiene
- Commit small, not giant dumps.
- Do not use messages like `final`, `fix`, `asdf`, `last version`.
- Make sure each teammate has visible authorship across commits and PRs.
