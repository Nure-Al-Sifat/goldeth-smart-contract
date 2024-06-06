// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title GoldEth Token
 * @dev ERC20 Token with transfer fee that burns and redistributes a portion of the transfer amount.
 */
contract GoldEth is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAXIMUM_SUPPLY = 500_000_000 * 10 ** 18;
    address public feeRecipient; // Address to receive the fee
    uint256 public constant TRANSFER_FEE_RATE = 10; // 10%
    uint256 public constant BURN_RATE = 50; // 50% of the transfer fee (which is 5% of total transfer amount)

    mapping(address => bool) private _controllers;

    event FeeRecipientChanged(
        address indexed previousRecipient,
        address indexed newRecipient
    );
    event ControllerAdded(address indexed controller);
    event ControllerRemoved(address indexed controller);

    /**
     * @dev Constructor that sets the initial supply and initializes the token details.
     */
    constructor(
        address _feeRecipient
    ) ERC20("GoldEth", "GETH") Ownable(msg.sender) {
        require(
            _feeRecipient != address(0),
            "GoldEth: feeRecipient is the zero address"
        );
        feeRecipient = _feeRecipient;
        _mint(msg.sender, MAXIMUM_SUPPLY);
    }

    /**
     * @dev Overrides the ERC20 transfer function to include a transfer fee.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens being transferred.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transferWithFee(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Overrides the ERC20 transferFrom function to include a transfer fee.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens being transferred.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = allowance(sender, _msgSender());
        require(
            currentAllowance >= amount,
            "GoldEth: transfer amount exceeds allowance"
        );
        _approve(sender, _msgSender(), currentAllowance - amount);
        _transferWithFee(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Internal function to handle transfer logic with fee.
     * @param sender The address sending tokens.
     * @param recipient The address receiving tokens.
     * @param amount The amount of tokens being transferred.
     */
    function _transferWithFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(
            sender != address(0),
            "GoldEth: transfer from the zero address"
        );
        require(
            recipient != address(0),
            "GoldEth: transfer to the zero address"
        );

        uint256 feeAmount = (amount * TRANSFER_FEE_RATE) / 100;
        uint256 burnAmount = (feeAmount * BURN_RATE) / 100;
        uint256 feeRecipientAmount = feeAmount - burnAmount;
        uint256 transferAmount = amount - feeAmount;

        if (burnAmount > 0) {
            _burn(sender, burnAmount);
        }

        if (feeRecipientAmount > 0) {
            super._transfer(sender, feeRecipient, feeRecipientAmount);
        }

        super._transfer(sender, recipient, transferAmount);
    }

    /**
     * @dev Sets a new fee recipient address.
     * @param newFeeRecipient The address of the new fee recipient.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(
            newFeeRecipient != address(0),
            "GoldEth: new feeRecipient is the zero address"
        );
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /**
     * @dev Function to mint tokens.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external {
        require(_controllers[msg.sender], "GoldEth: Only controllers can mint");
        require(
            totalSupply() + amount <= MAXIMUM_SUPPLY,
            "GoldEth: Maximum supply reached"
        );
        _mint(to, amount);
    }

    /**
     * @dev Adds a new controller.
     * @param controller The address of the new controller.
     */
    function addController(address controller) external onlyOwner {
        require(
            controller != address(0),
            "GoldEth: controller is the zero address"
        );
        _controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    /**
     * @dev Removes an existing controller.
     * @param controller The address of the controller to remove.
     */
    function removeController(address controller) external onlyOwner {
        require(_controllers[controller], "GoldEth: controller does not exist");
        _controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    /**
     * @dev Returns true if the address is a controller, and false otherwise.
     * @param controller The address to check.
     */
    function isController(address controller) external view returns (bool) {
        return _controllers[controller];
    }
}
