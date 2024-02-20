// SPDX-License-Identifier: UNLICENSED
pragma abicoder v2;

import {BaseSetup} from '@chimera/BaseSetup.sol';

import 'contracts/interfaces/IUniswapV3Factory.sol';
import 'contracts/interfaces/callback/IUniswapV3FlashCallback.sol';
import 'contracts/UniswapV3PoolDeployer.sol';
import 'contracts/UniswapV3Factory.sol';
import 'contracts/interfaces/pool/IUniswapV3PoolOwnerActions.sol';
import 'contracts/interfaces/IUniswapV3PoolDeployer.sol';
import 'contracts/interfaces/IERC20Minimal.sol';
import 'contracts/interfaces/IUniswapV3Pool.sol';
import 'contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol';
import 'contracts/interfaces/pool/IUniswapV3PoolEvents.sol';
import 'contracts/interfaces/pool/IUniswapV3PoolState.sol';
import 'contracts/interfaces/pool/IUniswapV3PoolActions.sol';
import 'contracts/interfaces/callback/IUniswapV3SwapCallback.sol';
import 'contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import 'contracts/interfaces/pool/IUniswapV3PoolImmutables.sol';
import 'contracts/UniswapV3Pool.sol';
import 'contracts/test/TestERC20.sol';
import 'test/recon/SetupUniswap.sol';
import 'contracts/libraries/TickMath.sol';

