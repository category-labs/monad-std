// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {Test} from "forge-std/Test.sol";

import {PageIndex, PageHandle, Pages} from "../src/utils/storage/Pages.sol";

contract PagesHarness {
    PageHandle internal handle;
    mapping(uint256 => PageHandle) internal handles;

    function page() external view returns (PageIndex) {
        return handle.page();
    }

    function page(uint256 key) external view returns (PageIndex) {
        return handles[key].page();
    }

    function slot(PageIndex base, uint256 offset) external pure returns (uint256) {
        return Pages.slot(base, offset);
    }
}

contract PagesTest is Test {
    PagesHarness internal harness;

    function setUp() public {
        harness = new PagesHarness();
    }

    /// @dev The harness declares `handle` at slot 0, so slot zero of its page is
    /// `keccak256(abi.encode(uint256(0)))` with its low seven bits cleared.
    function testPageStartsAtHashOfHandleSlotRoundedDown() public view {
        assertEq(harness.page().slot(0), 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e500);
    }

    /// @dev The page follows the slot of the handle wherever it is declared. The harness declares
    /// `handles` at slot 1, so `handles[key]` lives at `keccak256(abi.encode(key, uint256(1)))`.
    function testFuzzPageFollowsHandleSlot(uint256 key) public view {
        uint256 handleSlot = uint256(keccak256(abi.encode(key, uint256(1))));
        PageIndex expected = Pages.fromSlot(uint256(keccak256(abi.encode(handleSlot))));
        assertEq(PageIndex.unwrap(harness.page(key)), PageIndex.unwrap(expected));
    }

    function testFuzzFromSlotReturnsContainingPage(uint256 storageSlot) public pure {
        assertEq(Pages.fromSlot(storageSlot).slot(storageSlot % Pages.SLOTS_PER_PAGE), storageSlot);
    }

    function testSlotRejectsOffsetOutsidePage() public {
        vm.expectRevert(abi.encodeWithSelector(Pages.OffsetOutOfPage.selector, Pages.SLOTS_PER_PAGE));
        // forge-lint: disable-next-line(unused-return)
        harness.slot(PageIndex.wrap(0), Pages.SLOTS_PER_PAGE);
    }

    /// @dev Counting `index` slots from the start of a page ends `index / 128` pages later, at
    /// offset `index % 128`. `lastBase` is the last page the index fits in.
    function testFuzzSlotUnboundedCrossesPages(uint256 rawBase, uint256 index) public pure {
        uint256 lastBase = PageIndex.unwrap(Pages.fromSlot(type(uint256).max - index));
        PageIndex base = PageIndex.wrap(bound(rawBase, 0, lastBase));

        assertEq(base.slotUnbounded(index), base.add(index / Pages.SLOTS_PER_PAGE).slot(index % Pages.SLOTS_PER_PAGE));
    }
}
