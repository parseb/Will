// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Will} from "src/Will.sol";
import {WillTokenTestUtils, MockERC20} from "./WillTokenTestUtils.sol";

import {console} from "forge-std/console.sol";

/// @title WillTokenPriceTest
/// @notice Tests the price mechanism and model
contract WillTokenPriceTest is WillTokenTestUtils {
    Will public willToken;

    address alice;
    address bob;
    address charlie;
    address david;

    uint256 constant INITIAL_MINT = 10 ether;
    uint256 constant LARGE_MINT_AMOUNT = 1000 ether;
    uint256 constant STRESS_ITERATIONS = 10;

    function setUp() public {
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        recipients[0] = alice = createUserWithBalance("alice", 10000 ether);
        bob = createUserWithBalance("bob", 10000 ether);
        charlie = createUserWithBalance("charlie", 10000 ether);
        david = createUserWithBalance("david", 10000 ether);

        amounts[0] = INITIAL_MINT;
        willToken = new Will(recipients, amounts);
    }

    //==============================================================================
    // Price Mechanism Tests
    //==============================================================================

    /// @notice Verify burn mechanism maintains fair value distribution
    function testSomePriceChange() public {
        uint256 priceOne = willToken.currentPrice();

        // Initial setup with multiple minters
        vm.prank(bob);
        uint256 bobMinted = willToken.mintFromETH{value: 2 ether}();

        vm.prank(charlie);
        uint256 charlieMinted = willToken.mintFromETH{value: 1 ether}();

        uint256 aliceInitialBalance = address(alice).balance;
        assertTrue(bobMinted == charlieMinted * 2, "Bob should have 2x Charlie");
        vm.roll(block.number + 1);
        uint256 priceTwo = willToken.currentPrice();
        vm.prank(bob);
        bobMinted = willToken.mintFromETH{value: 10 ether}();

        vm.roll(block.number + 1);
        vm.prank(charlie);
        charlieMinted = willToken.mintFromETH{value: 5 ether}();
        vm.roll(block.number + 1);
        
        console.log("priceOne", priceOne);
        console.log("priceTwo", priceTwo);
        console.log("priceThree", willToken.currentPrice());
        console.log("bobMinted", bobMinted);
        console.log("charlieMinted", charlieMinted);
        assertTrue(bobMinted > charlieMinted * 2, "Bob should have more than Charlie");

        uint256 priceThree = willToken.currentPrice();
        assertTrue(priceThree > priceTwo, "Price should increase over time 3-2");
        assertTrue(priceTwo > priceOne, "Price should increase over time 2-1");
        assertTrue(bobMinted > charlieMinted, "Bob should have more than Charlie");
        assertTrue(bobMinted > charlieMinted * 2, "Bob should have more than 2x Charlie");


        // Alice burns her initial tokens
        vm.prank(alice);
        uint256 burnReturn = willToken.burn(INITIAL_MINT);

        assertGt(burnReturn, 0, "Burn should return some value");

        assertGt(address(alice).balance, aliceInitialBalance, "Alice should receive ETH");
    }

    /// @notice Test price proportionality with total supply, burn return value, and minting mechanics
    function testPriceAndBurnMechanics() public {
        uint256 initialPrice = willToken.currentPrice();



        vm.roll(block.number + 1); // Roll to the next block
        uint256 charliePrice = willToken.currentPrice();

        vm.prank(charlie);
        uint256 charlieMinted = willToken.mintFromETH{value: 1 ether}();
        vm.roll(block.number + 1);
        uint256 priceAfterMints = willToken.currentPrice();
        uint256 supplyAfterMints = willToken.totalSupply();

        // Verify price increases proportionally with total supply
        assertGt(priceAfterMints, initialPrice, "Price should increase with total supply");
        assertEq(priceAfterMints, supplyAfterMints / 1 gwei, "Price should be proportional to total supply");

        // Verify number of tokens minted decreases as total supply increases for the same ETH value
        vm.roll(block.number + 1); // Roll to the next block
        uint256 davidPrice = willToken.currentPrice();
        vm.prank(david);
        uint256 davidMinted = willToken.mintFromETH{value: 1 ether}();

        console.log(charlieMinted, davidMinted, charliePrice, davidPrice);

        assertTrue(charliePrice < davidPrice, "Price should increase with supply");
        assertTrue(davidMinted < charlieMinted, "Minted tokens should decrease as total supply increases");

        // Calculate expected burn return based on proportion of total supply
        uint256 expectedBurnReturn = address(willToken).balance* INITIAL_MINT / willToken.totalSupply();

        // Alice burns her initial tokens
        vm.roll(block.number + 1); // Roll to the next block
        vm.prank(alice);
        uint256 burnReturn = willToken.burn(INITIAL_MINT/2);

        assertGt(burnReturn, 0, "Burn should return some value");
        assertEq(burnReturn, expectedBurnReturn / 2, "Burn return should match expected value");

        // Verify burn return value increases with additional mints
        vm.roll(block.number + 1); // Roll to the next block
        vm.prank(bob);
        willToken.mintFromETH{value: 5 ether}();

        vm.roll(block.number + 1); // Roll to the next block
        vm.prank(alice);
        uint256 burnReturnAfterMint = willToken.burn(INITIAL_MINT/2);
        assertGt(burnReturnAfterMint, burnReturn, "Burn return should increase with additional mints");
    }

    /// @notice Test price updates across multiple blocks and minters
    function testPriceUpdateMechanics() public {
        uint256 initialPrice = willToken.currentPrice();

        // First mint should use initial price
        vm.prank(bob);
        willToken.mintFromETH{value: 3 ether}();

        uint256 sameBlockPrice = willToken.currentPrice();
        assertEq(sameBlockPrice, initialPrice, "Price shouldn't change in same block");

        // Price should update after rolling to next block
        vm.roll(block.number + 1);
        uint256 totalSupply = willToken.totalSupply();

        // Need to trigger price update with a mint
        vm.prank(charlie);
        willToken.mintFromETH{value: willToken.currentPrice() * 3}();

        assertEq(willToken.currentPrice(), totalSupply / 1 gwei);
    }

    /// @notice Test anti-arbitrage mechanics preventing same-block mint and burn
    function testAntiArbitragePrevention() public {
        uint256 initialPrice = willToken.currentPrice();

        // Try to mint and burn in same block
        vm.startPrank(bob);
        uint256 minted = willToken.mintFromETH{value: 2 ether}();
        uint256 burnReturn = willToken.burn(minted);
        vm.stopPrank();

        assertEq(willToken.currentPrice(), initialPrice, "Price should not change in same block");
        assertLt(burnReturn, 2 ether, "Should not be profitable to mint and burn in same block");
    }

    /// @notice Test minting from ETH with various input amounts
    function testMintFromETHVariousAmounts() public {
        uint256[] memory testAmounts = new uint256[](4);
        testAmounts[0] = 0.1 ether;
        testAmounts[1] = 1 ether;
        testAmounts[2] = 10 ether;
        testAmounts[3] = 50 ether;


        for (uint256 i = 0; i < testAmounts.length; i++) {
            uint256 currentPrice = willToken.currentPrice();
            uint256 oldBalance = willToken.balanceOf(bob);
            vm.prank(bob);
            uint256 minted = willToken.mintFromETH{value: testAmounts[i]}();

            assertEq(minted, (testAmounts[i] / currentPrice * 1 ether), "Minted amount should match expected");

            assertGt(minted, 0, "Should always mint some tokens");
            uint256 newBalance = minted + oldBalance;
            assertEq(willToken.balanceOf(bob), newBalance, "Minted amount should match balance");

            vm.roll(block.number + 1);
        }
    }

    function testPriceIncrementReturn() public {
        uint256 initialPrice = willToken.currentPrice();
        vm.prank(bob);
        willToken.mintFromETH{value: 0.0001 ether}();

        vm.roll(block.number + 1);
        uint256 newPrice = willToken.currentPrice();
        assertTrue(newPrice > initialPrice, "Price should increase after minting");

        vm.prank(charlie);
        willToken.mintFromETH{value: 1 ether}();
        vm.roll(block.number + 1);

        uint256 newPriceAfterSecondMint = willToken.currentPrice();
        assertTrue(newPriceAfterSecondMint > newPrice, "Price should increase after second minting");
        assertTrue(newPriceAfterSecondMint > initialPrice, "Price should be higher than initial price");

        uint256 charlieMinted = willToken.balanceOf(charlie);
        uint256 bobMinted = willToken.balanceOf(bob);

        assertTrue(charlieMinted < bobMinted, "Bob should have more tokens than Charlie");

        vm.roll(block.number + 1);

        vm.prank(bob);
        uint256 bobBurnReturn = willToken.burn(1 ether);
        vm.prank(charlie);
        uint256 charlieBurnReturn = willToken.burn(1 ether);

        assertTrue(bobBurnReturn > 1 gwei, "Bob should receive some ETH on burn");
        assertTrue(charlieBurnReturn > 1 gwei, "Charlie should receive some ETH on burn");

        assertTrue(bobBurnReturn == charlieBurnReturn, "Bob should receive more ETH than Charlie");



    }

}
