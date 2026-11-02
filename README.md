# Arcadia Lending

[![Foundry][foundry-badge]][foundry]
[![License: BUSL-1.1][license-badge]](LICENSE.md)
[![Docs][docs-badge]][docs]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license-badge]: https://img.shields.io/badge/License-BUSL--1.1-blue.svg
[docs]: https://docs.arcadia.finance
[docs-badge]: https://img.shields.io/badge/Docs-docs.arcadia.finance-0A0A0A.svg

Smart contracts for the Lending Pools and the Liquidator of the [Arcadia Protocol](https://arcadia.finance), a non-custodial, composable margin protocol for leveraged yield strategies on AMM liquidity positions, live on Base, Optimism, Unichain and Robinhood.

Lending Pools are isolated, single-asset pools. Lenders supply liquidity and earn interest; Arcadia Margin Accounts borrow against the assets they hold. Each Lending Pool is a Creditor for [Arcadia Accounts](https://github.com/arcadia-finance/accounts-v2), which provides the Accounts, the Factory and the Registry (pricing and risk parameters) and is included as a submodule in `lib/accounts-v2`.

## Overview

### Lending Pools

[`LendingPool`](src/LendingPool.sol) implements the Creditor interface of Arcadia Accounts and is responsible for:

- Issuing and repaying debt of Margin Accounts, tracked with a non-transferable [`DebtToken`](src/DebtToken.sol) (ERC-4626 based).
- Accounting of the liquidity of each Tranche.
- Accruing interest and distributing it to the Tranches and the treasury.
- Starting liquidations and settling them, including bad debt.

Borrowing always goes through an Arcadia Margin Account that has opened a position with the pool. `borrow` sends funds out, provided the Account stays healthy. `flashAction` lends to the Account and executes a [Flash Action](https://docs.arcadia.finance/protocol/flash-actions) on it in the same transaction, which is how one-click leverage and refinancing work. Each pool sets which Account versions it accepts, a minimum margin and an origination fee.

### Tranches

Lenders do not deposit into the pool directly but into a [`Tranche`](src/Tranche.sol), an ERC-4626 vault on the pool's underlying asset. A pool can have several Tranches with different interest weights: more junior Tranches earn a larger share of the interest and are the first to absorb bad debt. If bad debt exceeds the liquidity of the most junior Tranche, that Tranche is wiped out, locked and removed from the pool, and the remainder is charged to the next Tranche. While any auction is running, the most junior Tranche blocks deposits and withdrawals.

[`TrancheWrapper`](src/periphery/tranche-wrapper/TrancheWrapper.sol) wraps a Tranche into a fully ERC-4626 compliant vault with 1:1 shares. It is the recommended entry point for integrations.

### Interest rates

The interest rate is a function of pool utilisation with two linear slopes: a base rate plus a low slope up to an optimal utilisation, and a steep slope above it. Interest is split between the Tranches and the treasury according to their interest weights.

### Liquidations

A Margin Account becomes liquidatable once its used margin (open debt plus the pool's minimum margin) exceeds its liquidation value. From then on:

1. **Initiation.** Anyone can call `liquidateAccount` on the [Liquidator](src/liquidators). The pool adds the liquidation incentives to the Account's debt: an initiation reward, a termination reward and a liquidation penalty, each a share of the debt with a minimum and a cap.
2. **Dutch auction.** The Liquidator sells the Account's assets in a Dutch auction. The price starts at a multiple of the used margin and decays exponentially towards a floor. Bidders can buy any share of the assets, their payment repays the debt, and an optional [`bidCallback`](src/interfaces/IBidCallback.sol) lets them sell the assets before paying.
3. **Termination.** The auction ends when the Account is healthy again, all assets are sold, or the cutoff time passes. Whoever ends it receives the termination reward (reduced or skipped if the auction leaves bad debt), and any remaining assets stay in the Account.
4. **Bad debt.** Debt left after the auction is written off, first against the pending incentives and then against the Tranches, most junior first.

[`LiquidatorL2`](src/liquidators/LiquidatorL2.sol) additionally checks a sequencer uptime feed, so auctions do not progress while the sequencer is down.

### Emergency controls

[`LendingPoolGuardian`](src/guardians/LendingPoolGuardian.sol) lets an authorised guardian pause repays, withdrawals, borrows, deposits and liquidations. The owner can unpause each function individually, and anyone can unpause everything after a fixed cool-down period.

See the docs for more on [Lending Pools](https://docs.arcadia.finance/introduction/concepts/lending-pools), [margin calculations](https://docs.arcadia.finance/protocol/margin-calculations-and-requirements) and [liquidations](https://docs.arcadia.finance/protocol/liquidations).

## Repository structure

```
src
├── LendingPool.sol     Creditor for Arcadia Accounts: debt, interest, liquidation settlement
├── Tranche.sol         ERC-4626 vault for lenders, one per risk tranche
├── DebtToken.sol       Debt accounting of borrowers (ERC-4626 based, non-transferable)
├── guardians/          Emergency pause logic for the LendingPool
├── liquidators/        Dutch auction Liquidator for L1s and L2s
├── periphery/          TrancheWrapper, a fully ERC-4626 compliant Tranche wrapper
├── interfaces/
└── libraries/          Errors and LogExpMath (exponential price decay)
test
├── fuzz/               Fuzz tests, one folder per contract
├── scenario/           End-to-end scenarios: borrow and repay, leveraged actions
├── invariant/          Invariant tests
└── utils/              Fixtures, mocks and test extensions
lib
└── accounts-v2/        Arcadia Accounts: Factory, Registry, Accounts, Creditor base contract
```

## Deployments

The contracts have the same address on every chain they are deployed on: Base (8453), Optimism (10), Unichain (130) and Robinhood (4663).

| Contract   | Address                                      |
| ---------- | -------------------------------------------- |
| Liquidator | `0xA4B0b9fD1d91fA2De44F6ABFd59cC14bA1E1a7Af` |

| Pool  | LendingPool                                  | Wrapped Senior Tranche                       | Chains                     |
| ----- | -------------------------------------------- | -------------------------------------------- | -------------------------- |
| WETH  | `0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2` | `0xD82BFa27D49e5a394ba371B293DaE65E9B7a8C60` | Base, Optimism, Unichain, Robinhood |
| USDC  | `0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1` | `0xbc10718571fcB3c3F67800e7C0887E450D2Ff398` | Base, Optimism, Unichain   |
| cbBTC | `0xa37E9b4369dc20940009030BfbC2088F09645e3B` | `0x7Cc8013e784418dc9771403DD057f55cEb34Ba3A` | Base                       |
| USDG  | `0xf37c0C5996503Fdd2b5CCCE36E659cD30393AE59` | `0x490D997D69Ed770CC510fF4a080416BB563b979b` | Robinhood                  |

The underlying Tranches and all other contracts are listed in the [contract addresses](https://docs.arcadia.finance/developers/contract-addresses/creditors) docs.

## Development

Requires [Foundry](https://getfoundry.sh/).

```shell
git clone https://github.com/arcadia-finance/lending-v2.git
cd lending-v2
git submodule update --init
git -C lib/accounts-v2 submodule update --init
git -C lib/accounts-v2 submodule update --init --recursive lib/slipstream lib/v4-periphery
forge build
```

Run the tests:

```shell
forge test
```

Fuzz runs are set per Foundry profile: `default` (50 runs), `ci` (200 runs, used in CI) and `hf` (2,000 runs). The `lite` profile builds without the optimizer for faster local iteration.

```shell
FOUNDRY_PROFILE=hf forge test
```

CI also checks formatting with `forge fmt --check`.

## Integrating

- [Running a liquidation bot](https://docs.arcadia.finance/developers/integrations/liquidators)
- [Building a Creditor](https://docs.arcadia.finance/developers/integrations/creditors)
- [Wallets and indexers](https://docs.arcadia.finance/developers/integrations/wallets)

## Security

The contracts in this repository have been reviewed in the following audits:

| Date | Auditor | Scope | Report |
| --- | --- | --- | --- |
| 2023-12 | Trust Security | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2023-12%20Trust%20Security.pdf) |
| 2024-01 | Pashov Audit Group | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-01%20Pashov%20Group.pdf) |
| 2024-01 | Renascence | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-01%20Renascense.pdf) |
| 2024-02 | Sherlock (contest) | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-02%20Sherlock.pdf) |
| 2024-06 | Renascence | TrancheWrapper | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-06%20Renascense.pdf) |
| 2025-09 | Sherlock | LendingPool, LiquidatorL1 | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2025-09%20Sherlock.pdf) |

All reports, including those for other Arcadia repositories, are in [arcadia-finance-audits](https://github.com/arcadia-finance/arcadia-finance-audits). See the docs for the protocol's [roles](https://docs.arcadia.finance/security-and-risk/roles), [risk management](https://docs.arcadia.finance/security-and-risk/risk) and [circuit breakers](https://docs.arcadia.finance/security-and-risk/circuit-breakers).

Please report vulnerabilities privately to dev `[at]` arcadia.finance instead of opening a public issue.

## Contributing

Contributions are welcome. For larger changes, get in touch first on [Discord](https://discord.gg/PXcr8SEeTH) or via dev `[at]` arcadia.finance.

## License

The core contracts are licensed under the Business Source License 1.1, see [LICENSE.md](LICENSE.md) for the Additional Use Grant and Change Date. Interfaces and some libraries carry their own SPDX license identifier.

## Links

[Website](https://arcadia.finance) · [Docs](https://docs.arcadia.finance) · [Discord](https://discord.gg/PXcr8SEeTH) · [X](https://x.com/ArcadiaFi) · [Blog](https://arcadiafinance.medium.com/)
