// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/// @notice Decides whether a proposed call into a domain contract may run.
interface IDomainAccessPolicy {
    /// @notice Returns the verdict for a proposed call frame without executing it.
    /// @dev Evaluated through a static call. Implementations must decide from their own
    /// storage and the supplied arguments without making external calls. Consumers must
    /// deny a call if evaluation reverts or returns anything but a canonical ABI true.
    /// @param caller Effective msg.sender in the proposed execution frame.
    /// @param context Address whose storage and balance the proposed call will use.
    /// @param data Original calldata of the proposed call.
    function canCall(address caller, address context, bytes calldata data) external view returns (bool);
}
