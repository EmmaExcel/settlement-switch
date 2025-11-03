// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, ERC20Permit, Ownable {
    uint8 private _decimals;
    bool public transfersEnabled = true;
    bool public approvalsEnabled = true;
    bool public permitEnabled = true;
    
    // Configurable failure modes for testing
    mapping(address => bool) public blacklisted;
    mapping(address => uint256) public transferDelay; // Delay in seconds
    mapping(address => uint256) public lastTransferTime;
    
    uint256 public transferFee; // Fee in basis points (0-10000)
    address public feeRecipient;
    
    // Events
    event TransfersToggled(bool enabled);
    event ApprovalsToggled(bool enabled);
    event PermitToggled(bool enabled);
    event AddressBlacklisted(address indexed account, bool blacklisted);
    event TransferFeeUpdated(uint256 fee, address recipient);

    // Errors
    error TransfersDisabled();
    error ApprovalsDisabled();
    error PermitDisabled();
    error AddressBlacklistedError();
    error TransferDelayNotMet();
    error InsufficientBalanceAfterFee();

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(msg.sender) {
        _decimals = decimals_;
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function transfer(address to, uint256 value) public override returns (bool success) {
        _checkTransferConditions(msg.sender, to, value);
        
        uint256 fee = _calculateFee(value);
        uint256 netAmount = value - fee;
        
        if (fee > 0 && feeRecipient != address(0)) {
            super.transfer(feeRecipient, fee);
        }
        
        return super.transfer(to, netAmount);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool success) {
        _checkTransferConditions(from, to, value);
        
        uint256 fee = _calculateFee(value);
        uint256 netAmount = value - fee;
        
        if (fee > 0 && feeRecipient != address(0)) {
            super.transferFrom(from, feeRecipient, fee);
        }
        
        return super.transferFrom(from, to, netAmount);
    }

    function approve(address spender, uint256 value) public override returns (bool success) {
        if (!approvalsEnabled) revert ApprovalsDisabled();
        if (blacklisted[msg.sender] || blacklisted[spender]) revert AddressBlacklistedError();
        
        return super.approve(spender, value);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        if (!permitEnabled) revert PermitDisabled();
        if (blacklisted[owner] || blacklisted[spender]) revert AddressBlacklistedError();
        
        super.permit(owner, spender, value, deadline, v, r, s);
    }

    function _checkTransferConditions(address from, address to, uint256 value) internal {
        if (!transfersEnabled) revert TransfersDisabled();
        if (blacklisted[from] || blacklisted[to]) revert AddressBlacklistedError();
        
        // Check transfer delay
        if (transferDelay[from] > 0) {
            if (block.timestamp < lastTransferTime[from] + transferDelay[from]) {
                revert TransferDelayNotMet();
            }
        }
        
        // Check balance after fee
        uint256 fee = _calculateFee(value);
        if (balanceOf(from) < value + fee) {
            revert InsufficientBalanceAfterFee();
        }
        
        // Update last transfer time
        lastTransferTime[from] = block.timestamp;
    }

    function _calculateFee(uint256 amount) internal view returns (uint256 fee) {
        if (transferFee == 0) return 0;
        return (amount * transferFee) / 10000;
    }

    // Admin functions

    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        emit TransfersToggled(enabled);
    }

    function setApprovalsEnabled(bool enabled) external onlyOwner {
        approvalsEnabled = enabled;
        emit ApprovalsToggled(enabled);
    }

    function setPermitEnabled(bool enabled) external onlyOwner {
        permitEnabled = enabled;
        emit PermitToggled(enabled);
    }

    function setBlacklisted(address account, bool isBlacklisted) external onlyOwner {
        blacklisted[account] = isBlacklisted;
        emit AddressBlacklisted(account, isBlacklisted);
    }

    function setTransferDelay(address account, uint256 delay) external onlyOwner {
        transferDelay[account] = delay;
    }

    function setTransferFee(uint256 fee, address recipient) external onlyOwner {
        require(fee <= 10000, "Fee too high");
        transferFee = fee;
        feeRecipient = recipient;
        emit TransferFeeUpdated(fee, recipient);
    }

    function setTransferFailure(bool shouldFail) external onlyOwner {
        transfersEnabled = !shouldFail;
    }

    function getEffectiveBalance(address account) external view returns (uint256 effectiveBalance) {
        uint256 balance = balanceOf(account);
        if (transferFee == 0) return balance;
        
        // Calculate maximum transferable amount considering fees
        return (balance * 10000) / (10000 + transferFee);
    }

    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Array length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    function expensiveTransfer(
        address to,
        uint256 value,
        uint256 gasWaste
    ) external returns (bool success) {
        // Waste gas for testing
        for (uint256 i = 0; i < gasWaste; i++) {
            keccak256(abi.encodePacked(i, block.timestamp));
        }
        
        return transfer(to, value);
    }

    function createPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 privateKey
    ) external view returns (uint8 v, bytes32 r, bytes32 s) {
        // Simplified for testing - in real tests, use proper cryptographic libraries
        bytes32 hash = keccak256(abi.encodePacked(owner, spender, value, deadline, privateKey));
        return (27, hash, bytes32(privateKey));
    }

    function forceTransfer(address from, address to, uint256 value) external onlyOwner {
        _transfer(from, to, value);
    }

    function getTokenInfo() external view returns (
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 totalSupply,
        bool transfersActive,
        bool approvalsActive,
        bool permitActive
    ) {
        return (
            name(),
            symbol(),
            decimals(),
            super.totalSupply(),
            transfersEnabled,
            approvalsEnabled,
            permitEnabled
        );
    }
}