// SPDX-License-Identifier: UNLICENSED
pragma abicoder v2;

import {BaseTargetFunctions} from '@chimera/BaseTargetFunctions.sol';
import {BeforeAfter} from './BeforeAfter.sol';
import {Properties} from './Properties.sol';
import {vm} from '@chimera/Hevm.sol';
import 'contracts/libraries/TickMath.sol';
import 'test/recon/SetupUniswap.sol';

abstract contract TargetFunctions is BaseTargetFunctions, Properties, BeforeAfter {
    function uniswapV3Pool_collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) public {
        uniswapV3Pool.collect(recipient, tickLower, tickUpper, amount0Requested, amount1Requested);
    }

    function uniswapV3Pool_collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) public {
        uniswapV3Pool.collectProtocol(recipient, amount0Requested, amount1Requested);
    }

    function uniswapV3Pool_flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) public {
        uniswapV3Pool.flash(recipient, amount0, amount1, data);
    }

    function uniswapV3Pool_increaseObservationCardinalityNext(uint16 observationCardinalityNext) public {
        uniswapV3Pool.increaseObservationCardinalityNext(observationCardinalityNext);
    }

    function uniswapV3Pool_initialize(uint160 sqrtPriceX96) public {
        uniswapV3Pool.initialize(sqrtPriceX96);
    }

    function uniswapV3Pool_mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) public {
        uniswapV3Pool.mint(recipient, tickLower, tickUpper, amount, data);
    }

    function uniswapV3Pool_setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) public {
        uniswapV3Pool.setFeeProtocol(feeProtocol0, feeProtocol1);
    }

    function testERC20_approve(address spender, uint256 amount) public {
        testERC20.approve(spender, amount);
    }

    function testERC20_mint(address to, uint256 amount) public {
        testERC20.mint(to, amount);
    }

    function testERC20_transfer(address recipient, uint256 amount) public {
        testERC20.transfer(recipient, amount);
    }

    function testERC20_transferFrom(address sender, address recipient, uint256 amount) public {
        testERC20.transferFrom(sender, recipient, amount);
    }

    // swap invariant prop #17
    function test_swap_exactIn_zeroForOne(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        __before();
        swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);
        __after();

        int24 beforeCurrentTick = _before.uniswapV3Pool_currentTick;
        int24 afterCurrentTick = _after.uniswapV3Pool_currentTick;

        check_swap_invariants(
            beforeCurrentTick,
            afterCurrentTick,
            _before.uniswapV3Pool_liquidity,
            _after.uniswapV3Pool_liquidity,
            _before.testERC20_balanceOfToken0,
            _after.testERC20_balanceOfToken0,
            _before.testERC20_balanceOfToken1,
            _after.testERC20_balanceOfToken1,
            _before.uniswapV3Pool_feeGrowthGlobal0X128,
            _after.uniswapV3Pool_feeGrowthGlobal0X128,
            _before.uniswapV3Pool_feeGrowthGlobal1X128,
            _after.uniswapV3Pool_feeGrowthGlobal1X128
        );
    }

    function test_swap_exactIn_oneForZero(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token1.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        __before();
        swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);
        __after();

        int24 beforeCurrentTick = _before.uniswapV3Pool_currentTick;
        int24 afterCurrentTick = _after.uniswapV3Pool_currentTick;

        check_swap_invariants(
            beforeCurrentTick,
            afterCurrentTick,
            _before.uniswapV3Pool_liquidity,
            _after.uniswapV3Pool_liquidity,
            _before.testERC20_balanceOfToken0,
            _after.testERC20_balanceOfToken0,
            _before.testERC20_balanceOfToken1,
            _after.testERC20_balanceOfToken1,
            _before.uniswapV3Pool_feeGrowthGlobal0X128,
            _after.uniswapV3Pool_feeGrowthGlobal0X128,
            _before.uniswapV3Pool_feeGrowthGlobal1X128,
            _after.uniswapV3Pool_feeGrowthGlobal1X128
        );
    }

    function test_swap_exactOut_zeroForOne(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        __before();
        swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);
        __after();

        int24 beforeCurrentTick = _before.uniswapV3Pool_currentTick;
        int24 afterCurrentTick = _after.uniswapV3Pool_currentTick;

        check_swap_invariants(
            beforeCurrentTick,
            afterCurrentTick,
            _before.uniswapV3Pool_liquidity,
            _after.uniswapV3Pool_liquidity,
            _before.testERC20_balanceOfToken0,
            _after.testERC20_balanceOfToken0,
            _before.testERC20_balanceOfToken1,
            _after.testERC20_balanceOfToken1,
            _before.uniswapV3Pool_feeGrowthGlobal0X128,
            _after.uniswapV3Pool_feeGrowthGlobal0X128,
            _before.uniswapV3Pool_feeGrowthGlobal1X128,
            _after.uniswapV3Pool_feeGrowthGlobal1X128
        );
    }

    function test_swap_exactOut_oneForZero(uint128 _amount) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        __before();
        swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);
        __after();

        int24 beforeCurrentTick = _before.uniswapV3Pool_currentTick;
        int24 afterCurrentTick = _after.uniswapV3Pool_currentTick;

        check_swap_invariants(
            beforeCurrentTick,
            afterCurrentTick,
            _before.uniswapV3Pool_liquidity,
            _after.uniswapV3Pool_liquidity,
            _before.testERC20_balanceOfToken0,
            _after.testERC20_balanceOfToken0,
            _before.testERC20_balanceOfToken1,
            _after.testERC20_balanceOfToken1,
            _before.uniswapV3Pool_feeGrowthGlobal0X128,
            _after.uniswapV3Pool_feeGrowthGlobal0X128,
            _before.uniswapV3Pool_feeGrowthGlobal1X128,
            _after.uniswapV3Pool_feeGrowthGlobal1X128
        );
    }
}
