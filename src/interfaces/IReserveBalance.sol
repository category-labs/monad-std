// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/**
 * @title Reserve Balance Precompile Interface
 * @notice Interface for the Monad reserve balance precompile at `address(0x1001)`.
 * @dev The method is intentionally not marked `view`.
 *
 * The reserve balance precompile only accepts plain `CALL` and rejects
 * `STATICCALL`, `DELEGATECALL`, and `CALLCODE`.
 *
 * See MIP-4 for full specification.
 */
interface IReserveBalance {
    /**
     * @notice Returns whether the current execution state is in reserve balance violation.
     * @dev Allows contracts to detect and recover from temporary reserve violations
     * before transaction completion.
     * @return dipped True if any touched account is below its reserve threshold.
     */
    function dippedIntoReserve() external returns (bool dipped);
}
