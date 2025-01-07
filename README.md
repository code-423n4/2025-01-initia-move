# Initia Move audit details
- Total Prize Pool: $70,000 in USDC
  - HM awards: $56,300 in USDC
  - QA awards: $2,300 in USDC
  - Judge awards: $6,800 in USDC
  - Validator awards: $4,600 in USDC 
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts January 7, 2025 20:00 UTC
- Ends January 28, 2025 20:00 UTC

**Note re: risk level upgrades/downgrades**

Two important notes about judging phase risk adjustments: 
- High- or Medium-risk submissions downgraded to Low-risk (QA)) will be ineligible for awards.
- Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.

As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

# Overview

Initia is a network for interwoven optimistic rollups; Initia is holistically rebuilding how the multichain system should look, feel, and operate.

At its core, Initia reconstructs the entire technological stack, introducing a foundational Layer 1 blockchain integrated with the Layer 2 infrastructure. This integration fosters a tightly knit, interwoven ecosystem of modular networks. Owning the complete technological stack enables Initia to implement chain-level mechanisms that harmonize the economic interests of users, developers, Layer 2 app-chains, and the Layer 1 chain itself.

## Links

- **Previous audits:**  https://github.com/Zellic/publications/blob/master/Initia%20-%20Zellic%20Audit%20Report.pdf
- **Documentation:** https://initialabs-develop.mintlify.app/
- **Website:** https://initia.xyz/
- **X/Twitter:** https://x.com/initia
- **Discord:** https://discord.gg/initia

---

# Scope

- **VIP Modules**
	- Repository: https://github.com/code-423n4/2025-01-initia-move/blob/main/vip-module
  - Files
    - sources/lock_staking.move
    - sources/vesting.move
    - sources/vault.move
    - sources/tvl_manager.move
    - sources/weight_vote.move
    - sources/utils.move
    - sources/operator.move
    - sources/vip.move
- **Usernames**
	- Repository: https://github.com/code-423n4/2025-01-initia-move/blob/main/usernames-module
  - Files:
	  - sources/metadata.move
	  - sources/name_service.move
- **Move VM**
	- Repository: https://github.com/initia-labs/movevm
	- [Diff](https://github.com/initia-labs/movevm/compare/455fe586ea89fcf10afdaf0766da5151d163edc8...7096b76ba9705d4d932808e9c80b72101eafc0a8) from Git commit [455fe586ea89fcf10afdaf0766da5151d163edc8](https://github.com/initia-labs/movevm/tree/455fe586ea89fcf10afdaf0766da5151d163edc8) in main (base) to Git commit [7096b76ba9705d4d932808e9c80b72101eafc0a8](https://github.com/initia-labs/movevm/commit/7096b76ba9705d4d932808e9c80b72101eafc0a8) in main
- **MiniMove**
	- https://github.com/initia-labs/minimove
	- Commit: [5d298bb96a4d19467178f06d56171c097773eed4](https://github.com/initia-labs/minimove/commit/b36d068a7faec31a59d56472e77a9785397f9663)
  - Files:
    - app/**
- **Initia L1 (some minor move pieces in here)**
	- Repository: https://github.com/initia-labs/initia
	- Commit: [c79d3315f16e624f9a39641c52f63b3fc5e2881b](https://github.com/initia-labs/initia/commit/c79d3315f16e624f9a39641c52f63b3fc5e2881b)
	- Files:
    - x/move/* 

Excluding all auto-generated files, tests, and mocks in all of the above scopes.

### Files out of scope

- [Previous audit reports](https://github.com/Zellic/publications/blob/master/Initia%20-%20Zellic%20Audit%20Report.pdf)

# Additional context

## Main invariants

1. consensus breaking (non-deterministic)
2. authorization problem (especially signer permission)
3. correctness of implementation (especially dex part)

## Attack ideas (where to focus for bugs)

- In our ecosystem, we frequently use the bridge hook for IBC (Inter-Blockchain Communication) transfers. Therefore, we want to identify and mitigate any potential security vulnerabilities associated with the use of this bridge hook.
- In movevm, we have implemented json interface and json marshal unmarshal feature on move contract. It's kinda unique feature on move ecosystem, so good to focus on this part.

## All trusted roles in the protocol

The Governance Account

## Describe any novel or unique curve logic or mathematical models implemented in the contracts:

We have two dex implementations
  1. balancer dex (precompiles/modules/initia_stdlib/dex.move)
  2. stableswap (precompiles/modules/initia_stdlib/stableswap.move)

## Running tests

```bash
# initia
git clone https://github.com/initia-labs/initia
(cd initia && make test)

# movevm
git clone https://github.com/initia-labs/movevm
(cd movevm && make test)

# run move tests
(cd movevm && initiad move test --path ./precompiles/modules/initia_stdlib --statistics)

# run vip tests
git clone https://github.com/code-423n4/2025-01-initia-move
(cd 2025-01-initia-move && initiad move test --path ./vip-module --statistics)

# run usernames tests
git clone https://github.com/code-423n4/2025-01-initia-move
(cd 2025-01-initia-move && initiad move test --path ./usernames-module --statistics)
```

## Miscellaneous
Employees of Initia and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.
