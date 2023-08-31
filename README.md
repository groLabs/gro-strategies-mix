## Official GroDAO Strategy Mix for [GSquared Protocol](https://github.com/groLabs/GSquared)

| Coverage: [![codecov](https://codecov.io/gh/groLabs/gro-strategies-mix/graph/badge.svg?token=0iPvKbSGYo)](https://codecov.io/gh/groLabs/gro-strategies-mix)  | Tests: [![test](https://github.com/groLabs/gro-strategies-mix/actions/workflows/test.yml/badge.svg)](https://github.com/groLabs/gro-strategies-mix/actions/workflows/test.yml)  |
|---|---|

## What this is ?

This is a standalone repo for all strategies that GSquared protocol uses(or might potentially use in the future).

All strategies implement `IStrategy` interface of GSquared strategy, making it very easy to plug in into [GVault](https://github.com/groLabs/GSquared/blob/master/contracts/GVault.sol) and start harvesting yield

### Building the project and running tests
To build run:

```bash
$ forge build
```

To run tests:
```bash
$ forge test --fork-url ${{ env.ALCHEMY_RPC_URL }} --fork-block-number XXX -vv
```

---

## List of strategies:

## Flux Strategy
