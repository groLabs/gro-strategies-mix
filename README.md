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

## List of strategies
## Flux Strategy
The Flux strategy operates on top of the Flux Protocol: https://fluxfinance.com/

Flux allows us to lend stablecoins and generate some yield.

### How does it work in the context of the GSquared protocol?
Once the strategy is added to the GVault strategies and the debtRatio is set, it can start harvesting yield.

Now, let's take a closer look at how the harvest happens. This is the entrypoint for the harvest. Here's what it does:

- Pulls out assets from GVault denominated in 3CRV.
- Withdraws USDC/USDT/DAI from the 3CRV pool, effectively exchanging 3crv for any of those stablecoins.
- Calls .mint() on the corresponding fToken from the Flux Finance protocol.

For any subsequent harvests, it:
- Compares the invested assets from the Flux protocol to the strategy debt snapshot in GVault.
- Reports back profit or loss to GVault.
- Divests assets from Flux to return back to GVvault.
- Reinvests loose assets back into Flux to farm more yield.

### How does the strategy estimate its current assets?

The strategy estimates its current assets as follows:

- Fetch the current fToken balance of the strategy.
-  Multiply it by the fToken exchange rate stored in the same fToken contract to get an approximate amount of USDC/USDT/DAI invested into the fToken.
- Use calc_token_amount from the 3CRV pool to calculate an estimate of the 3crv tokens we can obtain by depositing the stablecoin amount from the previous step.
