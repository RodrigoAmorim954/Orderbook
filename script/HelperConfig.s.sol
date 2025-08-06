// //SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    // --- Chains Ids ---
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        address weth;
        address wbtc;
        address dai;
    }

    NetworkConfig public networkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaETHConfig();
    }

    function getSepoliaETHConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9, wbtc: 0xf5c1F61deC83a5994a0cb96d30f8cF7A074B045b, dai: 0x511243992D17992E34125EF1274C7DCA4a94C030});
    }

    function getConfigByChainId(uint256 _chainId) public view returns (NetworkConfig memory) {
        if (networkConfigs[_chainId].weth != address(0) && networkConfigs[_chainId].wbtc != address(0) && networkConfigs[_chainId].dai != address(0)) {
            return networkConfigs[_chainId];
        } else if (_chainId == SEPOLIA_CHAIN_ID) {
            return getSepoliaETHConfig();
        } else {
            return getOrCreaveAnvilConfig();
        }
    }

    function getOrCreaveAnvilConfig() public pure returns (NetworkConfig memory) {
        // Create Some Mocks
    }
}
