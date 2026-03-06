# monad-std

Utilities and interfaces for Solidity development on Monad Foundry.

## Included

- `src/interfaces/IMonadStaking.sol`: staking precompile interface (`0x1000`) with NatSpec and C++-parity selectors.
- `src/MonadVm.sol`: Monad Foundry cheatcode interface.
- `src/MonadStdConstants.sol`: canonical Monad addresses and typed handles.
- `src/Base.sol`: forge-style base aliases (`monadVm`, `staking`) using std constants.
- `src/MonadTest.sol`: aggregate convenience import/base (`MonadTest`).

## Development

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```
