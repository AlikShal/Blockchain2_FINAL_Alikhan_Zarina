import { useEffect, useState } from "react";
import {
  useAccount,
  useBalance,
  useChainId,
  useConnect,
  useDisconnect,
  useReadContract,
  useSwitchChain,
  useWriteContract
} from "wagmi";
import { getPublicClient, waitForTransactionReceipt } from "wagmi/actions";
import { formatUnits, parseUnits } from "viem";
import { appConfig, expectedChain } from "./wagmi";
import {
  ammAbi,
  contracts,
  contractsReady,
  erc20Abi,
  governorAbi,
  isConfiguredAddress,
  missingContractKeys,
  subgraphUrl,
  vaultAbi
} from "./contracts";
import { getReadableError } from "./errors";

const proposalStates = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed"
];

const proposalQuery = `
  query DashboardData {
    proposals(first: 6, orderBy: createdAtBlock, orderDirection: desc) {
      id
      proposalId
      proposer
      description
      state
      forVotes
      againstVotes
      abstainVotes
      createdAtBlock
    }
    swaps(first: 5, orderBy: timestamp, orderDirection: desc) {
      id
      trader
      amountIn
      amountOut
      timestamp
    }
  }
`;

const isPlaceholderSubgraphUrl =
  !subgraphUrl || subgraphUrl.includes("YOUR_SUBGRAPH_ID");

function formatToken(value, decimals = 18, digits = 4) {
  if (value === undefined || value === null) {
    return "0";
  }

  const numeric = Number(formatUnits(value, decimals));
  return Number.isFinite(numeric) ? numeric.toFixed(digits) : "0";
}

