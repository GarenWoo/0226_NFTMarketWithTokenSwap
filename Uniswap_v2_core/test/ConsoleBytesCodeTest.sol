// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import '../src/UniswapV2Pair.sol';

import {Test, console} from "forge-std/Test.sol";

contract ConsoleBytesCodeTest is Test {
    function setUp() public {
    }

    function test_ConsoleByteCode() public {
        bytes32 bytecode32 = keccak256(type(UniswapV2Pair).creationCode);
        console.logBytes32(bytecode32);
        assertTrue(bytecode32.length > 0);
    }

}
