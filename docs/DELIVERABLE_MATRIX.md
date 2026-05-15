# Deliverable Matrix

Use this file as the submission checklist that maps requirements to concrete artifacts.

| Requirement | Artifact | Current Status |
| --- | --- | --- |
| GitHub repo by Week 6 | remote repo + commit history | `todo` |
| Smart contract codebase | `src/` | `implemented for Phases 2-4` |
| 50+ tests | `test/` | `77 passing tests` |
| Fuzz tests | `test/FuzzAndInvariant.t.sol` | `11 fuzz tests` |
| Invariant tests | `test/FuzzAndInvariant.t.sol` | `7 invariant tests` |
| Fork tests | `test/ForkReadiness.t.sol` | `4 fork-ready tests` |
| >= 90% coverage | `reports/coverage/coverage.md` | `96.64% src line coverage` |
| ERC20Votes + ERC20Permit | `src/Governance.sol` | `implemented` |
| Governor + Timelock | `src/Governance.sol` + deploy script | `implemented` |
| ERC721 or ERC1155 | `src/AssetReceipt.sol` | `implemented as ERC1155 companion receipt` |
| ERC4626 vault | `src/AssetVault.sol` | `implemented` |
| Chainlink oracle | `src/PriceOracle.sol` | `implemented with mock tests` |
| CREATE + CREATE2 factory | `src/VaultFactory.sol` | `implemented and tested` |
| UUPS upgrade path | `src/AssetRegistry.sol` + `src/AssetRegistryV2.sol` | `implemented and tested` |
| Yul benchmark | `src/AMM.sol` + `reports/gas/gas-report.md` | `implemented` |
| Frontend dApp | `frontend/` | `todo` |
| Subgraph | `subgraph/` | `todo` |
| L2 deployment script | `script/Deploy.s.sol` | `protocol deployment script added` |
| Post-deploy verification | `script/VerifyPostDeploy.s.sol` | `role and vault checks added` |
| GitHub Actions | `.github/workflows/ci.yml` | `Foundry, coverage, and Slither` |
| Audit report | `docs/audit/` | `added` |
| Architecture report | `docs/architecture/architecture.md` | `added with Mermaid contract map` |
| Presentation deck | `docs/presentation/` | `todo` |
| Gas report | `reports/gas/gas-report.md` | `added` |
