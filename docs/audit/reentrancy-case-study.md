# Reentrancy Case Study

## Vulnerable Pattern

`test/OracleAndSecurity.t.sol` includes `VulnerableEtherVault`, which transfers ETH before clearing the caller balance. The attacker contract re-enters during `receive()` and drains more ETH than the initial deposit.

Covered by:

- `testReentrancyCaseStudyDrainsVulnerableVault`

## Hardened Pattern

`HardenedEtherVault` clears balances before transfer and uses OpenZeppelin `ReentrancyGuard`.

Covered by:

- `testReentrancyCaseStudyHardenedVaultRevertsAttack`

## Protocol Application

The production `AssetVault` and `AMM` apply `nonReentrant` on deposit, withdraw, mint, redeem, add liquidity, remove liquidity, and swap flows.
