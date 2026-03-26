// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PagedArray} from "src/utils/PagedArray.sol";
import {MonadTest} from "src/MonadTest.sol";

// ---------------------------------------------------------------------------
// Harness — wraps reverting calls so they happen at a lower call depth
// ---------------------------------------------------------------------------

contract ArrayHarness {
    using PagedArray for PagedArray.Array;

    PagedArray.Array public arr;

    function push(uint256 v) external {
        arr.push(v);
    }

    function pop() external returns (uint256) {
        return arr.pop();
    }

    function popN(uint256 n) external returns (uint256[] memory) {
        return arr.pop(n);
    }

    function get(uint256 i) external view returns (uint256) {
        return arr.get(i);
    }

    function len() external view returns (uint256) {
        return arr.len();
    }

    function set(uint256 start, uint256[] memory values) external {
        arr.set(start, values);
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

contract PagedArrayTest is MonadTest {
    using PagedArray for PagedArray.Array;

    ArrayHarness private h;
    PagedArray.Array private arr;
    PagedArray.Array private arr2;

    function setUp() public {
        h = new ArrayHarness();
    }

    // -------------------------------------------------------------------------
    // len
    // -------------------------------------------------------------------------

    function test_len_initiallyZero() public view {
        assertEq(arr.len(), 0);
    }

    // -------------------------------------------------------------------------
    // push / len
    // -------------------------------------------------------------------------

    function test_push_incrementsLen() public {
        arr.push(1);
        assertEq(arr.len(), 1);
        arr.push(2);
        assertEq(arr.len(), 2);
    }

    function test_push_firstElement() public {
        arr.push(42);
        assertEq(arr.get(0), 42);
    }

    function test_push_multipleElements() public {
        arr.push(10);
        arr.push(20);
        arr.push(30);
        assertEq(arr.get(0), 10);
        assertEq(arr.get(1), 20);
        assertEq(arr.get(2), 30);
    }

    function test_push_maxUint() public {
        arr.push(type(uint256).max);
        assertEq(arr.get(0), type(uint256).max);
    }

    function test_push_zero() public {
        arr.push(0);
        assertEq(arr.len(), 1);
        assertEq(arr.get(0), 0);
    }

    // -------------------------------------------------------------------------
    // pop (single)
    // -------------------------------------------------------------------------

    function test_pop_returnsLastElement() public {
        arr.push(10);
        arr.push(20);
        assertEq(arr.pop(), 20);
    }

    function test_pop_decrementsLen() public {
        arr.push(1);
        arr.push(2);
        arr.pop();
        assertEq(arr.len(), 1);
    }

    function test_pop_clearsSlot() public {
        arr.push(99);
        arr.pop();
        arr.push(77);
        assertEq(arr.get(0), 77);
    }

    function test_pop_emptyReverts() public {
        vm.expectRevert(PagedArray.EmptyArray.selector);
        h.pop();
    }

    function test_pop_toEmpty() public {
        arr.push(1);
        arr.pop();
        assertEq(arr.len(), 0);
    }

    function test_pop_toEmptyThenPushAgain() public {
        arr.push(1);
        arr.pop();
        arr.push(2);
        assertEq(arr.len(), 1);
        assertEq(arr.get(0), 2);
    }

    // -------------------------------------------------------------------------
    // pop (n)
    // -------------------------------------------------------------------------

    function test_popN_returnsElementsInLIFOOrder() public {
        arr.push(10);
        arr.push(20);
        arr.push(30);
        uint256[] memory out = arr.pop(2);
        assertEq(out.length, 2);
        assertEq(out[0], 30);
        assertEq(out[1], 20);
    }

    function test_popN_decrementsLen() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        arr.pop(2);
        assertEq(arr.len(), 1);
    }

    function test_popN_clearsSlots() public {
        arr.push(1);
        arr.push(2);
        arr.pop(2);
        arr.push(99);
        assertEq(arr.get(0), 99);
        assertEq(arr.len(), 1);
    }

    function test_popN_zero() public {
        arr.push(1);
        uint256[] memory out = arr.pop(0);
        assertEq(out.length, 0);
        assertEq(arr.len(), 1);
    }

    function test_popN_all() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory out = arr.pop(3);
        assertEq(out.length, 3);
        assertEq(arr.len(), 0);
    }

    function test_popN_exceedsLenReverts() public {
        h.push(2);
        vm.expectRevert(abi.encodeWithSelector(PagedArray.InsufficientElements.selector, 3, 1));
        h.popN(3);
    }

    function test_popN_emptyReverts() public {
        vm.expectRevert(abi.encodeWithSelector(PagedArray.InsufficientElements.selector, 1, 0));
        h.popN(1);
    }

    // -------------------------------------------------------------------------
    // get
    // -------------------------------------------------------------------------

    function test_get_outOfBoundsReverts() public {
        h.push(1);
        vm.expectRevert(abi.encodeWithSelector(PagedArray.IndexOutOfBounds.selector, 1, 1));
        h.get(1);
    }

    function test_get_emptyReverts() public {
        vm.expectRevert(abi.encodeWithSelector(PagedArray.IndexOutOfBounds.selector, 0, 0));
        h.get(0);
    }

    // -------------------------------------------------------------------------
    // page boundary
    // -------------------------------------------------------------------------

    function test_crossPageBoundary_push() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        assertEq(arr.len(), 200);
    }

    function test_crossPageBoundary_get() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        assertEq(arr.get(0), 0);
        assertEq(arr.get(126), 126);
        assertEq(arr.get(127), 127);
        assertEq(arr.get(199), 199);
    }

    function test_crossPageBoundary_pop() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        assertEq(arr.pop(), 199);
        assertEq(arr.len(), 199);
    }

    function test_crossPageBoundary_popN() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        uint256[] memory out = arr.pop(10);
        assertEq(out.length, 10);
        assertEq(out[0], 199);
        assertEq(out[9], 190);
        assertEq(arr.len(), 190);
    }

    // -------------------------------------------------------------------------
    // no collision between two separate arrays
    // -------------------------------------------------------------------------

    function test_twoArraysNoCollision() public {
        arr.push(1);
        arr.push(2);
        arr2.push(100);
        arr2.push(200);
        assertEq(arr.get(0), 1);
        assertEq(arr.get(1), 2);
        assertEq(arr2.get(0), 100);
        assertEq(arr2.get(1), 200);
    }

    // -------------------------------------------------------------------------
    // toMemory
    // -------------------------------------------------------------------------

    function test_toMemory_empty() public view {
        assertEq(arr.toMemory().length, 0);
    }

    function test_toMemory_singleElement() public {
        arr.push(42);
        uint256[] memory out = arr.toMemory();
        assertEq(out.length, 1);
        assertEq(out[0], 42);
    }

    function test_toMemory_multipleElements() public {
        arr.push(10);
        arr.push(20);
        arr.push(30);
        uint256[] memory out = arr.toMemory();
        assertEq(out[0], 10);
        assertEq(out[1], 20);
        assertEq(out[2], 30);
    }

    function test_toMemory_doesNotMutateStorage() public {
        arr.push(1);
        arr.push(2);
        arr.toMemory();
        assertEq(arr.len(), 2);
        assertEq(arr.get(0), 1);
        assertEq(arr.get(1), 2);
    }

    function test_toMemory_isIndependentCopy() public {
        arr.push(99);
        uint256[] memory out = arr.toMemory();
        arr.pop();
        arr.push(77);
        assertEq(out[0], 99);
    }

    function test_toMemory_crossPageBoundary() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        uint256[] memory out = arr.toMemory();
        assertEq(out.length, 200);
        for (uint256 i; i < 200; i++) {
            assertEq(out[i], i);
        }
    }

    // -------------------------------------------------------------------------
    // fuzz
    // -------------------------------------------------------------------------

    function testFuzz_pushThenGet(uint256[] calldata values) public {
        vm.assume(values.length > 0 && values.length <= 500);
        for (uint256 i; i < values.length; i++) {
            arr.push(values[i]);
        }
        for (uint256 i; i < values.length; i++) {
            assertEq(arr.get(i), values[i]);
        }
    }

    function testFuzz_pushThenPop(uint256[] calldata values) public {
        vm.assume(values.length > 0 && values.length <= 500);
        for (uint256 i; i < values.length; i++) {
            arr.push(values[i]);
        }
        for (uint256 i = values.length; i > 0; i--) {
            assertEq(arr.pop(), values[i - 1]);
        }
        assertEq(arr.len(), 0);
    }

    function testFuzz_toMemory(uint256[] calldata values) public {
        vm.assume(values.length <= 500);
        for (uint256 i; i < values.length; i++) {
            arr.push(values[i]);
        }
        uint256[] memory out = arr.toMemory();
        assertEq(out.length, values.length);
        for (uint256 i; i < values.length; i++) {
            assertEq(out[i], values[i]);
        }
    }

    function testFuzz_popN(uint256[] calldata values, uint256 n) public {
        vm.assume(values.length > 0 && values.length <= 500);
        vm.assume(n > 0 && n <= values.length);
        for (uint256 i; i < values.length; i++) {
            arr.push(values[i]);
        }
        uint256[] memory out = arr.pop(n);
        assertEq(out.length, n);
        assertEq(arr.len(), values.length - n);
        for (uint256 i; i < n; i++) {
            assertEq(out[i], values[values.length - 1 - i]);
        }
    }

    function test_pushN_crossPageBoundary() public {
        uint256[] memory values = new uint256[](200);
        for (uint256 i; i < 200; i++) {
            values[i] = i;
        }
        arr.push(values);
        assertEq(arr.len(), 200);
        assertEq(arr.get(126), 126);
        assertEq(arr.get(127), 127);
        assertEq(arr.get(199), 199);
    }

    function test_pushN_consistentWithSinglePush() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;
        arr.push(10);
        arr.push(20);
        arr.push(30);
        arr2.push(values);
        assertEq(arr.len(), arr2.len());
        for (uint256 i; i < 3; i++) {
            assertEq(arr.get(i), arr2.get(i));
        }
    }

    function testFuzz_pushN(uint256[] calldata values) public {
        vm.assume(values.length <= 500);
        uint256[] memory mem = new uint256[](values.length);
        for (uint256 i; i < values.length; i++) {
            mem[i] = values[i];
        }
        arr.push(mem);
        assertEq(arr.len(), values.length);
        for (uint256 i; i < values.length; i++) {
            assertEq(arr.get(i), values[i]);
        }
    }

    function testFuzz_pushN_consistentWithSinglePush(uint256[] calldata values) public {
        vm.assume(values.length <= 500);
        uint256[] memory mem = new uint256[](values.length);
        for (uint256 i; i < values.length; i++) {
            mem[i] = values[i];
            arr.push(values[i]);
        }
        arr2.push(mem);
        assertEq(arr.len(), arr2.len());
        for (uint256 i; i < values.length; i++) {
            assertEq(arr.get(i), arr2.get(i));
        }
    }

    // -------------------------------------------------------------------------
    // set(start, values)
    // -------------------------------------------------------------------------

    function test_set_overwritesElements() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory values = new uint256[](2);
        values[0] = 20;
        values[1] = 30;
        arr.set(1, values);
        assertEq(arr.get(0), 1);
        assertEq(arr.get(1), 20);
        assertEq(arr.get(2), 30);
    }

    function test_set_fromStart() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;
        arr.set(0, values);
        assertEq(arr.get(0), 10);
        assertEq(arr.get(1), 20);
        assertEq(arr.get(2), 30);
    }

    function test_set_singleElement() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory values = new uint256[](1);
        values[0] = 99;
        arr.set(1, values);
        assertEq(arr.get(0), 1);
        assertEq(arr.get(1), 99);
        assertEq(arr.get(2), 3);
    }

    function test_set_doesNotChangeLen() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory values = new uint256[](2);
        values[0] = 10;
        values[1] = 20;
        arr.set(0, values);
        assertEq(arr.len(), 3);
    }

    function test_set_emptyValues() public {
        arr.push(1);
        arr.push(2);
        arr.set(0, new uint256[](0));
        assertEq(arr.len(), 2);
        assertEq(arr.get(0), 1);
        assertEq(arr.get(1), 2);
    }

    function test_set_crossPageBoundary() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        uint256[] memory values = new uint256[](10);
        for (uint256 i; i < 10; i++) {
            values[i] = 999 + i;
        }
        arr.set(122, values);
        for (uint256 i; i < 10; i++) {
            assertEq(arr.get(122 + i), 999 + i);
        }
        assertEq(arr.get(121), 121);
        assertEq(arr.get(132), 132);
    }

    function test_set_outOfBoundsReverts() public {
        h.push(1);
        h.push(2);
        uint256[] memory values = new uint256[](2);
        values[0] = 10;
        values[1] = 20;
        vm.expectRevert(abi.encodeWithSelector(PagedArray.IndexOutOfBounds.selector, 2, 2));
        h.set(1, values);
    }

    function test_set_emptyArrayReverts() public {
        uint256[] memory values = new uint256[](1);
        values[0] = 1;
        vm.expectRevert(abi.encodeWithSelector(PagedArray.IndexOutOfBounds.selector, 0, 0));
        h.set(0, values);
    }

    function testFuzz_set(uint256[] calldata initial, uint256[] calldata updates, uint256 start) public {
        vm.assume(initial.length > 0 && initial.length <= 500);
        vm.assume(updates.length > 0 && updates.length <= initial.length);
        vm.assume(start <= initial.length - updates.length);
        for (uint256 i; i < initial.length; i++) {
            arr.push(initial[i]);
        }
        uint256[] memory mem = new uint256[](updates.length);
        for (uint256 i; i < updates.length; i++) {
            mem[i] = updates[i];
        }
        arr.set(start, mem);
        for (uint256 i; i < start; i++) {
            assertEq(arr.get(i), initial[i]);
        }
        for (uint256 i; i < updates.length; i++) {
            assertEq(arr.get(start + i), updates[i]);
        }
        for (uint256 i = start + updates.length; i < initial.length; i++) {
            assertEq(arr.get(i), initial[i]);
        }
        assertEq(arr.len(), initial.length);
    }

    // -------------------------------------------------------------------------
    // fromMemory
    // -------------------------------------------------------------------------

    function test_fromMemory_onEmptyArray() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;
        arr.fromMemory(values);
        assertEq(arr.len(), 3);
        assertEq(arr.get(0), 10);
        assertEq(arr.get(1), 20);
        assertEq(arr.get(2), 30);
    }

    function test_fromMemory_replacesExistingElements() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;
        arr.fromMemory(values);
        assertEq(arr.len(), 3);
        assertEq(arr.get(0), 10);
        assertEq(arr.get(1), 20);
        assertEq(arr.get(2), 30);
    }

    function test_fromMemory_shrinks_clearsStaleSlots() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        uint256[] memory values = new uint256[](1);
        values[0] = 99;
        arr.fromMemory(values);
        assertEq(arr.len(), 1);
        assertEq(arr.get(0), 99);
        arr.push(0);
        arr.push(0);
        assertEq(arr.get(1), 0);
        assertEq(arr.get(2), 0);
    }

    function test_fromMemory_grows() public {
        arr.push(1);
        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;
        arr.fromMemory(values);
        assertEq(arr.len(), 3);
        assertEq(arr.get(0), 10);
        assertEq(arr.get(1), 20);
        assertEq(arr.get(2), 30);
    }

    function test_fromMemory_empty_clearsAll() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        arr.fromMemory(new uint256[](0));
        assertEq(arr.len(), 0);
        arr.push(0);
        arr.push(0);
        arr.push(0);
        assertEq(arr.get(0), 0);
        assertEq(arr.get(1), 0);
        assertEq(arr.get(2), 0);
    }

    function test_fromMemory_crossPageBoundary() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        uint256[] memory values = new uint256[](150);
        for (uint256 i; i < 150; i++) {
            values[i] = 999 + i;
        }
        arr.fromMemory(values);
        assertEq(arr.len(), 150);
        for (uint256 i; i < 150; i++) {
            assertEq(arr.get(i), 999 + i);
        }
        arr.push(0);
        assertEq(arr.get(150), 0);
    }

    function testFuzz_fromMemory(uint256[] calldata initial, uint256[] calldata next) public {
        vm.assume(initial.length <= 500 && next.length <= 500);
        for (uint256 i; i < initial.length; i++) {
            arr.push(initial[i]);
        }
        uint256[] memory mem = new uint256[](next.length);
        for (uint256 i; i < next.length; i++) {
            mem[i] = next[i];
        }
        arr.fromMemory(mem);
        assertEq(arr.len(), next.length);
        for (uint256 i; i < next.length; i++) {
            assertEq(arr.get(i), next[i]);
        }
        if (next.length < initial.length) {
            uint256 staleCount = initial.length - next.length;
            for (uint256 i; i < staleCount; i++) {
                arr.push(0);
            }
            for (uint256 i; i < staleCount; i++) {
                assertEq(arr.get(next.length + i), 0);
            }
        }
    }

    // -------------------------------------------------------------------------
    // clear
    // -------------------------------------------------------------------------

    function test_clear_setsLenToZero() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        arr.clear();
        assertEq(arr.len(), 0);
    }

    function test_clear_clearsSlots() public {
        arr.push(1);
        arr.push(2);
        arr.push(3);
        arr.clear();
        arr.push(0);
        arr.push(0);
        arr.push(0);
        assertEq(arr.get(0), 0);
        assertEq(arr.get(1), 0);
        assertEq(arr.get(2), 0);
    }

    function test_clear_onEmptyArray() public {
        arr.clear();
        assertEq(arr.len(), 0);
    }

    function test_clear_thenPush() public {
        arr.push(1);
        arr.push(2);
        arr.clear();
        arr.push(99);
        assertEq(arr.len(), 1);
        assertEq(arr.get(0), 99);
    }

    function test_clear_crossPageBoundary() public {
        for (uint256 i; i < 200; i++) {
            arr.push(i);
        }
        arr.clear();
        assertEq(arr.len(), 0);
        for (uint256 i; i < 200; i++) {
            arr.push(0);
        }
        for (uint256 i; i < 200; i++) {
            assertEq(arr.get(i), 0);
        }
    }
}
