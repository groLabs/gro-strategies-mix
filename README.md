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
Fkux strategy is operating on top of the Flux Protocol: https://fluxfinance.com/

Flux allows us to lend stablecoins and generate some yield on that

### How does it work in the context of GSquared protocol?

Once strategy is added into GVault strategies, debtRatio is set, it can start harvesting yield. 

Now, let's get a closer look on how harvest happens:
This is the [entrypoint](https://github.com/groLabs/gro-strategies-mix/blob/main/src/FluxStrategy.sol#L131) to the harvest. What it does:
1. Pulls out assets from GVault which are denominated in 3CRV
2. Withdraws USDC/USDT/DAI from 3CRV pool, effectively exchanging 3crv to any of those stables
3. And calls `.mint()` on corresponding fToken from Flux Finance protocol

For any other consequent harvest it:
- Compares invested assets from Flux protocol to the strategy debt snapshot in GVault
- Report back profit or loss to GVault
- Divest assets from Flux to return back to gVault
- Invest loose assets back into Flux to farm more yield

### How does strategy estimate it's current assets ?
- Fetch current fToken balance of the strategy
- Multiply it by fToken exchange rate stored in same f token contract to get approx amount of USDC/USDT/DAI invested into fToken
- Use `calc_token_amount` from 3CRV pool to calculate estimate of 3crv token we can obtain by depositing stablecoin amount from previous step