abstract contract Setup is BaseSetup {
    UniswapV3Pool uniswapV3Pool;
    TestERC20 testERC20; //default from harness
    TestERC20 token0;
    TestERC20 token1;

    SetupTokens tokens;
    SetupUniswap uniswap;

    // UniswapV3Pool pool;

    UniswapMinter minter;
    UniswapSwapper swapper;

    PoolParams poolParams;
    PoolPositions poolPositions;
    PoolPosition[] positions;

    int24[] usedTicks;
    bool inited;

    struct PoolParams {
        uint24 fee;
        int24 tickSpacing;
        int24 minTick;
        int24 maxTick;
        uint24 tickCount;
        uint160 startPrice;
        int24 startTick;
    }

    struct PoolPosition {
        int24 tickLower;
        int24 tickUpper;
        uint128 amount;
        bytes32 key;
    }

    struct PoolPositions {
        int24[] tickLowers;
        int24[] tickUppers;
        uint128[] amounts;
    }

    function setup() internal virtual override {
        // uniswapV3Pool = new UniswapV3Pool(); // pool requires more complicated initialization steps so using the ToB initialization function
        testERC20 = new TestERC20(1e9 ether);
        token0 = new TestERC20(1e9 ether);
        token1 = new TestERC20(1e9 ether);

        // setup for tests
        tokens = new SetupTokens();
        token0 = tokens.token0();
        token1 = tokens.token1();

        uniswap = new SetupUniswap(token0, token1);

        minter = new UniswapMinter(token0, token1);
        swapper = new UniswapSwapper(token0, token1);

        tokens.mintTo(0, address(swapper), 1e9 ether);
        tokens.mintTo(1, address(swapper), 1e9 ether);

        tokens.mintTo(0, address(minter), 1e10 ether);
        tokens.mintTo(1, address(minter), 1e10 ether);
    }

    // helper functions
    function _init(uint128 _seed) internal {
        //
        // generate random pool params
        //
        poolParams = forgePoolParams(_seed);

        //
        // deploy the pool
        //
        uniswap.createPool(poolParams.fee, poolParams.startPrice);
        uniswapV3Pool = uniswap.pool();

        //
        // set the pool inside the minter and swapper contracts
        //
        minter.setPool(uniswapV3Pool);
        swapper.setPool(uniswapV3Pool);

        //
        // generate random positions
        //
        poolPositions = forgePoolPositions(_seed, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);

        //
        // create the positions
        //
        for (uint8 i = 0; i < poolPositions.tickLowers.length; i++) {
            int24 tickLower = poolPositions.tickLowers[i];
            int24 tickUpper = poolPositions.tickUppers[i];
            uint128 amount = poolPositions.amounts[i];

            minter.doMint(tickLower, tickUpper, amount);

            bool lowerAlreadyUsed = false;
            bool upperAlreadyUsed = false;
            for (uint8 j = 0; j < usedTicks.length; j++) {
                if (usedTicks[j] == tickLower) lowerAlreadyUsed = true;
                else if (usedTicks[j] == tickUpper) upperAlreadyUsed = true;
            }
            if (!lowerAlreadyUsed) usedTicks.push(tickLower);
            if (!upperAlreadyUsed) usedTicks.push(tickUpper);
        }

        inited = true;
    }

    function forgePoolParams(uint128 _seed) internal view returns (PoolParams memory poolParams) {
        //
        // decide on one of the three fees, and corresponding tickSpacing
        //
        if (_seed % 3 == 0) {
            poolParams.fee = uint24(500);
            poolParams.tickSpacing = int24(10);
        } else if (_seed % 3 == 1) {
            poolParams.fee = uint24(3000);
            poolParams.tickSpacing = int24(60);
        } else if (_seed % 3 == 2) {
            poolParams.fee = uint24(10000);
            poolParams.tickSpacing = int24(2000);
        }

        poolParams.maxTick = (int24(887272) / poolParams.tickSpacing) * poolParams.tickSpacing;
        poolParams.minTick = -poolParams.maxTick;
        poolParams.tickCount = uint24(poolParams.maxTick / poolParams.tickSpacing);

        //
        // set the initial price
        //
        poolParams.startTick = int24((_seed % uint128(poolParams.tickCount)) * uint128(poolParams.tickSpacing));
        if (_seed % 3 == 0) {
            // set below 0
            poolParams.startPrice = TickMath.getSqrtRatioAtTick(-poolParams.startTick);
        } else if (_seed % 3 == 1) {
            // set at 0
            poolParams.startPrice = TickMath.getSqrtRatioAtTick(0);
            poolParams.startTick = 0;
        } else if (_seed % 3 == 2) {
            // set above 0
            poolParams.startPrice = TickMath.getSqrtRatioAtTick(poolParams.startTick);
        }
    }

    function forgePoolPositions(
        uint128 _seed,
        int24 _poolTickSpacing,
        uint24 _poolTickCount,
        int24 _poolMaxTick
    ) internal view returns (PoolPositions memory poolPositions_) {
        // between 1 and 10 (inclusive) positions
        uint8 positionsCount = uint8(_seed % 10) + 1;

        poolPositions_.tickLowers = new int24[](positionsCount);
        poolPositions_.tickUppers = new int24[](positionsCount);
        poolPositions_.amounts = new uint128[](positionsCount);

        for (uint8 i = 0; i < positionsCount; i++) {
            int24 tickLower;
            int24 tickUpper;
            uint128 amount;

            int24 randomTick1 = int24((_seed % uint128(_poolTickCount)) * uint128(_poolTickSpacing));

            if (_seed % 2 == 0) {
                // make tickLower positive
                tickLower = randomTick1;

                // tickUpper is somewhere above tickLower
                uint24 poolTickCountLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                int24 randomTick2 = int24((_seed % uint128(poolTickCountLeft)) * uint128(_poolTickSpacing));
                tickUpper = tickLower + randomTick2;
            } else {
                // make tickLower negative or zero
                tickLower = randomTick1 == 0 ? 0 : -randomTick1;

                uint24 poolTickCountNegativeLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                uint24 poolTickCountTotalLeft = poolTickCountNegativeLeft + _poolTickCount;

                uint24 randomIncrement = uint24((_seed % uint128(poolTickCountTotalLeft)) * uint128(_poolTickSpacing));

                if (randomIncrement <= uint24(tickLower)) {
                    // tickUpper will also be negative
                    tickUpper = tickLower + int24(randomIncrement);
                } else {
                    // tickUpper is positive
                    randomIncrement -= uint24(-tickLower);
                    tickUpper = tickLower + int24(randomIncrement);
                }
            }

            amount = uint128(1e8 ether);

            poolPositions_.tickLowers[i] = tickLower;
            poolPositions_.tickUppers[i] = tickUpper;
            poolPositions_.amounts[i] = amount;

            _seed += uint128(tickLower);
        }
    }

    function get_random_zeroForOne_priceLimit(
        int256 _amountSpecified
    ) internal view returns (uint160 sqrtPriceLimitX96) {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice, , , , , , ) = uniswapV3Pool.slot0();
        uint160 minimumPrice = TickMath.MIN_SQRT_RATIO;
        sqrtPriceLimitX96 =
            minimumPrice +
            uint160(
                (uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (currentPrice - minimumPrice))
            );
    }

    function get_random_oneForZero_priceLimit(
        int256 _amountSpecified
    ) internal view returns (uint160 sqrtPriceLimitX96) {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice, , , , , , ) = uniswapV3Pool.slot0();
        uint160 maximumPrice = TickMath.MAX_SQRT_RATIO;
        sqrtPriceLimitX96 =
            currentPrice +
            uint160(
                (uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (maximumPrice - currentPrice))
            );
    }

    function check_swap_invariants(
        int24 tick_bfre,
        int24 tick_aftr,
        uint128 liq_bfre,
        uint128 liq_aftr,
        uint256 bal_sell_bfre,
        uint256 bal_sell_aftr,
        uint256 bal_buy_bfre,
        uint256 bal_buy_aftr,
        uint256 feegrowth_sell_bfre,
        uint256 feegrowth_sell_aftr,
        uint256 feegrowth_buy_bfre,
        uint256 feegrowth_buy_aftr
    ) internal {
        // prop #17
        if (tick_bfre == tick_aftr) {
            assert(liq_bfre == liq_aftr);
        }
    }

    function _getRandomPositionIdx(uint128 _seed, uint256 _positionsCount) internal view returns (uint128 positionIdx) {
        positionIdx = _seed % uint128(_positionsCount);
    }

    function _getRandomBurnAmount(uint128 _seed, uint128 _positionAmount) internal view returns (uint128 burnAmount) {
        burnAmount = _seed % _positionAmount;
        require(burnAmount < _positionAmount);
        require(burnAmount > 0);
    }

    function _getRandomPositionIdxAndBurnAmount(
        uint128 _seed
    ) internal view returns (uint128 positionIdx, uint128 burnAmount) {
        positionIdx = _getRandomPositionIdx(_seed, positions.length);
        burnAmount = _getRandomBurnAmount(_seed, positions[positionIdx].amount);
    }

    function check_burn_invariants(
        uint128 _burnAmount,
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _newPosAmount,
        UniswapMinter.MinterStats memory bfre,
        UniswapMinter.MinterStats memory aftr
    ) internal {
        (, int24 currentTick, , , , , ) = uniswapV3Pool.slot0();

        bytes32 positionKey = keccak256(abi.encodePacked(address(minter), _tickLower, _tickUpper));
        (uint128 positionLiquidity, , , , ) = uniswapV3Pool.positions(positionKey);

        // prop #27
        assert(positionLiquidity == _newPosAmount);
    }
}
