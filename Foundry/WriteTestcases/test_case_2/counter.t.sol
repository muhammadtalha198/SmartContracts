// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();

    }

    function test_Increment() public {
        counter.inc();
        assertEq(counter.get(), 1);
    }

    function test_Decrement() public {
        counter.inc();  
        counter.inc();
        counter.dec();

        assertEq(counter.get(), 1);
    }

     function test_Invrement_Decrement() public {
        counter.inc();
        counter.dec();
        assertEq(counter.get(), 0);
    }

    function test_Increment_Revert() public {
        // vm.expectRevert("Counter underflow");
        vm.expectRevert(stdError.arithmeticError);
        counter.dec();
    }
   
}
