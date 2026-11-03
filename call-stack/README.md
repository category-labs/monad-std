# MIP-18 call-stack introspection

`CallStack` lets ordinary Solidity contracts read their current depth and ancestor callers. It uses internal `view` functions and one direct `STATICCALL` to a separately deployed, immutable, stateless Yul helper. Applications need stock Solidity, not a compiler fork. There is no canonical helper address.

## Usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {CallStack} from "monad-std/CallStack.sol";

contract Market {
    address public immutable callStackHelper;

    constructor(address helper) {
        CallStack.validateHelper(helper);
        callStackHelper = helper;
    }

    function context(uint256 n) external view returns (uint256 depth, address ancestor) {
        return CallStack.read(callStackHelper, n);
    }

    function currentDepth() external view returns (uint256) {
        return CallStack.depth(callStackHelper);
    }

    function ancestorCaller(uint256 n) external view returns (address) {
        return CallStack.callerAt(callStackHelper, n);
    }
}
```

All library functions are internal. Neither calling the Solidity wrapper nor a Yul function creates a frame. The helper's external `STATICCALL` creates exactly one frame. Do not place a forwarding contract, external library, or proxy between the application and the helper. Application proxies are supported and their frames remain visible.

If the helper executes at depth `D`, it returns application depth `D - 1`. For `n < D`, the ancestor is its native `CALLERN(n + 1)`; otherwise it returns zero. The bound is checked before addition, so `uint256.max` safely returns zero. `D == 0` reverts because there is no invoking application.

For `user → router → market → helper`, the market gets depth `1`, `callerAt(helper, 0) == router`, `callerAt(helper, 1) == user`, and zero at index `2`. These are each frame's **CALLER values**, not code addresses. Delegatecalls can repeat caller values; no frames or duplicates are removed. Top-level application execution, including a transaction's constructor, has depth zero.

## Runtime support and pins

The implementation follows [MIP-18](https://mips.monad.xyz/MIPs/MIP-18) and its [source](https://github.com/monad-crypto/MIPs/blob/main/MIPs/MIP-18.md), using the [MIP-7](https://github.com/monad-crypto/MIPs/blob/main/MIPs/MIP-7.md) extension prefix. `AE 00` is `CALLSTACKDEPTH` (zero inputs, one output); `AE 01` is `CALLERN` (one full-width uint256 input, one output). Each complete instruction costs two gas, including the prefix.

Verified on 2026-11-03:

| Component | Pin / configuration |
| --- | --- |
| Stock solc | `0.8.35+commit.47b9dedd` |
| Helper builds | Standalone Yul, EVM `cancun`, optimizer enabled/disabled, runs `200`; settings recorded in each artifact |
| Solidity runtime fixtures | Same solc and EVM target, optimizer enabled, runs `200`, `viaIR: false`, no CBOR metadata |
| Monad runtime | [`9082f9b850998df1b5322dec5d38d129e565d0ea`](https://github.com/category-labs/monad-revm/tree/9082f9b850998df1b5322dec5d38d129e565d0ea), explicitly `MonadNext` |
| REVM | `43.0.0`; interpreter `43.0.2`; transitive versions pinned in `runtime/Cargo.lock` |
| Rust | `1.94.1` |
| Foundry used for compilation, formatting, hashing and ordinary tests | `1.8.5`, commit `51a52c59cffd940f76eddd0b4bb1791aa4b5ac7f` |

That Foundry build uses released `monad-revm` 0.8.0, whose source predates MIP-18. The inspected local Foundry checkout (`bfa7f43f4f01177fca564b8acc1d2f0db926b8c0`) uses 0.7.0. Neither is used as evidence of working MIP-18 execution. A small Rust integration harness pins the supporting development runtime instead of patching Foundry. No runtime code is modified by the harness.

The pinned runtime enables these instructions only in `MonadNext`, which has no mainnet or testnet activation timestamp. This is local development support, not evidence of public-network activation. Check the target network's activation and runtime before using the package. Merely selecting a hardfork named `MonadNext` in older tooling does not add the instructions.

Stock solc accepts `verbatim` in standalone Yul, but rejects it in Solidity inline assembly. See the [Yul documentation](https://docs.soliditylang.org/en/latest/yul.html#verbatim). Only `CallStack.yul` and the standalone reference test use `verbatim`; the importable `.sol` files use ordinary Solidity and compile at the repository's minimum version, 0.8.13.

## Build and test

Run from the repository root. Install Python 3, Foundry (`forge`, `cast`), stock solc **0.8.35**, and Rust **1.94.1**. `SOLC` and `CAST` may point to explicit executable paths; the build rejects a different solc version. For example, install the compiler with `solc-select install 0.8.35` and select it with `solc-select use 0.8.35`.

```bash
# Regenerate the two helper artifacts and the library's expected code hash.
python3 call-stack/build.py

# Verify reproducibility, then compile the Solidity and native Yul test fixtures.
python3 call-stack/build.py --check --fixtures
cargo +1.94.1 test --locked --manifest-path call-stack/runtime/Cargo.toml -- --nocapture

