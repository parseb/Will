// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";
import {SuperchainERC20} from "@contracts-bedrock/L2/SuperchainERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

import {IERC20} from "./interfaces/IERC20.sol";

contract Will is SuperchainERC20 {
    bool private entered;
    uint256 public lastPrice;
    uint256 public lastPriceBlock;

    constructor(address[] memory initMintAddrs_, uint256[] memory initMintAmts_) {
        lastPriceBlock = block.number;
        uint256 initialSupply;
        uint256 i;
        if (initMintAddrs_.length > 0 && initMintAmts_[0] > 0) {
            for (i; i < initMintAddrs_.length; ++i) {
                if (initMintAddrs_[i] == address(0) || initMintAmts_[i] == 0) continue;
                _mint(initMintAddrs_[i], initMintAmts_[i]);
                initialSupply += initMintAmts_[i];
            }
        }
        lastPrice = initialSupply / 1 gwei;
    }

    error TransferFailedFor(address failingToken);
    error InsufficentBalance();
    error PayCallF();
    error Reentrant();
    error ValueMismatch();
    error BurnRefundF();

    event PriceUpdated(uint256 previousPrice, uint256 newPrice);

    function name() public pure override returns (string memory) {
        return "Will";
    }

    function symbol() public pure override returns (string memory) {
        return "WILL";
    }

    function currentPrice() public view returns (uint256) {
        if (block.number > lastPriceBlock) {
            return totalSupply() / 1 gwei;
        }
        return lastPrice;
    }

    function mintFromETH() public payable returns (uint256 howMuchMinted) {
        // Cache the block price for consistent calculations
        uint256 _lastPriceBlock = lastPriceBlock;
        uint256 _currentPrice = lastPrice;

        // Only update price if on a new block
        if (block.number > _lastPriceBlock) {
            uint256 newPrice = totalSupply() / 1 gwei;
            emit PriceUpdated(_currentPrice, newPrice);
            lastPrice = newPrice;
            lastPriceBlock = block.number;
            _currentPrice = newPrice;
        }

        if (msg.value < _currentPrice) revert ValueMismatch();
        howMuchMinted = (msg.value * 1 gwei) / _currentPrice;
        _mint(msg.sender, howMuchMinted);
    }

    function mint(uint256 howMany_) public payable {
        uint256 _currentPrice = lastPrice;
        
        // Only update price if on a new block
        if (block.number > lastPriceBlock) {
            uint256 newPrice = totalSupply() / 1 gwei;
            emit PriceUpdated(_currentPrice, newPrice);
            lastPrice = newPrice;
            lastPriceBlock = block.number;
            _currentPrice = newPrice;
        }

        if (msg.value < mintCost(howMany_)) revert ValueMismatch();
        _mint(msg.sender, howMany_);
    }

    function burn(uint256 howMany_) public returns (uint256 amtValReturned) {
        if (balanceOf(msg.sender) < howMany_) revert InsufficentBalance();
        
        amtValReturned = burnReturns(howMany_);
        if (amtValReturned == 0 || amtValReturned > address(this).balance) revert InsufficentBalance();
        
        _burn(msg.sender, howMany_);

        bool success;
        assembly {
            success := call(gas(), caller(), amtValReturned, 0, 0, 0, 0)
        }
        if (!success) revert BurnRefundF();
        
        return amtValReturned;
    }

    function burnTo(uint256 howMany_, address to_) public returns (uint256 amount) {
        if (balanceOf(msg.sender) < howMany_) revert InsufficentBalance();
        
        amount = burnReturns(howMany_);
        if (amount == 0 || amount > address(this).balance) revert InsufficentBalance();
        
        _burn(msg.sender, howMany_);

        bool success;
        assembly {
            success := call(gas(), to_, amount, 0, 0, 0, 0)
        }
        if (!success) revert BurnRefundF();
        
        return amount;
    }

    function deconstructBurn(uint256 amountToBurn_, address[] memory tokensToRedeem)
        external
        returns (uint256 shareBurned)
    {
        if (entered) revert Reentrant();
        entered = true;

        if (balanceOf(msg.sender) < amountToBurn_) revert InsufficentBalance();

        shareBurned = (amountToBurn_ * 1e18) / totalSupply();
        _burn(msg.sender, amountToBurn_);

        for (uint256 i; i < tokensToRedeem.length;) {
            IERC20 token = IERC20(tokensToRedeem[i]);
            uint256 redeemAmount = (token.balanceOf(address(this)) * shareBurned) / 1e18;
            if (!token.transfer(msg.sender, redeemAmount)) revert TransferFailedFor(tokensToRedeem[i]);
            unchecked {
                ++i;
            }
        }

        uint256 ethAmount = (address(this).balance * shareBurned) / 1e18;
        if (ethAmount == 0 || ethAmount > address(this).balance) revert InsufficentBalance();

        bool success;
        assembly {
            success := call(gas(), caller(), ethAmount, 0, 0, 0, 0)
        }
        if (!success) revert PayCallF();

        entered = false;
    }

    function mintCost(uint256 amt_) public view virtual returns (uint256) {
        return (amt_ * currentPrice()) / 1 gwei;
    }

    function burnReturns(uint256 amt_) public view virtual returns (uint256 rv) {
        if (totalSupply() > 0) {
            rv = (amt_ * address(this).balance) / totalSupply();
        }
    }

    receive() external payable {
        mintFromETH();
    }
}