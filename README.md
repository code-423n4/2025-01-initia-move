# Initia Move audit details
- Total Prize Pool: $70,000 in USDC
  - HM awards: $55,800 in USDC
  - QA awards: $2,300 in USDC
  - Judge awards: $6,800 in USDC
  - Validator awards: $4,600 in USDC 
  - Scout awards: $500 in USDC
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts January 7, 2025 20:00 UTC
- Ends January 28, 2025 20:00 UTC

**Note re: risk level upgrades/downgrades**

Two important notes about judging phase risk adjustments: 
- High- or Medium-risk submissions downgraded to Low-risk (QA)) will be ineligible for awards.
- Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.

As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

# Overview

[ ⭐️ SPONSORS: add info here ]

## Links

- **Previous audits:**  https://github.com/Zellic/publications/blob/master/Initia%20-%20Zellic%20Audit%20Report.pdf
- **Documentation:** https://initialabs-develop.mintlify.app/
- **Website:** https://initia.xyz/
- **X/Twitter:** https://x.com/initia
- **Discord:** https://discord.gg/initia

---

# Scope

### Files in scope

*For sponsors that don't use the scoping tool: list all files in scope in the table below (along with hyperlinks) -- and feel free to add notes to emphasize areas of focus.*

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [contracts/folder/sample.sol](https://github.com/code-423n4/repo-name/blob/contracts/folder/sample.sol) | 123 | This contract does XYZ | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) |

### Files out of scope

- [Previous audit reports](https://github.com/Zellic/publications/blob/master/Initia%20-%20Zellic%20Audit%20Report.pdf)

# Additional context

## Main invariants

1. consensus breaking (non-deterministic)
2. authorization problem (especially signer permission)
3. correctness of implementation (especially dex part)

## Attack ideas (where to focus for bugs)

- In our ecosystem, we are using bridge hook a lot when we use IBC transfer. so want to user any possible attack when we use this bridge hook.
- In movevm, we have implemented json interface and json marshal unmarshal feature on move contract. It's kinda unique feature on move ecosystem, so good to focus on this part.

## All trusted roles in the protocol

The Governance Account

## Describe any novel or unique curve logic or mathematical models implemented in the contracts:

We have two dex implementations
  1. balancer dex (precompiles/modules/initia_stdlib/dex.move)
  2. stableswap (precompiles/modules/initia_stdlib/stableswap.move)

## Running tests

git clone https://github.com/initia-labs/initia
cd initia
make install

cd ..
git clone https://github.com/initia-labs/movevm
cd movevm
initiad move test --path ./precompiles/modules/initia_stdlib --statistics

```bash
git clone https://github.com/code-423n4/2023-08-arbitrum
git submodule update --init --recursive
cd governance
foundryup
make install
make build
make sc-election-test
```
To run code coverage
```bash
make coverage
```
To run gas benchmarks
```bash
make gas
```


## Miscellaneous
Employees of Initia and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.
