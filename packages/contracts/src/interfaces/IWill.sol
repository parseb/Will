// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.3;

import {IERC20ASG} from "ERC20ASG/src/IERC20ASG.sol";

interface IWill is IERC20ASG {
    /// @notice burns amount of token and retrieves underlying value as well as corresponding share of specified tokens
    ///
    function deconstructBurn(uint256 amountToBurn_, address[] memory tokensToRedeem)
        external
        returns (uint256 shareBurned);

    function simpleBurn(uint256 amountToBurn_) external returns (uint256 amtValReturned);

    function mintFromETH() external payable returns (uint256 howMuchMinted);

    /// @notice Mints new tokens
    /// @notice Value calculation required
    /// @param howMany_ The amount of tokens to mint
    function mint(uint256 howMany_) external payable;

    /// @notice Burns tokens and returns ETH
    /// @param howMany_ The amount of tokens to burn
    /// @return amtValReturned The amount of ETH returned
    function burn(uint256 howMany_) external returns (uint256 amtValReturned);

    /// @notice Burns tokens and sends ETH to a specified address
    /// @param howMany_ The amount of tokens to burn
    /// @param to_ The address to send the ETH to
    /// @return amount The amount of ETH sent
    function burnTo(uint256 howMany_, address to_) external returns (uint256 amount);

    /// @notice Calculates the cost to mint a given amount of tokens
    /// @param amt_ The amount of tokens to mint
    /// @return The cost in ETH to mint the specified amount
    function mintCost(uint256 amt_) external view returns (uint256);

    /// @notice Calculates the amount of ETH that would be returned for burning a given amount of tokens
    /// @param amt_ The amount of tokens to burn
    /// @return rv The amount of ETH that would be returned
    function burnReturns(uint256 amt_) external view returns (uint256 rv);

    /// @notice Returns the current price per token
    /// @return The current price per token
    function currentPrice() external view returns (uint256);

    /// @notice Returns the timestamp when the contract was initialized
    /// @return The initialization timestamp
    function initTime() external view returns (uint256);

    /// @notice Returns the price increase per second
    /// @return The price increase per second in wei
    function pps() external view returns (uint256);
}
