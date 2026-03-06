// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/**
 * @title Monad Staking Precompile Interface
 * @notice Interface for the Monad staking precompile at `address(0x1000)`.
 * @dev Read methods are intentionally not marked `view`.
 *
 * The staking precompile only accepts plain `CALL` and rejects `STATICCALL`,
 * `DELEGATECALL`, and `CALLCODE`.
 *
 * Some getter paths can also settle staking state as part of execution
 * (notably `getDelegator`), so this interface mirrors runtime behavior and
 * keeps these methods non-`view`.
 *
 * Syscall methods are intentionally not exposed in this public developer
 * interface.
 */
interface IMonadStaking {
    /*//////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when validator rewards are applied.
    event ValidatorRewarded(uint64 indexed validatorId, address indexed from, uint256 amount, uint64 epoch);

    /// @notice Emitted when a validator is created.
    event ValidatorCreated(uint64 indexed validatorId, address indexed authAddress, uint256 commission);

    /// @notice Emitted when validator status flags are updated.
    event ValidatorStatusChanged(uint64 indexed validatorId, uint64 flags);

    /// @notice Emitted when stake is delegated.
    event Delegate(uint64 indexed validatorId, address indexed delegator, uint256 amount, uint64 activationEpoch);

    /// @notice Emitted when stake is undelegated.
    event Undelegate(
        uint64 indexed validatorId, address indexed delegator, uint8 withdrawId, uint256 amount, uint64 activationEpoch
    );

    /// @notice Emitted when a withdrawal request is redeemed.
    event Withdraw(
        uint64 indexed validatorId, address indexed delegator, uint8 withdrawId, uint256 amount, uint64 epoch
    );

    /// @notice Emitted when rewards are claimed.
    event ClaimRewards(uint64 indexed validatorId, address indexed delegator, uint256 amount, uint64 epoch);

    /// @notice Emitted when validator commission is changed.
    event CommissionChanged(uint64 indexed validatorId, uint256 oldCommission, uint256 newCommission);

    /// @notice Emitted when epoch changes.
    event EpochChanged(uint64 oldEpoch, uint64 newEpoch);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new validator.
     * @dev `msg.value` must match the signed stake encoded in `payload`.
     * @param payload Validator registration payload.
     * @param signedSecpMessage Compressed secp256k1 signature for `payload`.
     * @param signedBlsMessage Compressed BLS signature for `payload`.
     * @return validatorId The newly assigned validator ID.
     */
    function addValidator(bytes calldata payload, bytes calldata signedSecpMessage, bytes calldata signedBlsMessage)
        external
        payable
        returns (uint64 validatorId);

    /**
     * @notice Delegates stake to a validator.
     * @dev Uses `msg.value` as delegation amount.
     * @param validatorId Validator ID receiving delegation.
     * @return success True on success.
     */
    function delegate(uint64 validatorId) external payable returns (bool success);

    /**
     * @notice Requests undelegation from a validator.
     * @param validatorId Validator ID to undelegate from.
     * @param amount Amount to undelegate.
     * @param withdrawId Caller-selected withdrawal slot.
     * @return success True on success.
     */
    function undelegate(uint64 validatorId, uint256 amount, uint8 withdrawId) external returns (bool success);

    /**
     * @notice Compounds pending rewards back into stake.
     * @param validatorId Validator ID to compound for.
     * @return success True on success.
     */
    function compound(uint64 validatorId) external returns (bool success);

    /**
     * @notice Withdraws a matured undelegation request.
     * @param validatorId Validator ID associated with the withdrawal request.
     * @param withdrawId Withdrawal slot to redeem.
     * @return success True on success.
     */
    function withdraw(uint64 validatorId, uint8 withdrawId) external returns (bool success);

    /**
     * @notice Claims pending delegation rewards.
     * @param validatorId Validator ID to claim rewards from.
     * @return success True on success.
     */
    function claimRewards(uint64 validatorId) external returns (bool success);

    /**
     * @notice Updates validator commission.
     * @param validatorId Validator ID to update.
     * @param commission New commission value.
     * @return success True on success.
     */
    function changeCommission(uint64 validatorId, uint256 commission) external returns (bool success);

    /**
     * @notice Adds external reward to an active validator pool.
     * @dev Uses `msg.value` as reward amount.
     * @param validatorId Validator ID to reward.
     * @return success True on success.
     */
    function externalReward(uint64 validatorId) external payable returns (bool success);

    /**
     * @notice Returns current epoch state.
     * @return epoch Current epoch number.
     * @return inEpochDelayPeriod True when in epoch delay period.
     */
    function getEpoch() external returns (uint64 epoch, bool inEpochDelayPeriod);

    /**
     * @notice Returns current proposer validator ID.
     * @return valId Current proposer validator ID.
     */
    function getProposerValId() external returns (uint64 valId);

