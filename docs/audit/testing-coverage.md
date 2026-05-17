# Testing Coverage and Methodology

This document describes the testing strategy, coverage metrics, test suite structure, and CI integration for the RWA tokenization protocol.

---

## 1. Overview

The test suite is implemented in Foundry and located in `test/`. It covers unit behavior, fuzz-driven property testing, protocol invariants, governance lifecycle, security case studies, and CI-validated static analysis.

| Metric | Value |
|---|---|
| Total passing tests | 82 |
| Line coverage | 96.64% (288 / 298) |
| Function coverage | 92.11% (70 / 76) |
| Slither findings (High / Medium) | 0 / 0 |
| Test files | 9 |
| Invariants enforced | 7 |

---

## 2. Test Files

### 2.1 Unit Tests

#### `ProtocolCore.t.sol` — 213 lines

Tests the full asset lifecycle through `AssetRegistry`, `AssetToken`, `AssetVault`, and `VaultFactory`:

- Registry initialization and role assignment
- Issuer authorization and revocation via `ISSUER_ADMIN_ROLE`
- Asset registration with `registerAsset` and metadata persistence
- Pause and unpause via `PAUSER_ROLE`
- ERC-1155 receipt minting through `AssetReceipt`
- Vault factory deployment via `CREATE` and `CREATE2`
- Upgrade path from `AssetRegistry` (V1) to `AssetRegistryV2` through the UUPS proxy

#### `AMM.t.sol` — 117 lines

Tests the constant-product AMM:

- Initial liquidity provisioning and LP token minting
- Swap A-for-B and B-for-A with expected output amounts
- Fee deduction at 0.3% (30 BPS)
- Slippage protection: reverts when output is below `minAmountOut`
- Liquidity removal and proportional token return
- Comparison of `sqrtSolidity` and `sqrtAssembly` for identical output

#### `AssetToken.t.sol` — 106 lines

Tests `AssetToken` as an ERC-20 with role-gated mint and burn:

- Minting up to `MAX_SUPPLY` (1,000,000,000 × 10¹⁸)
- Revert on mint exceeding supply cap
- Burning via `burn` and `burnFrom`
- `burnBackingFrom` called by authorized burner
- `MINTER_ROLE` and `BURNER_ROLE` gating
- Permit signature flow (EIP-2612)
- `remainingSupply` accounting

#### `AssetVault.t.sol` — 107 lines

Tests the ERC-4626 vault mechanics:

- `deposit` transfers collateral and mints `AssetToken` 1:1
- `withdraw` burns `AssetToken` and returns collateral
- ERC-4626 preview functions (`previewDeposit`, `previewWithdraw`, `previewMint`, `previewRedeem`)
- `getReserveRatio` returns 100 when fully backed
- `isHealthy` returns `true` when reserve ratio ≥ 100
- Per-user deposit tracking via `userDeposits`
- Insufficient deposit revert on over-withdrawal

#### `Governance.t.sol` — 146 lines

Tests the full governance lifecycle:

- `GovernanceToken` delegation and voting power checkpointing
- Proposal creation with `PROPOSAL_THRESHOLD` enforcement
- Casting votes: for, against, abstain
- Voting delay (`VOTING_DELAY_BLOCKS = 43,200`) and period (`VOTING_PERIOD_BLOCKS = 302,400`)
- Proposal state transitions: Pending → Active → Succeeded → Queued → Executed
- Timelock queueing and execution with 2-day delay
- Quorum threshold of 4%

### 2.2 Fuzz Tests

Located in `FuzzAndInvariant.t.sol` — 192 lines total (fuzz and invariant combined).

| Test | What is fuzzed |
|---|---|
| `testFuzzGetAmountOutPositive` | `amountIn` across the range [1 ether, 1,000 ether]; asserts output is always positive |
| `testFuzzSwapAForBRespectsSlippage` | Random `amountIn` and `extra`; confirms swap reverts when `minAmountOut` exceeds computed output |
| `testFuzzSwapBForARespectsSlippage` | Mirror of above for B-to-A direction |
| `testFuzzAddLiquidityMintsLp` | Random `amountA` and `amountB`; asserts LP balance increases |
| `testFuzzSqrtAssemblyMatchesSolidity` | Random `value` across [0, 2¹²⁸ − 1]; asserts assembly and Solidity sqrt agree |
| `testFuzzVaultDeposit` | Random deposit `amount`; asserts `AssetToken` balance matches |
| `testFuzzVaultWithdraw` | Random deposit and full withdrawal; asserts `userDeposits` reaches zero |
| `testFuzzAssetTokenMint` | Random `amount` up to `MAX_SUPPLY`; asserts correct balance |
| `testFuzzAssetTokenBurn` | Random `amount`; asserts balance returns to zero after burn |
| `testFuzzGovernanceVotingPowerMatchesDelegatedBalance` | Random `amount`; asserts `getVotes` matches delegated balance |
| `testFuzzMin` | Random `a`, `b`; asserts `amm.min` returns the correct minimum |

Foundry fuzzer configuration (from `foundry.toml`):

```toml
[invariant]
runs = 32
depth = 64
```

### 2.3 Invariant Tests

Invariant tests use `StdInvariant` with an `AMMHandler` actor contract to drive arbitrary sequences of swaps and liquidity operations. Seven protocol invariants are enforced:

