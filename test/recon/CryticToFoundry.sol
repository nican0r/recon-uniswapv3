// SPDX-License-Identifier: UNLICENSED
pragma abicoder v2;

import {Test} from 'forge-std/Test.sol';
import {TargetFunctions} from './TargetFunctions.sol';
import {FoundryAsserts} from '@chimera/FoundryAsserts.sol';

contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }

    function testDemo() public {
        // TODO: Given any target function and foundry assert, test your results
    }
}
