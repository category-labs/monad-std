// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {MonadBase} from "./Base.sol";
import {MonadVm} from "./MonadVm.sol";
import {MonadStdConstants} from "./MonadStdConstants.sol";
import {IMonadStaking} from "./interfaces/IMonadStaking.sol";
import {IReserveBalance} from "./interfaces/IReserveBalance.sol";

interface Vm {
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert() external;
    function assume(bool condition) external pure;
}

/// @title MonadTest
/// @notice Convenience aggregate import/base for Monad std utilities in tests.
abstract contract MonadTest is MonadBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq(uint256) failed");
    }

    function assertEq(uint256 a, uint256 b, string memory message) internal pure {
        require(a == b, message);
    }

    function assertEq(uint256[] memory a, uint256[] memory b) internal pure {
        require(a.length == b.length, "assertEq(uint256[]): length mismatch");
        for (uint256 i; i < a.length; i++) {
            require(a[i] == b[i], "assertEq(uint256[]): element mismatch");
        }
    }
}
