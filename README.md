# Recon Demo On Uniswap V3
This repo provides a working example for how to setup Recon on an existing repo forked from [Uniswap V3 Core](https://github.com/Uniswap/v3-core) to start running Echidna Tests. 

# Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Echidna](https://github.com/crytic/echidna) 
- [Recon](https://staging.getrecon.xyz/)

# Running the Tests
The tests are located in the test/recon directory and can be run from the root directory using:

```echidna test/recon/CryticTester.sol --contract CryticTester --config echidna.yaml```

All tests will pass in the default configuration, to verify that the tests verify the following invariant: 
  - If calling swap does not change the sqrtPriceX96, liquidity will not change 

uncomment [line 724](https://github.com/nican0r/recon-uniswapv3/blob/3e54f84505b1d44d0be3d94ad7d8960e1236af26/contracts/UniswapV3Pool.sol#L724) in the UniswapV3Pool contract using the same command.
