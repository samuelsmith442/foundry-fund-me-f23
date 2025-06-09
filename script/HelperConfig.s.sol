// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title HelperConfig
 * @author Patrick Collins (GitHub: @PatrickAlphaC)
 * @dev From https://github.com/Cyfrin/foundry-fund-me-f23
 * @notice This contract is used to manage network configurations for different environments.
 * @dev This contract provides price feed addresses for different networks:
 *      - For Sepolia testnet: Uses the actual Chainlink ETH/USD price feed address
 *      - For local development (Anvil): Deploys a mock price feed contract
 *      This approach allows the same deployment script to work across different networks.
 */
import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    // The active network configuration that will be used by the deployment script
    NetworkConfig public activeNetworkConfig;

    // Constants for the mock price feed
    uint8 public constant DECIMALS = 8; // Number of decimals for the price feed
    int256 public constant INITIAL_PRICE = 2000e8; // Initial ETH/USD price (2000 USD with 8 decimals)

    /**
     * @dev Struct to hold network-specific configuration
     * @param priceFeed The address of the ETH/USD price feed contract for the network
     */
    struct NetworkConfig {
        address priceFeed;
    }

    /**
     * @notice Constructor that sets the active network configuration based on the current chain ID
     * @dev Uses chain ID to determine whether to use Sepolia testnet or local Anvil configuration
     *      - 11155111: Sepolia testnet
     *      - Any other chain ID: Assumed to be local Anvil chain
     */
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    /**
     * @notice Returns the configuration for Sepolia testnet
     * @dev Uses the actual Chainlink ETH/USD price feed address on Sepolia
     * @return NetworkConfig The Sepolia network configuration
     */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306});
        return sepoliaConfig;
    }

    /**
     * @notice Returns or creates a configuration for local Anvil development
     * @dev If a configuration already exists, returns it; otherwise deploys a mock price feed
     * @return NetworkConfig The Anvil network configuration with a mock price feed address
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // If we already have a price feed configured, return the existing config
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }

        // Deploy a mock price feed for local testing
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();

        // Create and return the Anvil configuration with the mock price feed
        NetworkConfig memory anvilConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});
        return anvilConfig;
    }
}
