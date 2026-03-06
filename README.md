# Monad Standard Library • [![CI status](https://github.com/category-labs/monad-std/actions/workflows/test.yml/badge.svg)](https://github.com/category-labs/monad-std/actions/workflows/test.yml)

Monad Standard Library (`monad-std`) is a collection of Monad-specific interfaces and testing helpers for [Foundry](https://github.com/foundry-rs/foundry).

It provides Solidity interfaces that track Monad runtime behavior and lightweight base contracts for ergonomic test usage.

## Install

```bash
forge install category-labs/monad-std
```

## Contracts

### `IMonadStaking`

[`src/interfaces/IMonadStaking.sol`](./src/interfaces/IMonadStaking.sol) defines the public interface for the staking precompile at `0x1000`.

### `MonadVm`

[`src/MonadVm.sol`](./src/MonadVm.sol) defines Monad Foundry cheatcodes exposed by Monad's VM interface.

### `MonadStdConstants`

[`src/MonadStdConstants.sol`](./src/MonadStdConstants.sol) exposes canonical Monad addresses and typed handles:

- `MONAD_VM_ADDRESS`
- `STAKING_ADDRESS`
- `MONAD_VM`
- `STAKING`

### `MonadBase` and `MonadTest`

[`src/Base.sol`](./src/Base.sol) and [`src/MonadTest.sol`](./src/MonadTest.sol) provide forge-std-style ergonomics for tests:

- `monadVm` alias for `MONAD_VM`
- `staking` alias for `STAKING`
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
