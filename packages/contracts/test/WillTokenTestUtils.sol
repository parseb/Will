// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "@openzeppelin/contracts-v5/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {Will} from "src/Will.sol";


/// @title WillTokenTestUtils
/// @notice Utilities and mocks for testing Will token contract
contract WillTokenTestUtils is Test {
    /// @notice Helper to create addresses with ETH balance
    function createUserWithBalance(string memory label, uint256 balance) public returns (address) {
        address user = makeAddr(label);
        vm.deal(user, balance);
        return user;
    }
    
    /// @notice Helper to mock multiple token balances
    function mockTokenBalances(address[] memory tokens, address holder, uint256[] memory amounts) public {
        require(tokens.length == amounts.length, "Length mismatch");
        for(uint256 i = 0; i < tokens.length; i++) {
            MockERC20(tokens[i]).mint(holder, amounts[i]);
        }
    }
}

/// @notice Mock ERC20 token for testing
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    bool public transferShouldRevert;
    bool public mintShouldRevert;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function setTransferShouldRevert(bool shouldRevert) external {
        transferShouldRevert = shouldRevert;
    }

    function setMintShouldRevert(bool shouldRevert) external {
        mintShouldRevert = shouldRevert;
    }

    function mint(address to, uint256 amount) public {
        require(!mintShouldRevert, "Mint reverted");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public {
        _totalSupply -= amount;
        _balances[from] -= amount;
        emit Transfer(from, address(0), amount);
    }

    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return 18; }
    function totalSupply() public view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view returns (uint256) { return _balances[account]; }
    function allowance(address owner, address spender) public view returns (uint256) { return _allowances[owner][spender]; }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(!transferShouldRevert, "Transfer reverted");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(!transferShouldRevert, "Transfer reverted");
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}