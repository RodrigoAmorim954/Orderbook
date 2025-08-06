//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {OrderBook} from "../../src/OrderBook.sol";
import {DeployOrderBook} from "../../script/DeployOrderBook.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract OrderBookTest is Test {
    // --- Contracts ---
    HelperConfig helperConfig;
    OrderBook orderBook;
    DeployOrderBook deployer;

    // --- Events ---
    event OrderCreated(uint256 indexed orderId, address indexed seller, address indexed tokenToSell, uint256 amountToSell, uint256 priceInUSD, uint256 deadlineTimeStamp);
    event OrderAmended(uint256 indexed orderId, uint256 indexed amountToSell, uint256 indexed priceInUsd, uint256 deadlineTimeStamp);
    event OrderCancelled(uint256 indexed orderId);
    event OrderExpired(uint256 indexed orderId);
    event OrderFulfilled(uint256 indexed orderId, address indexed buyer, address indexed seller, address tokenToSell, uint256 amountToBuy);
    event FeesWithdrawn(address indexed to, address indexed tokenToWithdraw, uint256 indexedamountToWithdraw);
    event TokenAllowed(address indexed TokenAllowed, string indexed tokenSymbol);

    // --- Accounts ---
    address buyer = makeAddr("buyer");
    address seller = makeAddr("seller");
    address another = makeAddr("another");
    uint256 public constant INTIAL_ETH_BALANCE = 100 ether;

    // --- Tokens ---
    address weth;
    address wbtc;
    address dai;
    address solana;

    function setUp() public {
        deployer = new DeployOrderBook();
        (helperConfig, orderBook) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);

        (weth, wbtc, dai) = (config.weth, config.wbtc, config.dai);

        // Minting for the buyer
        ERC20Mock(weth).mint(buyer, INTIAL_ETH_BALANCE);
        ERC20Mock(wbtc).mint(buyer, 10 ether);
        ERC20Mock(dai).mint(buyer, 10000 ether);

        // Minting for the Seller
        ERC20Mock(weth).mint(seller, INTIAL_ETH_BALANCE);
        ERC20Mock(wbtc).mint(seller, 10 ether);
        ERC20Mock(dai).mint(seller, 10000 ether);

        ERC20Mock(dai).mint(another, 1 ether);

        // Testing new token
        vm.startBroadcast();
        ERC20Mock solMock = new ERC20Mock("Sol", "Sol");
        vm.stopBroadcast();
        solana = address(solMock);

        ERC20Mock(solMock).mint(seller, 10 ether);
    }

    // --- Constructor Checks ---
    function testIfTokenAndSymbolAddressAreInitializedCorrectly() public view {
        (address expectedWEth, string memory expectedEthSymbol) = orderBook.getTokenAddressAndSymbol(0);
        (address expectedWbtc, string memory expectedBtcSymbol) = orderBook.getTokenAddressAndSymbol(1);
        (address expectedDai, string memory expectedDaiSymbol) = orderBook.getTokenAddressAndSymbol(2);

        assertEq(weth, expectedWEth);
        assertEq(expectedEthSymbol, "WETH");

        assertEq(wbtc, expectedWbtc);
        assertEq(expectedBtcSymbol, "WBTC");

        assertEq(dai, expectedDai);
        assertEq(expectedDaiSymbol, "DAI");
    }

    // --- Create Sell Order ---
    function testIfRevertsWhentryingToUseAnInvalidToken() public {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidTokenAddress.selector);
        orderBook.createSellOrder(address(0), 1 ether, 2000 ether, 60);
    }

    function testIfRevertsWhenTryingToSellInvalidAmount() public {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidAmount.selector);
        orderBook.createSellOrder(weth, 0 ether, 2000 ether, 60);
    }

    function testIfRevertsWhenTryingToSellInvalidDeadline() public {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidDeadline.selector);
        orderBook.createSellOrder(weth, 1 ether, 2000 ether, 150);
    }

    function testIfRevertsWhenTryingToSellInvalidPrice() public {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidPrice.selector);
        orderBook.createSellOrder(weth, 1 ether, 0, 60);
    }

    function testIfCreateSellOrderIsWorking() public {
        uint256 sellerInitialBalance = ERC20Mock(weth).balanceOf(seller);
        uint256 orderBookInitialBalance = ERC20Mock(weth).balanceOf(address(orderBook));

        vm.startPrank(seller);
        ERC20Mock(weth).approve(address(orderBook), type(uint256).max);

        // Emits Correctly the event

        vm.expectEmit(true, true, true, true, address(orderBook));
        emit OrderCreated(1, seller, weth, 1 ether, 2000 ether, 40);
        orderBook.createSellOrder(weth, 1 ether, 2000 ether, 40);
        vm.stopPrank();

        uint256 orderBookFinalBalance = ERC20Mock(weth).balanceOf(address(orderBook));
        uint256 sellerFinalBalance = ERC20Mock(weth).balanceOf(seller);

        OrderBook.Order memory order = orderBook.getOrderDetails(1);

        assertEq(order.seller, seller);
        assertEq(order.tokenToSell, weth);
        assertEq(order.amountToSell, 1 ether);
        assertEq(order.priceInUSD, 2000 ether);
        assertEq(order.deadlineTimeStamp, 40 + block.timestamp);
        assertEq(order.isActive, true);

        assertEq(orderBookFinalBalance, orderBookInitialBalance + 1 ether);
        assertEq(sellerFinalBalance, sellerInitialBalance - 1 ether);
    }

    modifier orderCreated() {
        vm.startPrank(seller);
        ERC20Mock(weth).approve(address(orderBook), type(uint256).max);
        orderBook.createSellOrder(weth, 1 ether, 2000 ether, 40);
        vm.stopPrank();
        _;
    }

    // --- Amend Sell Order ---
    function testIfRevertsWhenTryingToAmendInvalidAmount() public orderCreated {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidAmount.selector);
        orderBook.amendSellOrder(1, 0 ether, 1 ether, true, 45);
    }

    function testIfRevertsWhenTryingToAmendInvalidOrderId() public orderCreated {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidOrder.selector);
        orderBook.amendSellOrder(2, 0 ether, 1 ether, true, 45);
    }

    function testIfRevertsWhenTryingToAmendInvalidPrice() public orderCreated {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidPrice.selector);
        orderBook.amendSellOrder(1, 10 ether, 0 ether, true, 45);
    }

    function testIfRevertsWhenTryingToAmendInvalidDeadline() public orderCreated {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidDeadline.selector);
        orderBook.amendSellOrder(1, 10 ether, 1 ether, true, 150);
    }

    function testIfRevertsWhenTryngToAmendIfAnotherUser() public orderCreated {
        vm.prank(buyer);
        vm.expectRevert(OrderBook.OrderBook__InvalidSender.selector);
        orderBook.amendSellOrder(1, 10 ether, 1 ether, true, 45);
    }

    function testIfAmendSellOrderIsWorkingUpdatingTheOrderIfABiggerValue() public orderCreated {
        uint256 sellerInitialBalance = ERC20Mock(weth).balanceOf(seller); // Initial Seller ballance is 100 - 1 ether = 99 ether
        uint256 orderBookInitialBalance = ERC20Mock(weth).balanceOf(address(orderBook)); // Inital OrderBook ballance is 1 ether

        vm.startPrank(seller);
        vm.expectEmit(true, true, true, true, address(orderBook));
        emit OrderAmended(1, 5 ether, 9000 ether, 45);
        orderBook.amendSellOrder(1, 5 ether, 9000 ether, true, 45);
        vm.stopPrank();

        OrderBook.Order memory order = orderBook.getOrderDetails(1);
        assertEq(order.amountToSell, 5 ether);
        assertEq(order.priceInUSD, 9000 ether);
        assertEq(order.deadlineTimeStamp, 45 + block.timestamp);
        assertEq(order.isActive, true);

        uint256 sellerFinalBalance = ERC20Mock(weth).balanceOf(seller);
        uint256 orderBookFinalBalance = ERC20Mock(weth).balanceOf(address(orderBook));
        assertEq(sellerFinalBalance, sellerInitialBalance - 4 ether);
        assertEq(orderBookFinalBalance, orderBookInitialBalance + 4 ether);
    }

    function testIfAmendSellOrderIsWorkingUpdatingTheOrderIfASmallerValue() public orderCreated {
        uint256 sellerInitialBalance = ERC20Mock(weth).balanceOf(seller); // Initial Seller ballance is 100 - 1 ether = 99 ether
        uint256 orderBookInitialBalance = ERC20Mock(weth).balanceOf(address(orderBook)); // Inital OrderBook ballance is 1 ether

        vm.prank(seller);
        orderBook.amendSellOrder(1, 0.5 ether, 1500 ether, true, 45);

        OrderBook.Order memory order = orderBook.getOrderDetails(1);
        assertEq(order.amountToSell, 0.5 ether);
        assertEq(order.priceInUSD, 1500 ether);
        assertEq(order.deadlineTimeStamp, 45 + block.timestamp);
        assertEq(order.isActive, true);

        uint256 sellerFinalBalance = ERC20Mock(weth).balanceOf(seller);
        uint256 orderBookFinalBalance = ERC20Mock(weth).balanceOf(address(orderBook));
        assertEq(sellerFinalBalance, sellerInitialBalance + 0.5 ether);
        assertEq(orderBookFinalBalance, orderBookInitialBalance - 0.5 ether);
    }

    function testIfFailsWhenTryToAmendSellOrderIfTheOrderIsNotActive() public orderCreated {
        vm.startPrank(seller);
        orderBook.cancelSellOrder(1);
        vm.expectRevert(OrderBook.OrderBook__OrderInactive.selector);
        orderBook.amendSellOrder(1, 0.5 ether, 1500 ether, true, 45);
        vm.stopPrank();
    }

    // --- Cancel Order ---

    function testIfRevertsWhenTryingToCancelInvalidOrderId() public orderCreated {
        vm.prank(seller);
        vm.expectRevert(OrderBook.OrderBook__InvalidOrder.selector);
        orderBook.cancelSellOrder(2);
    }

    function testIfRevertsWhenTryingToCancelIfAnotherUser() public orderCreated {
        vm.prank(buyer);
        vm.expectRevert(OrderBook.OrderBook__InvalidSender.selector);
        orderBook.cancelSellOrder(1);
    }

    function testIfCancelAOrderWorks() public orderCreated {
        uint256 orderBookInitialBalance = ERC20Mock(weth).balanceOf(address(orderBook)); // 1 ether
        uint256 sellerInitialBalance = ERC20Mock(weth).balanceOf(seller); // 99 ether

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, false, address(orderBook));
        emit OrderCancelled(1);
        orderBook.cancelSellOrder(1);
        vm.stopPrank();

        OrderBook.Order memory order = orderBook.getOrderDetails(1);
        assertEq(order.isActive, false);

        uint256 orderBookFinalBalance = ERC20Mock(weth).balanceOf(address(orderBook));
        uint256 sellerFinalBalance = ERC20Mock(weth).balanceOf(seller);
        assertEq(orderBookFinalBalance, orderBookInitialBalance - 1 ether);
        assertEq(sellerFinalBalance, sellerInitialBalance + 1 ether);
    }

    // --- Buy Order ---

    function testIfRevertsWhenTryingToBuyInvalidOrderId() public orderCreated {
        vm.startPrank(buyer);
        ERC20Mock(dai).approve(address(orderBook), type(uint256).max);
        vm.expectRevert(OrderBook.OrderBook__InvalidOrder.selector);
        orderBook.buyOrder(2);
        vm.stopPrank();
    }

    function testIfRevertsWhenTryingToBuyInactiveOrder() public orderCreated {
        vm.prank(seller);
        orderBook.cancelSellOrder(1);

        vm.startPrank(buyer);
        ERC20Mock(dai).approve(address(orderBook), type(uint256).max);
        vm.expectRevert(OrderBook.OrderBook__OrderInactive.selector);
        orderBook.buyOrder(1);
        vm.stopPrank();
    }

    function testIfRevertsWhenTryingToBuyOrderWithInsufficientFunds() public orderCreated {
        vm.startPrank(another);
        ERC20Mock(dai).approve(address(orderBook), 1 ether);
        vm.expectRevert(OrderBook.OrderBook__InsufficientFunds.selector);
        orderBook.buyOrder(1);
        vm.stopPrank();
    }

    function testIfCanBuyOrderIfTimeExpired() public orderCreated {
        uint256 orderBookInitialBalance = ERC20Mock(weth).balanceOf(address(orderBook)); // 1 ether
        // uint256 sellerInitialBalance = ERC20Mock(weth).balanceOf(seller); // 99 ether

        vm.warp(block.timestamp + 61);
        vm.startPrank(buyer);
        ERC20Mock(dai).approve(address(orderBook), type(uint256).max);
        vm.expectEmit(true, false, false, false, address(orderBook));
        emit OrderExpired(1);
        orderBook.buyOrder(1);
        vm.stopPrank();

        OrderBook.Order memory order = orderBook.getOrderDetails(1);
        assertEq(order.isActive, false);

        uint256 orderBookFinalBalance = ERC20Mock(weth).balanceOf(address(orderBook));
        uint256 sellerFinalBalance = ERC20Mock(weth).balanceOf(seller);
        assertEq(orderBookFinalBalance, orderBookInitialBalance - 1 ether);
        assertEq(sellerFinalBalance, INTIAL_ETH_BALANCE);
    }

    function testIfCanBuyOrderEmitsEventAndFeesAreCorrect() public orderCreated {
        uint256 sellerInitialDaiBalance = ERC20Mock(dai).balanceOf(seller); // 10000
        uint256 buyerInitialEthBalance = ERC20Mock(weth).balanceOf(buyer); // 100 ether
        uint256 buyerInitialDaiBalance = ERC20Mock(dai).balanceOf(buyer); // 10000

        OrderBook.Order memory order = orderBook.getOrderDetails(1);

        vm.startPrank(buyer);
        ERC20Mock(dai).approve(address(orderBook), type(uint256).max);
        vm.expectEmit(true, true, true, true, address(orderBook));
        emit OrderFulfilled(1, buyer, order.seller, order.tokenToSell, order.amountToSell);
        orderBook.buyOrder(1);
        vm.stopPrank();

        order = orderBook.getOrderDetails(1);
        assertEq(order.isActive, false);

        uint256 feesInCrypto = (order.amountToSell * orderBook.getFeeValue()) / orderBook.getPrecision();
        uint256 feesInDai = (order.priceInUSD * orderBook.getFeeValue()) / orderBook.getPrecision();

        uint256 orderBookFinalEthBalance = ERC20Mock(weth).balanceOf(address(orderBook));
        uint256 orderBookFinalDaiBalance = ERC20Mock(dai).balanceOf(address(orderBook));
        uint256 sellerFinalDaiBalance = ERC20Mock(dai).balanceOf(seller);
        uint256 buyerFinalEthBalance = ERC20Mock(weth).balanceOf(buyer);
        uint256 buyerFinalDaiBalance = ERC20Mock(dai).balanceOf(buyer);

        assertEq(orderBookFinalEthBalance, feesInCrypto);
        assertEq(orderBookFinalDaiBalance, feesInDai);
        assertEq(sellerFinalDaiBalance, sellerInitialDaiBalance + order.priceInUSD - feesInDai);
        assertEq(buyerFinalDaiBalance, buyerInitialDaiBalance - order.priceInUSD);
        assertEq(buyerFinalEthBalance, buyerInitialEthBalance + order.amountToSell - feesInCrypto);
    }

    modifier orderFulfilled() {
        vm.startPrank(seller);
        ERC20Mock(weth).approve(address(orderBook), type(uint256).max);
        orderBook.createSellOrder(weth, 1 ether, 2000 ether, 40);
        vm.stopPrank();
        vm.startPrank(buyer);
        ERC20Mock(dai).approve(address(orderBook), type(uint256).max);
        orderBook.buyOrder(1);
        vm.stopPrank();
        _;
    }

    // --- WithdrawFees ---
    function testWithdrawIfInvalidAmount() public orderFulfilled {
        vm.startPrank(orderBook.getOwner());
        vm.expectRevert(OrderBook.OrderBook__InvalidWithdrawAmount.selector);
        orderBook.withdrawFees(buyer, 10 ether, wbtc);
        vm.stopPrank();
    }

    function testWithdrawIfAmountIsLessThenFess() public orderFulfilled {
        vm.startPrank(orderBook.getOwner());
        vm.expectRevert(OrderBook.OrderBook__InvalidWithdrawAmount.selector);
        orderBook.withdrawFees(buyer, 3 ether, weth);
        vm.stopPrank();
    }

    function testWithdrawIfIsSentToAddressZero() public orderFulfilled {
        vm.startPrank(orderBook.getOwner());
        vm.expectRevert(OrderBook.OrderBook__InvalidAddress.selector);
        orderBook.withdrawFees(address(0), 0.02 ether, weth);
        vm.stopPrank();
    }

    function testWithdrawFeesCorrectly() public orderFulfilled {
        uint256 anotherInitialEthBalance = ERC20Mock(weth).balanceOf(another);
        // uint256 totalInitialEthFees = orderBook.getTotalFees(weth);
        uint256 totalInitialDaiFees = orderBook.getTotalFees(dai);

        vm.startPrank(orderBook.getOwner());
        vm.expectEmit(true, true, true, false, address(orderBook));
        emit FeesWithdrawn(another, weth, 0.02 ether);
        orderBook.withdrawFees(another, 0.02 ether, weth);
        vm.stopPrank();

        uint256 anotherFinalEthBalance = ERC20Mock(weth).balanceOf(another);
        uint256 totalFinalEthFees = orderBook.getTotalFees(weth);
        uint256 totalFinalDaiFees = orderBook.getTotalFees(dai);
        assertEq(anotherFinalEthBalance, anotherInitialEthBalance + 0.02 ether);
        assertEq(totalFinalEthFees, 0);
        assertEq(totalFinalDaiFees, totalInitialDaiFees);
    }

    // --- Allow New Token ---

    function testIfRevertsWhenTryingToAddAnInvalidToken() public {
        vm.prank(orderBook.getOwner());
        vm.expectRevert(OrderBook.OrderBook__InvalidTokenAddress.selector);
        orderBook.allowNewToken(address(0), "address(0)");
    }

    function testIfRevertWhenTryingToAddAExistingToken() public {
        vm.prank(orderBook.getOwner());
        vm.expectRevert(OrderBook.OrderBook__InvalidTokenAddress.selector);
        orderBook.allowNewToken(weth, "WETH");
    }

    function testIfEmitEventAddingNewToken() public {
        vm.startPrank(orderBook.getOwner());
        vm.expectEmit(true, true, false, false, address(orderBook));
        emit TokenAllowed(solana, "Sol");
        orderBook.allowNewToken(solana, "Sol");
        vm.stopPrank();

        assertEq(orderBook.getTokenIsAllowToTrade(solana), true);
    }

    function testIfNewTokenCanBeTradedAndAddsFees() public {
        vm.startPrank(orderBook.getOwner());
        orderBook.allowNewToken(solana, "Sol");
        vm.stopPrank();

        uint256 sellerInitialDaiBalance = ERC20Mock(dai).balanceOf(seller);
        vm.startPrank(seller);
        ERC20Mock(solana).approve(address(orderBook), type(uint256).max);
        orderBook.createSellOrder(solana, 5 ether, 1000 ether, 40);
        vm.stopPrank();

        vm.startPrank(buyer);
        ERC20Mock(dai).approve(address(orderBook), type(uint256).max);
        orderBook.buyOrder(1);
        vm.stopPrank();

        uint256 solanaFees = orderBook.getTotalFees(solana);
        uint256 daiFees = orderBook.getTotalFees(dai);
        assertEq(solanaFees, 0.1 ether);

        uint256 buyerSolanaBalance = ERC20Mock(solana).balanceOf(buyer);
        assertEq(buyerSolanaBalance, 5 ether - solanaFees);

        uint256 sellerFinalDaiBalance = ERC20Mock(dai).balanceOf(seller);
        assertEq(sellerFinalDaiBalance, sellerInitialDaiBalance + 1000 ether - daiFees);
    }

    // --- Getter Functions ---

    function testIfRevertsWhenTryingToGetAnInvalidTokenByIndex() public {
        vm.expectRevert(OrderBook.OrderBook__InvalidTokenIndex.selector);
        orderBook.getTokenAddressAndSymbol(3);
    }

    function testIfTokenAllowedIsCorrectAndCorrectlyConstantsValues() public view {
        assertEq(orderBook.getTokenIsAllowToTrade(weth), true);
        assertEq(orderBook.getTokenIsAllowToTrade(wbtc), true);
        assertEq(orderBook.getTokenIsAllowToTrade(dai), true);
        assertEq(orderBook.getTokenIsAllowToTrade(address(0)), false);
        assertEq(orderBook.getFeeValue(), 2);
        assertEq(orderBook.getMaximumDeadline(), 60);
        assertEq(orderBook.getPrecision(), 100);
    }

    function testGetOrderDetails() public orderCreated {
        string memory details = orderBook.getOrderDetailsAsString(1);
        console2.log(details);
    }
}
