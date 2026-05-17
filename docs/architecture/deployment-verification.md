# Deployment and Verification Guide

This guide covers the complete deployment workflow: local development, Sepolia testnet deployment, contract verification, frontend startup, and subgraph deployment.

---

## 1. Prerequisites

| Requirement | Version / Notes |
|---|---|
| [Foundry](https://book.getfoundry.sh/) | Latest stable (`foundryup`) |
| Node.js | 20 LTS |
| npm | Bundled with Node 20 |
| Python 3.11 | Required for Slither |
| Graph CLI | `npm i -g @graphprotocol/graph-cli` |
| Wallet with test ETH | Sepolia ETH for gas |

Install Node dependencies from the repo root:

```bash
npm ci
npm ci --prefix frontend
npm ci --prefix subgraph
```

Install Foundry dependencies:

```bash
forge install
```

---

## 2. Environment Variables

### Root `.env` (smart contracts and scripts)

Copy `.env.example` to `.env` and populate:

```bash
cp .env.example .env
```

| Variable | Description |
|---|---|
| `PRIVATE_KEY` | Deployer private key (no `0x` prefix) |
| `TESTNET_RPC_URL` | Sepolia RPC endpoint (default: `https://sepolia.base.org`) |
| `MAINNET_RPC_URL` | Ethereum mainnet RPC (for fork tests) |
| `DEPLOYER_ADDRESS` | Address derived from `PRIVATE_KEY` |
| `ASSET_TOKEN` | Populated after deployment |
| `ASSET_VAULT` | Populated after deployment |
| `ASSET_REGISTRY` | Populated after deployment |
| `GOVERNANCE_TOKEN` | Populated after deployment |
| `GOVERNOR` | Populated after deployment |
| `TIMELOCK` | Populated after deployment |

### Frontend `.env` (`frontend/.env`)

Copy `frontend/.env.example` to `frontend/.env` and populate after deployment:

```bash
cp frontend/.env.example frontend/.env
```

| Variable | Description |
|---|---|
| `VITE_CHAIN` | Target chain (`baseSepolia`) |
| `VITE_PUBLIC_RPC_URL` | Public RPC URL for the chain |
| `VITE_SUBGRAPH_URL` | Deployed subgraph query endpoint |
| `VITE_RESERVE_TOKEN_ADDRESS` | `mUSD` address from deployment output |
| `VITE_QUOTE_TOKEN_ADDRESS` | `mQUOTE` address from deployment output |
| `VITE_ASSET_TOKEN_ADDRESS` | `AssetToken` address |
| `VITE_ASSET_VAULT_ADDRESS` | `AssetVault` address |
| `VITE_AMM_ADDRESS` | `AMM` address |
| `VITE_GOVERNANCE_TOKEN_ADDRESS` | `GovernanceToken` address |
| `VITE_GOVERNOR_ADDRESS` | `ProtocolGovernor` address |

---

## 3. Local Development (Anvil)

Start a local Anvil node:

```bash
npm run anvil
```

Deploy to the local node:

```bash
npm run deploy:anvil
```

This is equivalent to:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast
```

The deployment output prints all ten contract addresses to stdout.

---

## 4. Sepolia Deployment Flow

### 4.1 Build and Test

Always build and run tests before deploying:

```bash
forge build
forge test
```

### 4.2 Deploy

```bash
npm run deploy:testnet
```

This is equivalent to:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $TESTNET_RPC_URL \
  --broadcast \
  --verify
```

The `--verify` flag submits source code to the block explorer via the Foundry verification module.

### 4.3 Deployment Order

`Deploy.s.sol` deploys the protocol in the following order:

1. `MockERC20` — backing asset (`mUSD`, 18 decimals)
2. `MockERC20` — quote asset (`mQUOTE`, 18 decimals)
3. `AssetToken` — ERC-20 backed asset token
4. `GovernanceToken` — ERC20Votes governance token
5. `AssetVault` — ERC-4626 reserve vault linked to `mUSD` and `AssetToken`
6. `AMM` — constant-product AMM for `AssetToken`/`mQUOTE` pair
7. `VaultFactory` — CREATE/CREATE2 vault deployer
8. `TimelockController` — 2-day delay, `ProtocolGovernor` as proposer/canceller
9. `ProtocolGovernor` — full OpenZeppelin governor stack
10. `AssetRegistry` — UUPS proxy (implementation + `ERC1967Proxy`)

After contract deployment, the script:

- Grants `PROPOSER_ROLE` and `CANCELLER_ROLE` to `ProtocolGovernor` on the timelock
- Grants `ISSUER_ROLE` and `PAUSER_ROLE` to deployer on `AssetRegistry` before handing off admin
- Mints 1,000,000 `AssetToken` seed supply to deployer
- Hands off all admin roles to `TimelockController`; deployer renounces admin roles
- Adds 10,000 `AssetToken` + 10,000 `mQUOTE` as initial AMM liquidity
- Deposits 5,000 `mUSD` into `AssetVault`
- Registers the mock asset in `AssetRegistry`

### 4.4 Capture Addresses

Record the addresses printed to stdout and populate both `.env` files before proceeding.

---

## 5. Post-Deployment Verification

Run the verification script to confirm roles and state were set correctly:

```bash
npm run verify:post
```

This is equivalent to:

```bash
forge script script/VerifyPostDeploy.s.sol:VerifyPostDeploy \
  --rpc-url $TESTNET_RPC_URL
```

The script asserts:

- `AssetVault` holds `MINTER_ROLE` and `BURNER_ROLE` on `AssetToken`
- `TimelockController` holds `DEFAULT_ADMIN_ROLE`, `UPGRADER_ROLE`, `ISSUER_ADMIN_ROLE`, and `PAUSER_ROLE` on `AssetRegistry`
- `TimelockController` is the owner of `AssetToken` and `GovernanceToken`
- `ProtocolGovernor` holds `PROPOSER_ROLE` and `CANCELLER_ROLE` on the timelock
- Deployer holds none of the above roles
- Timelock delay equals 2 days
- Governance parameters match the constants in `Governance.sol`

---

## 6. Contract Verification on Explorer

If `--verify` was not passed during deployment, verify manually:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/AssetToken.sol:AssetToken \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

Repeat for each deployed contract, replacing the source path and contract name. Proxy contracts require verifying the implementation and the proxy separately.

---

## 7. Frontend Startup

After populating `frontend/.env`:

```bash
npm run dev --prefix frontend
```

Or for a production build:

```bash
npm run build --prefix frontend
```

The built output is placed in `frontend/dist/`.

The frontend connects to Sepolia (Base Sepolia by default) via the RPC URL configured in `VITE_PUBLIC_RPC_URL` and queries the subgraph at `VITE_SUBGRAPH_URL`.

---

## 8. Subgraph Deployment

### 8.1 Update Addresses

Edit `subgraph/subgraph.yaml` and replace the placeholder addresses under each `source.address` with the addresses from the deployment output:

| Data source | Field |
|---|---|
| `AssetRegistry` | `source.address` |
| `AssetVault` | `source.address` |
| `AMM` | `source.address` |
| `ProtocolGovernor` | `source.address` |

Set `startBlock` to the block number of the first deployment transaction to avoid scanning from genesis.

### 8.2 Generate Types and Build

```bash
npm run codegen --prefix subgraph
npm run build --prefix subgraph
```

### 8.3 Deploy to Subgraph Studio

```bash
graph auth --studio <DEPLOY_KEY>
graph deploy --studio option-c-rwa --prefix subgraph
```

After deployment, the query URL follows the format:

```
https://api.studio.thegraph.com/query/<SUBGRAPH_ID>/option-c-rwa/version/latest
```

Set this URL as `VITE_SUBGRAPH_URL` in `frontend/.env` and rebuild the frontend.

---

## 9. Placeholder Deployment Addresses

The following addresses are recorded at the time of the latest testnet deployment. Replace with live addresses after external deployment.

| Contract | Address |
|---|---|
| `AssetToken` | `0x0000000000000000000000000000000000000000` |
| `AssetVault` | `0x0000000000000000000000000000000000000000` |
| `AssetRegistry` (proxy) | `0x0000000000000000000000000000000000000000` |
| `GovernanceToken` | `0x0000000000000000000000000000000000000000` |
| `ProtocolGovernor` | `0x0000000000000000000000000000000000000000` |
| `TimelockController` | `0x0000000000000000000000000000000000000000` |
| `AMM` | `0x0000000000000000000000000000000000000000` |
| `VaultFactory` | `0x0000000000000000000000000000000000000000` |
| `MockERC20` (mUSD) | `0x0000000000000000000000000000000000000000` |
| `MockERC20` (mQUOTE) | `0x0000000000000000000000000000000000000000` |

### Placeholder Subgraph URL

```
https://api.studio.thegraph.com/query/YOUR_SUBGRAPH_ID/option-c-rwa/version/latest
```

---

## 10. Troubleshooting

| Symptom | Likely Cause | Resolution |
|---|---|---|
| `forge build` fails with import not found | Submodule or npm package missing | Run `forge install` and `npm ci` |
| Deployment reverts at `initialize` | Registry already initialized on this chain | Use a fresh RPC URL or redeploy mocks |
| `verify:post` assertion fails on roles | Role handoff did not complete | Check that `PRIVATE_KEY` matches `DEPLOYER_ADDRESS` and re-run deployment |
| Frontend shows "missing address" error | `.env` not populated after deployment | Populate `frontend/.env` with addresses from deployment output |
| Subgraph returns empty data | `startBlock` set to 0 and sync is in progress | Wait for sync or set `startBlock` to the deployment block |
| Slither times out on CI | Large dependency tree | CI uses `--exclude-dependencies` and `--filter-paths "(src/flat_)"` flags |
