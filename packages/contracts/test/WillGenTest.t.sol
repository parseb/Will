// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Will.sol";
import "forge-std/console.sol";

contract WillTest is Test {
    using stdStorage for StdStorage;

    Will public will;
    address[] public users;
    uint256 constant USERS = 5;
    uint256 constant INITIAL_ETH = 10 ether;

    function setUp() public {
        // Deploy contract with empty initial distribution
        address[] memory initAddrs = new address[](0);
        uint256[] memory initAmts = new uint256[](0);
        will = new Will(initAddrs, initAmts);

        // Setup test users with ETH
        for (uint256 i = 0; i < USERS; i++) {
            address user = address(uint160(0x1000 + i));
            users.push(user);
            vm.deal(user, INITIAL_ETH);
        }
    }

    function testInitialState() public {
        assertEq(will.totalSupply(), 1 ether);
        assertEq(will.currentPrice(), 1 gwei);
        assertEq(will.lastPrice(), 1 gwei);
        assertEq(will.lastBlockSupply(), 1 ether);
        assertEq(address(will).balance, 0);
    }

    function testBasicMint() public {
        vm.startPrank(users[0]);

        // 1 gwei should mint 1 ether of tokens at initial price
        will.mintFromETH{value: 1 gwei}();
        assertEq(will.balanceOf(users[0]), 1 ether);
        assertEq(address(will).balance, 1 gwei);

        vm.roll(block.number + 1);
        // Price should update to 2 gwei (2 ether supply / 1 gwei)
        assertEq(will.currentPrice(), 2 gwei);

        vm.stopPrank();
    }

    function testPriceEvolution() public {
        vm.startPrank(users[0]);

        // First mint
        will.mintFromETH{value: 1 gwei}();
        vm.roll(block.number + 1);
        assertEq(will.currentPrice(), 2 gwei);

        // Second mint at new price
        will.mintFromETH{value: 2 gwei}();
        vm.roll(block.number + 1);
        assertEq(will.currentPrice(), 3 gwei);

        vm.stopPrank();
    }


    function testLargeMints() public {
        vm.startPrank(users[0]);

        // Mint with 1 ether
        will.mintFromETH{value: 1 ether}();
        uint256 tokensReceived = will.balanceOf(users[0]);

        // Should get proportional tokens based on price
        assertEq(tokensReceived, 1 ether * 1 ether / 1 gwei);

        vm.roll(block.number + 1);
        uint256 newPrice = will.currentPrice();
        assertTrue(newPrice > 1 gwei);

        vm.stopPrank();
    }

    function testMultiUserScenario() public {
        // First user mints
        vm.prank(users[0]);
        will.mintFromETH{value: 1 gwei}();
        vm.roll(block.number + 1);

        // Second user mints at new price
        vm.prank(users[1]);
        will.mintFromETH{value: 2 gwei}();
        vm.roll(block.number + 1);

        // First user burns
        vm.prank(users[0]);
        will.burn(1 ether / 2);
        vm.roll(block.number + 1);

        // Verify final state
        assertEq(will.balanceOf(users[0]), 1 ether / 2);
        assertEq(will.balanceOf(users[1]), 1 ether);
        assertTrue(will.currentPrice() > 2 gwei);
    }

    function testFailInsufficientValue() public {
        vm.prank(users[0]);
        will.mintFromETH{value: 0.5 gwei}(); // Should revert
    }

    function testFailBurnTooMuch() public {
        vm.startPrank(users[0]);
        will.mintFromETH{value: 1 gwei}();
        will.burn(2 ether); // Should revert
    }

    function testBurnTo() public {
        vm.startPrank(users[0]);
        vm.roll(block.number + 1);
        uint256 value1 = will.currentPrice();
        will.mintFromETH{value: value1}();
        vm.roll(block.number + 1);
        value1 = address(will).balance * 1e18 / will.totalSupply();
        uint256 recipient_before = users[1].balance;
        uint256 value2 = will.burnReturns(1 ether);
        will.burnTo(1 ether, users[1]);
        uint256 recipient_after = users[1].balance;
        assertEq(value1, value2, "Burn should match mint subsequence");
        assertEq(recipient_after - recipient_before, value2, "Diff should match mint burn");
        assertEq(will.balanceOf(users[0]), 0, "Burned it all not");
    }

    function logState(string memory label) internal view {
        console.log("\n=== ", label, " ===");
        console.log("Total Supply:", will.totalSupply());
        console.log("Price (gwei):", will.currentPrice());
        console.log("Contract Balance:", address(will).balance);
    }
}
