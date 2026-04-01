### MIP-8 Collections

A set of data structures optimized for [MIP-8](https://github.com/monad-crypto/MIPs/blob/main/MIPS/MIP-8.md) page-aware storage. MIP-8 makes the page — 128 contiguous EVM slots — the atomic unit of storage I/O. Once any slot on a page is accessed, all subsequent reads and writes to that page within the transaction are warm. These collections align their storage layouts to page boundaries to exploit this property, co-locating related data so that a single cold SLOAD warms everything needed for common operations.

#### `PagedArray`

[`src/utils/PagedArray.sol`](src/utils/PagedArray.sol) is a dynamic array that stores its length and data on the same MIP-8 page, unlike a native Solidity `uint256[]` which scatters length and data across two separate pages.

```solidity
import {PagedArray} from "monad-std/utils/PagedArray.sol";

contract Example {
    using PagedArray for PagedArray.Array;

    PagedArray.Array private items;

    function add(uint256 value) external { items.push(value); }
    function remove() external returns (uint256) { return items.pop(); }
    function at(uint256 i) external view returns (uint256) { return items.get(i); }
    function count() external view returns (uint256) { return items.len(); }
}
```

**API**

| Function | Description |
|---|---|
| `push(value)` | Append a single element |
| `push(values[])` | Append multiple elements from memory |
| `pop()` | Remove and return the last element |
| `pop(n)` | Remove and return the last `n` elements |
| `get(index)` | Read element at index |
| `set(start, values[])` | Overwrite elements starting at index |
| `len()` | Return current length |
| `toMemory()` | Copy entire array to a memory array |
| `fromMemory(values[])` | Replace contents from a memory array |
| `clear()` | Remove all elements and reclaim storage |

**Gas comparison** (Monad gas constants: 8,100 cold / 100 warm)

| Operation | `uint256[]` | `PagedArray` |
|---|---|---|
| Read length + 1 element | 2 × 8,100 = 16,200 | 8,100 + 100 = 8,200 |
| Read length + 8 elements | 9 × 8,100 = 72,900 | 8,100 + 8 × 100 = 8,900 |
| Read length + 127 elements | 128 × 8,100 = 1,036,800 | 8,100 + 127 × 100 = 20,800 |