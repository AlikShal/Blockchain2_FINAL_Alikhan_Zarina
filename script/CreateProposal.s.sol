// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/Governance.sol";

// Creates a harmless governance proposal on Sepolia so the subgraph indexes a
// ProposalCreated event and the frontend Governance Feed is populated.
//
// The proposal target is the TimelockController itself; it proposes to call
// updateDelay(currentDelay) — setting the delay to its existing value, a no-op.
//
// Two-phase flow (needed because vote checkpoints lag one block):
//   Phase 1 — run once if the deployer has never self-delegated:
//     The script detects no delegation, calls govToken.delegate(deployer), and exits.
//     Wait for that transaction to be mined.
//   Phase 2 — run again:
//     The script now sees votes >= threshold and submits governor.propose().
//
// Usage:
//   forge script script/CreateProposal.s.sol --rpc-url $SEPOLIA_RPC_URL \
//     --broadcast --private-key $PRIVATE_KEY
contract CreateProposal is Script {
    address constant GOVERNOR = 0xE1071aD02D88fBFB1F6998e4AFf28b641CBb7E24;
    address constant GOV_TOKEN = 0x8e39D14aCD09115D26386de8944B68c961B46706;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        ProtocolGovernor governor = ProtocolGovernor(payable(GOVERNOR));
        GovernanceToken govToken = GovernanceToken(GOV_TOKEN);

        address currentDelegate = govToken.delegates(deployer);
        uint256 currentVotes = govToken.getVotes(deployer);
        uint256 threshold = governor.proposalThreshold();

        console2.log("deployer  :", deployer);
        console2.log("delegate  :", currentDelegate);
        console2.log("votes     :", currentVotes);
        console2.log("threshold :", threshold);

        vm.startBroadcast(deployerKey);

        // Phase 1: self-delegate if not yet done.
        if (currentDelegate != deployer) {
            govToken.delegate(deployer);
            console2.log("Self-delegated. Wait for this tx to mine, then re-run the script to create the proposal.");
            vm.stopBroadcast();
            return;
        }

        // Votes are checkpointed at delegation block; governor reads clock()-1.
        require(currentVotes >= threshold, "Votes not yet reflected - wait one block after delegating, then re-run.");

        // Resolve the timelock address from the governor (avoids hardcoding).
        address timelockAddr = address(governor.timelock());
        uint256 currentDelay = TimelockController(payable(timelockAddr)).getMinDelay();

        console2.log("timelock  :", timelockAddr);
        console2.log("delay     :", currentDelay);

        // Proposal action: updateDelay(currentDelay) — reconfirms existing value, no state change.
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = timelockAddr;
        calldatas[0] = abi.encodeCall(TimelockController.updateDelay, (currentDelay));

        string memory description = "Demo Proposal: reconfirm timelock min-delay (no-op, for subgraph indexing)";

        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        console2.log("ProposalCreated - proposalId:", proposalId);

        vm.stopBroadcast();
    }
}
