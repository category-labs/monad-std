// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {MonadVm} from "./MonadVm.sol";
import {MonadStdConstants} from "./MonadStdConstants.sol";
import {IMonadStaking} from "./interfaces/IMonadStaking.sol";
import {IReserveBalance} from "./interfaces/IReserveBalance.sol";

/// @title MonadBase
/// @notice Shared base contract exposing ergonomic Monad handles.
/// @dev Constants and addresses come from `MonadStdConstants` (single source of truth).
abstract contract MonadBase is MonadStdConstants {
    /// @notice Ergonomic alias for `MONAD_VM`.
    MonadVm internal constant monadVm = MONAD_VM;

    /// @notice Ergonomic alias for `STAKING`.
    IMonadStaking internal constant staking = STAKING;

    /// @notice Ergonomic alias for `RESERVE_BALANCE`.
    IReserveBalance internal constant reserveBalance = RESERVE_BALANCE;
}
