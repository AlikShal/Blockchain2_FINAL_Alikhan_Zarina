# Access Control Case Study

## Vulnerable Pattern

`test/OracleAndSecurity.t.sol` includes `VulnerableAccessControl`, where any caller can replace `admin`. This allows an attacker to take over privileged actions.

Covered by:

- `testVulnerableAccessControlCanBeTakenOver`

## Hardened Pattern

`HardenedAccessControl` uses OpenZeppelin `AccessControl` and restricts privileged updates to `OPERATOR_ROLE`.

Covered by:

- `testHardenedAccessControlBlocksUnauthorizedUser`
- `testHardenedAccessControlAllowsOperator`

## Protocol Application

The protocol uses explicit roles:

- `DEFAULT_ADMIN_ROLE`
- `ISSUER_ADMIN_ROLE`
- `ISSUER_ROLE`
- `PAUSER_ROLE`
- `UPGRADER_ROLE`
- `MINTER_ROLE`
- `BURNER_ROLE`
- `URI_MANAGER_ROLE`

This keeps issuance, pause control, upgrades, and token mint/burn authority separated.
