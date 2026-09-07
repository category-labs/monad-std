// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

/// @notice A storage slot reached through a pointer
struct Word {
    uint256 value;
}

/**
 * @title Words
 * @notice Turns a storage slot number into a storage pointer
 *
 * Example usage:
 * Words.ref(slot).value = total;
 * uint256 stored = Words.ref(slot).value;
 */
library Words {
    /**
     * @notice Returns a pointer to the word at a storage slot.
     * @param slot Storage slot of the word.
     * @return word Pointer to the word.
     */
    function ref(uint256 slot) internal pure returns (Word storage word) {
        assembly ("memory-safe") {
            word.slot := slot
        }
    }
}
