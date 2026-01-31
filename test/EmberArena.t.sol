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

contract EmberArenaV2Test is Test {
    EmberArena public arena;
    MockEMBER public ember;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public ideaCreator;
    address public booster;

    uint256 public constant MIN_THRESHOLD = 100 ether;
    uint256 public constant SUBMISSION_FEE = 100_000 ether; // 100K EMBER

    // Events
    event RoundStarted(uint256 indexed roundId, uint256 submissionStart, uint256 votingStart, uint256 votingEnd);
    event RoundCancelled(uint256 indexed roundId);
    event IdeaSubmitted(uint256 indexed roundId, uint256 indexed ideaId, address indexed creator, string description, uint256 fee);
    event IdeaBacked(uint256 indexed roundId, uint256 indexed ideaId, address indexed backer, uint256 amount);
    event RoundBoosted(uint256 indexed roundId, address indexed booster, uint256 amount);
    event RoundResolved(uint256 indexed roundId, uint256[] winningIdeaIds, uint256 winnersCount, uint256 totalPool);
    event WinningsClaimed(uint256 indexed roundId, address indexed backer, uint256 amount);
    event TokensBurned(uint256 indexed roundId, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        ideaCreator = makeAddr("ideaCreator");
        booster = makeAddr("booster");

        ember = new MockEMBER();
        arena = new EmberArena(address(ember), MIN_THRESHOLD);

        // Fund users with enough for submission fees + backing
        ember.mint(user1, 1_000_000 ether);
        ember.mint(user2, 1_000_000 ether);
        ember.mint(user3, 1_000_000 ether);
        ember.mint(user4, 1_000_000 ether);
        ember.mint(ideaCreator, 1_000_000 ether);
        ember.mint(booster, 1_000_000 ether);

        // Approve arena for all users
        vm.prank(user1);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(user2);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(user3);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(user4);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(ideaCreator);
        ember.approve(address(arena), type(uint256).max);
        vm.prank(booster);
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
        assertEq(arena.BURN_BPS(), 1000); // 10%
        assertEq(arena.WINNER_BPS(), 9000); // 90%
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

        (
            uint256 roundId,
            uint256 submissionStart,
            uint256 votingStart,
            uint256 votingEnd,
            uint256 totalPool,
            bool resolved,
            bool cancelled,
            uint256 ideaCount,
            uint256 boostPool
        ) = arena.getRoundInfo(1);

        assertEq(roundId, 1);
        assertEq(submissionStart, block.timestamp);
        assertEq(votingStart, block.timestamp + 24 hours);
        assertEq(votingEnd, block.timestamp + 48 hours);
        assertEq(totalPool, 0);
        assertEq(resolved, false);
        assertEq(cancelled, false);
        assertEq(ideaCount, 0);
        assertEq(boostPool, 0);
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
    }

    // ============================================
    // Boost Round Tests (NEW in v2)
    // ============================================

    function test_BoostRound() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Build a DEX", "");

        // Anyone can boost
        vm.prank(booster);
        vm.expectEmit(true, true, false, true);
        emit RoundBoosted(1, booster, 50_000 ether);
        arena.boostRound(1, 50_000 ether);

        (,,,, uint256 totalPool,,,, uint256 boostPool) = arena.getRoundInfo(1);
        assertEq(boostPool, 50_000 ether);
        assertEq(totalPool, SUBMISSION_FEE + 50_000 ether);
    }

    function test_BoostRound_MultipleBoosts() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.prank(user1);
        arena.boostRound(1, 10_000 ether);

        vm.prank(user2);
        arena.boostRound(1, 20_000 ether);

        (,,,, uint256 totalPool,,,, uint256 boostPool) = arena.getRoundInfo(1);
        assertEq(boostPool, 30_000 ether);
        assertEq(totalPool, SUBMISSION_FEE + 30_000 ether);
    }

    function test_BoostRound_RevertZeroAmount() public {
        arena.startRound();

        vm.prank(booster);
        vm.expectRevert(EmberArena.ZeroAmount.selector);
        arena.boostRound(1, 0);
    }

    function test_BoostRound_RevertInvalidRoundId() public {
        vm.prank(booster);
        vm.expectRevert(EmberArena.InvalidRoundId.selector);
        arena.boostRound(999, 1000 ether);
    }

    function test_BoostRound_RevertAfterResolution() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        vm.prank(booster);
        vm.expectRevert(EmberArena.RoundAlreadyResolved.selector);
        arena.boostRound(1, 1000 ether);
    }

    // ============================================
    // Auto-Resolution Tests (NEW in v2)
    // ============================================

    function test_ResolveRound_SingleWinner() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        vm.warp(start + 25 hours);

        // Idea 1: 150 ether (wins)
        vm.prank(user1);
        arena.backIdea(1, 150 ether);

        // Idea 2: 50 ether (loses - below threshold anyway)
        vm.prank(user2);
        arena.backIdea(2, 50 ether);

        vm.warp(start + 49 hours);

        // Anyone can resolve
        vm.prank(user3);
        arena.resolveRound(1);

        (,,,,,bool resolved,,,) = arena.getRoundInfo(1);
        assertTrue(resolved);

        uint256[] memory winners = arena.getWinningIdeaIds(1);
        assertEq(winners.length, 1);
        assertEq(winners[0], 1); // Idea 1 wins

        EmberArena.Idea memory idea1 = arena.getIdea(1);
        assertTrue(idea1.isWinner);

        EmberArena.Idea memory idea2 = arena.getIdea(2);
        assertFalse(idea2.isWinner);
    }

    function test_ResolveRound_TieBreaker() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        vm.warp(start + 25 hours);

        // EQUAL backing - TIE!
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.prank(user2);
        arena.backIdea(2, 100 ether);

        vm.warp(start + 49 hours);

        arena.resolveRound(1);

        uint256[] memory winners = arena.getWinningIdeaIds(1);
        assertEq(winners.length, 2); // Both win!
        
        // Both should be marked as winners
        assertTrue(arena.getIdea(1).isWinner);
        assertTrue(arena.getIdea(2).isWinner);
    }

    function test_ResolveRound_ThreeWayTie() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");
        vm.prank(user3);
        arena.submitIdea("Idea 3", "");

        vm.warp(start + 25 hours);

        // All equal
        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(2, 100 ether);
        vm.prank(user3);
        arena.backIdea(3, 100 ether);

        vm.warp(start + 49 hours);

        arena.resolveRound(1);

        uint256[] memory winners = arena.getWinningIdeaIds(1);
        assertEq(winners.length, 3); // All win!
    }

    function test_ResolveRound_AnyoneCanCall() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);

        // Random person can resolve
        address randomPerson = makeAddr("random");
        vm.prank(randomPerson);
        arena.resolveRound(1);

        (,,,,,bool resolved,,,) = arena.getRoundInfo(1);
        assertTrue(resolved);
    }

    function test_ResolveRound_RevertVotingNotEnded() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        // Still in submission phase
        vm.expectRevert(EmberArena.VotingNotEnded.selector);
        arena.resolveRound(1);
    }

    function test_ResolveRound_RevertNoEligibleWinners() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        
        // Back with less than threshold
        vm.prank(user1);
        arena.backIdea(1, 50 ether);

        vm.warp(start + 49 hours);

        vm.expectRevert(EmberArena.NoEligibleWinners.selector);
        arena.resolveRound(1);
    }

    function test_ResolveRound_Burns10Percent() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);

        uint256 totalPool = SUBMISSION_FEE + 100 ether;
        uint256 expectedBurn = (totalPool * 1000) / 10000; // 10%

        uint256 burnBalanceBefore = ember.balanceOf(arena.BURN_ADDRESS());

        arena.resolveRound(1);

        uint256 burnBalanceAfter = ember.balanceOf(arena.BURN_ADDRESS());
        assertEq(burnBalanceAfter - burnBalanceBefore, expectedBurn);
    }

    // ============================================
    // Claim Winnings Tests (Updated for v2)
    // ============================================

    function test_ClaimWinnings_SingleWinner() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Winning idea", "");

        vm.warp(start + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        // Total = SUBMISSION_FEE + 200 ether
        // Distributable = 90%
        // Each user backed 50% of winner
        uint256 totalPool = SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 9000) / 10000;
        uint256 expectedShare = (100 ether * distributable) / 200 ether;

        uint256 user1Before = ember.balanceOf(user1);

        vm.prank(user1);
        arena.claimWinnings(1);

        assertEq(ember.balanceOf(user1) - user1Before, expectedShare);
    }

    function test_ClaimWinnings_WithIdeaId() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        uint256 user1Before = ember.balanceOf(user1);

        // Use the explicit ideaId overload
        vm.prank(user1);
        arena.claimWinnings(1, 1);

        assertTrue(ember.balanceOf(user1) > user1Before);
    }

    function test_ClaimWinnings_TieSplitEqually() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        vm.warp(start + 25 hours);

        // TIE: both have 100 ether
        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(2, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        // Total = 2 * SUBMISSION_FEE + 200 ether
        // Distributable = 90%
        // Total winner backing = 200 ether (100 + 100)
        // Each user gets: (100 / 200) * distributable = 50% each
        uint256 totalPool = 2 * SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 9000) / 10000;
        uint256 expectedShare = (100 ether * distributable) / 200 ether;

        uint256 user1Before = ember.balanceOf(user1);
        uint256 user2Before = ember.balanceOf(user2);

        vm.prank(user1);
        arena.claimWinnings(1);

        vm.prank(user2);
        arena.claimWinnings(1);

        assertEq(ember.balanceOf(user1) - user1Before, expectedShare);
        assertEq(ember.balanceOf(user2) - user2Before, expectedShare);
    }

    function test_ClaimWinnings_TieWithMultipleBackers() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("Idea 1", "");
        vm.prank(ideaCreator);
        arena.submitIdea("Idea 2", "");

        vm.warp(start + 25 hours);

        // Idea 1: user1 backs 60, user2 backs 40 = 100 total
        vm.prank(user1);
        arena.backIdea(1, 60 ether);
        vm.prank(user2);
        arena.backIdea(1, 40 ether);

        // Idea 2: user3 backs 100 = 100 total (TIE!)
        vm.prank(user3);
        arena.backIdea(2, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        // Total pool = 2 * SUBMISSION_FEE + 200 ether
        // Distributable = 90%
        // Total winner backing = 200 ether
        // User1: 60/200 of distributable
        // User2: 40/200 of distributable
        // User3: 100/200 of distributable
        uint256 totalPool = 2 * SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 9000) / 10000;

        uint256 expected1 = (60 ether * distributable) / 200 ether;
        uint256 expected2 = (40 ether * distributable) / 200 ether;
        uint256 expected3 = (100 ether * distributable) / 200 ether;

        uint256 u1Before = ember.balanceOf(user1);
        uint256 u2Before = ember.balanceOf(user2);
        uint256 u3Before = ember.balanceOf(user3);

        vm.prank(user1);
        arena.claimWinnings(1, 1);
        vm.prank(user2);
        arena.claimWinnings(1, 1);
        vm.prank(user3);
        arena.claimWinnings(1, 2);

        assertEq(ember.balanceOf(user1) - u1Before, expected1);
        assertEq(ember.balanceOf(user2) - u2Before, expected2);
        assertEq(ember.balanceOf(user3) - u3Before, expected3);
    }

    function test_ClaimWinnings_RevertNotAWinner() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        vm.warp(start + 25 hours);

        // Idea 1 wins
        vm.prank(user1);
        arena.backIdea(1, 150 ether);

        // Idea 2 loses
        vm.prank(user2);
        arena.backIdea(2, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        // User2 backed losing idea
        vm.prank(user2);
        vm.expectRevert(EmberArena.NotAWinner.selector);
        arena.claimWinnings(1, 2);
    }

    function test_ClaimWinnings_RevertNothingToClaim() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        // User2 didn't back anything
        vm.prank(user2);
        vm.expectRevert(EmberArena.NothingToClaim.selector);
        arena.claimWinnings(1);
    }

    function test_ClaimWinnings_RevertAlreadyClaimed() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        vm.prank(user1);
        arena.claimWinnings(1);

        vm.prank(user1);
        vm.expectRevert(EmberArena.AlreadyClaimed.selector);
        arena.claimWinnings(1);
    }

    // ============================================
    // Boost + Winnings Integration
    // ============================================

    function test_BoostIncreasesWinnings() public {
        uint256 start = block.timestamp;
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        // Boost before voting
        vm.prank(booster);
        arena.boostRound(1, 100_000 ether);

        vm.warp(start + 25 hours);
        vm.prank(user1);
        arena.backIdea(1, 100 ether);

        vm.warp(start + 49 hours);
        arena.resolveRound(1);

        // Total = SUBMISSION_FEE + 100_000 boost + 100 backing
        uint256 totalPool = SUBMISSION_FEE + 100_000 ether + 100 ether;
        uint256 distributable = (totalPool * 9000) / 10000;
        uint256 expected = distributable; // User1 is sole backer

        uint256 user1Before = ember.balanceOf(user1);
        vm.prank(user1);
        arena.claimWinnings(1);

        assertEq(ember.balanceOf(user1) - user1Before, expected);
    }

    // ============================================
    // View Functions Tests
    // ============================================

    function test_GetLeadingIdeas() public {
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(2, 50 ether);

        (uint256[] memory leaders, uint256 highest) = arena.getLeadingIdeas(1);
        assertEq(leaders.length, 1);
        assertEq(leaders[0], 1);
        assertEq(highest, 100 ether);
    }

    function test_GetLeadingIdeas_Tie() public {
        arena.startRound();

        vm.prank(user1);
        arena.submitIdea("Idea 1", "");
        vm.prank(user2);
        arena.submitIdea("Idea 2", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(2, 100 ether);

        (uint256[] memory leaders, uint256 highest) = arena.getLeadingIdeas(1);
        assertEq(leaders.length, 2);
        assertEq(highest, 100 ether);
    }

    function test_GetCurrentPhase() public {
        assertEq(arena.getCurrentPhase(), 0); // No round

        uint256 start = block.timestamp;
        arena.startRound();
        assertEq(arena.getCurrentPhase(), 1); // Submission

        vm.warp(start + 25 hours);
        assertEq(arena.getCurrentPhase(), 2); // Voting

        vm.warp(start + 49 hours);
        assertEq(arena.getCurrentPhase(), 3); // Ended
    }

    function test_CalculatePotentialWinnings() public {
        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(1, 100 ether);

        // Total = SUBMISSION_FEE + 200 ether
        // Distributable = 90%
        // User1's share if idea wins alone: (100/200) * distributable
        uint256 totalPool = SUBMISSION_FEE + 200 ether;
        uint256 distributable = (totalPool * 9000) / 10000;
        uint256 expected = (100 ether * distributable) / 200 ether;

        uint256 potential = arena.calculatePotentialWinnings(1, 1, user1);
        assertEq(potential, expected);
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

        arena.cancelRound();

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

        vm.prank(user1);
        arena.emergencyRefund(1, 1);

        assertEq(ember.balanceOf(user1), user1Before + 100 ether);
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

    // ============================================
    // Full Flow Integration Test
    // ============================================

    function test_FullFlow_WithBoostAndTie() public {
        uint256 start = block.timestamp;

        // Round 1
        arena.startRound();

        // Submit ideas
        vm.prank(user1);
        arena.submitIdea("Build AMM", "ipfs://amm");
        vm.prank(user2);
        arena.submitIdea("Build Lending", "ipfs://lending");

        // Boost
        vm.prank(booster);
        arena.boostRound(1, 50_000 ether);

        // Move to voting
        vm.warp(start + 25 hours);

        // Create a tie!
        vm.prank(user1);
        arena.backIdea(1, 100 ether);
        vm.prank(user2);
        arena.backIdea(2, 100 ether);

        // End voting
        vm.warp(start + 49 hours);

        // Total = 2 * SUBMISSION_FEE + 50K boost + 200 backing
        uint256 totalPool = 2 * SUBMISSION_FEE + 50_000 ether + 200 ether;

        // Anyone resolves
        vm.prank(user3);
        arena.resolveRound(1);

        // Verify tie
        uint256[] memory winners = arena.getWinningIdeaIds(1);
        assertEq(winners.length, 2);

        // Verify burn (10%)
        uint256 burnAmount = (totalPool * 1000) / 10000;
        assertEq(ember.balanceOf(arena.BURN_ADDRESS()), burnAmount);

        // Claim winnings - each gets 50% of 90%
        uint256 distributable = (totalPool * 9000) / 10000;
        uint256 expectedEach = (100 ether * distributable) / 200 ether;

        uint256 u1Before = ember.balanceOf(user1);
        vm.prank(user1);
        arena.claimWinnings(1);
        assertEq(ember.balanceOf(user1) - u1Before, expectedEach);

        uint256 u2Before = ember.balanceOf(user2);
        vm.prank(user2);
        arena.claimWinnings(1);
        assertEq(ember.balanceOf(user2) - u2Before, expectedEach);
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

    function testFuzz_BoostAmount(uint256 boostAmount) public {
        boostAmount = bound(boostAmount, 1 ether, 1_000_000 ether);
        
        ember.mint(booster, boostAmount);

        arena.startRound();

        vm.prank(ideaCreator);
        arena.submitIdea("idea", "");

        vm.prank(booster);
        arena.boostRound(1, boostAmount);

        (,,,, uint256 totalPool,,,, uint256 boostPool) = arena.getRoundInfo(1);
        assertEq(boostPool, boostAmount);
        assertEq(totalPool, SUBMISSION_FEE + boostAmount);
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

        arena.resolveRound(1);

        uint256 totalPool = SUBMISSION_FEE + backing1 + backing2;
        uint256 distributable = (totalPool * 9000) / 10000;
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
    // Reentrancy Tests
    // ============================================

    function test_BackIdea_ReentrancyProtection() public {
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

        vm.expectRevert();
        malicious.attack(address(maliciousArena), 1, 50 ether);
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
            target.backIdea(1, amount);
        }
        return super.transferFrom(from, to, amount);
    }
}