function shortenAddress(address) {
  if (!address || address.length < 10) {
    return "Not delegated";
  }

  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function ProposalCard({ proposal, onVote }) {
  const proposalState = useReadContract({
    address: contracts.governor,
    abi: governorAbi,
    functionName: "state",
    args: [BigInt(proposal.proposalId)],
    query: { enabled: contractsReady }
  });

  const liveState = proposalState.data !== undefined ? proposalStates[Number(proposalState.data)] : proposal.state;

  return (
    <article className="proposal-card">
      <div className="proposal-header">
        <div>
          <span className="proposal-id">Proposal #{proposal.proposalId}</span>
          <h3>{proposal.description || "Protocol proposal"}</h3>
        </div>
        <span className="state-badge">{liveState}</span>
      </div>
      <p className="proposal-meta">Proposer: {shortenAddress(proposal.proposer)}</p>
      <div className="proposal-votes">
        <span>For: {formatToken(BigInt(proposal.forVotes || "0"))}</span>
        <span>Against: {formatToken(BigInt(proposal.againstVotes || "0"))}</span>
        <span>Abstain: {formatToken(BigInt(proposal.abstainVotes || "0"))}</span>
      </div>
      <button className="primary-button" onClick={() => onVote(proposal.proposalId)}>
        Vote For
      </button>
    </article>
  );
}

export default function App() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const wrongNetwork = isConnected && chainId !== expectedChain.id;
  const { connect, connectors, isPending: isConnecting } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChainAsync, isPending: isSwitching } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();

  const [delegatee, setDelegatee] = useState("");
  const [depositAmount, setDepositAmount] = useState("");
  const [swapAmount, setSwapAmount] = useState("");
  const [minOutAmount, setMinOutAmount] = useState("");
  const [status, setStatus] = useState("Configure deployed addresses and connect a wallet to use the dApp.");
  const [subgraphState, setSubgraphState] = useState({ proposals: [], swaps: [], error: "" });

  const reserveDecimals = useReadContract({
    address: contracts.reserveToken,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: contractsReady }
  });

  const quoteDecimals = useReadContract({
    address: contracts.quoteToken,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: contractsReady }
  });

  const reserveSymbol = useReadContract({
    address: contracts.reserveToken,
    abi: erc20Abi,
    functionName: "symbol",
    query: { enabled: contractsReady }
  });

  const quoteSymbol = useReadContract({
    address: contracts.quoteToken,
    abi: erc20Abi,
    functionName: "symbol",
    query: { enabled: contractsReady }
  });

  const assetDecimals = useReadContract({
    address: contracts.assetToken,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: contractsReady }
  });

  const assetSymbol = useReadContract({
    address: contracts.assetToken,
    abi: erc20Abi,
    functionName: "symbol",
    query: { enabled: contractsReady }
  });

  const reserveBalance = useBalance({
    address,
    token: contracts.reserveToken,
    query: { enabled: isConnected && contractsReady }
  });

  const assetBalance = useBalance({
    address,
    token: contracts.assetToken,
    query: { enabled: isConnected && contractsReady }
  });

  const governanceBalance = useBalance({
    address,
    token: contracts.governanceToken,
    query: { enabled: isConnected && contractsReady }
  });

  const votingPower = useReadContract({
    address: contracts.governanceToken,
    abi: erc20Abi,
    functionName: "getVotes",
    args: address ? [address] : undefined,
    query: { enabled: isConnected && contractsReady }
  });

  const delegateAddress = useReadContract({
    address: contracts.governanceToken,
    abi: erc20Abi,
    functionName: "delegates",
    args: address ? [address] : undefined,
    query: { enabled: isConnected && contractsReady }
  });

  const vaultShares = useReadContract({
    address: contracts.assetVault,
    abi: vaultAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: isConnected && contractsReady }
  });

  const vaultAssets = useReadContract({
    address: contracts.assetVault,
    abi: vaultAbi,
    functionName: "totalAssets",
    query: { enabled: contractsReady }
  });

  const totalDeposited = useReadContract({
    address: contracts.assetVault,
    abi: vaultAbi,
    functionName: "totalDeposited",
    query: { enabled: contractsReady }
  });

  const reserveA = useReadContract({
    address: contracts.amm,
    abi: ammAbi,
    functionName: "reserveA",
    query: { enabled: contractsReady }
  });

  const reserveB = useReadContract({
    address: contracts.amm,
    abi: ammAbi,
    functionName: "reserveB",
    query: { enabled: contractsReady }
  });

  useEffect(() => {
    const controller = new AbortController();

    async function fetchOnchainFeed() {
      if (!contractsReady) {
        setSubgraphState({ proposals: [], swaps: [], error: "Contract addresses are required before loading local activity." });
        return;
      }

      try {
        const client = getPublicClient(appConfig);

        const [proposalLogs, swapLogs] = await Promise.all([
          client.getLogs({
            address: contracts.governor,
            event: governorAbi.find(
              (item) => item.type === "event" && item.name === "ProposalCreated"
            ),
            fromBlock: 0n,
            toBlock: "latest"
          }),
          client.getLogs({
            address: contracts.amm,
            event: ammAbi.find((item) => item.type === "event" && item.name === "Swap"),
            fromBlock: 0n,
            toBlock: "latest"
          })
        ]);

        const proposals = await Promise.all(
          proposalLogs
            .slice()
            .reverse()
            .slice(0, 6)
            .map(async (log) => {
              const proposalId = log.args.proposalId;
              const [state, votes] = await Promise.all([
                client.readContract({
                  address: contracts.governor,
                  abi: governorAbi,
                  functionName: "state",
                  args: [proposalId]
                }),
                client.readContract({
                  address: contracts.governor,
                  abi: governorAbi,
                  functionName: "proposalVotes",
                  args: [proposalId]
                })
              ]);

              return {
                id: proposalId.toString(),
                proposalId: proposalId.toString(),
                proposer: log.args.proposer,
                description: log.args.description,
                state: proposalStates[Number(state)] || "Unknown",
                againstVotes: votes[0].toString(),
                forVotes: votes[1].toString(),
                abstainVotes: votes[2].toString(),
                createdAtBlock: log.blockNumber?.toString() || "0"
              };
            })
        );

        const swaps = swapLogs
          .slice()
          .reverse()
          .slice(0, 5)
          .map((log) => ({
            id: `${log.transactionHash}-${log.logIndex}`,
            trader: log.args.swapper,
            amountIn: log.args.amountIn.toString(),
            amountOut: log.args.amountOut.toString(),
            timestamp: "0"
          }));

        setSubgraphState({
          proposals,
          swaps,
          error: "Local mode: showing direct on-chain activity without subgraph."
        });
      } catch (error) {
        setSubgraphState({
          proposals: [],
          swaps: [],
          error: getReadableError(error)
        });
      }
    }

    async function fetchSubgraphData() {
      try {
        const response = await fetch(subgraphUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ query: proposalQuery }),
          signal: controller.signal
        });
        const payload = await response.json();

        if (!response.ok || payload.errors) {
          throw new Error("The subgraph query returned an error.");
        }

        setSubgraphState({
          proposals: payload.data?.proposals || [],
          swaps: payload.data?.swaps || [],
          error: ""
        });
      } catch (error) {
        if (!controller.signal.aborted) {
          await fetchOnchainFeed();
        }
      }
    }

    if (isPlaceholderSubgraphUrl || expectedChain.id === 31_337) {
      fetchOnchainFeed();
    } else {
      fetchSubgraphData();
    }

    return () => controller.abort();
  }, [contractsReady]);

  async function submitAndWait(request, pendingLabel) {
    const hash = await writeContractAsync(request);
    setStatus(`${pendingLabel} submitted: ${hash}`);
    await waitForTransactionReceipt(appConfig, { hash });
    setStatus(`${pendingLabel} confirmed.`);
  }

  async function ensureReady() {
    if (!isConnected) {
      throw new Error("Connect a wallet before sending transactions.");
    }

    if (!contractsReady) {
      throw new Error(`Missing contract addresses: ${missingContractKeys.join(", ")}`);
    }

    if (wrongNetwork) {
      throw new Error("Wallet connected to the wrong chain.");
    }
  }

  async function handleDelegate() {
    try {
      await ensureReady();
      if (!isConfiguredAddress(delegatee)) {
        throw new Error("Enter a valid delegate address.");
      }

      await submitAndWait(
        {
          address: contracts.governanceToken,
          abi: erc20Abi,
          functionName: "delegate",
          args: [delegatee]
        },
        "Delegation"
      );
    } catch (error) {
      setStatus(getReadableError(error));
    }
  }

  async function handleDeposit() {
    try {
      await ensureReady();
      const decimals = Number(reserveDecimals.data ?? 18);
      const amount = parseUnits(depositAmount || "0", decimals);
      const walletBalance = reserveBalance.data?.value ?? 0n;

      if (amount <= 0n) {
        throw new Error("Enter a deposit amount greater than zero.");
      }

      if (walletBalance < amount) {
        throw new Error("Reserve token balance is too low for this deposit.");
      }

      await submitAndWait(
        {
          address: contracts.reserveToken,
          abi: erc20Abi,
          functionName: "approve",
          args: [contracts.assetVault, amount]
        },
        "Vault approval"
      );

      await submitAndWait(
        {
          address: contracts.assetVault,
          abi: vaultAbi,
          functionName: "deposit",
          args: [amount, address]
        },
        "Vault deposit"
      );
    } catch (error) {
      setStatus(getReadableError(error));
    }
  }

  async function handleSwap() {
    try {
      await ensureReady();
      const inputDecimals = Number(assetDecimals.data ?? 18);
      const outputDecimals = Number(quoteDecimals.data ?? 18);
      const amountIn = parseUnits(swapAmount || "0", inputDecimals);
      const minOut = parseUnits(minOutAmount || "0", outputDecimals);
      const walletBalance = assetBalance.data?.value ?? 0n;

      if (amountIn <= 0n) {
        throw new Error("Enter a swap amount greater than zero.");
      }

      if (walletBalance < amountIn) {
        throw new Error("Asset token balance is too low for this swap.");
      }

      await submitAndWait(
        {
          address: contracts.assetToken,
          abi: erc20Abi,
          functionName: "approve",
          args: [contracts.amm, amountIn]
        },
        "AMM approval"
      );

      await submitAndWait(
        {
          address: contracts.amm,
          abi: ammAbi,
          functionName: "swapAForB",
          args: [amountIn, minOut]
        },
        "Swap"
      );
    } catch (error) {
      setStatus(getReadableError(error));
    }
  }

  async function handleVote(proposalId) {
    try {
      await ensureReady();
      await submitAndWait(
        {
          address: contracts.governor,
          abi: governorAbi,
          functionName: "castVote",
          args: [BigInt(proposalId), 1]
        },
        `Vote for proposal ${proposalId}`
      );
    } catch (error) {
      setStatus(getReadableError(error));
    }
  }

  async function handleSwitchChain() {
    try {
      await switchChainAsync({ chainId: expectedChain.id });
      setStatus("Network switched. You can continue with protocol actions.");
    } catch (error) {
      setStatus(getReadableError(error));
    }
  }

  return (
    <div className="page-shell">
      <div className="ambient ambient-left" />
      <div className="ambient ambient-right" />

      <header className="hero">
        <div>
          <p className="eyebrow">Blockchain Technologies 2</p>
          <h1>Option C RWA Tokenization Control Room</h1>
          <p className="hero-copy">
            Monitor reserve-backed assets, run user flows through the vault and AMM, and interact
            with on-chain governance from one dashboard.
          </p>
        </div>

        <div className="hero-actions">
          {!isConnected ? (
            <button
              className="primary-button"
              onClick={() => connect({ connector: connectors[0] })}
              disabled={isConnecting || connectors.length === 0}
            >
              {isConnecting ? "Connecting..." : "Connect MetaMask"}
            </button>
          ) : (
            <>
              <div className="wallet-pill">
                <span>Wallet</span>
                <strong>{shortenAddress(address)}</strong>
              </div>
              <button className="ghost-button" onClick={() => disconnect()}>
                Disconnect
              </button>
            </>
          )}
        </div>
      </header>

      <section className="status-bar">
        <div>
          <span className="status-label">Network</span>
          <strong>{wrongNetwork ? "Wrong chain detected" : expectedChain.name}</strong>
        </div>
        <div>
          <span className="status-label">Frontend status</span>
          <strong>{contractsReady ? "Contract config loaded" : "Missing addresses"}</strong>
        </div>
        <div className="status-cta">
          {wrongNetwork ? (
            <button className="primary-button" onClick={handleSwitchChain} disabled={isSwitching}>
              {isSwitching ? "Switching..." : `Switch to ${expectedChain.name}`}
            </button>
          ) : null}
        </div>
      </section>

      {!contractsReady ? (
        <section className="warning-card">
          <h2>Deployment values still needed</h2>
          <p>
            Fill the missing environment variables in <code>frontend/.env</code>:
          </p>
          <p className="inline-list">{missingContractKeys.join(", ")}</p>
        </section>
      ) : null}

      <main className="dashboard-grid">
        <section className="panel">
          <h2>Wallet and Governance</h2>
          <div className="stat-grid">
            <article className="stat-card">
              <span>Reserve Balance</span>
              <strong>{reserveBalance.data ? reserveBalance.data.formatted : "0"} {reserveSymbol.data || "RSV"}</strong>
            </article>
            <article className="stat-card">
              <span>Asset Balance</span>
              <strong>{assetBalance.data ? assetBalance.data.formatted : "0"} ASSET</strong>
            </article>
            <article className="stat-card">
              <span>Governance Balance</span>
              <strong>{governanceBalance.data ? governanceBalance.data.formatted : "0"} GOV</strong>
            </article>
            <article className="stat-card">
              <span>Voting Power</span>
              <strong>{formatToken(votingPower.data)}</strong>
            </article>
            <article className="stat-card">
              <span>Delegate</span>
              <strong>{shortenAddress(delegateAddress.data)}</strong>
            </article>
            <article className="stat-card">
              <span>Vault Shares</span>
              <strong>{formatToken(vaultShares.data)}</strong>
            </article>
          </div>

          <div className="form-card">
            <label htmlFor="delegatee">Delegate governance power</label>
            <input
              id="delegatee"
              value={delegatee}
              onChange={(event) => setDelegatee(event.target.value)}
              placeholder="0x..."
            />
            <button className="primary-button" onClick={handleDelegate}>
              Delegate Votes
            </button>
          </div>
        </section>

        <section className="panel">
          <h2>Protocol State</h2>
          <div className="stat-grid">
            <article className="stat-card">
              <span>Vault Reserve Assets</span>
              <strong>{formatToken(vaultAssets.data, Number(reserveDecimals.data ?? 18))}</strong>
            </article>
            <article className="stat-card">
              <span>Total Deposited</span>
              <strong>{formatToken(totalDeposited.data, Number(reserveDecimals.data ?? 18))}</strong>
            </article>
            <article className="stat-card">
              <span>AMM Reserve A</span>
              <strong>{formatToken(reserveA.data, Number(assetDecimals.data ?? 18))} {assetSymbol.data || "ASSET"}</strong>
            </article>
            <article className="stat-card">
              <span>AMM Reserve B</span>
              <strong>{formatToken(reserveB.data, Number(quoteDecimals.data ?? 18))} {quoteSymbol.data || "QTE"}</strong>
            </article>
          </div>
        </section>

        <section className="panel">
          <h2>Vault Deposit</h2>
          <div className="form-card">
            <label htmlFor="depositAmount">Deposit reserve asset</label>
            <input
              id="depositAmount"
              value={depositAmount}
              onChange={(event) => setDepositAmount(event.target.value)}
              placeholder={`100 ${reserveSymbol.data || "RSV"}`}
            />
            <button className="primary-button" onClick={handleDeposit}>
              Approve and Deposit
            </button>
          </div>
        </section>

        <section className="panel">
          <h2>AMM Swap</h2>
          <div className="form-card">
            <label htmlFor="swapAmount">Swap asset token for quote token</label>
            <input
              id="swapAmount"
              value={swapAmount}
              onChange={(event) => setSwapAmount(event.target.value)}
              placeholder={`25 ${assetSymbol.data || "ASSET"}`}
            />
            <label htmlFor="minOutAmount">Minimum quote output</label>
            <input
              id="minOutAmount"
              value={minOutAmount}
              onChange={(event) => setMinOutAmount(event.target.value)}
              placeholder={`24 ${quoteSymbol.data || "QTE"}`}
            />
            <button className="primary-button" onClick={handleSwap}>
              Approve and Swap
            </button>
          </div>
        </section>

        <section className="panel panel-wide">
          <h2>Indexed Governance Feed</h2>
          <p className="panel-copy">
            This section is intentionally sourced from the subgraph rather than direct contract
            calls, so the frontend satisfies the indexing requirement.
          </p>
          {subgraphState.error ? <p className="error-text">{subgraphState.error}</p> : null}
          <div className="proposal-list">
            {subgraphState.proposals.length === 0 ? (
              <article className="proposal-card">
                <strong>No indexed proposals yet.</strong>
                <p>Once the subgraph is deployed and synced, proposals will appear here with vote buttons.</p>
              </article>
            ) : (
              subgraphState.proposals.map((proposal) => (
                <ProposalCard key={proposal.id} proposal={proposal} onVote={handleVote} />
              ))
            )}
          </div>
        </section>

        <section className="panel panel-wide">
          <h2>Recent Indexed Swaps</h2>
          <div className="swap-table">
            <div className="swap-row swap-head">
              <span>Trader</span>
              <span>Amount In</span>
              <span>Amount Out</span>
            </div>
            {subgraphState.swaps.length === 0 ? (
              <div className="swap-row">
                <span>No indexed swaps yet.</span>
                <span>-</span>
                <span>-</span>
              </div>
            ) : (
              subgraphState.swaps.map((swap) => (
                <div className="swap-row" key={swap.id}>
                  <span>{shortenAddress(swap.trader)}</span>
                  <span>{formatToken(BigInt(swap.amountIn || "0"), Number(assetDecimals.data ?? 18))}</span>
                  <span>{formatToken(BigInt(swap.amountOut || "0"), Number(quoteDecimals.data ?? 18))}</span>
                </div>
              ))
            )}
          </div>
        </section>
      </main>

      <footer className="status-footer">
        <span>Status</span>
        <strong>{status}</strong>
      </footer>
    </div>
  );
}
