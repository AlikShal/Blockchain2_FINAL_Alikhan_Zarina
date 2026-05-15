# Master Roadmap

This is the high-level roadmap from the current prototype to an exam-ready submission.

## Phase 0 - Repo Reset
- Clean the repo and remove legacy handout files.
- Initialize Git and push the first real project commit.
- Keep the current prototype as a reference baseline, not as the final architecture.

Exit criteria:
- Clean root directory
- Git repository created
- New roadmap docs committed

## Phase 1 - Architecture Lock
- Confirm the project scenario as `Option C - RWA Tokenization Platform`.
- Split ownership with your teammate even if you write most of the code.
- Produce the first architecture draft:
  - contracts list
  - trust model
  - governance model
  - external dependencies

Exit criteria:
- [TEAM_OWNERSHIP.md](TEAM_OWNERSHIP.md) filled in
- contract/module list frozen
- report outline started

## Phase 2 - Protocol Core
- Replace the prototype governance with:
  - `ERC20Votes`
  - `ERC20Permit`
  - `Governor`
  - `TimelockController`
- Implement the core RWA flow:
  - asset registry
  - issuer authorization
  - reserve-backed asset token
  - `ERC4626` reserve or yield vault
- Keep or rebuild the AMM so it satisfies:
  - constant product invariant
  - 0.3% fee
  - slippage protection
  - LP tokens

Exit criteria:
- contracts compile
- core access control model is in place
- no placeholder TODOs in main flows

## Phase 3 - Advanced Solidity Requirements
- Add one `UUPS` upgradeable contract with V1 -> V2 upgrade path.
- Add one factory using both `CREATE` and `CREATE2`.
- Add one Yul-based micro-optimization with a benchmark against plain Solidity.

Good candidates:
- upgradeable asset registry
- vault factory / market factory
- assembly math or storage utility

Exit criteria:
- upgrade demo works in tests
- CREATE and CREATE2 addresses are tested
- gas benchmark documented

## Phase 4 - Oracle, Security, and Protocol Hardening
- Integrate a Chainlink price feed with stale-price checks.
- Add mock aggregators for tests.
- Replace raw ERC-20 calls with `SafeERC20`.
- Reproduce and fix:
  - one reentrancy issue
  - one access-control issue

Exit criteria:
- slippage/oracle checks implemented
- vulnerability case studies captured in tests
- Slither is being run regularly

## Phase 5 - Testing Expansion
- Reach the exam minimums:
  - 50+ unit tests
  - 10+ fuzz tests
  - 5+ invariant tests
  - 3+ fork tests
- Reach `>= 90%` line coverage.

Exit criteria:
- CI green
- coverage report committed
- no failing tests

## Phase 6 - Frontend and Subgraph
- Build the dApp with:
  - wallet connection
  - read views for balances / voting power / protocol state
  - write flows for deposit / swap / vote
  - proposal lifecycle UI
- Build the subgraph:
  - 4+ entities
  - 5 documented GraphQL queries

Exit criteria:
- frontend runs locally
- subgraph indexes deployed contracts
- at least one UI section reads from The Graph

## Phase 7 - L2 Deployment and CI
- Deploy to one L2 Sepolia network.
- Verify all contracts.
- Add GitHub Actions:
  - build
  - test
  - coverage
  - Slither
- Add post-deployment verification script output.

Exit criteria:
- deployed addresses in README
- explorer links added
- CI required on PRs

## Phase 8 - Final Submission Package
- Finish architecture doc.
- Finish audit report.
- Finish gas report.
- Finish slide deck and demo script.
- Record the demo fallback video.

Exit criteria:
- all deliverables present
- presentation rehearsed
- Q&A prep done
