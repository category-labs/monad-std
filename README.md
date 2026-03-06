# monad-std

Utilities and interfaces for Solidity development on Monad Foundry.

## Included

- `src/interfaces/IMonadStaking.sol`: staking precompile interface (`0x1000`) with NatSpec and C++-parity selectors.

## Development

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```
