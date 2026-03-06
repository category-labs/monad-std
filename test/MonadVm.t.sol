// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {MonadVm} from "../src/MonadVm.sol";
import {MonadTest} from "../src/MonadTest.sol";

contract MonadVmSelectorTest is MonadTest {
    function testAddressBinding() public pure {
        assert(MONAD_VM_ADDRESS == address(0xc0FFeeCD43A10e1C2b0De63c6CDCFe5B7d0e0CEA));
        assert(STAKING_ADDRESS == address(0x1000));

        assert(address(MONAD_VM) == MONAD_VM_ADDRESS);
        assert(address(STAKING) == STAKING_ADDRESS);

        assert(address(monadVm) == MONAD_VM_ADDRESS);
        assert(address(staking) == STAKING_ADDRESS);
    }

    function testSelectorsMatchMonadFoundry() public pure {
        assert(MonadVm.setEpoch.selector == bytes4(0x8d33af46));
        assert(MonadVm.setProposer.selector == bytes4(0x53417aa5));
        assert(MonadVm.setAccumulator.selector == bytes4(0xe0480ffb));
        assert(MonadVm.blockReward.selector == bytes4(0x2714fe4b));
        assert(MonadVm.epochSnapshot.selector == bytes4(0x5ab25e92));
        assert(MonadVm.epochChange.selector == bytes4(0x3a3b7cb7));
        assert(MonadVm.epochBoundary.selector == bytes4(0xfd138d27));
    }
}
