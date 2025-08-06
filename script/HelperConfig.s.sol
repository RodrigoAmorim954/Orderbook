// //SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

abstract contract CodeConstants {
    // --- Chains Ids ---
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChain();

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

    function getConfigByChainId(uint256 _chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[_chainId].weth != address(0) && networkConfigs[_chainId].wbtc != address(0) && networkConfigs[_chainId].dai != address(0)) {
            return networkConfigs[_chainId];
        } else if (_chainId == LOCAL_CHAIN_ID) {
            return networkConfigs[LOCAL_CHAIN_ID] = getOrCreaveAnvilConfig();
        } else {
            revert HelperConfig__InvalidChain();
        }
    }

    function getOrCreaveAnvilConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[LOCAL_CHAIN_ID].weth != address(0)) {
            return networkConfigs[LOCAL_CHAIN_ID];
        } else {
            vm.startBroadcast();

            ERC20Mock dai = new ERC20Mock("Dai", "Dai"); // 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
            ERC20Mock wbtc = new ERC20Mock("Mock Wrapped BTC", "WBtc"); // 0x90193C961A926261B756D1E5bb255e67ff9498A1
            ERC20Mock weth = new ERC20Mock("Mock Wrapped ETH", "WEth"); // 0x34A1D3fff3958843C43aD80F30b94c510645C316
            vm.stopBroadcast();

            return NetworkConfig({weth: address(weth), wbtc: address(wbtc), dai: address(dai)});
        }
    }
}
