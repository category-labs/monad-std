// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {MonadVm} from "./MonadVm.sol";
import {IMonadStaking} from "./interfaces/IMonadStaking.sol";

/// @title MonadStdConstants
/// @notice Shared Monad constants and typed handles (forge-std style).
abstract contract MonadStdConstants {
    /// @notice Monad Foundry cheatcode address (`keccak256("monad cheatcode")[12:]`).
    address internal constant MONAD_VM_ADDRESS = 0xc0FFeeCD43A10e1C2b0De63c6CDCFe5B7d0e0CEA;

    /// @notice Monad staking precompile address.
    address internal constant STAKING_ADDRESS = address(0x1000);

    /// @notice Typed MonadVm handle bound to `MONAD_VM_ADDRESS`.
    MonadVm internal constant MONAD_VM = MonadVm(MONAD_VM_ADDRESS);

    /// @notice Typed Monad staking precompile handle bound to `STAKING_ADDRESS`.
    IMonadStaking internal constant STAKING = IMonadStaking(STAKING_ADDRESS);
}
