// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/// @notice ABI of the standalone MIP-18 helper, called directly by an application.
interface ICallStack {
    /// @notice The selector, calldata size, or attached value is invalid.
    error InvalidCalldata();

    /// @notice A top-level helper call has no invoking application frame.
    error NoInvoker();

    /// @notice Returns the invoking application's zero-based call depth.
    /// @return depth The application's depth, excluding the helper frame.
    function callStackDepth() external view returns (uint256 depth);

    /// @notice Returns the caller of the invoking application's nth ancestor frame.
    /// @dev callerN(0) equals the application's msg.sender, including through delegatecalls.
    /// @param n Zero selects the application's own caller; out-of-range indices return zero.
    /// @return ancestor The selected frame's CALLER value, preserving delegatecall ancestry.
    function callerN(uint256 n) external view returns (address ancestor);
}
