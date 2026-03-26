// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {MonadBase} from "./Base.sol";
import {MonadVm} from "./MonadVm.sol";
import {MonadStdConstants} from "./MonadStdConstants.sol";
import {IMonadStaking} from "./interfaces/IMonadStaking.sol";
import {IReserveBalance} from "./interfaces/IReserveBalance.sol";

/// @title MonadTest
/// @notice Convenience aggregate import/base for Monad std utilities in tests.
abstract contract MonadTest is MonadBase {}
