// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title PagedArray
/// @notice A storage-efficient dynamic array library that aligns data to MIP-8
///         page boundaries, ensuring all elements within a page are warm after
///         the first SLOAD.
/// @dev MIP-8 defines a page as 128 contiguous EVM words (4096 bytes). A slot
///      belongs to a page via:
///
///        page_index(slot) = slot >> 7
///        offset(slot)     = slot & 0x7F
///
///      Once any slot on a page is accessed, all subsequent SLOAD/SSTORE on
///      that page are charged at warm cost. This library exploits that property
///      by aligning the array base to a 128-slot page boundary:
///
///        base = and(keccak256(arr.slot), not(0x7f))   — clears low 7 bits
///
///        base + 0    →  length
///        base + 1    →  arr[0]
///        base + 2    →  arr[1]
///        ...
///        base + N    →  arr[N-1]
///
///      Crucially, the length is stored at `base + 0` — on the same page as
///      the data — rather than at `arr.slot` (as a native Solidity array would).
///      This is intentional: length and data are almost always accessed
///      together (bounds checks, iteration, push, pop), so co-locating them on
///      the same page means the first SLOAD warms the entire page, making all
///      subsequent length and data reads warm at no extra cold cost.
///      A native `uint256[]` stores its length at `arr.slot` and data at
///      `keccak256(arr.slot)`, which land on different pages and incur two
///      separate cold SLOAD charges.
///
///      All elements within the first page (indices 0–126) share a single cold
///      SLOAD charge. Beyond 127 elements the array spills naturally into
///      subsequent pages with no special handling required.
///
///      The `Array` struct uses a dummy `_ptr` field solely to anchor a unique
///      storage slot. Its value is never read or written by this library.
///      This avoids collision with native `uint256[]` Solidity arrays, which
///      store their length at the declared slot and data at `keccak256(slot)`.
///
/// @custom:mip https://github.com/monad-crypto/MIPs/blob/main/MIPS/MIP-8.md
library PagedArray {
    /// @notice Thrown when pop() is called on an array with no elements.
    error EmptyArray();

    /// @notice Thrown when pop(n) is called with `n` greater than the current length.
    /// @param requested Number of elements requested to pop.
    /// @param available Number of elements currently in the array.
    error InsufficientElements(uint256 requested, uint256 available);

    /// @notice Thrown when get() is called with an index that is out of bounds.
    /// @param index     The index that was requested.
    /// @param length    The current length of the array.
    error IndexOutOfBounds(uint256 index, uint256 length);

    /// @notice Handle to a page-aware array in contract storage.
    /// @dev The `_ptr` field is never read or written — it exists only to
    ///      reserve a unique storage slot that `arr.slot` resolves to.
    struct Array {
        uint256 _ptr;
    }

    function dataLocationAndLen(Array storage arr) internal view returns (uint256 baseSlot, uint256 length) {
        assembly {
            mstore(0x00, arr.slot)
            baseSlot := and(keccak256(0x00, 0x20), not(0x7f))
            length := sload(baseSlot)
        }
    }

    /// @notice Returns the number of elements in the array.
    /// @param arr Storage pointer to the array.
    /// @return arrayLen Current number of elements.
    function len(Array storage arr) internal view returns (uint256 arrayLen) {
        (, arrayLen) = dataLocationAndLen(arr);
    }

    /// @notice Appends a value to the end of the array.
    /// @dev Increments the length stored at the page-aligned base slot and
    ///      writes `value` to `baseSlot + newLength`. Data is 1-indexed so
    ///      that index 0 never aliases the length slot.
    /// @param arr   Storage pointer to the array.
    /// @param value Value to append.
    function push(Array storage arr, uint256 value) internal {
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        assembly {
            sstore(add(baseSlot, add(arrayLen, 1)), value)
            sstore(baseSlot, add(arrayLen, 1))
        }
    }

    /// @notice Appends multiple elements to the end of the array.
    /// @dev Elements are written sequentially starting at `baseSlot + arrayLen + 1`.
    ///      A single length update is deferred to after the loop, saving repeated
    ///      SSTOREs to the length slot.
    /// @param arr    Storage pointer to the array.
    /// @param values Memory array of values to append.
    function push(Array storage arr, uint256[] memory values) internal {
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        assembly {
            let count := mload(values)
            let ptr := add(values, 0x20)
            let writeSlot := add(baseSlot, add(arrayLen, 1))
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                sstore(writeSlot, mload(ptr))
                writeSlot := add(writeSlot, 1)
                ptr := add(ptr, 0x20)
            }
            sstore(baseSlot, add(arrayLen, count))
        }
    }

    /// @notice Removes and returns the last element of the array.
    /// @dev Clears the vacated storage slot to reclaim gas. Reverts with
    ///      `EmptyArray()` if the array is empty.
    /// @param arr Storage pointer to the array.
    /// @return poppedValue The value that was removed.
    function pop(Array storage arr) internal returns (uint256 poppedValue) {
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        require(arrayLen > 0, EmptyArray());

        assembly {
            poppedValue := sload(add(baseSlot, arrayLen))
            sstore(add(baseSlot, arrayLen), 0)
            sstore(baseSlot, sub(arrayLen, 1))
        }
    }

    /// @notice Removes and returns the last `n` elements of the array in LIFO order.
    /// @dev Clears each vacated slot to reclaim gas. Reverts if `n` exceeds the
    ///      current length. Elements are returned as a freshly allocated memory
    ///      array where index 0 is the last element of the storage array.
    /// @param arr Storage pointer to the array.
    /// @param n   Number of elements to pop.
    /// @return out Memory array of popped values in LIFO order.
    function pop(Array storage arr, uint256 n) internal returns (uint256[] memory out) {
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        require(n <= arrayLen, InsufficientElements(n, arrayLen));
        out = new uint256[](n);
        assembly {
            let newLen := sub(arrayLen, n)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                let storageIdx := sub(arrayLen, i) // arrayLen, arrayLen-1, ...
                let val := sload(add(baseSlot, storageIdx))
                mstore(add(out, shl(5, add(i, 1))), val) // out[i] = val
                sstore(add(baseSlot, storageIdx), 0)
            }
            sstore(baseSlot, newLen)
        }
    }

    /// @notice Returns the element at `index` without modifying the array.
    /// @dev Reverts with {IndexOutOfBounds} if `index` is out of bounds.
    ///      Elements are stored at `baseSlot + index + 1` (1-indexed).
    /// @param arr   Storage pointer to the array.
    /// @param index Zero-based index of the element to retrieve.
    /// @return value The element at the given index.
    function get(Array storage arr, uint256 index) internal view returns (uint256 value) {
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        require(index < arrayLen, IndexOutOfBounds(index, arrayLen));
        assembly {
            value := sload(add(baseSlot, add(index, 1)))
        }
    }

    /// @notice Overwrites elements starting at `start` with the given values.
    /// @dev Reverts if the range [start, start + values.length) exceeds the
    ///      current length — this method only overwrites existing elements,
    ///      it does not extend the array. Use push() to append new elements.
    /// @param arr    Storage pointer to the array.
    /// @param start  Zero-based index of the first element to overwrite.
    /// @param values Memory array of values to write.
    function set(Array storage arr, uint256 start, uint256[] memory values) internal {
        if (values.length == 0) {
            return;
        }
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        uint256 count = values.length;
        require(start + count <= arrayLen, IndexOutOfBounds(start + count - 1, arrayLen));
        assembly {
            let ptr := add(values, 0x20)
            let writeSlot := add(baseSlot, add(start, 1))
            for { let i := 0 } lt(i, count) { i := add(i, 1) } {
                sstore(writeSlot, mload(ptr))
                writeSlot := add(writeSlot, 1)
                ptr := add(ptr, 0x20)
            }
        }
    }

    /// @notice Copies the entire array from storage into a new memory array.
    /// @dev Reads length once, then loads each element sequentially. Elements
    ///      within the same page are warm after the first SLOAD, so this is
    ///      cheap for arrays that fit within a single page (up to 126 elements).
    /// @param arr Storage pointer to the array.
    /// @return out A freshly allocated memory array containing all elements.
    function toMemory(Array storage arr) internal view returns (uint256[] memory out) {
        (uint256 baseSlot, uint256 arrayLen) = dataLocationAndLen(arr);
        out = new uint256[](arrayLen);
        assembly {
            let ptr := add(out, 0x20)
            for { let i := 0 } lt(i, arrayLen) { i := add(i, 1) } {
                mstore(ptr, sload(add(baseSlot, add(i, 1))))
                ptr := add(ptr, 0x20)
            }
        }
    }

    /// @notice Initializes the array from a memory array, replacing all existing contents.
    /// @dev Reads the old length first, then clears any slots beyond the new length
    ///      to reclaim gas refunds. Slots within the new length are overwritten
    ///      directly without clearing first. Length is updated once at the end.
    /// @param arr    Storage pointer to the array.
    /// @param values Memory array of values to initialize from.
    function fromMemory(Array storage arr, uint256[] memory values) internal {
        (uint256 baseSlot, uint256 oldLen) = dataLocationAndLen(arr);
        uint256 newLen = values.length;
        assembly {
            // overwrite slots [1, newLen] with new values
            let ptr := add(values, 0x20)
            let writeSlot := add(baseSlot, 1)
            for { let i := 0 } lt(i, newLen) { i := add(i, 1) } {
                sstore(writeSlot, mload(ptr))
                writeSlot := add(writeSlot, 1)
                ptr := add(ptr, 0x20)
            }

            // clear stale slots (newLen, oldLen]
            for { let i := add(newLen, 1) } iszero(gt(i, oldLen)) { i := add(i, 1) } {
                sstore(add(baseSlot, i), 0)
            }

            sstore(baseSlot, newLen)
        }
    }

    /// @notice Removes all elements from the array and clears their storage slots.
    /// @dev Delegates to fromMemory with an empty array, reclaiming gas refunds
    ///      for all cleared slots.
    /// @param arr Storage pointer to the array.
    function clear(Array storage arr) internal {
        fromMemory(arr, new uint256[](0));
    }
}
