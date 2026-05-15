# Deliverable Matrix

| Requirement | Evidence in Repo | Status |
| --- | --- | --- |
| Foundry smart contracts | `src/`, `script/`, `test/` | Done |
| Unit, fuzz, invariant, fork tests | `test/` with 82 passing tests | Done |
| Frontend dApp | `frontend/` Vite + React + Wagmi dashboard | Done, pending deployed addresses |
| The Graph subgraph | `subgraph/` with schema, mappings, ABIs, queries | Done, pending deployment |
| Deployment scripts | `script/Deploy.s.sol`, `script/VerifyPostDeploy.s.sol` | Done |
| Security audit report | `docs/audit/audit-report.md` | Done |
| Architecture document | `docs/architecture/architecture.md` | Done |
| Gas report | `reports/gas/gas-report.md` | Done |
| Coverage report | `reports/coverage/coverage.md` | Done |
| README | `README.md` | Done |
| L2 verified addresses | Not yet committed | Pending external deployment |
| Final slide deck PDF | Not in repo | Pending manual presentation work |

## Current Gaps That Still Need External Execution

The following items cannot be truthfully completed without running against a live L2 environment:

- Deploying all contracts to Base Sepolia or another approved L2
- Verifying those contracts on the explorer
- Publishing the subgraph with real addresses
- Capturing final L1 vs L2 gas comparison for live deployments
- Preparing and exporting the slide deck PDF
