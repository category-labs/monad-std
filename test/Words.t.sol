// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {Test} from "forge-std/Test.sol";

import {Words} from "../src/utils/storage/Words.sol";

contract WordsHarness {
    function read(uint256 slot) external view returns (uint256) {
        return Words.ref(slot).value;
    }

    function write(uint256 slot, uint256 value) external {
        Words.ref(slot).value = value;
    }
}

contract WordsTest is Test {
    WordsHarness internal harness;

    function setUp() public {
        harness = new WordsHarness();
    }

    /// @dev The pointer reads and writes exactly the slot it was given.
    function testFuzzPointerTargetsSlot(uint256 slot, uint256 stored, uint256 written) public {
        vm.store(address(harness), bytes32(slot), bytes32(stored));
        assertEq(harness.read(slot), stored);

        harness.write(slot, written);
        assertEq(vm.load(address(harness), bytes32(slot)), bytes32(written));
    }
}