# Repository checks and minimum-version compilation.
forge fmt --check
forge build --use 0.8.13
forge build --use 0.8.35 --sizes
forge test --use 0.8.35 -vvv
cargo +1.94.1 fmt --manifest-path call-stack/runtime/Cargo.toml -- --check
cargo +1.94.1 clippy --locked --manifest-path call-stack/runtime/Cargo.toml --all-targets -- -D warnings
```

`artifacts/CallStack.json` and `artifacts/CallStack.unoptimized.json` contain initcode, runtime bytecode, source digest, compiler settings, and Keccak-256 runtime hashes. Test fixtures are generated under ignored `out/`; build outputs stay under ignored `runtime/target/`.

The ten Rust tests deploy real helper initcode and stock-solc application bytecode into an in-memory VM. They cover top-level application calls, nested routers, multiple delegatecall proxies, transaction constructors, factory `CREATE`/`CREATE2`, last-valid/first-invalid/large/max indices, restored context after return and revert, direct helper rejection, bad calldata/value, missing code, failed calls, malformed and dirty-address responses, identity validation, and unsupported Ethereum/Monad runtimes. Both optimized and unoptimized helpers run; context cases also run with and without the observational inspector. The native standalone-Yul reference compares direct instructions with the adjusted helper results in the same frame. Traces verify two-gas instruction pricing and exactly one helper `STATICCALL` per combined wrapper read. No cheatcodes or mocked context values establish these results.

## Local deployment and identity

The Rust tests already deploy the helper locally through real creation transactions; no RPC node is required for full runtime validation. To install the optimized artifact on an existing local JSON-RPC node with an unlocked account:

```bash
python3 call-stack/deploy.py --rpc-url http://127.0.0.1:8545
# Optional: --sender 0x... to select an unlocked local account.
```

The script accepts numeric loopback addresses only, sends a creation transaction, and verifies the resulting runtime byte-for-byte. It returns JSON containing the helper address, code hash, and transaction hash. Deployment can succeed on an unsupported VM because the constructor does not execute MIP-18; deployment success is **not** an activation check. Use a supporting development node to call through the wrapper. Do not use `eth_call` directly on the helper as an application-context read: it is a top-level invocation and reverts on a supporting VM.

The optimized runtime is 99 bytes; its expected Keccak-256 hash is:

```text
0x834cf0edc80c8a7287345bdc0500c3d4025257f8ee905f66b44d4682b521973c
```

`CallStack.validateHelper(helper)` compares `EXTCODEHASH` to `CallStack.HELPER_CODE_HASH`. Validate during construction or when changing configuration. `read`, `depth`, and `callerAt` check code presence but deliberately do not repeat the identity check. Successfully decoding an arbitrary contract's response does not establish its identity. The helper has no storage writes, external calls, upgrade mechanism, or self-destruct path.

The unoptimized runtime is 94 bytes with hash `0x0fcbaba1a6f1ee1f986d46b307a85cbb0b72041707de7233f29b0e71c90e0aa6`. It is a test variant; `validateHelper` accepts only the published optimized runtime.

## Failures and gas

| Condition | Result |
| --- | --- |
| No helper code | `CallStack.MissingHelper(helper)` |
| Helper reverts, halts, lacks gas, or cannot open another frame | `CallStack.HelperCallFailed(helper)` |
| Return data is not exactly 64 bytes, or the address has nonzero upper bits | `CallStack.InvalidHelperResponse(helper)` |
| Identity check sees other code | `CallStack.UnexpectedHelperCode(helper)` |
| Helper calldata is not exactly selector `8485ba60` plus one word, or carries value | `ICallStack.InvalidCalldata()` |
| Helper executes as the top-level message | `ICallStack.NoInvoker()` |

Out-of-range indices return a legitimate zero address. Failure never falls back to zero. Helper errors are mapped to `HelperCallFailed` by the wrapper; raw helper calls expose its own errors.

The wrapper forwards at most **2,000 execution gas**. Unsupported instructions may consume all forwarded gas; older Monad revisions and Ethereum tests verify that the parent retains gas to return the explicit error. The allowance also bounds an untrusted callee's return-data allocation. Account-access costs, ABI handling, copying and the caller's memory expansion are outside that allowance. EIP-150 or very low available gas can further reduce forwarding, and the parent still needs enough gas to handle failure.

Measured using the pinned `MonadNext` runtime and optimized Solidity fixtures, at index zero. Values are `gasleft()` deltas around the actual wrapper expressions, including measurement and ABI/memory overhead, excluding transaction intrinsic gas and outer dispatch. “Cold” is the first helper access in a transaction; “warm” repeats it in the same frame. These are execution costs, not Monad receipt fees (which charge the transaction gas limit).

| Expression | Optimized helper, cold | Optimized helper, warm | Unoptimized helper, cold | Unoptimized helper, warm |
| --- | ---: | ---: | ---: | ---: |
| `read(helper, 0)` | 11,145 | 1,143 | 11,132 | 1,130 |
| `depth(helper)` | 11,177 | 1,175 | 11,164 | 1,162 |
| `callerAt(helper, 0)` | 11,183 | 1,181 | 11,170 | 1,168 |
| Separate `depth` and `callerAt` | 12,351 | 2,350 | 12,325 | 2,324 |

The helper's own valid-index execution costs 167 gas optimized and 154 unoptimized; all tested helper index paths use under 300 gas. The optimizer is slightly larger and more expensive for this tiny helper. The 2,000-gas allowance leaves ample room for these fixed artifacts, not a guarantee for future replacements or gas schedules. Re-run `representative_wrapper_gas` after any compiler, runtime or wrapper change.

## Limits

Matching context values do not reproduce every operational property of the native instructions. The helper adds gas/account-access costs and a call frame, can fail near the call-depth or gas limit, replaces the application's return-data buffer, and adds a visible `STATICCALL` to execution traces. Results depend on the configured helper's code and the VM's MIP-18 support. Use the returned Solidity values instead of relying on a previous call's return-data buffer surviving a read.

Call-stack introspection is not a reliable simulation detector: simulations can reproduce the same call graph. Follow MIP-18's authorization warning; ancestor callers inherit the pitfalls of `tx.origin` and must not replace application authorization.
