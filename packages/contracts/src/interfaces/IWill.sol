// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IWill {
    /// @notice Emitted when the price is updated
    event PriceUpdated(uint256 previousPrice, uint256 newPrice);

    /// @notice Custom error for failed transfers
    error TransferFailedFor(address failingToken);

    /// @notice Custom error for insufficient balance
    error InsufficentBalance();

    /// @notice Custom error for payment call failures
    error PayCallF();

    /// @notice Custom error for reentrancy protection
    error Reentrant();

    /// @notice Custom error for value mismatches
    error ValueMismatch();

    /// @notice Custom error for burn refund failures
    error BurnRefundF();

    /// @notice Burns amount of token and retrieves underlying value as well as corresponding share of specified tokens
    /// @param amountToBurn_ Amount of tokens to burn
    /// @param tokensToRedeem Array of token addresses to redeem
    /// @return shareBurned Proportion of tokens burned
    function deconstructBurn(uint256 amountToBurn_, address[] memory tokensToRedeem)
        external
        returns (uint256 shareBurned);

    /// @notice Mints tokens using ETH
    /// @return howMuchMinted Amount of tokens minted
    function mintFromETH() external payable returns (uint256 howMuchMinted);

    /// @notice Mints new tokens
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

    /// @notice Returns the last price update block
    /// @return The block number of the last price update
    function lastPriceBlock() external view returns (uint256);

    /// @notice Returns the last recorded price
    /// @return The last recorded price
    function lastPrice() external view returns (uint256);
}