    /**
     * @notice Returns validator state across execution, consensus, and snapshot views.
     * @param validatorId Validator ID to query.
     * @return authAddress Validator auth/delegation address.
     * @return flags Validator status flags.
     * @return stake Execution-view stake.
     * @return accRewardPerToken Execution-view accumulated reward per token.
     * @return commission Execution-view commission.
     * @return unclaimedRewards Execution-view unclaimed validator rewards.
     * @return consensusStake Consensus-view stake.
     * @return consensusCommission Consensus-view commission.
     * @return snapshotStake Snapshot-view stake.
     * @return snapshotCommission Snapshot-view commission.
     * @return secpPubkey Compressed secp256k1 pubkey bytes.
     * @return blsPubkey Compressed BLS pubkey bytes.
     */
    function getValidator(uint64 validatorId)
        external
        returns (
            address authAddress,
            uint64 flags,
            uint256 stake,
            uint256 accRewardPerToken,
            uint256 commission,
            uint256 unclaimedRewards,
            uint256 consensusStake,
            uint256 consensusCommission,
            uint256 snapshotStake,
            uint256 snapshotCommission,
            bytes memory secpPubkey,
            bytes memory blsPubkey
        );

    /**
     * @notice Returns delegator position against a validator.
     * @dev This call can settle delegator state before returning.
     * @param validatorId Validator ID to query.
     * @param delegator Delegator address to query.
     * @return stake Active delegated stake.
     * @return accRewardPerToken Last synced accumulated reward per token.
     * @return unclaimedRewards Delegator rewards available to claim.
     * @return deltaStake Pending stake delta.
     * @return nextDeltaStake Next pending stake delta.
     * @return deltaEpoch Epoch for `deltaStake` activation.
     * @return nextDeltaEpoch Epoch for `nextDeltaStake` activation.
     */
    function getDelegator(uint64 validatorId, address delegator)
        external
        returns (
            uint256 stake,
            uint256 accRewardPerToken,
            uint256 unclaimedRewards,
            uint256 deltaStake,
            uint256 nextDeltaStake,
            uint64 deltaEpoch,
            uint64 nextDeltaEpoch
        );

    /**
     * @notice Returns a withdrawal request slot.
     * @param validatorId Validator ID associated with the request.
     * @param delegator Delegator that owns the request.
     * @param withdrawId Withdrawal slot index.
     * @return withdrawalAmount Principal amount requested for withdrawal.
     * @return accRewardPerToken Accumulator snapshot captured at undelegation.
     * @return withdrawEpoch Epoch when withdrawal becomes claimable.
     */
    function getWithdrawalRequest(uint64 validatorId, address delegator, uint8 withdrawId)
        external
        returns (uint256 withdrawalAmount, uint256 accRewardPerToken, uint64 withdrawEpoch);

    /**
     * @notice Returns a paginated page of consensus validator IDs.
     * @param startIndex Zero-based page start index.
     * @return isDone True when the page reaches the end.
     * @return nextIndex Index to use for the next page.
     * @return valIds Validator IDs in this page.
     */
    function getConsensusValidatorSet(uint32 startIndex)
        external
        returns (bool isDone, uint32 nextIndex, uint64[] memory valIds);

    /**
     * @notice Returns a paginated page of snapshot validator IDs.
     * @param startIndex Zero-based page start index.
     * @return isDone True when the page reaches the end.
     * @return nextIndex Index to use for the next page.
     * @return valIds Validator IDs in this page.
     */
    function getSnapshotValidatorSet(uint32 startIndex)
        external
        returns (bool isDone, uint32 nextIndex, uint64[] memory valIds);

    /**
     * @notice Returns a paginated page of execution validator IDs.
     * @param startIndex Zero-based page start index.
     * @return isDone True when the page reaches the end.
     * @return nextIndex Index to use for the next page.
     * @return valIds Validator IDs in this page.
     */
    function getExecutionValidatorSet(uint32 startIndex)
        external
        returns (bool isDone, uint32 nextIndex, uint64[] memory valIds);

    /**
     * @notice Returns a paginated page of validator IDs delegated by an address.
     * @param delegator Delegator address to query.
     * @param startValId Validator ID cursor for pagination.
     * @return isDone True when traversal reaches the list end.
     * @return nextValId Validator ID cursor for the next page.
     * @return valIds Validator IDs in this page.
     */
    function getDelegations(address delegator, uint64 startValId)
        external
        returns (bool isDone, uint64 nextValId, uint64[] memory valIds);

    /**
     * @notice Returns a paginated page of delegator addresses for a validator.
     * @param validatorId Validator ID to query.
     * @param startDelegator Delegator cursor for pagination.
     * @return isDone True when traversal reaches the list end.
     * @return nextDelegator Delegator cursor for the next page.
     * @return delegators Delegator addresses in this page.
     */
    function getDelegators(uint64 validatorId, address startDelegator)
        external
        returns (bool isDone, address nextDelegator, address[] memory delegators);
}
