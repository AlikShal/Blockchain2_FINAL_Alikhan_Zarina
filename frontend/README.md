# Frontend dApp

This frontend is a Vite + React + Wagmi dashboard for the `Option C` RWA tokenization flow.

Implemented flows:

- MetaMask wallet connection
- Wrong-network detection with switch prompt for Base Sepolia
- Read token balance, delegated voting power, delegate address, vault shares, vault reserve balance, and AMM reserves
- Write transactions for `delegate`, `deposit`, `swapAForB`, and `castVote`
- Proposal feed sourced from the subgraph endpoint
- Human-readable error handling for rejected transactions and common wallet/RPC failures

Setup:

```bash
cd frontend
npm install
copy .env.example .env
npm run dev
```

Required environment variables are listed in `.env.example`.
