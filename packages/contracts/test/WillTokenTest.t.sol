// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";
import {IERC20} from "@openzeppelin/contracts-v5/token/ERC20/IERC20.sol";
import {SuperchainERC20} from "@contracts-bedrock/L2/SuperchainERC20.sol";

import {Will} from "src/Will.sol";
import {WillTokenTestUtils, MockERC20} from "./WillTokenTestUtils.sol";

/// @title WillTokenTest
/// @notice Tests for the Will token contract
contract WillTokenTest is WillTokenTestUtils {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = Predeploys.SUPERCHAIN_TOKEN_BRIDGE;
    address internal constant MESSENGER = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
    
    Will public willToken;
    
    address alice;
    address bob;
    address charlie;
    
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;
    
    uint256 constant INITIAL_MINT = 100 ether;
    uint256 constant TEST_AMOUNT = 1 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event PriceUpdated(uint256 previousPrice, uint256 newPrice);

    function setUp() public {
        alice = createUserWithBalance("alice", 100 ether);
        bob = createUserWithBalance("bob", 100 ether);
        charlie = createUserWithBalance("charlie", 100 ether);
        
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = alice;
        amounts[0] = INITIAL_MINT;
        
        willToken = new Will(recipients, amounts);
        
        token1 = new MockERC20("Token1", "TK1");
        token2 = new MockERC20("Token2", "TK2");
        token3 = new MockERC20("Token3", "TK3");
    }

    //==============================================================================
    // Basic Token Tests
    //==============================================================================

    function testMetadata() public {
        assertEq(willToken.name(), "Will");
        assertEq(willToken.symbol(), "WILL");
        assertEq(willToken.decimals(), 18);
    }

    function testInitialSupply() public {
        assertEq(willToken.balanceOf(alice), INITIAL_MINT);
        assertEq(willToken.totalSupply(), INITIAL_MINT);
    }

    function testInitialPrice() public {
        assertEq(willToken.currentPrice(), INITIAL_MINT / 1 gwei);
        assertEq(willToken.lastPriceBlock(), block.number);
    }

    //==============================================================================
    // Price Mechanism Tests
    //==============================================================================

    function testPriceMechanics() public {
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

    function testAntiArbitrage() public {
        uint256 initialPrice = willToken.currentPrice();
        
        // Try to mint and burn in same block
        vm.startPrank(bob);
        uint256 minted = willToken.mintFromETH{value: 2 ether}();
        uint256 burnReturn = willToken.burn(minted);
        vm.stopPrank();
        
        assertEq(willToken.currentPrice(), initialPrice, "Price should not change in same block");
        assertLt(burnReturn, 2 ether, "Should not be profitable to mint and burn in same block");
    }

    //==============================================================================
    // Minting Tests
    //==============================================================================

    function testMintFromETH() public {
        uint256 initialPrice = willToken.currentPrice();
        
        vm.prank(bob);
        uint256 minted = willToken.mintFromETH{value: TEST_AMOUNT}();
        
        assertGt(minted, 0, "Should mint non-zero amount");
        assertEq(willToken.balanceOf(bob), minted);
        assertEq(address(willToken).balance, TEST_AMOUNT, "ETH should be held by contract");
        assertEq(willToken.currentPrice(), initialPrice, "Price should not change in same block");
    }

    function testMintBelowMinimum() public {
        uint256 minValue = willToken.currentPrice();
        
        vm.prank(bob);
        vm.expectRevert(Will.ValueMismatch.selector);
        willToken.mintFromETH{value: minValue - 1}();
    }

    function testFuzzMintFromETH(uint256 ethAmount) public {
        uint256 minPrice = willToken.currentPrice();
        vm.assume(ethAmount >= minPrice && ethAmount < 1000 ether);
        
        uint256 contractBalanceBefore = address(willToken).balance;
        
        vm.deal(bob, ethAmount);
        vm.prank(bob);
        uint256 minted = willToken.mintFromETH{value: ethAmount}();
        
        assertGt(minted, 0, "Should mint non-zero amount");
        assertEq(willToken.balanceOf(bob), minted);
        assertEq(address(willToken).balance, contractBalanceBefore + ethAmount);
    }

    //==============================================================================
    // Burning Tests
    //==============================================================================

    function testBurn() public {
        // Setup: first mint to get ETH balance
        vm.prank(bob);
        willToken.mintFromETH{value: 5 ether}();
        
        uint256 burnAmount = TEST_AMOUNT;
        uint256 aliceInitialBalance = address(alice).balance;
        
        vm.prank(alice);
        uint256 returned = willToken.burn(burnAmount);
        
        assertGt(returned, 0, "Should return non-zero ETH");
        assertEq(address(alice).balance, aliceInitialBalance + returned);
        assertEq(willToken.balanceOf(alice), INITIAL_MINT - burnAmount);
    }

    function testBurnWithInsufficientBalance() public {
        vm.prank(bob);
        vm.expectRevert(Will.InsufficentBalance.selector);
        willToken.burn(1);
    }

    function testBurnWithNoContractBalance() public {
        vm.prank(alice);
        vm.expectRevert(Will.InsufficentBalance.selector);
        willToken.burn(TEST_AMOUNT);
    }

    //==============================================================================
    // Deconstruct Tests
    //==============================================================================

    function testDeconstructWithETHAndTokens() public {
        // Setup initial balances
        vm.deal(address(willToken), 10 ether);
        token1.mint(address(willToken), 1000 ether);
        token2.mint(address(willToken), 500 ether);
        
        address[] memory tokens = new address[](2);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        
        uint256 aliceInitialBalance = address(alice).balance;
        vm.prank(alice);
        uint256 shareBurned = willToken.deconstructBurn(TEST_AMOUNT, tokens);
        
        assertGt(shareBurned, 0);
        assertGt(address(alice).balance, aliceInitialBalance);
        assertGt(token1.balanceOf(alice), 0);
        assertGt(token2.balanceOf(alice), 0);
    }

function testMultiBlockPriceUpdates() public {
    vm.prank(bob);
    willToken.mintFromETH{value: 2 ether}();
    uint256 price1 = willToken.currentPrice();
    
    vm.roll(block.number + 1);
    vm.prank(charlie);
    willToken.mintFromETH{value: 0.01 ether}();
    
    vm.roll(block.number + 1);
    uint256 price2 = willToken.currentPrice();
    
    assertGt(price2, price1, "Price should increase with supply");
    
    uint256 totalSupplyInGwei = willToken.totalSupply() / 1 gwei;
    assertEq(price2, totalSupplyInGwei, "Price should match total supply in gwei");
}
function testFailedDeconstructBurn() public {
    token1.mint(address(willToken), 1000 ether);
    token1.setTransferShouldRevert(true);
    
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    
    vm.prank(alice);
    vm.expectRevert(
        abi.encodeWithSelector(Will.TransferFailedFor.selector, address(token1))
    );
    willToken.deconstructBurn(TEST_AMOUNT, tokens);
}






}

