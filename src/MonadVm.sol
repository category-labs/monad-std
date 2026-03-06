// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/**
 * @title MonadVm
 * @notice Interface for Monad-specific Foundry cheatcodes.
 * @dev Implemented by Monad Foundry at:
 * `0xc0FFeeCD43A10e1C2b0De63c6CDCFe5B7d0e0CEA`.
 */
interface MonadVm {
    /**
     * @notice Sets current epoch and delay-period flag for staking state.
     * @param epoch Epoch value to set.
     * @param inDelayPeriod Whether the staking state is in delay period.
     */
    function setEpoch(uint64 epoch, bool inDelayPeriod) external;

    /**
     * @notice Sets current proposer validator ID.
     * @param valId Proposer validator ID.
     */
    function setProposer(uint64 valId) external;

    /**
     * @notice Sets validator accumulated reward-per-token directly.
     * @param valId Validator ID.
     * @param value Accumulated reward-per-token value to set.
     */
    function setAccumulator(uint64 valId, uint256 value) external;

    /**
     * @notice Runs block-reward flow via staking syscall handler.
     * @param author Block author address.
     * @param reward Reward amount to distribute.
     */
    function blockReward(address author, uint256 reward) external;

    /// @notice Runs snapshot syscall (consensus/snapshot view refresh).
    function epochSnapshot() external;

    /**
     * @notice Runs epoch-change syscall to advance staking epoch.
     * @param newEpoch Target epoch value.
     */
    function epochChange(uint64 newEpoch) external;

    /**
     * @notice Convenience helper: `epochSnapshot()` then `epochChange(newEpoch)`.
     * @param newEpoch Target epoch value for the boundary transition.
     */
    function epochBoundary(uint64 newEpoch) external;
}
