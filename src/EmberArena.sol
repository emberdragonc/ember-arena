// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Ember Arena
 * @author Ember 🐉 (@emberclawd)
 * @notice Idea Backing / Prediction Market - Back ideas with $EMBER, winners split the pool
 * @dev Uses 2-day cycles: Day 1 submissions, Day 2 backing. Owner selects winner.
 * 
 * Security features:
 * - ReentrancyGuard on all state-changing functions
 * - SafeERC20 for token transfers
 * - Pausable for emergencies
 * - Ownable2Step for safe ownership transfer
 * - Pull payment pattern for winnings
 * - CEI pattern throughout
 */
contract EmberArena is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============================================
    // Constants
    // ============================================

    /// @notice Duration of submission phase
    uint256 public constant SUBMISSION_DURATION = 24 hours;

    /// @notice Duration of voting/backing phase
    uint256 public constant VOTING_DURATION = 24 hours;

    /// @notice Burn percentage in basis points (20% = 2000)
    uint256 public constant BURN_BPS = 2000;

    /// @notice Maximum ideas per round to prevent DoS
    uint256 public constant MAX_IDEAS_PER_ROUND = 100;

    /// @notice Minimum backing amount to prevent dust attacks
    uint256 public constant MIN_BACKING_AMOUNT = 1e16; // 0.01 tokens

    /// @notice Dead address for burning
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // ============================================
    // State Variables
    // ============================================

    /// @notice The $EMBER token used for backing
    IERC20 public immutable emberToken;

    /// @notice Minimum total backing required for an idea to be selectable as winner
    uint256 public minBackingThreshold;

    /// @notice Current round ID (starts at 1)
    uint256 public currentRoundId;

    /// @notice Total ideas ever created (global counter)
    uint256 public totalIdeas;

    // ============================================
    // Structs
    // ============================================

    struct Round {
        uint256 roundId;
        uint256 submissionStart;
        uint256 votingStart;
        uint256 votingEnd;
        uint256 totalPool;
        uint256 winningIdeaId;
        bool resolved;
        uint256 ideaCount;
    }

    struct Idea {
        uint256 ideaId;
        uint256 roundId;
        address creator;
        string description;
        string metadata; // IPFS hash or URL
        uint256 totalBacking;
        bool isWinner;
    }

    struct Backing {
        address backer;
        uint256 ideaId;
        uint256 amount;
        bool claimed;
    }

    // ============================================
    // Storage
    // ============================================

    /// @notice Round ID => Round data
    mapping(uint256 => Round) public rounds;

    /// @notice Idea ID => Idea data
    mapping(uint256 => Idea) public ideas;

    /// @notice Round ID => list of idea IDs
    mapping(uint256 => uint256[]) public roundIdeas;

    /// @notice User => Round ID => list of backing indices
    mapping(address => mapping(uint256 => uint256[])) private userBackingIndices;

    /// @notice Round ID => Idea ID => list of backings
    mapping(uint256 => mapping(uint256 => Backing[])) public ideaBackings;

    /// @notice Round ID => Idea ID => Backer => backing index (for lookup)
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public backerIndex;

    /// @notice Round ID => Idea ID => Backer => has backed
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasBacked;

    // ============================================
    // Events
    // ============================================

    event RoundStarted(uint256 indexed roundId, uint256 submissionStart, uint256 votingStart, uint256 votingEnd);
    event IdeaSubmitted(uint256 indexed roundId, uint256 indexed ideaId, address indexed creator, string description);
    event IdeaBacked(uint256 indexed roundId, uint256 indexed ideaId, address indexed backer, uint256 amount);
    event WinnerSelected(uint256 indexed roundId, uint256 indexed winningIdeaId, address indexed creator, uint256 totalPool);
    event WinningsClaimed(uint256 indexed roundId, address indexed backer, uint256 amount);
    event TokensBurned(uint256 indexed roundId, uint256 amount);
    event MinBackingThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    // ============================================
    // Errors
    // ============================================

    error RoundNotActive();
    error RoundAlreadyActive();
    error NotInSubmissionPhase();
    error NotInVotingPhase();
    error RoundNotResolved();
    error RoundAlreadyResolved();
    error IdeaDoesNotExist();
    error IdeaNotInCurrentRound();
    error IdeaBelowThreshold();
    error AmountBelowMinimum();
    error NothingToClaim();
    error AlreadyClaimed();
    error TransferFailed();
    error MaxIdeasReached();
    error EmptyDescription();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidRoundId();

    // ============================================
    // Constructor
    // ============================================

    /**
     * @notice Deploy EmberArena
     * @param _emberToken Address of the $EMBER ERC20 token
     * @param _minBackingThreshold Minimum backing required for an idea to win
     */
    constructor(
        address _emberToken,
        uint256 _minBackingThreshold
    ) Ownable(msg.sender) {
        if (_emberToken == address(0)) revert ZeroAddress();
        emberToken = IERC20(_emberToken);
        minBackingThreshold = _minBackingThreshold;
    }

    // ============================================
    // Round Management (Owner)
    // ============================================

    /**
     * @notice Start a new round
     * @dev Can only be called when no round is active
     */
    function startRound() external onlyOwner whenNotPaused nonReentrant {
        // Check no active round
        if (currentRoundId > 0) {
            Round storage lastRound = rounds[currentRoundId];
            if (!lastRound.resolved && block.timestamp < lastRound.votingEnd) {
                revert RoundAlreadyActive();
            }
        }

        currentRoundId++;
        uint256 roundId = currentRoundId;

        uint256 submissionStart = block.timestamp;
        uint256 votingStart = submissionStart + SUBMISSION_DURATION;
        uint256 votingEnd = votingStart + VOTING_DURATION;

        rounds[roundId] = Round({
            roundId: roundId,
            submissionStart: submissionStart,
            votingStart: votingStart,
            votingEnd: votingEnd,
            totalPool: 0,
            winningIdeaId: 0,
            resolved: false,
            ideaCount: 0
        });

        emit RoundStarted(roundId, submissionStart, votingStart, votingEnd);
    }

    /**
     * @notice Select the winning idea for a round
     * @param _ideaId ID of the winning idea
     */
    function selectWinner(uint256 _ideaId) external onlyOwner whenNotPaused nonReentrant {
        if (currentRoundId == 0) revert RoundNotActive();

        Round storage round = rounds[currentRoundId];

        // Must be after voting ends
        if (block.timestamp < round.votingEnd) revert NotInVotingPhase();
        if (round.resolved) revert RoundAlreadyResolved();

        Idea storage idea = ideas[_ideaId];
        if (idea.ideaId == 0) revert IdeaDoesNotExist();
        if (idea.roundId != currentRoundId) revert IdeaNotInCurrentRound();
        if (idea.totalBacking < minBackingThreshold) revert IdeaBelowThreshold();

        // Effects
        round.winningIdeaId = _ideaId;
        round.resolved = true;
        idea.isWinner = true;

        // Calculate burn amount
        uint256 totalPool = round.totalPool;
        uint256 burnAmount = (totalPool * BURN_BPS) / 10000;

        // Interactions - burn tokens
        if (burnAmount > 0) {
            emberToken.safeTransfer(BURN_ADDRESS, burnAmount);
            emit TokensBurned(currentRoundId, burnAmount);
        }

        emit WinnerSelected(currentRoundId, _ideaId, idea.creator, totalPool);
    }

    /**
     * @notice Update minimum backing threshold
     * @param _newThreshold New threshold value
     */
    function setMinBackingThreshold(uint256 _newThreshold) external onlyOwner {
        uint256 oldThreshold = minBackingThreshold;
        minBackingThreshold = _newThreshold;
        emit MinBackingThresholdUpdated(oldThreshold, _newThreshold);
    }

    // ============================================
    // User Actions
    // ============================================

    /**
     * @notice Submit an idea for the current round
     * @param _description Brief description of the idea
     * @param _metadata IPFS hash or URL for additional details
     */
    function submitIdea(
        string calldata _description,
        string calldata _metadata
    ) external whenNotPaused nonReentrant returns (uint256 ideaId) {
        if (bytes(_description).length == 0) revert EmptyDescription();
        if (currentRoundId == 0) revert RoundNotActive();

        Round storage round = rounds[currentRoundId];

        // Must be in submission phase
        if (block.timestamp < round.submissionStart) revert NotInSubmissionPhase();
        if (block.timestamp >= round.votingStart) revert NotInSubmissionPhase();
        if (round.ideaCount >= MAX_IDEAS_PER_ROUND) revert MaxIdeasReached();

        totalIdeas++;
        ideaId = totalIdeas;

        ideas[ideaId] = Idea({
            ideaId: ideaId,
            roundId: currentRoundId,
            creator: msg.sender,
            description: _description,
            metadata: _metadata,
            totalBacking: 0,
            isWinner: false
        });

        roundIdeas[currentRoundId].push(ideaId);
        round.ideaCount++;

        emit IdeaSubmitted(currentRoundId, ideaId, msg.sender, _description);
    }

    /**
     * @notice Back an idea with $EMBER tokens
     * @param _ideaId ID of the idea to back
     * @param _amount Amount of $EMBER to stake
     */
    function backIdea(uint256 _ideaId, uint256 _amount) external whenNotPaused nonReentrant {
        if (_amount < MIN_BACKING_AMOUNT) revert AmountBelowMinimum();
        if (currentRoundId == 0) revert RoundNotActive();

        Round storage round = rounds[currentRoundId];

        // Must be in voting phase
        if (block.timestamp < round.votingStart) revert NotInVotingPhase();
        if (block.timestamp >= round.votingEnd) revert NotInVotingPhase();

        Idea storage idea = ideas[_ideaId];
        if (idea.ideaId == 0) revert IdeaDoesNotExist();
        if (idea.roundId != currentRoundId) revert IdeaNotInCurrentRound();

        // Effects
        idea.totalBacking += _amount;
        round.totalPool += _amount;

        uint256 backingIdx = ideaBackings[currentRoundId][_ideaId].length;

        // Store or update backing
        if (hasBacked[currentRoundId][_ideaId][msg.sender]) {
            // Add to existing backing
            uint256 existingIdx = backerIndex[currentRoundId][_ideaId][msg.sender];
            ideaBackings[currentRoundId][_ideaId][existingIdx].amount += _amount;
        } else {
            // New backing
            ideaBackings[currentRoundId][_ideaId].push(Backing({
                backer: msg.sender,
                ideaId: _ideaId,
                amount: _amount,
                claimed: false
            }));

            hasBacked[currentRoundId][_ideaId][msg.sender] = true;
            backerIndex[currentRoundId][_ideaId][msg.sender] = backingIdx;
            userBackingIndices[msg.sender][currentRoundId].push(_ideaId);
        }

        // Interactions - transfer tokens in
        emberToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit IdeaBacked(currentRoundId, _ideaId, msg.sender, _amount);
    }

    /**
     * @notice Claim winnings for a resolved round
     * @param _roundId ID of the resolved round
     */
    function claimWinnings(uint256 _roundId) external whenNotPaused nonReentrant {
        if (_roundId == 0 || _roundId > currentRoundId) revert InvalidRoundId();

        Round storage round = rounds[_roundId];
        if (!round.resolved) revert RoundNotResolved();

        uint256 winningIdeaId = round.winningIdeaId;
        if (!hasBacked[_roundId][winningIdeaId][msg.sender]) revert NothingToClaim();

        uint256 backingIdx = backerIndex[_roundId][winningIdeaId][msg.sender];
        Backing storage backing = ideaBackings[_roundId][winningIdeaId][backingIdx];

        if (backing.claimed) revert AlreadyClaimed();

        // Calculate share: (userBacking / winningIdeaBacking) * (totalPool * 80%)
        Idea storage winningIdea = ideas[winningIdeaId];
        uint256 distributablePool = (round.totalPool * (10000 - BURN_BPS)) / 10000;
        uint256 userShare = (backing.amount * distributablePool) / winningIdea.totalBacking;

        if (userShare == 0) revert NothingToClaim();

        // Effects
        backing.claimed = true;

        // Interactions
        emberToken.safeTransfer(msg.sender, userShare);

        emit WinningsClaimed(_roundId, msg.sender, userShare);
    }

    // ============================================
    // Emergency Functions
    // ============================================

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of stuck tokens
     * @param _token Token address to rescue
     * @param _to Recipient address
     * @param _amount Amount to rescue
     */
    function emergencyWithdraw(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        IERC20(_token).safeTransfer(_to, _amount);
    }

    // ============================================
    // View Functions
    // ============================================

    /**
     * @notice Get current round info
     * @return round The current round data
     */
    function getCurrentRound() external view returns (Round memory) {
        return rounds[currentRoundId];
    }

    /**
     * @notice Get round info by ID
     * @param _roundId Round ID to query
     * @return round The round data
     */
    function getRoundInfo(uint256 _roundId) external view returns (Round memory) {
        return rounds[_roundId];
    }

    /**
     * @notice Get idea by ID
     * @param _ideaId Idea ID to query
     * @return idea The idea data
     */
    function getIdea(uint256 _ideaId) external view returns (Idea memory) {
        return ideas[_ideaId];
    }

    /**
     * @notice Get all idea IDs for a round
     * @param _roundId Round ID to query
     * @return ideaIds Array of idea IDs
     */
    function getRoundIdeaIds(uint256 _roundId) external view returns (uint256[] memory) {
        return roundIdeas[_roundId];
    }

    /**
     * @notice Get user's backings for a round
     * @param _user User address
     * @param _roundId Round ID
     * @return backedIdeaIds Array of idea IDs the user backed
     */
    function getUserBackings(
        address _user,
        uint256 _roundId
    ) external view returns (uint256[] memory backedIdeaIds) {
        return userBackingIndices[_user][_roundId];
    }

    /**
     * @notice Get user's backing details for a specific idea
     * @param _user User address
     * @param _roundId Round ID
     * @param _ideaId Idea ID
     * @return backing The backing data
     */
    function getUserBackingForIdea(
        address _user,
        uint256 _roundId,
        uint256 _ideaId
    ) external view returns (Backing memory) {
        if (!hasBacked[_roundId][_ideaId][_user]) {
            return Backing(address(0), 0, 0, false);
        }
        uint256 idx = backerIndex[_roundId][_ideaId][_user];
        return ideaBackings[_roundId][_ideaId][idx];
    }

    /**
     * @notice Get all backings for an idea
     * @param _roundId Round ID
     * @param _ideaId Idea ID
     * @return backings Array of all backings
     */
    function getIdeaBackings(
        uint256 _roundId,
        uint256 _ideaId
    ) external view returns (Backing[] memory) {
        return ideaBackings[_roundId][_ideaId];
    }

    /**
     * @notice Check current phase of active round
     * @return phase 0=No Round, 1=Submission, 2=Voting, 3=Ended
     */
    function getCurrentPhase() external view returns (uint256 phase) {
        if (currentRoundId == 0) return 0;

        Round storage round = rounds[currentRoundId];

        if (block.timestamp < round.votingStart) return 1; // Submission
        if (block.timestamp < round.votingEnd) return 2; // Voting
        return 3; // Ended
    }

    /**
     * @notice Calculate potential winnings for a backer
     * @param _roundId Round ID
     * @param _ideaId Idea ID
     * @param _backer Backer address
     * @return potentialWinnings Amount they would win if this idea wins
     */
    function calculatePotentialWinnings(
        uint256 _roundId,
        uint256 _ideaId,
        address _backer
    ) external view returns (uint256 potentialWinnings) {
        if (!hasBacked[_roundId][_ideaId][_backer]) return 0;

        Round storage round = rounds[_roundId];
        Idea storage idea = ideas[_ideaId];

        if (idea.totalBacking == 0) return 0;

        uint256 idx = backerIndex[_roundId][_ideaId][_backer];
        uint256 userAmount = ideaBackings[_roundId][_ideaId][idx].amount;

        uint256 distributablePool = (round.totalPool * (10000 - BURN_BPS)) / 10000;
        return (userAmount * distributablePool) / idea.totalBacking;
    }
}
