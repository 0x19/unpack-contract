// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

/// @custom:security-contact info@unpack.dev
contract UnPack is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");
    bytes32 public constant PRESALER_ROLE = keccak256("PRESALER_ROLE");

    uint256 private taxPercentage; // Tax percentage (default to 3%)
    address private adminAddr; // Address of the admin account
    address private pauserAddr; // Address of the pauser account
    address private developerAddr; // Address of the developer account
    address private presalerAddr; // Address of the presale account
    address private airdropperAddr; // Address of the airdrop account

    // Event declarations
    event Subscribed(address indexed user, uint256 amount);
    event Unsubscribed(address indexed user, uint256 refundAmount);
    event TaxPercentageChanged(uint256 newTaxPercentage);

    struct SubscriberInfo {
        uint256 subscribedAt;
        uint256 lastRewardTime;
        uint256 subscriptionAmount;
    }
    mapping(address => SubscriberInfo) private subscribers;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin, 
        address pauser,
        address developer,
        address presaler,
        address airdroper
        ) initializer public {
        __ERC20_init("UnPack", "UPK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("UnPack");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(AIRDROP_ROLE, airdroper);
        _grantRole(PRESALER_ROLE, presaler);

        taxPercentage = 3; // Default tax percentage
        adminAddr = admin;
        pauserAddr = pauser;
        developerAddr = developer;
        presalerAddr = presaler;
        airdropperAddr = airdroper;
        
        uint256 totalSupply = 1000000000 * 10 ** decimals();
    
        // Distributing the tokens
        _mint(developer, totalSupply * 10 / 100); // 10% to developer
        _mint(presaler, totalSupply * 10 / 100);   // 10% to presale
        _mint(airdroper, totalSupply * 30 / 100);   // 30% to staking
        _mint(admin, totalSupply * 50 / 100); // 50% to general purpose (default admin)
    }


    // Subscribe function with dynamic subscription fee in Ether
    function subscribe() public payable {
        require(subscribers[msg.sender].subscribedAt == 0, "Already subscribed");
        require(msg.value > 0, "Subscription amount must be greater than 0");
        require(balanceOf(msg.sender) >= msg.value, "Insufficient token balance to subscribe");

        payable(developerAddr).transfer(msg.value);
        subscribers[msg.sender] = SubscriberInfo(block.timestamp, block.timestamp, msg.value);

        emit Subscribed(msg.sender, msg.value);
    }

    // Unsubscribe function with refund
    function unsubscribe() public {
        require(subscribers[msg.sender].subscribedAt != 0, "Not subscribed");

        uint256 daysSubscribed = (block.timestamp - subscribers[msg.sender].subscribedAt) / 60 / 60 / 24;
        uint256 refundAmount = calculateRefund(subscribers[msg.sender].subscriptionAmount, daysSubscribed);

        payable(msg.sender).transfer(refundAmount);
        delete subscribers[msg.sender];

        emit Unsubscribed(msg.sender, refundAmount);
    }

    // Calculate the refund amount based on the subscription duration
    function calculateRefund(uint256 subscriptionAmount, uint256 daysSubscribed) private pure returns (uint256) {
        uint256 refundRatePerDay = subscriptionAmount / 30; // Assuming 30-day month for simplicity
        uint256 refundAmount = subscriptionAmount - (refundRatePerDay * daysSubscribed);
        return refundAmount;
    }

    function setTaxPercentage(uint256 _taxPercentage) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_taxPercentage <= 5, "Tax cannot exceed 5%");
        taxPercentage = _taxPercentage;
        emit TaxPercentageChanged(_taxPercentage);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        // List of initialized addresses
        address[] memory exemptAddresses = new address[](2);
        exemptAddresses[1] = pauserAddr; // Replace with actual pauser address variable

        bool isExemptAddress = false;
        for (uint i = 0; i < exemptAddresses.length; i++) {
            if (to == exemptAddresses[i]) {
                isExemptAddress = true;
                break;
            }
        }

        if (from != address(0) && !isExemptAddress) { // Tax only on sell transactions and non-exempt addresses
            uint256 tax = value * taxPercentage / 100;
            uint256 valueAfterTax = value - tax;

            super._update(from, airdropperAddr, tax); // Transfer the tax to the airdrop account
            super._update(from, to, valueAfterTax); // Transfer the remaining amount to the recipient
        } else {
            super._update(from, to, value); // Handle minting, buying, and transfers to exempt addresses normally
        }
    }
}