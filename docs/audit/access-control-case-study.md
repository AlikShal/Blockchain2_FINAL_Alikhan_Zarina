# Access-Control Case Study

The repository includes a reproduced access-control takeover and a hardened replacement in `test/OracleAndSecurity.t.sol`.

## Vulnerable Pattern

- Contract: `VulnerableAccessControl`
- Issue: `setAdmin()` is callable by anyone
- Effect: attacker promotes self to admin and can mutate privileged state

## Hardened Pattern

- Contract: `HardenedAccessControl`
- Fixes:
  - uses OpenZeppelin `AccessControl`
  - gates privileged action behind `OPERATOR_ROLE`

## Test Evidence

- Takeover succeeds in vulnerable variant: `testVulnerableAccessControlCanBeTakenOver`
- Unauthorized call fails in hardened variant: `testHardenedAccessControlBlocksUnauthorizedUser`
