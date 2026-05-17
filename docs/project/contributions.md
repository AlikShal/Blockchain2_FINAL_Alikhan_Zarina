# Team Contributions

This document records the contribution breakdown for the Option C — RWA Tokenization Platform project.

**Team:** Alikhan, Zarina

---

## Contribution Summary

| Area | Primary |
|---|---|
| Smart Contract Architecture | Alikhan |
| Governance Implementation | Alikhan |
| Frontend Development | Zarina |
| Deployment Scripts | Alikhan |
| Testing Suite | Alikhan, Zarina |
| Security Review | Alikhan, Zarina |
| Documentation | Zarina |
| Subgraph Integration | Zarina |
| CI/CD Pipeline | Alikhan |

---

## 1. Smart Contracts

**Primary: Alikhan**

Designed and implemented the full on-chain protocol:

- `AssetRegistry` — UUPS-upgradeable registry with role-based issuer authorization, asset record storage, and pause/unpause controls
- `AssetRegistryV2` — upgrade-path demonstration that extends V1 without storage collision
- `AssetToken` — ERC-20 with `MINTER_ROLE` / `BURNER_ROLE` gating, supply cap, ERC20Burnable, and ERC20Permit
- `AssetReceipt` — ERC-1155 receipt layer with per-token supply caps and issuer-controlled minting
- `AssetVault` — ERC-4626 reserve vault with 1:1 collateral backing, per-user accounting, and health-ratio enforcement
- `AMM` — constant-product AMM with 0.3% swap fee, slippage protection, LP token minting, and assembly-optimized square root
- `PriceOracle` — Chainlink AggregatorV3Interface wrapper with stale-price, invalid-round, and non-positive-price protection
- `VaultFactory` — deterministic vault deployment via `CREATE` and `CREATE2`
- Mock contracts for testing: `MockERC20`, `MockV3Aggregator`

---

## 2. Governance Implementation

**Primary: Alikhan**

Implemented and configured the full OpenZeppelin governor stack:

- `GovernanceToken` — ERC20Votes + ERC20Permit with 100M token cap; initial 1M mint to deployer
- `ProtocolGovernor` — composed from `GovernorSettings`, `GovernorCountingSimple`, `GovernorVotes`, `GovernorVotesQuorumFraction`, and `GovernorTimelockControl`
- Governance parameters: 43,200-block voting delay (~1 day on Base), 302,400-block voting period (~1 week), 10,000 GOV proposal threshold, 4% quorum
- `TimelockController` — 2-day execution delay; `ProtocolGovernor` granted `PROPOSER_ROLE` and `CANCELLER_ROLE`
- Governance demo script: `CreateProposal.s.sol` for self-delegation and proposal creation

---

## 3. Frontend Development

**Primary: Zarina**

Built the React dApp using Vite and Wagmi:

- `App.jsx` — main dashboard with tabbed interface covering vault deposit/withdrawal, AMM swap, governance proposal feed, and oracle price display
- `wagmi.js` — Wagmi client with Base Sepolia chain config, Alchemy RPC provider, and wallet connectors
- `contracts.js` — ABI definitions and contract address loading from environment variables
- `errors.js` — human-readable error message mapping for on-chain reverts
- GraphQL integration via Apollo for subgraph queries on proposal and vault position history
- `frontend/.env.example` — frontend environment variable template

---

## 4. Deployment Scripts

**Primary: Alikhan**

Authored the Foundry broadcast scripts:

- `Deploy.s.sol` — deploys all ten protocol contracts in dependency order, seeds AMM liquidity (10,000 + 10,000), seeds vault deposit (5,000), registers mock asset, and performs complete role handoff from deployer to `TimelockController`
- `VerifyPostDeploy.s.sol` — post-deployment assertion script validating role assignments, ownership transfers, governance parameters, and deployer role renunciation
- `CreateProposal.s.sol` — governance demo: self-delegate, create a no-op proposal, and emit events for subgraph indexing
- Provided flattened contract variants (`flat_*.sol`, `flat_*.s.sol`) for block explorer verification

---

