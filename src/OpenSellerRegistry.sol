// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "./IMarketplaceSellerRegistry.sol";

/**
 * @title OpenSellerRegistry
 * @notice A seller registry that allows everyone by default, with owner-managed blocklist.
 * @dev Implements IMarketplaceSellerRegistry. Any address can sell UNLESS they are on the blocklist.
 *      Only the owner (deployer) can add/remove addresses from the blocklist.
 */
contract OpenSellerRegistry is IMarketplaceSellerRegistry, Ownable {
    /// @dev Mapping of blocklisted addresses
    mapping(address => bool) public blocklisted;

    /// @dev Event emitted when an address is added to blocklist
    event AddressBlocklisted(address indexed account);

    /// @dev Event emitted when an address is removed from blocklist
    event AddressUnblocklisted(address indexed account);

    /**
     * @notice Constructs the OpenSellerRegistry
     * @param _owner The address that will own this registry (can manage blocklist)
     */
    constructor(address _owner) Ownable(_owner) {
        // Owner is set via Ownable constructor
    }

    /**
     * @notice Check if seller is authorized (not blocklisted)
     * @param seller Address of seller to check
     * @return bool True if seller is NOT blocklisted, false otherwise
     */
    function isAuthorized(address seller, bytes calldata /* data */) external view override returns (bool) {
        return !blocklisted[seller];
    }

    /**
     * @notice Add an address to the blocklist
     * @dev Only callable by owner
     * @param account The address to blocklist
     */
    function addToBlocklist(address account) external onlyOwner {
        require(account != address(0), "OpenSellerRegistry: Cannot blocklist zero address");
        require(!blocklisted[account], "OpenSellerRegistry: Already blocklisted");
        
        blocklisted[account] = true;
        emit AddressBlocklisted(account);
        emit SellerRemoved(msg.sender, account);
    }

    /**
     * @notice Add multiple addresses to the blocklist
     * @dev Only callable by owner
     * @param accounts Array of addresses to blocklist
     */
    function addToBlocklistBatch(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            require(account != address(0), "OpenSellerRegistry: Cannot blocklist zero address");
            if (!blocklisted[account]) {
                blocklisted[account] = true;
                emit AddressBlocklisted(account);
                emit SellerRemoved(msg.sender, account);
            }
        }
    }

    /**
     * @notice Remove an address from the blocklist
     * @dev Only callable by owner
     * @param account The address to remove from blocklist
     */
    function removeFromBlocklist(address account) external onlyOwner {
        require(blocklisted[account], "OpenSellerRegistry: Not blocklisted");
        
        blocklisted[account] = false;
        emit AddressUnblocklisted(account);
        emit SellerAdded(msg.sender, account);
    }

    /**
     * @notice Remove multiple addresses from the blocklist
     * @dev Only callable by owner
     * @param accounts Array of addresses to remove from blocklist
     */
    function removeFromBlocklistBatch(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (blocklisted[account]) {
                blocklisted[account] = false;
                emit AddressUnblocklisted(account);
                emit SellerAdded(msg.sender, account);
            }
        }
    }

    /**
     * @notice Check if an address is blocklisted
     * @param account The address to check
     * @return bool True if blocklisted
     */
    function isBlocklisted(address account) external view returns (bool) {
        return blocklisted[account];
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IMarketplaceSellerRegistry).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}

