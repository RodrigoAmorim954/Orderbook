//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// --- Imports ---
import {OrderBook} from "../src/OrderBook.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployOrderBook is Script {
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    address dai;

    function run() external returns (HelperConfig, OrderBook) {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);

        (weth, wbtc, dai) = (config.weth, config.wbtc, config.dai);

        // Initialize the tokens and give approval (how do that?)

        vm.startBroadcast();
        OrderBook orderBook = new OrderBook(msg.sender, weth, wbtc, dai);
        vm.stopBroadcast();

        return (helperConfig, orderBook);
    }
}
