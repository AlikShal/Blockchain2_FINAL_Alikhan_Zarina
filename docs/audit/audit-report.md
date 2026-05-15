# Internal Security Audit Report

## 1. Executive Summary

This audit reviews the `Option C` RWA tokenization protocol implementation in `src/`, the deployment scripts in `script/`, and the security-focused tests in `test/`. The project uses OpenZeppelin primitives for governance, access control, ERC-20, ERC-1155, ERC-4626, and upgradeability, while implementing a custom AMM, oracle wrapper, vault wiring, and registry.

Result summary:

- No unresolved Slither findings at submission time
- No High or Medium severity issues reported by Slither
- Reentrancy and access-control case studies reproduced and fixed in dedicated tests
- Governance/timelock configuration aligned more closely with the course specification

## 2. Scope

### In Scope

- `src/AMM.sol`
- `src/AssetReceipt.sol`
- `src/AssetRegistry.sol`
- `src/AssetRegistryV2.sol`
- `src/AssetToken.sol`
- `src/AssetVault.sol`
- `src/Governance.sol`
- `src/PriceOracle.sol`
- `src/VaultFactory.sol`
- `script/Deploy.s.sol`
- `script/VerifyPostDeploy.s.sol`

### Out of Scope

- External OpenZeppelin library internals
- Base Sepolia explorer verification flow
- Presentation materials

## 3. Methodology

Tools and methods used:

- `forge build`
- `forge test`
- `forge coverage`
- `slither . --filter-paths "lib|node_modules|out|cache" --exclude solc-version`
- Manual review of permissions, external calls, mint/burn flows, upgrade path, and governance lifecycle
- Manual review of CEI/ReentrancyGuard usage and SafeERC20 call sites

## 4. Findings Table

| ID | Title | Severity | Location | Status |
| --- | --- | --- | --- | --- |
| F-01 | Reentrancy pattern reproduced in case-study vault | High | `test/OracleAndSecurity.t.sol` | Fixed in hardened variant |
| F-02 | Admin takeover pattern reproduced in case-study contract | High | `test/OracleAndSecurity.t.sol` | Fixed in hardened variant |
| F-03 | Governance configuration initially too permissive for exam spec | Low | `src/Governance.sol`, `script/Deploy.s.sol` | Fixed |
| F-04 | Deployment backdoor risk if deployer kept admin roles | Low | `script/Deploy.s.sol` | Fixed |
| F-05 | Staleness check uses timestamp by design | Informational | `src/PriceOracle.sol` | Acknowledged |

## 5. Detailed Findings

### F-01: Reentrancy pattern reproduced in case-study vault

- Severity: High
- Location: `test/OracleAndSecurity.t.sol`
- Description: The `VulnerableEtherVault` case study sends ETH before zeroing the attacker balance, enabling recursive withdrawal.
- Impact: Drain of ETH reserves in the vulnerable sample.
- Proof of Concept: `testReentrancyCaseStudyDrainsVulnerableVault`.
- Recommendation: Use CEI and `ReentrancyGuard`, and zero state before the external call.
- Status: Fixed in `HardenedEtherVault` and covered by `testReentrancyCaseStudyHardenedVaultRevertsAttack`.

### F-02: Admin takeover pattern reproduced in case-study contract

- Severity: High
- Location: `test/OracleAndSecurity.t.sol`
- Description: The `VulnerableAccessControl` sample lets anyone rewrite the admin address and gain privileged write access.
- Impact: Full privilege escalation in the vulnerable sample.
- Proof of Concept: `testVulnerableAccessControlCanBeTakenOver`.
- Recommendation: Use `AccessControl` or `Ownable` for every privileged function.
- Status: Fixed in `HardenedAccessControl` and covered by `testHardenedAccessControlBlocksUnauthorizedUser`.

### F-03: Governance configuration initially too permissive for exam spec

- Severity: Low
- Location: `src/Governance.sol`
- Description: An earlier configuration used a near-zero proposal barrier and short timelock delay.
- Impact: Proposal spam and reduced governance hardening.
- Recommendation: Configure a one-day voting delay target, one-week voting period target, 4% quorum, 1% proposal threshold, and 2-day timelock.
- Status: Fixed.

### F-04: Deployment backdoor risk if deployer kept admin roles

- Severity: Low
- Location: `script/Deploy.s.sol`
- Description: Keeping token or registry admin roles on the deployer would leave a centralization backdoor after launch.
- Impact: Off-governance privileged mutations by the deployer key.
- Recommendation: Hand off durable admin power to the timelock and renounce deployer roles.
- Status: Fixed.

### F-05: Staleness check uses timestamp by design

- Severity: Informational
- Location: `src/PriceOracle.sol`
- Description: `block.timestamp` is used only for feed freshness comparison, not for randomness or reward distribution.
- Impact: Minimal; validators can shift timestamps within protocol bounds, but the check is appropriate for stale oracle rejection.
- Recommendation: Keep stale window conservative and document the assumption.
- Status: Acknowledged.

## 6. Centralization Analysis

After the deployment script handoff:

1. `TimelockController` is intended to hold durable admin power over `AssetRegistry`.
2. `TimelockController` becomes owner of `AssetToken` and `GovernanceToken`.
3. `AssetVault` retains `MINTER_ROLE` and `BURNER_ROLE` over `AssetToken` for reserve-backed issuance.
4. The deployer should not retain registry admin, timelock admin, or token admin roles.

Risk if compromised:

- A compromised timelock admin path can authorize issuers, pause assets, or alter privileged protocol settings through governance-linked execution.
- A compromised vault address with mint/burn permissions could corrupt backing-token accounting.

## 7. Governance Attack Analysis

### Flash-Loan Governance

- Mitigation: `ERC20Votes` snapshots voting power, so votes depend on historical balance checkpoints rather than same-transaction balance changes alone.

### Whale Capture

- Mitigation: quorum is 4%, and the proposal threshold is non-zero.
- Residual risk: concentrated token distribution can still dominate if governance token allocation is poorly distributed.

### Proposal Spam

- Mitigation: proposal threshold raised to 1% of the initial governance distribution.

### Timelock Bypass

- Mitigation: privileged actions are intended to route through `TimelockController`, and the deployment script removes the deployer backdoor.

## 8. Oracle Attack Analysis

### Price Manipulation

- The current `PriceOracle` wrapper trusts the external feed and does not aggregate multiple sources. The main defense is selecting a reputable Chainlink feed.

### Stale Price

- Mitigation: explicit stale-time rejection through `staleAfter`.

### Invalid Round Data

- Mitigation: rejection of non-positive prices, unset rounds, and incomplete rounds.

## 9. Slither Appendix

See [slither-findings.md](./slither-findings.md).
