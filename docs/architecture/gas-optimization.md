# Gas Optimization

This document describes the gas optimization strategies applied across the RWA tokenization protocol.

---

## 1. Compiler Settings

The following settings are declared in `foundry.toml`:

| Setting | Value | Effect |
|---|---|---|
| `optimizer` | `true` | Enables the Solidity bytecode optimizer |
| `optimizer_runs` | `200` | Balanced between deployment cost and call cost |
| `via_ir` | `true` | Routes compilation through Yul IR; enables cross-function optimizations |
| `solc_version` | `0.8.20` | Latest stable 0.8.x with custom error support and improved codegen |

`via_ir = true` enables the intermediate representation pipeline, which unlocks inlining and dead-code elimination passes that are unavailable in the legacy pipeline.

---

## 2. Immutable Variables

Storage reads cost 2,100 gas (cold) or 100 gas (warm) per `SLOAD`. Variables set once in a constructor and never changed are declared `immutable`, which bakes their value into bytecode and replaces `SLOAD` with a constant push.

| Contract | Immutable | Purpose |
|---|---|---|
| `AMM` | `tokenA`, `tokenB` | Traded pair addresses, fixed at construction |
| `AssetVault` | `assetToken` | Linked ERC-20 address, fixed at construction |
| `PriceOracle` | `feed`, `staleAfter` | Chainlink feed address and stale-price window |

---

## 3. Calldata Usage

External function parameters that are only read (not written) should use `calldata` rather than `memory` to avoid a copy into the EVM memory region.

In `AssetRegistry.registerAsset`, the `metadataURI` string parameter is declared `calldata`:

```solidity
function registerAsset(
    bytes32 assetId,
    address reserveAsset,
    address assetToken,
    address vault,
    uint256 maxSupply,
    string calldata metadataURI
) external onlyRole(ISSUER_ROLE)
```

Dynamic types like `string` benefit most from this: a `memory` copy would allocate and zero the full string buffer in EVM memory, whereas `calldata` reads are pointer-based.

---

## 4. Custom Errors

Since Solidity 0.8.4, custom errors replace `require(condition, "string")` with typed error objects. Custom errors reduce deployment cost by removing the string data from bytecode, and they reduce revert cost because no string encoding is needed at call time.

`PriceOracle` uses three custom errors in place of string reverts:

```solidity
error InvalidPrice();
error StalePrice(uint256 updatedAt, uint256 currentTime);
error IncompleteRound(uint80 roundId, uint80 answeredInRound);
```

`StalePrice` and `IncompleteRound` carry diagnostic payload without the overhead of ABI-encoding a string.

---

## 5. Constants vs Storage

Protocol-level constants are declared with the `constant` keyword, which substitutes the value inline during compilation and generates no `SLOAD`:

| Contract | Constant | Value |
|---|---|---|
| `AMM` | `FEE_BPS` | 30 |
| `AMM` | `BPS_DENOMINATOR` | 10,000 |
| `AssetVault` | `RESERVE_RATIO` | 100 |
| `AssetToken` | `MAX_SUPPLY` | 1,000,000,000 × 10¹⁸ |
| `GovernanceToken` | `MAX_SUPPLY` | 100,000,000 × 10¹⁸ |
| `ProtocolGovernor` | `VOTING_DELAY_BLOCKS` | 43,200 |
| `ProtocolGovernor` | `VOTING_PERIOD_BLOCKS` | 302,400 |
| `ProtocolGovernor` | `PROPOSAL_THRESHOLD` | 10,000 × 10¹⁸ |
| `ProtocolGovernor` | `QUORUM_PERCENT` | 4 |

Role identifiers (`MINTER_ROLE`, `BURNER_ROLE`, `ISSUER_ROLE`, etc.) are `bytes32` constants computed from `keccak256` at compile time.

---

## 6. Storage Layout Considerations

### AssetVault

`AssetVault` maintains two storage mappings and a scalar:

```solidity
uint256 public totalDeposited;
mapping(address => uint256) public userDeposits;
```

`totalDeposited` is updated on every deposit and withdrawal. A single scalar is used instead of recomputing the sum from the mapping to avoid iterating over unbounded state.

### AssetRegistry

Asset records are stored in a single `mapping(bytes32 => AssetRecord)`. The `bytes32` key is computed off-chain (`keccak256` of an asset identifier string), so no on-chain string storage is needed for lookup.

```solidity
struct AssetRecord {
    address issuer;      // 20 bytes
    address reserveAsset; // 20 bytes
    address assetToken;   // 20 bytes
    address vault;        // 20 bytes
    uint256 maxSupply;
    string metadataURI;
    bool active;
}
```

The struct is not manually packed because the `string` field breaks word-boundary packing anyway. Addresses occupy 20 bytes but are stored in 32-byte slots by default in the EVM when mixed with other types.

---

## 7. Governance Gas Considerations

Governance operations (propose, vote, queue, execute) are infrequent and administrator-level. Gas cost is not a primary concern for these paths. The `ProtocolGovernor` uses the full OpenZeppelin governor stack with:

- `GovernorCountingSimple` for for/against/abstain vote tallying
- `GovernorVotesQuorumFraction` for fractional quorum
- `GovernorTimelockControl` for timelock integration

These extensions each add some bytecode, but governance calls are expected to occur at most weekly. The tradeoff favors correctness and auditability over marginal call-gas savings.

---

## 8. ERC-4626 Vault Efficiency

`AssetVault` inherits `ERC4626` from OpenZeppelin, which provides standard `deposit`, `withdraw`, `mint`, and `redeem` semantics. The vault uses `previewMint` and `previewRedeem` for share-to-asset conversion, which are pure view functions with no storage writes.

The 1:1 backing design means the `convertToShares` and `convertToAssets` functions simplify to identity (1 share = 1 asset unit), making share math cheap.

---

## 9. AMM Efficiency

### Constant-Product Formula

The AMM implements the constant-product formula in a single expression within `getAmountOut`:

```solidity
uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - FEE_BPS);
return (amountInWithFee * reserveOut) / (reserveIn * BPS_DENOMINATOR + amountInWithFee);
```

Fee deduction and output calculation are combined into one arithmetic pass with no intermediate storage writes.

### Assembly Square Root

Initial liquidity provisioning uses a geometric mean (`sqrt(amountA * amountB)`) to determine the initial LP token supply. This is computed with a Yul assembly implementation that reduces gas by approximately 76% compared to the equivalent pure-Solidity Newton's method:

| Function | Gas (local benchmark) |
|---|---:|
| `sqrtSolidity` | 17,335 |
| `sqrtAssembly` | 4,109 |

Benchmark command:

```bash
forge test --match-test testGasBenchmarkSqrtAssemblyVsSolidity -vv
```

---

## 10. Gas vs. Readability Tradeoffs

| Decision | Gas Impact | Readability Impact |
|---|---|---|
| `via_ir = true` | Smaller bytecode, fewer redundant copies | No change to source |
| `immutable` variables | Eliminates storage reads on hot paths | Slightly reduces flexibility |
| Custom errors | Smaller bytecode, cheaper reverts | Requires error type lookup |
| Assembly sqrt | 76% gas saving on sqrt | Lower readability; benchmarked and documented |
| `calldata` strings | Avoids memory copy for large strings | No change to call signature |
| Single `totalDeposited` scalar | Avoids re-deriving from mapping | Extra storage slot per write |

The assembly square root is the only non-idiomatic optimization in the codebase. All other optimizations are standard Solidity best practices that do not materially reduce source readability.
