import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  AssetActiveSet,
  AssetRegistered
} from "../generated/AssetRegistry/AssetRegistry";
import {
  DepositRecorded,
  TokensMinted,
  WithdrawalRecorded
} from "../generated/AssetVault/AssetVault";
import { Swap as SwapEvent } from "../generated/AMM/AMM";
import {
  ProposalCanceled,
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  VoteCast
} from "../generated/ProtocolGovernor/ProtocolGovernor";
import { Asset, Proposal, Swap, VaultPosition, Vote } from "../generated/schema";

const ZERO = BigInt.zero();

function getVaultPositionId(vault: Address, user: Address): string {
  return vault.toHexString() + "-" + user.toHexString();
}

function getOrCreateVaultPosition(vault: Address, user: Address, blockNumber: BigInt): VaultPosition {
  let position = VaultPosition.load(getVaultPositionId(vault, user));

  if (position == null) {
    position = new VaultPosition(getVaultPositionId(vault, user));
    position.user = user;
    position.vault = vault;
    position.deposited = ZERO;
    position.assetTokenMinted = ZERO;
    position.createdAtBlock = blockNumber;
    position.updatedAtTimestamp = ZERO;
  }

  return position;
}

function getOrCreateProposal(id: BigInt): Proposal {
  let proposal = Proposal.load(id.toString());

  if (proposal == null) {
    proposal = new Proposal(id.toString());
    proposal.proposalId = id;
    proposal.proposer = Address.zero();
    proposal.description = "";
    proposal.state = "Unknown";
    proposal.forVotes = ZERO;
    proposal.againstVotes = ZERO;
    proposal.abstainVotes = ZERO;
    proposal.createdAtBlock = ZERO;
    proposal.createdAtTimestamp = ZERO;
  }

  return proposal;
}

export function handleAssetRegistered(event: AssetRegistered): void {
  let asset = new Asset(event.params.assetId.toHexString());
  asset.issuer = event.params.issuer;
  asset.reserveAsset = event.params.reserveAsset;
  asset.assetToken = event.params.assetToken;
  asset.vault = event.params.vault;
  asset.maxSupply = event.params.maxSupply;
  asset.metadataURI = event.params.metadataURI;
  asset.active = true;
  asset.createdAtBlock = event.block.number;
  asset.createdAtTimestamp = event.block.timestamp;
  asset.save();
}

export function handleAssetActiveSet(event: AssetActiveSet): void {
  let asset = Asset.load(event.params.assetId.toHexString());

  if (asset == null) {
    return;
  }

  asset.active = event.params.active;
  asset.save();
}

export function handleDepositRecorded(event: DepositRecorded): void {
  let position = getOrCreateVaultPosition(event.address, event.params.user, event.block.number);
  position.deposited = position.deposited.plus(event.params.amount);
  position.updatedAtTimestamp = event.block.timestamp;
  position.save();
}

export function handleWithdrawalRecorded(event: WithdrawalRecorded): void {
  let position = getOrCreateVaultPosition(event.address, event.params.user, event.block.number);
  position.deposited = position.deposited.minus(event.params.amount);
  position.updatedAtTimestamp = event.block.timestamp;
  position.save();
}

export function handleTokensMinted(event: TokensMinted): void {
  let position = getOrCreateVaultPosition(event.address, event.params.user, event.block.number);
  position.assetTokenMinted = position.assetTokenMinted.plus(event.params.amount);
  position.updatedAtTimestamp = event.block.timestamp;
  position.save();
}

export function handleSwap(event: SwapEvent): void {
  let swap = new Swap(event.transaction.hash.toHexString() + "-" + event.logIndex.toString());
  swap.trader = event.params.swapper;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.isTokenA = event.params.isTokenA;
  swap.timestamp = event.block.timestamp;
  swap.blockNumber = event.block.number;
  swap.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let proposal = new Proposal(event.params.proposalId.toString());
  proposal.proposalId = event.params.proposalId;
  proposal.proposer = event.params.proposer;
  proposal.description = event.params.description;
  proposal.state = "Pending";
  proposal.forVotes = ZERO;
  proposal.againstVotes = ZERO;
  proposal.abstainVotes = ZERO;
  proposal.createdAtBlock = event.block.number;
  proposal.createdAtTimestamp = event.block.timestamp;
  proposal.save();
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let proposal = getOrCreateProposal(event.params.proposalId);
  proposal.state = "Canceled";
  proposal.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = getOrCreateProposal(event.params.proposalId);
  proposal.state = "Queued";
  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = getOrCreateProposal(event.params.proposalId);
  proposal.state = "Executed";
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let proposal = getOrCreateProposal(event.params.proposalId);
  let vote = new Vote(event.transaction.hash.toHexString() + "-" + event.logIndex.toString());
  vote.proposal = proposal.id;
  vote.voter = event.params.voter;
  vote.support = event.params.support;
  vote.weight = event.params.weight;
  vote.reason = event.params.reason;
  vote.createdAtBlock = event.block.number;
  vote.createdAtTimestamp = event.block.timestamp;
  vote.save();

  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight);
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight);
    proposal.state = "Active";
  } else {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight);
    proposal.state = "Active";
  }

  proposal.save();
}
