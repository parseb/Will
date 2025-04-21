// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";
import {SuperchainERC20} from "@contracts-bedrock/L2/SuperchainERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Will is SuperchainERC20 {
    using Strings for uint256;

    bool private entered;
    uint256 public lastPrice;
    uint256 public lastPriceBlock;
    uint256 public lastBlockSupply;

    // Events
    event WillMinted(address indexed to, uint256 amount, uint256 ethValue);
    event WillBurned(address indexed from, uint256 amount, uint256 ethReturned);
    event WillDeconstructBurned(
        address indexed from, 
        uint256 willAmount, 
        uint256 ethAmount
    );
    event PriceUpdated(uint256 newPrice);

    constructor(address[] memory initMintAddrs_, uint256[] memory initMintAmts_) {
        lastPriceBlock = block.number;
        uint256 i;
        if (initMintAddrs_.length > 0 && initMintAmts_[0] > 0) {
            for (i; i < initMintAddrs_.length; ++i) {
                if (initMintAddrs_[i] == address(0) || initMintAmts_[i] == 0) continue;
                _mint(initMintAddrs_[i], initMintAmts_[i]);
            }
        }
        if (totalSupply() == 0) _mint(address(0), 1 ether);
        
        lastPrice = 1 gwei; 
        lastBlockSupply = totalSupply();
    }

    error TransferFailedFor(address failingToken);
    error InsufficentBalance();
    error PayCallF();
    error Reentrant();
    error ValueMismatch();
    error BurnRefundF();
    error InsufficientValue(uint256 required, uint256 provided);

    function name() public pure override returns (string memory) {
        return "Will";
    }

    function symbol() public pure override returns (string memory) {
        return "WILL";
    }

    function _updatePriceIfNewBlock() internal {
        if (block.number > lastPriceBlock) {
            lastPrice = lastBlockSupply / 1 gwei;
            emit PriceUpdated(lastPrice);
            lastPriceBlock = block.number;
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
        lastBlockSupply = totalSupply();
    }

    function currentPrice() public view returns (uint256) {
        if (block.number > lastPriceBlock) {
            return totalSupply() / 1 gwei;
        }
        return lastPrice;
    }

    function mintFromETH() public payable returns (uint256 howMuchMinted) {
        _updatePriceIfNewBlock();
        if (msg.value < lastPrice) revert ValueMismatch();

        howMuchMinted = msg.value / currentPrice() * 1e18;
        _mint(msg.sender, howMuchMinted);
        
        emit WillMinted(msg.sender, howMuchMinted, msg.value);
    }

    function mint(uint256 howMany_) public payable {
        _updatePriceIfNewBlock();

        uint256 required = howMany_ * currentPrice();
        if (msg.value < required) revert InsufficientValue({required: required, provided: msg.value});
        
        _mint(msg.sender, howMany_ * 1e18);
        
        emit WillMinted(msg.sender, howMany_, msg.value);
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

        emit WillBurned(msg.sender, howMany_, amtValReturned);
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

        emit WillBurned(msg.sender, howMany_, amount);
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

        uint256[] memory redeemedAmounts = new uint256[](tokensToRedeem.length);
        for (uint256 i; i < tokensToRedeem.length;) {
            IERC20 token = IERC20(tokensToRedeem[i]);
            uint256 redeemAmount = (token.balanceOf(address(this)) * shareBurned) / 1e18;
            if (!token.transfer(msg.sender, redeemAmount)) revert TransferFailedFor(tokensToRedeem[i]);
            redeemedAmounts[i] = redeemAmount;
            unchecked {
                ++i;
            }
        }

        uint256 ethAmount = (address(this).balance * shareBurned) / 1e18;
        if (ethAmount == 0 || ethAmount >= address(this).balance) revert InsufficentBalance();

        bool success;
        assembly {
            success := call(gas(), caller(), ethAmount, 0, 0, 0, 0)
        }
        if (!success) revert PayCallF();

        emit WillDeconstructBurned(msg.sender, amountToBurn_, ethAmount);

        entered = false;
    }


    //// @note Returns the cost of minting a given amount of tokens
    /// @param amt_ The amount of tokens to mint in full 1e18 units
    /// @return The cost in wei to mint the specified amount of tokens
    function mintCost(uint256 amt_) public view virtual returns (uint256) {
        uint256 price = currentPrice();
        return (amt_ * price);
    }

    function burnReturns(uint256 amt_) public view virtual returns (uint256 rv) {
        if (totalSupply() > 0) rv = (amt_ * address(this).balance) / totalSupply();
    }

    receive() external payable {
        mintFromETH();
    }
}