// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { EmberArena } from "../src/EmberArena.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock EMBER token for testing
contract MockEMBER is ERC20 {
    constructor() ERC20("Ember Token", "EMBER") {
        _mint(msg.sender, 100_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EmberArenaTest is Test {
    EmberArena public arena;
    MockEMBER public ember;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public ideaCreator;

    uint256 public constant MIN_THRESHOLD = 100 ether;
    uint256 public constant SUBMISSION_FEE = 100_000 ether; // 100K EMBER

    // Events (updated to match contract)
    event RoundStarted(uint256 indexed roundId, uint256 submissionStart, uint256 votingStart, uint256 votingEnd);
    event IdeaSubmitted(uint256 indexed roundId, uint256 indexed ideaId, address indexed creator, string description, uint256 fee);
    event IdeaBacked(uint256 indexed roundId, uint256 indexed ideaId, address indexed backer, uint256 amount);
    event WinnerSelected(uint256 indexed roundId, uint256 indexed winningIdeaId, address indexed creator, uint256 totalPool);
    event WinningsClaimed(uint256 indexed roundId, address indexed backer, uint256 amount);
    event TokensBurned(uint256 indexed roundId, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        ideaCreator = makeAddr("ideaCreator");

        ember = new MockEMBER();
        arena = new EmberArena(address(ember), MIN_THRESHOLD);

        // Fund users with enough for submission fees + backing
        ember.mint(user1, 500_000 ether);
        ember.mint(user2, 500_000 ether);
        ember.mint(user3, 500_000 ether);
        ember.mint(ideaCreator, 500_000 ether);

        // Approve arena for all users
        vm.prank(user1);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(user2);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(user3);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(ideaCreator);
        ember.approve(address(arena), type(uint256).max);
    }

    // ============================================
    // Constructor Tests
    // ============================================

    function test_Constructor() public view {
        assertEq(address(arena.emberToken()), address(ember));
        assertEq(arena.minBackingThreshold(), MIN_THRESHOLD);
        assertEq(arena.owner(), owner);
        assertEq(arena.currentRoundId(), 0);
        assertEq(arena.totalIdeas(), 0);
    }

    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert(EmberArena.ZeroAddress.selector);
        new EmberArena(address(0), MIN_THRESHOLD);
    }

    // ============================================
    // Round Management Tests
    // ============================================

    function test_StartRound() public {
        vm.expectEmit(true, false, false, true);
        emit RoundStarted(1, block.timestamp, block.timestamp + 24 hours, block.timestamp + 48 hours);

        arena.startRound();

        assertEq(arena.currentRoundId(), 1);

        EmberArena.Round memory round = arena.getRoundInfo(1);
        assertEq(round.roundId, 1);
        assertEq(round.submissionStart, block.timestamp);
        assertEq(round.votingStart, block.timestamp + 24 hours);
        assertEq(round.votingEnd, block.timestamp + 48 hours);
        assertEq(round.totalPool, 0);
        assertEq(round.resolved, false);
    }

    function test_StartRound_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        arena.startRound();
    }

    function test_StartRound_RevertAlreadyActive() public {
        arena.startRound();

        vm.expectRevert(EmberArena.RoundAlreadyActive.selector);
        arena.startRound();
    }

    function test_StartRound_AfterPreviousEnds() public {
        arena.startRound();

        // Warp past voting end
        vm.warp(block.timestamp + 49 hours);

        // Can start new round
        arena.startRound();
        assertEq(arena.currentRoundId(), 2);
    }

    // ============================================
    // Idea Submission Tests
    // ============================================

    function test_SubmitIdea() public {
        arena.startRound();

        vm.prank(ideaCreator);
        vm.expectEmit(true, true, true, true);
        emit IdeaSubmitted(1, 1, ideaCreator, "Build a DEX", SUBMISSION_FEE);

        uint256 ideaId = arena.submitIdea("Build a DEX", "ipfs://Qm...");

        assertEq(ideaId, 1);
        assertEq(arena.totalIdeas(), 1);

        EmberArena.Idea memory idea = arena.getIdea(1);
        assertEq(idea.ideaId, 1);
        assertEq(idea.roundId, 1);
        assertEq(idea.creator, ideaCreator);
        assertEq(idea.description, "Build a DEX");
        assertEq(idea.metadata, "ipfs://Qm...");
        assertEq(idea.totalBacking, 0);
        assertEq(idea.isWinner, false);

        // Check fee was charged and added to pool
        EmberArena.Round memory round = arena.getRoundInfo(1);
        assertEq(round.totalPool, SUBMISSION_FEE);
    }

    function test_SubmitIdea_RevertNoRound() public {
        vm.prank(ideaCreator);
        vm.expectRevert(EmberArena.RoundNotActive.selector);
        arena.submitIdea("Build a DEX", "");
    }

    function test_SubmitIdea_RevertNotInSubmissionPhase() public {
        arena.startRound();

        // Warp to voting phase
        vm.warp(block.timestamp + 25 hours);

        vm.prank(ideaCreator);
        vm.expectRevert(EmberArena.NotInSubmissionPhase.selector);
        arena.submitIdea("Too late", "");
    }

    function test_SubmitIdea_RevertEmptyDescription() public {
        arena.startRound();

        vm.prank(ideaCreator);
        vm.expectRevert(EmberArena.EmptyDescription.selector);
        arena.submitIdea("", "ipfs://");
    }

    function test_SubmitIdea_MaxIdeas() public {
        arena.startRound();

        // Submit max ideas
        for (uint256 i = 0; i < 100; i++) {
            address creator = makeAddr(string(abi.encodePacked("creator", i)));
            ember.mint(creator, SUBMISSION_FEE);
            vm.prank(creator);
            ember.approve(address(arena), SUBMISSION_FEE);
            vm.prank(creator);
            arena.submitIdea("Idea", "");
        }

        // 101st should fail
        vm.prank(ideaCreator);
        vm.expectRevert(EmberArena.MaxIdeasReached.selector);
        arena.submitIdea("One too many", "");
    }

    // ============================================
    // Backing Tests
    // ============================================

    function test_BackIdea() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Build a DEX", "");

        // Warp to voting phase
        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IdeaBacked(1, 1, user1, 50 ether);
        arena.backIdea(1, 50 ether);

        EmberArena.Idea memory idea = arena.getIdea(1);
        assertEq(idea.totalBacking, 50 ether);

        EmberArena.Round memory round = arena.getRoundInfo(1);
        assertEq(round.totalPool, SUBMISSION_FEE + 50 ether);

        assertEq(ember.balanceOf(address(arena)), SUBMISSION_FEE + 50 ether);
    }

    function test_BackIdea_MultipleBacks() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Build a DEX", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 50 ether);

        vm.prank(user2);
        arena.backIdea(1, 30 ether);

        // User1 backs again
        vm.prank(user1);
        arena.backIdea(1, 20 ether);

        EmberArena.Idea memory idea = arena.getIdea(1);
        assertEq(idea.totalBacking, 100 ether);

        // Check user1's backing accumulated
        EmberArena.Backing memory backing = arena.getUserBackingForIdea(user1, 1, 1);
        assertEq(backing.amount, 70 ether);
    }

    function test_BackIdea_RevertNotInVotingPhase() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Build a DEX", "");

        // Still in submission phase
        vm.prank(user1);
        vm.expectRevert(EmberArena.NotInVotingPhase.selector);
        arena.backIdea(1, 50 ether);
    }

    function test_BackIdea_RevertAfterVotingEnds() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Build a DEX", "");

        // Warp past voting
        vm.warp(block.timestamp + 49 hours);

        vm.prank(user1);
        vm.expectRevert(EmberArena.NotInVotingPhase.selector);
        arena.backIdea(1, 50 ether);
    }

    function test_BackIdea_RevertBelowMinimum() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Build a DEX", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        vm.expectRevert(EmberArena.AmountBelowMinimum.selector);
        arena.backIdea(1, 1e15); // 0.001 tokens, below 0.01 minimum
    }

    function test_BackIdea_RevertIdeaDoesNotExist() public {
        arena.startRound();

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        vm.expectRevert(EmberArena.IdeaDoesNotExist.selector);
        arena.backIdea(999, 50 ether);
    }

    // ============================================
    // Winner Selection Tests
    // ============================================

    function test_SelectWinner() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.prank(user2);
        arena.backIdea(1, 100 ether);

        // Warp past voting
        vm.warp(block.timestamp + 25 hours);

        uint256 totalPool = SUBMISSION_FEE + 200 ether;
        uint256 burnAmount = (totalPool * 2000) / 10000; // 20%

        vm.expectEmit(true, true, true, true);
        emit TokensBurned(1, burnAmount);
        vm.expectEmit(true, true, true, true);
        emit WinnerSelected(1, 1, ideaCreator, totalPool);

        arena.selectWinner(1);

        EmberArena.Round memory round = arena.getRoundInfo(1);
        assertEq(round.resolved, true);
        assertEq(round.winningIdeaId, 1);

        EmberArena.Idea memory idea = arena.getIdea(1);
        assertEq(idea.isWinner, true);

        // Check burn
        assertEq(ember.balanceOf(arena.BURN_ADDRESS()), burnAmount);
    }

    function test_SelectWinner_RevertBeforeVotingEnds() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        // Still in voting
        vm.expectRevert(EmberArena.VotingNotEnded.selector);
        arena.selectWinner(1);
    }

    function test_SelectWinner_RevertBelowThreshold() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Underfunded idea", "");

        vm.warp(start + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 50 ether); // Below 100 ether threshold

        vm.warp(start + 49 hours);

        vm.expectRevert(EmberArena.IdeaBelowThreshold.selector);
        arena.selectWinner(1);
    }

    function test_SelectWinner_RevertAlreadyResolved() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning idea", "");

        vm.warp(start + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);

        arena.selectWinner(1);

        vm.expectRevert(EmberArena.RoundAlreadyResolved.selector);
        arena.selectWinner(1);
    }

    // ============================================
    // Claim Winnings Tests
    // ============================================

    function test_ClaimWinnings() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning idea", "");

        vm.warp(block.timestamp + 25 hours);

        // User1 backs with 100, User2 backs with 100
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.prank(user2);
        arena.backIdea(1, 100 ether);

        vm.warp(block.timestamp + 25 hours);

        arena.selectWinner(1);

        // Total pool = SUBMISSION_FEE + 200, distributable = 80% of that
        // Each user backed 50% of winning idea's backing
        // User share = (userBacking / ideaTotalBacking) * distributablePool
        uint256 totalPool = SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 8000) / 10000;
        uint256 expectedShare = (100 ether * distributable) / 200 ether;

        uint256 user1BalanceBefore = ember.balanceOf(user1);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit WinningsClaimed(1, user1, expectedShare);
        arena.claimWinnings(1);

        assertEq(ember.balanceOf(user1), user1BalanceBefore + expectedShare);
    }

    function test_ClaimWinnings_RevertNotResolved() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.prank(user1);
        vm.expectRevert(EmberArena.RoundNotResolved.selector);
        arena.claimWinnings(1);
    }

    function test_ClaimWinnings_RevertNothingToClaim() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning", "");

        vm.warp(start + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);

        arena.selectWinner(1);

        // User2 didn't back
        vm.prank(user2);
        vm.expectRevert(EmberArena.NothingToClaim.selector);
        arena.claimWinnings(1);
    }

    function test_ClaimWinnings_RevertAlreadyClaimed() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning", "");

        vm.warp(start + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);

        arena.selectWinner(1);

        vm.prank(user1);
        arena.claimWinnings(1);

        vm.prank(user1);
        vm.expectRevert(EmberArena.AlreadyClaimed.selector);
        arena.claimWinnings(1);
    }

    function test_ClaimWinnings_ProportionalDistribution() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning", "");

        vm.warp(start + 25 hours);

        // User1: 150, User2: 50 (3:1 ratio)
        vm.prank(user1);
        arena.backIdea(1, 150 ether);

        vm.prank(user2);
        arena.backIdea(1, 50 ether);

        vm.warp(start + 49 hours);

        arena.selectWinner(1);

        // Total = SUBMISSION_FEE + 200, distributable = 80%
        // Idea totalBacking = 200 ether
        // User1 gets 75% of distributable, User2 gets 25%
        uint256 totalPool = SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 8000) / 10000;
        uint256 expected1 = (150 ether * distributable) / 200 ether;
        uint256 expected2 = (50 ether * distributable) / 200 ether;

        uint256 user1Before = ember.balanceOf(user1);
        uint256 user2Before = ember.balanceOf(user2);

        vm.prank(user1);
        arena.claimWinnings(1);

        vm.prank(user2);
        arena.claimWinnings(1);

        assertEq(ember.balanceOf(user1) - user1Before, expected1);
        assertEq(ember.balanceOf(user2) - user2Before, expected2);
    }

    // ============================================
    // View Function Tests
    // ============================================

    function test_GetCurrentPhase() public {
        // No round
        assertEq(arena.getCurrentPhase(), 0);

        uint256 start = block.timestamp;
        arena.startRound();
        assertEq(arena.getCurrentPhase(), 1); // Submission

        vm.warp(start + 25 hours);
        assertEq(arena.getCurrentPhase(), 2); // Voting

        vm.warp(start + 49 hours);
        assertEq(arena.getCurrentPhase(), 3); // Ended
    }

    function test_GetRoundIdeaIds() public {
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");

        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        uint256[] memory ideaIds = arena.getRoundIdeaIds(1);
        assertEq(ideaIds.length, 2);
        assertEq(ideaIds[0], 1);
        assertEq(ideaIds[1], 2);
    }

    function test_GetUserBackings() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Idea 1", "");
        vm.prank(ideaCreator);
        arena.submitIdea("Idea 2", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 50 ether);
        vm.prank(user1);
        arena.backIdea(2, 30 ether);

        uint256[] memory backedIds = arena.getUserBackings(user1, 1);
        assertEq(backedIds.length, 2);
        assertEq(backedIds[0], 1);
        assertEq(backedIds[1], 2);
    }

    function test_CalculatePotentialWinnings() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.prank(user2);
        arena.backIdea(1, 100 ether);

        // Total pool = SUBMISSION_FEE + 200 ether
        // Idea backing = 200 ether
        // User1 potential: (100/200) * ((SUBMISSION_FEE + 200) * 0.8)
        uint256 totalPool = SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 8000) / 10000;
        uint256 expected = (100 ether * distributable) / 200 ether;

        uint256 potential = arena.calculatePotentialWinnings(1, 1, user1);
        assertEq(potential, expected);
    }

    // ============================================
    // Pause Tests
    // ============================================

    function test_Pause() public {
        arena.pause();
        assertTrue(arena.paused());

        vm.expectRevert();
        arena.startRound();
    }

    function test_Unpause() public {
        arena.pause();
        arena.unpause();
        assertFalse(arena.paused());

        arena.startRound();
        assertEq(arena.currentRoundId(), 1);
    }

    function test_Pause_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        arena.pause();
    }

    // ============================================
    // Emergency Withdrawal Tests
    // ============================================

    function test_EmergencyWithdraw() public {
        // Send some tokens to contract (not during active round)
        ember.transfer(address(arena), 100 ether);

        uint256 ownerBefore = ember.balanceOf(owner);

        arena.emergencyWithdraw(address(ember), owner, 50 ether);

        assertEq(ember.balanceOf(owner), ownerBefore + 50 ether);
    }

    function test_EmergencyWithdraw_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        arena.emergencyWithdraw(address(ember), user1, 1 ether);
    }

    function test_EmergencyWithdraw_RevertDuringActiveRound() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        // Contract now holds SUBMISSION_FEE
        // Try to withdraw EMBER during active round
        vm.expectRevert(EmberArena.CannotWithdrawUserFunds.selector);
        arena.emergencyWithdraw(address(ember), owner, SUBMISSION_FEE);
    }

    function test_EmergencyWithdraw_AllowedAfterResolution() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(block.timestamp + 25 hours);

        arena.selectWinner(1);

        // After resolution, remaining funds (if any) can be withdrawn
        // Note: In normal flow, all funds are distributed/burned
    }

    // ============================================
    // Threshold Update Tests
    // ============================================

    function test_SetMinBackingThreshold() public {
        arena.setMinBackingThreshold(500 ether);
        assertEq(arena.minBackingThreshold(), 500 ether);
    }

    function test_SetMinBackingThreshold_RevertNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        arena.setMinBackingThreshold(500 ether);
    }

    // ============================================
    // Cancel Round Tests
    // ============================================

    function test_CancelRound() public {
        arena.startRound();

        arena.cancelRound();

        EmberArena.Round memory round = arena.getRoundInfo(1);
        assertTrue(round.cancelled);
        assertEq(arena.getCurrentPhase(), 4); // Cancelled
    }

    function test_CancelRound_RevertNotOwner() public {
        arena.startRound();

        vm.prank(user1);
        vm.expectRevert();
        arena.cancelRound();
    }

    // ============================================
    // Emergency Refund Tests
    // ============================================

    function test_EmergencyRefund_AfterCancel() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        uint256 user1Before = ember.balanceOf(user1);

        // Cancel the round
        arena.cancelRound();

        // User can refund
        vm.prank(user1);
        arena.emergencyRefund(1, 1);

        assertEq(ember.balanceOf(user1), user1Before + 100 ether);
    }

    function test_EmergencyRefund_AfterTimeout() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        uint256 user1Before = ember.balanceOf(user1);

        // Warp past voting + 7 day timeout
        vm.warp(block.timestamp + 25 hours + 7 days + 1);

        // User can refund after timeout
        vm.prank(user1);
        arena.emergencyRefund(1, 1);

        assertEq(ember.balanceOf(user1), user1Before + 100 ether);
    }

    function test_EmergencyRefund_RevertTooEarly() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        // Warp past voting but before timeout
        vm.warp(block.timestamp + 25 hours + 1 days);

        vm.prank(user1);
        vm.expectRevert(EmberArena.RefundNotAvailable.selector);
        arena.emergencyRefund(1, 1);
    }

    function test_IsRefundAvailable() public {
        arena.startRound();

        assertFalse(arena.isRefundAvailable(1));

        // Warp past voting + timeout
        vm.warp(block.timestamp + 49 hours + 7 days + 1);

        assertTrue(arena.isRefundAvailable(1));
    }

    // ============================================
    // Reentrancy Tests
    // ============================================

    function test_BackIdea_ReentrancyProtection() public {
        // Create malicious token that calls back
        MaliciousToken malicious = new MaliciousToken(address(arena));
        EmberArena maliciousArena = new EmberArena(address(malicious), MIN_THRESHOLD);

        maliciousArena.startRound();

        malicious.mint(user1, 500_000 ether);
        vm.prank(user1);
        malicious.approve(address(maliciousArena), type(uint256).max);

        vm.prank(user1);
        maliciousArena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        malicious.mint(address(malicious), 1000 ether);
        malicious.approve(address(maliciousArena), type(uint256).max);

        // Attack should fail due to reentrancy guard
        vm.expectRevert();
        malicious.attack(address(maliciousArena), 1, 50 ether);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_BackingAmounts(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1e16, 500 ether);
        amount2 = bound(amount2, 1e16, 500 ether);

        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, amount1);

        vm.prank(user2);
        arena.backIdea(1, amount2);

        EmberArena.Idea memory idea = arena.getIdea(1);
        assertEq(idea.totalBacking, amount1 + amount2);
    }

    function testFuzz_WinningsDistribution(uint256 backing1, uint256 backing2) public {
        backing1 = bound(backing1, 50 ether, 500 ether);
        backing2 = bound(backing2, 50 ether, 500 ether);

        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, backing1);

        vm.prank(user2);
        arena.backIdea(1, backing2);

        vm.warp(start + 49 hours);

        arena.selectWinner(1);

        uint256 totalPool = SUBMISSION_FEE + backing1 + backing2;
        uint256 distributable = (totalPool * 8000) / 10000;
        uint256 ideaTotalBacking = backing1 + backing2;

        uint256 expected1 = (backing1 * distributable) / ideaTotalBacking;
        uint256 expected2 = (backing2 * distributable) / ideaTotalBacking;

        uint256 user1Before = ember.balanceOf(user1);
        uint256 user2Before = ember.balanceOf(user2);

        vm.prank(user1);
        arena.claimWinnings(1);

        vm.prank(user2);
        arena.claimWinnings(1);

        // Allow 1 wei rounding error
        assertApproxEqAbs(ember.balanceOf(user1) - user1Before, expected1, 1);
        assertApproxEqAbs(ember.balanceOf(user2) - user2Before, expected2, 1);
    }

    // ============================================
    // Full Flow Integration Test
    // ============================================

    function test_FullFlow() public {
        uint256 start = block.timestamp;
        // Round 1
        arena.startRound();

        // Submit ideas
        vm.prank(user1);
        arena.submitIdea("Build AMM", "ipfs://amm");

        vm.prank(user2);
        arena.submitIdea("Build Lending", "ipfs://lending");

        // Move to voting
        vm.warp(start + 25 hours);

        // Back ideas
        vm.prank(user1);
        arena.backIdea(1, 60 ether);

        vm.prank(user2);
        arena.backIdea(1, 40 ether);

        vm.prank(user3);
        arena.backIdea(2, 50 ether);

        // End voting
        vm.warp(start + 49 hours);

        // Total pool = 2 * SUBMISSION_FEE + 60 + 40 + 50 = 2 * 100K + 150
        uint256 totalPool = 2 * SUBMISSION_FEE + 150 ether;

        // Select winner (idea 1 has 100 ether, meets threshold)
        arena.selectWinner(1);

        // Verify state
        EmberArena.Round memory round = arena.getRoundInfo(1);
        assertEq(round.resolved, true);
        assertEq(round.winningIdeaId, 1);
        assertEq(round.totalPool, totalPool);

        // Claim winnings
        // Distributable = totalPool * 0.8
        // Idea 1 backing = 100 ether
        // User1: 60/100 * distributable
        // User2: 40/100 * distributable
        uint256 distributable = (totalPool * 8000) / 10000;
        uint256 expected1 = (60 ether * distributable) / 100 ether;
        uint256 expected2 = (40 ether * distributable) / 100 ether;

        uint256 u1Before = ember.balanceOf(user1);
        vm.prank(user1);
        arena.claimWinnings(1);
        assertEq(ember.balanceOf(user1) - u1Before, expected1);

        uint256 u2Before = ember.balanceOf(user2);
        vm.prank(user2);
        arena.claimWinnings(1);
        assertEq(ember.balanceOf(user2) - u2Before, expected2);

        // User3 backed losing idea - can't claim
        vm.prank(user3);
        vm.expectRevert(EmberArena.NothingToClaim.selector);
        arena.claimWinnings(1);

        // Verify burn (20% of totalPool)
        uint256 burnAmount = (totalPool * 2000) / 10000;
        assertEq(ember.balanceOf(arena.BURN_ADDRESS()), burnAmount);
    }
}

/// @notice Malicious token for reentrancy testing
contract MaliciousToken is ERC20 {
    EmberArena public target;
    bool public attacking;

    constructor(address _target) ERC20("Malicious", "MAL") {
        target = EmberArena(_target);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function attack(address arena, uint256 ideaId, uint256 amount) external {
        attacking = true;
        EmberArena(arena).backIdea(ideaId, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (attacking) {
            attacking = false;
            // Try to reenter
            target.backIdea(1, amount);
        }
        return super.transferFrom(from, to, amount);
    }
}
