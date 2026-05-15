# Step-by-Step Roadmap

This is the practical execution order.

## Track 1 - Clean Start
1. Initialize Git in this folder.
2. Create the GitHub repository.
3. Commit the cleaned skeleton as the first real baseline.
4. Add your teammate to [TEAM_OWNERSHIP.md](TEAM_OWNERSHIP.md).

## Track 2 - Freeze the Final Architecture
1. Keep the scenario as `Option C - RWA Tokenization Platform`.
2. Decide the exact contract set:
   - Governance token
   - Governor
   - Timelock
   - Asset token
   - Asset registry
   - ERC4626 vault
   - AMM
   - Factory
   - Oracle adapter
   - Upgradeable contract V1/V2
   - ERC721 or ERC1155 companion contract
3. Draw the contract relationship diagram before adding more code.

## Track 3 - Build the Smart Contract Backbone
1. Replace `src/Governance.sol` with real governance modules.
2. Add `AccessControl` roles:
   - admin
   - issuer
   - pauser
   - upgrader
3. Add the ERC4626 vault.
4. Upgrade the AMM with slippage protection and `SafeERC20`.
5. Add the oracle adapter with stale checks.
6. Add a CREATE/CREATE2 factory.
7. Add UUPS upgradeability and V2 upgrade test.

## Track 4 - Testing by Requirement Bucket
1. Expand unit tests until every public and external path is covered.
2. Add fuzz tests for:
   - swaps
   - vault deposit/withdraw
   - governance voting power
3. Add invariants for:
   - AMM `k`
   - supply conservation
   - treasury accounting
4. Add fork tests for:
   - Chainlink feed
   - USDC
   - Uniswap interaction
5. Run coverage and keep raising it to `>= 90%`.

## Track 5 - Security and Audit Work
1. Run Slither early.
2. Fix High and Medium findings until both are zero.
3. Create before/after exploit tests for:
   - reentrancy
   - access control
4. Write findings as you go in `docs/audit/`.

## Track 6 - Demo Surface
1. Build frontend read pages first.
2. Add write actions:
   - deposit
   - swap
   - vote
3. Add proposal state page.
4. Add wrong-network and transaction-error handling.
5. Build subgraph and wire one page to indexed data.

## Track 7 - Deployment and Presentation
1. Deploy to Anvil for local demo.
2. Deploy to one L2 Sepolia network.
3. Verify contracts.
4. Produce the gas comparison table for L1 vs L2.
5. Finalize slides and report.
6. Rehearse a 15-minute demo with a fallback script.
