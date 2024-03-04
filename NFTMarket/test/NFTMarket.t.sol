// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket_V4} from "../src/NFTMarket_V4.sol";
import {GTST} from "../src/GTST.sol";
import {ERC721Token_GOS_V3} from "../src/ERC721Token_GOS_V3.sol";
import {UniswapV2Router02} from "../lib/v2-periphery/contracts/UniswapV2Router02.sol";
import {WETH9} from "../lib/v2-periphery/contracts/test/WETH9.sol";
import {UniswapV2Factory} from "../lib/v2-core/contracts/UniswapV2Factory.sol";

contract NFTMarketTest is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    GTST public tokenContract;
    ERC721Token_GOS_V3 public nftContract;
    NFTMarket_V4 public nftMarketContract;
    WETH9 public wethContract;
    UniswapV2Factory public factoryContract;
    UniswapV2Router02 public routerContract;

    address public tokenAddr;
    address public nftAddr;
    address public marketAddr;
    address public wethAddr;
    address public factoryAddr;
    address public routerAddr;

    function setUp() public {
        vm.startPrank(alice);
        // initialization: deploying contracts
        tokenContract = new GTST();
        tokenAddr = address(tokenContract);
        nftContract = new ERC721Token_GOS_V3();
        nftAddr = address(nftContract);
        wethContract = new WETH9();
        wethAddr = address(wethContract);
        factoryContract = new UniswapV2Factory(alice);
        factoryAddr = address(factoryContract);
        routerContract = new UniswapV2Router02(factoryAddr, wethAddr);
        routerAddr = address(routerContract);
        nftMarketContract = new NFTMarket_V4(tokenAddr, wethAddr, routerAddr);
        marketAddr = address(nftMarketContract);
        // ETH balance assignment
        deal(alice, 200000 ether);
        deal(bob, 200000 ether);
        deal(carol, 200000 ether);
        // token transfer
        wethContract.deposit{value: 100000 ether}();
        wethContract.transfer(bob, 20000 ether);
        wethContract.transfer(carol, 30000 ether);
        tokenContract.transfer(bob, 20000 * 10 ** 18);
        tokenContract.transfer(carol, 30000 * 10 ** 18);
        // mint NFTs
        nftContract.mint(alice, "No.0");
        nftContract.mint(bob, "No.1");
        nftContract.mint(carol, "No.2");
        vm.stopPrank();
    }

    function test_NFTMarket_List() public {
        vm.startPrank(bob);
        nftContract.approve(marketAddr, 1);
        nftMarketContract.list(nftAddr, 1, 150 * 10 ** 18);
        assertEq(nftContract.ownerOf(1), marketAddr, "expect the current owner of #1 NFT is NFTMarket");
        assertEq(nftContract.getApproved(1), bob, "expect the current approved account is bob");
        assertEq(
            nftMarketContract.getNFTPrice(nftAddr, 1), 150 * 10 ** 18, "expect the price of #1 NFT is 150 * 10 ** 18"
        );
        vm.stopPrank();
    }

    function test_NFTMarket_Delist() public {
        vm.startPrank(carol);
        nftContract.approve(marketAddr, 2);
        nftMarketContract.list(nftAddr, 2, 20 * 10 ** 18);
        vm.stopPrank();
        vm.expectRevert("Not seller or Not on sale");
        vm.prank(alice);
        nftMarketContract.delist(nftAddr, 2);
        vm.prank(carol);
        nftMarketContract.delist(nftAddr, 2);
        assertEq(nftContract.ownerOf(2), carol, "expect the owner of #2 NFT is carol");
        assertEq(nftMarketContract.getNFTPrice(nftAddr, 2), 0, "expect the price of #2 NFT is 0");
    }

    function test_NFTMarket_tokensReceived() public {
        vm.startPrank(alice);
        routerContract.addLiquidityETH{value: 10000 * 10 ** 18}(tokenAddr, 10000 * 10 ** 18, 9900 * 10 ** 18, 9900 * 10 ** 18, alice, block.timestamp + 600);
        tokenContract.approve(marketAddr, 40000 * 10 ** 18);
        vm.startPrank(bob);
        nftContract.approve(marketAddr, 1);
        nftMarketContract.list(nftAddr, 1, 8 * 10 ** 18);
        vm.stopPrank();
        bytes memory _data = abi.encode(nftAddr, 1);
        vm.prank(alice);
        tokenContract.transferWithCallbackForNFT(marketAddr, 15 * 10 ** 18, _data);
        assertEq(
            nftContract.ownerOf(1),
            alice,
            "expect the current owner of #1 NFT is alice after transferring token to NFTMarket"
        );
    }

    function test_NFTMarket_Buy() public {
        vm.startPrank(carol);
        nftContract.approve(marketAddr, 2);
        tokenContract.approve(marketAddr, 10000 * 10 ** 18);
        nftMarketContract.list(nftAddr, 2, 120 * 10 ** 18);
        vm.startPrank(bob);
        nftContract.approve(marketAddr, 1);
        tokenContract.approve(marketAddr, 10000 * 10 ** 18);
        nftMarketContract.list(nftAddr, 1, 270 * 10 ** 18);
        vm.startPrank(alice);
        wethContract.approve(marketAddr, 10000 ether);
        nftMarketContract.buyNFTWithAnyToken(wethAddr, nftAddr, 1, 5, 3); // slippage == 0.5%
        assertEq(nftContract.ownerOf(1), alice, "expect the current owner of #1 NFT is alice after buying");
        vm.startPrank(bob);
        assertEq(nftMarketContract.getUserProfit(), 270 * 10 ** 18);
        nftMarketContract.buyNFTWithAnyToken(tokenAddr, nftAddr, 2, 6, 3);
        assertEq(nftContract.ownerOf(2), bob, "expect the current owner of #2 NFT is bob after buying");
        vm.stopPrank();
        vm.prank(carol);
        assertTrue(nftMarketContract.getUserProfit() > 0);
    }

}
