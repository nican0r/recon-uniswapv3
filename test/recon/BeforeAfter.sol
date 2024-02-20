// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import {Setup} from './Setup.sol';
import 'contracts/UniswapV3Pool.sol';
import 'contracts/libraries/Position.sol';

abstract contract BeforeAfter is Setup {
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    struct Vars {
        mapping(bytes32 => Position.Info) uniswapV3Pool_positions;
        uint256 testERC20_balanceOfToken0;
        uint256 testERC20_balanceOfToken1;
        // SwapperStats = liquidity, freeGrowthGlobal0, freeGrowthGlobal1, token0 balance, token1 balance
        uint256 uniswapV3Pool_feeGrowthGlobal0X128;
        uint256 uniswapV3Pool_feeGrowthGlobal1X128;
        uint128 uniswapV3Pool_liquidity;
        int24 uniswapV3Pool_currentTick;
    }

    Vars internal _before;
    Vars internal _after;

    function __before() internal {
        // replaced original implementation to allow querying balance of token0 and token1
        _before.testERC20_balanceOfToken0 = token0.balanceOf(address(this));
        _before.testERC20_balanceOfToken1 = token1.balanceOf(address(this));

        (, _before.uniswapV3Pool_currentTick, , , , , ) = uniswapV3Pool.slot0();
        _before.uniswapV3Pool_feeGrowthGlobal0X128 = uniswapV3Pool.feeGrowthGlobal0X128();
        _before.uniswapV3Pool_feeGrowthGlobal1X128 = uniswapV3Pool.feeGrowthGlobal1X128();
        _before.uniswapV3Pool_liquidity = uniswapV3Pool.liquidity();
    }

    function __after() internal {
        _after.testERC20_balanceOfToken0 = token0.balanceOf(address(this));
        _after.testERC20_balanceOfToken1 = token1.balanceOf(address(this));

        (, _after.uniswapV3Pool_currentTick, , , , , ) = uniswapV3Pool.slot0();
        _after.uniswapV3Pool_feeGrowthGlobal0X128 = uniswapV3Pool.feeGrowthGlobal0X128();
        _after.uniswapV3Pool_feeGrowthGlobal1X128 = uniswapV3Pool.feeGrowthGlobal1X128();
        _after.uniswapV3Pool_liquidity = uniswapV3Pool.liquidity();
    }
}
