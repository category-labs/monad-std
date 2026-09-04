// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/// @notice Index of a 128-slot storage page, defined by MIP-8: `slot / 128`
type PageIndex is uint256;

using {Pages.add, Pages.slot, Pages.slotUnbounded} for PageIndex global;

/// @notice Handle for a page. When declared, it reserves one storage slot.
/// The slot number picks the page as `keccak256(abi.encode(slot)) / 128`,
/// similar to how solidity does it for dynamic arrays.
struct PageHandle {
    uint256 _anchor;
}

using {Pages.page} for PageHandle global;

/**
 * @title Pages
 * @notice Implements page and slot arithmetic for MIP-8 storage pages.
 * @dev MIP-8 groups 128 slots of 32 bytes into a 4 KiB page:
 *
 * page_index(slot)   = slot / 128
 * offset(slot)       = slot % 128
 * slot(page, offset) = page * 128 + offset
 *
 * MIP-8: https://github.com/monad-crypto/MIPs/blob/6e78a6ac39547882f9905fba86d2c794eb1768ef/MIPs/MIP-8.md
 *
 * Example usage:
 * PageHandle internal ledger;
 *
 * PageIndex page = ledger.page();
 * Words.ref(page.slot(0)).value = total;
 * Words.ref(page.slotUnbounded(1 + i)).value = amount;
 */
library Pages {
    uint256 internal constant SLOTS_PER_PAGE = 128;

    /// @dev The offset passed to `slot` is 128 or more.
    error OffsetOutOfPage(uint256 offset);

    /**
     * @notice Returns the page of a page handle.
     * @param handle Handle of the page.
     * @return The page.
     */
    function page(PageHandle storage handle) internal pure returns (PageIndex) {
        uint256 anchor;
        assembly ("memory-safe") {
            anchor := handle.slot
        }
        return fromSlot(uint256(keccak256(abi.encode(anchor))));
    }

    /**
     * @notice Returns the page that contains a storage slot.
     * @param storageSlot Storage slot to locate.
     * @return The page that contains the slot.
     */
    function fromSlot(uint256 storageSlot) internal pure returns (PageIndex) {
        return PageIndex.wrap(storageSlot / SLOTS_PER_PAGE);
    }

    /**
     * @notice Returns the page located `pages` pages after a base page.
     * @param base Base page.
     * @param pages Number of pages to add.
     * @return The selected page.
     */
    function add(PageIndex base, uint256 pages) internal pure returns (PageIndex) {
        return PageIndex.wrap(PageIndex.unwrap(base) + pages);
    }

    /**
     * @notice Returns the slot at an offset inside a page.
     * @dev Reverts with `OffsetOutOfPage` when `offset` is 128 or more
     * @param base Page that holds the slot.
     * @param offset Position of the slot in the page, from zero through 127.
     * @return The storage slot.
     */
    function slot(PageIndex base, uint256 offset) internal pure returns (uint256) {
        if (offset >= SLOTS_PER_PAGE) revert OffsetOutOfPage(offset);
        return slotUnbounded(base, offset);
    }

    /**
     * @notice Returns the slot at `index`, counting from the first slot of a page.
     * @dev Crosses page bounds when `index` is 128 or more.
     * @param base Page whose first slot is index zero.
     * @param index Number of slots after the first slot of the page.
     * @return The storage slot.
     */
    function slotUnbounded(PageIndex base, uint256 index) internal pure returns (uint256) {
        return PageIndex.unwrap(base) * SLOTS_PER_PAGE + index;
    }
}