## 5. Testing Suite

**Primary: Alikhan, Zarina**

Jointly designed and implemented the 82-test suite across nine files:

- `ProtocolCore.t.sol` — registry lifecycle, upgrade path, vault factory (Alikhan)
- `AMM.t.sol` — swap mechanics, fee calculation, slippage, sqrt comparison (Alikhan)
- `AssetToken.t.sol` — mint/burn, permit, role gating (Zarina)
- `AssetVault.t.sol` — ERC-4626 flows, reserve ratio, health checks (Zarina)
- `Governance.t.sol` — proposal lifecycle, voting, timelock execution (Alikhan)
- `OracleAndSecurity.t.sol` — reentrancy and access-control case studies, oracle validation (Alikhan, Zarina)
- `FuzzAndInvariant.t.sol` — fuzz tests and seven protocol invariants (Alikhan)
- `GasBenchmark.t.sol` — gas snapshot benchmarks (Alikhan)
- `ForkReadiness.t.sol` — Sepolia fork validation (Zarina)

---

## 6. Security Review

**Primary: Alikhan, Zarina**

Conducted an internal security audit covering:

- Manual review of all external call sites, mint/burn flows, upgrade path, and governance lifecycle
- CEI pattern and `ReentrancyGuard` verification across `AMM`, `AssetVault`
- Reentrancy and access-control case studies implemented and documented in `OracleAndSecurity.t.sol`
- Oracle attack surface analysis: stale-price, invalid-round, and zero-price vectors
- Governance attack analysis: flash-loan governance, whale capture, proposal spam, timelock bypass
- Centralization analysis confirming deployer key is stripped of all admin roles post-deployment
- Slither static analysis; 66 contracts analyzed with zero High or Medium findings

See [audit-report.md](../audit/audit-report.md) for the full report.

---

## 7. Documentation

**Primary: Zarina**

Authored and organized the project documentation:

- `docs/architecture/architecture.md` — system design, component responsibilities, user-flow diagrams (Mermaid), storage layout, trust assumptions, ADR log
- `docs/architecture/gas-optimization.md` — compiler settings, immutables, calldata, custom errors, storage considerations, AMM efficiency
- `docs/architecture/deployment-verification.md` — prerequisites, environment variables, deployment flow, post-deploy verification, frontend startup, subgraph deployment
- `docs/audit/audit-report.md` — internal security audit with findings table and detailed analysis
- `docs/audit/testing-coverage.md` — test suite structure, fuzz strategy, invariants, CI integration, Slither results
- `docs/audit/slither-findings.md` — static analysis summary
- `docs/audit/reentrancy-case-study.md` — CEI pattern comparison
- `docs/audit/access-control-case-study.md` — role-based access control patterns
- `docs/DELIVERABLE_MATRIX.md` — requirements-to-evidence tracking
- `README.md` — project overview and quick-start guide

---

## 8. Subgraph Integration

**Primary: Zarina**

Designed and implemented The Graph indexing layer:

- `subgraph/schema.graphql` — six entity types: `Asset`, `VaultPosition`, `Proposal`, `Vote`, `Swap`, plus supporting types
- `subgraph/src/protocol.ts` — AssemblyScript event handlers for registry, vault, AMM, and governance events
- `subgraph/subgraph.yaml` — data source configuration for four contracts (AssetRegistry, AssetVault, AMM, ProtocolGovernor) with Sepolia network config
- ABI files in `subgraph/abis/` for each indexed contract
- Frontend Apollo queries wired to the subgraph endpoint

---

## 9. CI/CD Pipeline

**Primary: Alikhan**

Configured the GitHub Actions CI/CD pipeline (`.github/workflows/ci.yml`):

- `foundry` job: Node/frontend/subgraph dependency installation, Solidity formatting check, Solhint linting, frontend build, subgraph codegen and build, contract compilation, full test run, and coverage report
- `slither` job: Python 3.11 setup, Slither installation, and static analysis with dependency exclusion
- Both jobs run on every push and pull request to `main`
- `package.json` scripts provide npm-level aliases for all Foundry and deployment commands
