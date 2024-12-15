// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Will} from "src/Will.sol";
import {WillTokenTestUtils, MockERC20} from "./WillTokenTestUtils.sol";

/// @title WillTokenPriceTest
/// @notice Tests the price mechanism and model
contract WillTokenPriceTest is WillTokenTestUtils {
    Will public willToken;
    
    address alice;
    address bob;
    address charlie;
    address david;

    uint256 constant INITIAL_MINT = 100 ether;
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
    function testBurnValueDistribution() public {
        // Initial setup with multiple minters
        vm.prank(bob);
        uint256 bobMinted = willToken.mintFromETH{value: 50 ether}();
        
        vm.prank(charlie);
        uint256 charlieMinted = willToken.mintFromETH{value: 25 ether}();

        uint256 contractInitialBalance = address(willToken).balance;
        uint256 aliceInitialBalance = address(alice).balance;

        // Calculate expected burn return based on proportion of total supply
        uint256 expectedBurnReturn = (contractInitialBalance * INITIAL_MINT) / willToken.totalSupply();

        // Alice burns her initial tokens
        vm.prank(alice);
        uint256 burnReturn = willToken.burn(INITIAL_MINT);

        assertGt(burnReturn, 0, "Burn should return some value");
        
        // Allow some small variance due to floating-point-like calculations
        assertApproxEqRel(
            burnReturn, 
            expectedBurnReturn, 
            0.1e18, 
            "Burn return should be proportional to total supply"
        );

        assertGt(address(alice).balance, aliceInitialBalance, "Alice should receive ETH");
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
        willToken.mintFromETH{value: 1 ether}();
        
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
            uint256 oldBalance = willToken.balanceOf(bob);
            vm.prank(bob);
            uint256 minted = willToken.mintFromETH{value: testAmounts[i]}();
            
            assertGt(minted, 0, "Should always mint some tokens");
            uint256 newBalance = minted + oldBalance;
            assertEq(willToken.balanceOf(bob), newBalance, "Minted amount should match balance");
            
            vm.roll(block.number + 1);
        }
    }

    /// @notice Test price changes over multiple minting events
    function testPriceProgression() public {
        uint256 initialPrice = willToken.currentPrice();
        
        address[] memory minters = new address[](3);
        minters[0] = bob;
        minters[1] = charlie;
        minters[2] = david;

        uint256 lastRecordedPrice = initialPrice;

        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < minters.length; j++) {
                uint256 mintAmount = bound(j + i, 0.1 ether, 5 ether);
                
                vm.prank(minters[j]);
                willToken.mintFromETH{value: mintAmount}();
                
                vm.roll(block.number + 1);
                
                uint256 currentPrice = willToken.currentPrice();
                assertGt(currentPrice, lastRecordedPrice, "Price should monotonically increase");
                
                lastRecordedPrice = currentPrice;
            }
        }
    }
}