# Blockchain Technologies 2 Final Project

This repository targets `Option C — RWA Tokenization Platform`.

## What Is Implemented

- Upgradeable `AssetRegistry` with documented `V1 -> V2` path
- `AssetToken` ERC-20 with role-gated mint/burn
- `AssetReceipt` ERC-1155 receipt layer
- `AssetVault` ERC-4626 reserve-backed vault
- Custom constant-product `AMM` with 0.3% fee and slippage protection
- Chainlink-style `PriceOracle` with stale-price protection
- `GovernanceToken` using `ERC20Votes + ERC20Permit`
- `ProtocolGovernor + TimelockController`
- `VaultFactory` using both CREATE and CREATE2
- Foundry unit, fuzz, invariant, security, gas, and fork-ready tests
- React + Wagmi frontend in `frontend/`
- The Graph subgraph scaffold with mappings in `subgraph/`

## Repository Layout

- `src/`: protocol contracts
- `test/`: unit, fuzz, invariant, fork, governance, oracle, and security tests
- `script/`: deployment and post-deployment verification scripts
- `frontend/`: Vite React dApp for wallet, vault, AMM, and governance flows
- `subgraph/`: Graph schema, mappings, ABIs, and documented queries
- `docs/`: architecture and audit documents
- `reports/`: coverage and gas reports

## Quick Start

### Contracts

```bash
npm install
forge build
forge test
slither . --filter-paths "lib|node_modules|out|cache" --exclude solc-version
```

### Frontend

```bash
cd frontend
npm install
copy .env.example .env
npm run dev
```

### Subgraph

```bash
cd subgraph
npm install
npm run codegen
npm run build
```

## Key Documents

- [Deliverable Matrix](docs/DELIVERABLE_MATRIX.md)
- [Architecture](docs/architecture/architecture.md)
- [Audit Report](docs/audit/audit-report.md)
- [Coverage Report](reports/coverage/coverage.md)
- [Gas Report](reports/gas/gas-report.md)

## Current Status

What is ready inside the repo:

- 82 passing Foundry tests
- Slither clean on the current snapshot
- Governance parameters moved closer to the final project specification
- Deployment verification script checks timelock ownership and privileged-role handoff
- Frontend and subgraph now have working project structure instead of placeholders

## Final Submission Status

Ready inside the repository:

- 82 passing Foundry tests
- 96.64% line coverage
- Slither clean on the current snapshot
- GitHub Actions CI passing on the latest commit
- Deployment verification script checks timelock ownership and privileged-role handoff
- Frontend and subgraph project structure completed

Live deployment evidence:

- Contracts deployed to Base Sepolia
- Contracts verified on BaseScan
- Subgraph published with live Base Sepolia addresses
- Verified contract addresses documented in `docs/deployment/addresses.md`
- L1 vs L2 gas comparison documented in `reports/gas/gas-report.md`
