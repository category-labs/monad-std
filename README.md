# Monad Standard Library • [![CI status](https://github.com/category-labs/monad-std/actions/workflows/test.yml/badge.svg)](https://github.com/category-labs/monad-std/actions/workflows/test.yml)

Monad Standard Library (`monad-std`) is a collection of Monad-specific interfaces, access policies, and testing helpers for [Foundry](https://github.com/foundry-rs/foundry).

It provides Solidity interfaces that track Monad runtime behavior, reusable domain access policies, and lightweight base contracts for ergonomic test usage.

## Install

```bash
forge install category-labs/monad-std
```

## Contracts

### `IMonadStaking`

[`src/interfaces/IMonadStaking.sol`](./src/interfaces/IMonadStaking.sol) defines the public interface for the staking precompile at `0x1000`.

### `IReserveBalance`

[`src/interfaces/IReserveBalance.sol`](./src/interfaces/IReserveBalance.sol) defines the public interface for the reserve balance precompile at `0x1001` ([MIP-4](https://github.com/monad-crypto/MIPs/blob/main/MIPS/MIP-4.md)).

### `ERC20ReadPolicy`

[`src/access/ERC20ReadPolicy.sol`](./src/access/ERC20ReadPolicy.sol) implements the
[`IDomainAccessPolicy`](./src/interfaces/IDomainAccessPolicy.sol) callback for ERC-20 read access:

- `balanceOf(holder)` is allowed only when the caller is `holder`.
- `allowance(owner, spender)` is allowed when the caller is `owner` or `spender`.
- All other selectors, including metadata, transfers, approvals, and bridge mint/burn calls,
  are allowed by the policy and retain the token's own authorization checks.

Import it with `import {ERC20ReadPolicy} from "monad-std/access/ERC20ReadPolicy.sol";`.
Deploy one instance and have the registered policy owner install it for a token through
`DomainSpoke.setAccessPolicy(token, address(policy))`, or pass it as the initial policy when
the token self-registers. The same instance can serve multiple tokens without per-token setup.

The policy applies to call frames checked by domain access control. It does not restrict logs,
storage access, or internal token reads, and has no administrator or additional-reader grants.
Truncated arguments to protected selectors return false; non-canonical address encodings
revert. Policy consumers must treat reverts and any result other than a canonical ABI true
as denial. Valid arguments may include trailing calldata.

### `MonadVm`

[`src/MonadVm.sol`](./src/MonadVm.sol) defines Monad Foundry cheatcodes exposed by Monad's VM interface.

### `MonadStdConstants`

[`src/MonadStdConstants.sol`](./src/MonadStdConstants.sol) exposes canonical Monad addresses and typed handles:

- `MONAD_VM_ADDRESS`
- `STAKING_ADDRESS`
- `RESERVE_BALANCE_ADDRESS`
- `MONAD_VM`
- `STAKING`
- `RESERVE_BALANCE`

### `MonadBase` and `MonadTest`

[`src/Base.sol`](./src/Base.sol) and [`src/MonadTest.sol`](./src/MonadTest.sol) provide forge-std-style ergonomics for tests:

- `monadVm` alias for `MONAD_VM`
- `staking` alias for `STAKING`
- `reserveBalance` alias for `RESERVE_BALANCE`
- `MonadTest` as a convenience aggregate base

## Example Usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9.0;

import {MonadTest} from "monad-std/MonadTest.sol";

contract ExampleTest is MonadTest {
    function testUseMonadVm() public {
        monadVm.setEpoch(42, false);
        monadVm.setProposer(7);
        monadVm.epochBoundary(43);
    }

    function testUseStakingInterface() public {
        staking.getEpoch();
        uint64 proposerValId = staking.getProposerValId();
        staking.getValidator(proposerValId);
        staking.getConsensusValidatorSet(0);
    }
}
```

## Solidity Version Support

The current Solidity support range is:

- `>=0.8.13 <0.9.0`

## Development

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```

## Contributing

See the [contributing guide](./CONTRIBUTING.md).

## Getting Help

- Open an [issue](https://github.com/category-labs/monad-std/issues) for bugs or feature requests.

## License

Monad Standard Library is licensed under [MIT](./LICENSE-MIT).
