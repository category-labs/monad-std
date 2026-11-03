// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/// @notice ABI of the standalone MIP-18 helper, called directly by an application.
interface ICallStack {
    /// @notice The helper requires exactly one ABI-encoded argument and no value.
    error InvalidCalldata();

    /// @notice A top-level helper call has no invoking application frame.
    error NoInvoker();

    /// @notice Reads the invoking application's depth and the caller of its nth ancestor frame.
    /// @param n Zero selects the application's own caller; out-of-range indices return zero.
    /// @return depth The application's zero-based call depth.
    /// @return ancestor The selected frame's CALLER value, preserving delegatecall ancestry.
    function readForInvoker(uint256 n) external view returns (uint256 depth, address ancestor);
}
