// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {IReserveBalance} from "../src/interfaces/IReserveBalance.sol";

contract IReserveBalanceSelectorTest {
    function testSelectorsMatchCxxImplementation() public pure {
        assert(IReserveBalance.dippedIntoReserve.selector == bytes4(0x3a61584e));
    }
}