| Invariant | Assertion |
|---|---|
| `invariant_ReservesMatchTokenBalances` | `tokenA.balanceOf(amm) == amm.reserveA()` and `tokenB.balanceOf(amm) == amm.reserveB()` |
| `invariant_ConstantProductDoesNotDecreaseBelowInitial` | `reserveA * reserveB ≥ (1,000 ether)²` |
| `invariant_LpSupplyBackedByLiquidity` | LP total supply, `reserveA`, and `reserveB` are all greater than zero |
| `invariant_VaultReserveRatioHealthyWhenDeposited` | `getReserveRatio() >= RESERVE_RATIO` when `totalDeposited > 0` |
| `invariant_AssetTokenSupplyBelowCap` | `assetToken.totalSupply() <= MAX_SUPPLY` |
| `invariant_VaultTreasuryAccountingMatchesReserveBalance` | `reserve.balanceOf(vault) == vault.totalAssets()` |
| `invariant_VaultSupplyConservation` | `vault.totalSupply() == vault.totalAssets()` and `assetToken.totalSupply() == vault.totalDeposited()` |

---

## 3. Security Case Study Tests

`OracleAndSecurity.t.sol` — 190 lines

This file contains four groups of security-oriented tests that demonstrate both the vulnerable pattern and its hardened fix:

### Reentrancy

- `testReentrancyCaseStudyDrainsVulnerableVault`: deploys `VulnerableEtherVault`, which sends ETH before zeroing balance; an attacker contract re-enters and drains the vault.
- `testReentrancyCaseStudyHardenedVaultRevertsAttack`: deploys `HardenedEtherVault` using `ReentrancyGuard`; confirms the same attack reverts.

### Access Control

- `testVulnerableAccessControlCanBeTakenOver`: deploys `VulnerableAccessControl`, which allows any caller to overwrite the admin; confirms privilege escalation.
- `testHardenedAccessControlBlocksUnauthorizedUser`: deploys `HardenedAccessControl` using OpenZeppelin `AccessControl`; confirms unauthorized caller is rejected.

### Oracle Validation

- Stale price rejection: price feed with `updatedAt` older than `staleAfter` reverts with `StalePrice`.
- Invalid round detection: price with `answeredInRound < roundId` reverts with `IncompleteRound`.
- Non-positive price: price of zero or negative reverts with `InvalidPrice`.

---

## 4. Gas Benchmark Tests

`GasBenchmark.t.sol` — 34 lines

Benchmarks the two square root implementations used for initial LP provisioning:

```bash
forge test --match-test testGasBenchmarkSqrtAssemblyVsSolidity -vv
```

| Function | Gas |
|---|---:|
| `sqrtSolidity` | 17,335 |
| `sqrtAssembly` | 4,109 |

The assembly implementation reduces cost by approximately 76.3%.

---

## 5. Fork Readiness Tests

`ForkReadiness.t.sol` — 61 lines

Verifies that the deployment script behaves correctly when run against a forked Sepolia state. These tests confirm:

- All contracts deploy without revert on a realistic chain state
- Post-deploy role assertions pass against the forked environment
- Block numbers and timestamps are consistent with testnet expectations

Fork tests are conditional: they are skipped when no fork RPC is configured.

---

## 6. Coverage Report

Generated with:

```bash
forge coverage --report summary --ir-minimum
```

| Metric | Covered | Total | Percent |
|---|---:|---:|---:|
| Lines | 288 | 298 | 96.64% |
| Functions | 70 | 76 | 92.11% |

The LCOV artifact is `lcov.info` (generated in the project root). The uncovered lines are primarily in mock contracts and internal view helpers that are not reachable through the public interface in the test environment.

---

## 7. CI Validation

The CI pipeline (`.github/workflows/ci.yml`) runs two jobs on every push and pull request:

### `foundry` job

| Step | Command |
|---|---|
| Install Node dependencies | `npm ci` |
| Install frontend dependencies | `npm ci --prefix frontend` |
| Install subgraph dependencies | `npm ci --prefix subgraph` |
| Check Solidity formatting | `forge fmt --check` |
| Lint Solidity | `npm run lint:sol` |
| Check frontend formatting | `npm run format:check --prefix frontend` |
| Build frontend | `npm run build --prefix frontend` |
| Generate subgraph types | `npm run codegen --prefix subgraph` |
| Build subgraph | `npm run build --prefix subgraph` |
| Build contracts | `forge build` |
| Run tests | `forge test` |
| Coverage | `forge coverage --report summary --ir-minimum` |

### `slither` job

| Step | Command |
|---|---|
| Install Python 3.11 | via `setup-python` |
| Build contracts | `forge build` |
| Install Slither | `pip install slither-analyzer` |
| Run Slither | `slither . --exclude-dependencies --filter-paths "(src/flat_)" --exclude solc-version` |

---

## 8. Slither Static Analysis

Slither analyzed 66 contracts and reported:

| Severity | Count |
|---|---:|
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 0 |

The `block.timestamp` usage in `PriceOracle.latestPrice` is annotated with `// slither-disable-next-line timestamp` because the comparison is a freshness check against a known feed timestamp, not a source of randomness or reward distribution logic.

Full analysis details: [slither-findings.md](./slither-findings.md).

---

## 9. Testing Confidence and Methodology

The testing strategy is security-first:

1. **Unit tests** establish a behavioral contract for each function under normal and boundary conditions.
2. **Fuzz tests** explore the input space automatically, surfacing edge cases that deterministic tests miss.
3. **Invariant tests** enforce system-wide properties that must hold across arbitrary state transitions, modeled through a handler contract.
4. **Case study tests** demonstrate that known vulnerability patterns (reentrancy, access control takeover) have been correctly identified and mitigated in the production contracts.
5. **Static analysis** provides an independent, automated sweep for common Solidity vulnerability patterns.

The combination of 96.64% line coverage, seven enforced invariants, and a clean Slither report provides high confidence in the correctness and security of the protocol's core logic.
