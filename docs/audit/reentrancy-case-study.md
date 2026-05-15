# Reentrancy Case Study

The repository includes a reproduced reentrancy vulnerability and its hardened counterpart in `test/OracleAndSecurity.t.sol`.

## Vulnerable Pattern

- Contract: `VulnerableEtherVault`
- Issue: ETH is sent with `call{value: amount}("")` before the user balance is reset
- Exploit path: attacker contract re-enters `withdraw()` from the `receive()` hook

## Hardened Pattern

- Contract: `HardenedEtherVault`
- Fixes:
  - `nonReentrant`
  - state is zeroed before the external call

## Test Evidence

- Exploit succeeds: `testReentrancyCaseStudyDrainsVulnerableVault`
- Exploit fails: `testReentrancyCaseStudyHardenedVaultRevertsAttack`
