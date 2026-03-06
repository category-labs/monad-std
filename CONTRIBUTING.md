## Contributing to Monad Standard Library

Thanks for your interest in improving `monad-std`.

This guide is focused on keeping interfaces accurate to Monad runtime behavior and keeping the library easy to consume in Foundry projects.

### Ways to Contribute

1. Open an issue for bugs, interface mismatches, or missing utilities.
2. Add context to existing issues with concrete reproductions and references.
3. Open a pull request with a focused, reviewable change.

### Asking for Help

If you are blocked, open a GitHub issue with context and a minimal reproducible example.

### Reporting Bugs

When opening a bug report, include:

- `forge --version`
- Your OS and architecture
- A minimal reproduction
- Expected behavior vs actual behavior

### Proposing Interface Changes

If your change updates precompile or cheatcode interfaces, include:

- Source of truth references (Monad docs and/or runtime implementation)
- Selector and event-signature validation updates in tests
- Notes for any intentional divergence from docs

### Adding Monad Cheatcodes

`MonadVm` follows a different pipeline from upstream `forge-std/Vm.sol`.

- Monad cheatcodes are implemented in Monad Foundry at `crates/cheatcodes/src/monad.rs`.
- They are dispatched from a separate cheatcode address (`MONAD_CHEATCODE_ADDRESS`).
- They are not currently part of `crates/cheatcodes/spec/src/vm.rs`, so `cargo cheats` and `cheatcodes.json` do not generate `MonadVm.sol`.

Current recommended workflow:

1. Add/update the cheatcode interface and implementation in Monad Foundry (`crates/cheatcodes/src/monad.rs`).
2. Update Monad Foundry test interface `testdata/utils/MonadVm.sol` to match.
3. Add/update Monad Foundry integration tests (`testdata/default/cheats/MonadStaking.t.sol`).
4. Sync `monad-std/src/MonadVm.sol` and `monad-std/test/MonadVm.t.sol` selectors.
5. Run validation in both repos.

If we later add a dedicated Monad cheatcode JSON/spec in Monad Foundry, we can add a generator script in `monad-std` similar in spirit to `forge-std/scripts/vm.py`.

### Pull Request Checklist

Before opening a PR, run:

```bash
forge fmt --check
forge build --sizes
forge test -vvv
```

If your change affects public interfaces or usage, also update docs (`README.md`, NatSpec, or both).

### Commits

Keep commits logically grouped.

If you have fixup/checkpoint commits, squash them before requesting final review.

### Review and Iteration

Reviews may request follow-up changes.

Please address comments with code updates or clear reasoning when not applying a suggestion.

### License

By contributing, you agree that your contributions are licensed under the repository's [MIT license](./LICENSE-MIT).
