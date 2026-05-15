# Subgraph

This subgraph indexes the core `Option C` protocol events:

- `AssetRegistry` for asset onboarding and pause status
- `AssetVault` for depositor balances and minted asset tokens
- `AMM` for swap activity
- `ProtocolGovernor` for proposals and vote activity

Setup:

```bash
cd subgraph
npm install
npm run codegen
npm run build
```

Before deployment, replace the placeholder addresses in `subgraph.yaml` with the real verified Base Sepolia addresses.

Documented GraphQL queries:

```graphql
query Assets {
  assets(first: 10, orderBy: createdAtBlock, orderDirection: desc) {
    id
    issuer
    reserveAsset
    assetToken
    vault
    maxSupply
    metadataURI
    active
  }
}
```

```graphql
query VaultPositions {
  vaultPositions(first: 10, orderBy: updatedAtTimestamp, orderDirection: desc) {
    id
    user
    vault
    deposited
    assetTokenMinted
    updatedAtTimestamp
  }
}
```

```graphql
query Proposals {
  proposals(first: 10, orderBy: createdAtBlock, orderDirection: desc) {
    id
    proposalId
    proposer
    description
    state
    forVotes
    againstVotes
    abstainVotes
  }
}
```

```graphql
query VotesForProposal($proposalId: String!) {
  votes(where: { proposal: $proposalId }, first: 20, orderBy: createdAtBlock, orderDirection: desc) {
    id
    voter
    support
    weight
    reason
  }
}
```

```graphql
query RecentSwaps {
  swaps(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    trader
    amountIn
    amountOut
    isTokenA
    timestamp
  }
}
```
