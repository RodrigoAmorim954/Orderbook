//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// --- Imports ---
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // lib/openzeppelin-contracts/contracts/token/ERC20/SafeERC20
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol"; // access/Ownable.sol
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title OrderBook
 * @author Rodrigo Amorim
 * @notice This contract is a simple order book for trading Weth and Wbtc for Dai.
 */
contract OrderBook is Ownable {
    // --- Type Variables ---
    using SafeERC20 for IERC20;
    using Strings for uint256;

    // --- Structs ---
    struct Order {
        uint256 orderId;
        address seller;
        address tokenToSell; // Address of the token being sold (Weth or Wbtc)
        uint256 amountToSell;
        uint256 priceInUSD; // price of the token in USD
        uint256 deadlineTimeStamp; // Block timestamp after which the order expires
        bool isActive; // Flag indicating if the order is still active
    }

    // --- Constants ---
    uint256 private constant MAX_DEADLINE_DURATION = 60; // Max duration from order creation to expiration (60 seconds)
    uint256 private constant FEE = 2; // 2%
    uint256 private constant PRECISION = 100;

    // --- State Variables ---
    IERC20 private immutable iWeth;
    IERC20 private immutable iWbtc;
    IERC20 private immutable iDai;

    mapping(address token => bool allowed) private s_tokenAllowedToTrade;
    mapping(address token => string name) private s_tokenAddressToSymbol;
    mapping(uint256 => Order) private s_orders;
    address[] private s_tokensAllowed;
    uint256 private _nextOrderId;
    mapping(address => uint256) private s_totalFees;

    // --- Events ---
    event OrderCreated(uint256 indexed orderId, address indexed seller, address indexed tokenToSell, uint256 amountToSell, uint256 priceInUSD, uint256 deadlineTimeStamp);
    event OrderAmended(uint256 indexed orderId, uint256 indexed amountToSell, uint256 indexed priceInUsd, uint256 deadlineTimeStamp);
    event OrderCancelled(uint256 indexed orderId);
    event OrderExpired(uint256 indexed orderId);
    event OrderFulfilled(uint256 indexed orderId, address indexed buyer, address indexed seller, address tokenToSell, uint256 amountToBuy);
    event FeesWithdrawn(address indexed to, address indexed tokenToWithdraw, uint256 indexedamountToWithdraw);
    event TokenAllowed(address indexed TokenAllowed, string indexed tokenSymbol);

    // --- Errors ---
    error OrderBook__InvalidTokenAddress();
    error OrderBook__InvalidSender();
    error OrderBook__InvalidAmount();
    error OrderBook__InvalidPrice();
    error OrderBook__InvalidDeadline();
    error OrderBook__InvalidOrder();
    error OrderBook__OrderInactive();
    error OrderBook__InvalidWithdrawAmount();
    error OrderBook__InvalidAddress();
    error OrderBook__InvalidTokenIndex();
    error OrderBook__InsufficientFunds();

    // --- Constructor ---
    constructor(address _owner, address _weth, address _wbtc, address _Dai) Ownable(_owner) {
        if (_weth == address(0) || _wbtc == address(0) || _Dai == address(0)) {
            revert OrderBook__InvalidTokenAddress();
        }

        if (_owner == address(0)) {
            revert OrderBook__InvalidAddress();
        }

        iWeth = IERC20(_weth);
        s_tokenAllowedToTrade[_weth] = true;
        s_tokenAddressToSymbol[_weth] = "WETH";
        s_tokensAllowed.push(_weth);

        iWbtc = IERC20(_wbtc);
        s_tokenAddressToSymbol[_wbtc] = "WBTC";
        s_tokenAllowedToTrade[_wbtc] = true;
        s_tokensAllowed.push(_wbtc);

        iDai = IERC20(_Dai);
        s_tokenAddressToSymbol[_Dai] = "DAI";
        s_tokenAllowedToTrade[_Dai] = true;
        s_tokensAllowed.push(_Dai);

        _nextOrderId = 1; // OrderId Starts Here!!
    }

    // --- Functions ---
    /**
     * @dev This function is used to create a brand new order for selling a token.
     * @param _tokenToSell address token to sell
     * @param _amountToSell amount to sell from the token
     * @param _priceInUSD total price in USD of the order
     * @param _deadline timestamp until the order expires
     */
    function createSellOrder(address _tokenToSell, uint256 _amountToSell, uint256 _priceInUSD, uint256 _deadline) external returns (uint256) {
        // --- Checks ---
        if (!s_tokenAllowedToTrade[_tokenToSell]) {
            revert OrderBook__InvalidTokenAddress();
        }
        if (_amountToSell == 0) {
            revert OrderBook__InvalidAmount();
        }
        if (_priceInUSD <= 0) {
            revert OrderBook__InvalidPrice();
        }
        if (_deadline == 0 || _deadline > block.timestamp + MAX_DEADLINE_DURATION) {
            revert OrderBook__InvalidDeadline();
        }

        // --- Effects ---
        uint256 deadlineTimeStamp = block.timestamp + _deadline;
        uint256 orderId = _nextOrderId;
        _nextOrderId += 1;

        s_orders[orderId] = Order({
            orderId: orderId,
            seller: msg.sender,
            tokenToSell: _tokenToSell,
            amountToSell: _amountToSell,
            priceInUSD: _priceInUSD,
            deadlineTimeStamp: deadlineTimeStamp,
            isActive: true
        });

        emit OrderCreated(orderId, msg.sender, _tokenToSell, _amountToSell, _priceInUSD, _deadline);

        // -- Interactions ---
        IERC20(_tokenToSell).safeTransferFrom(msg.sender, address(this), _amountToSell);

        return orderId;
    }

    /**
     * @dev This function is used to amend an existing order by changing the amount to sell, the price or the deadline (is not necessary to change all the variables, just the one that  you want to change)
     * @param _orderId number of the orderId to change de order
     * @param _newAmountToSell new amount of the tokens to sell  (is not the difference between the old amount and the new amount)
     * @param _priceInUSD new price of the total order in USD
     * @param updateDeadline if you don't want to update the deadline, set it to false otherwise set it to true
     * @param _newDeadline new deadline for the order (we update the timestamp such as a new one is created)
     */
    function amendSellOrder(uint256 _orderId, uint256 _newAmountToSell, uint256 _priceInUSD, bool updateDeadline, uint256 _newDeadline) external {
        // --- Checks ---
        Order storage order = s_orders[_orderId];

        if (order.orderId == 0) {
            revert OrderBook__InvalidOrder();
        }
        if (order.seller != msg.sender) {
            revert OrderBook__InvalidSender();
        }

        if (_newAmountToSell <= 0) {
            revert OrderBook__InvalidAmount();
        }
        if (_priceInUSD <= 0) {
            revert OrderBook__InvalidPrice();
        }
        if (order.isActive == false) {
            revert OrderBook__OrderInactive();
        }
        if (updateDeadline == true) {
            if (_newDeadline == 0 || _newDeadline > block.timestamp + MAX_DEADLINE_DURATION) {
                revert OrderBook__InvalidDeadline();
            } else {
                order.deadlineTimeStamp = block.timestamp + _newDeadline; // We can update the timestamp for 5 more day
            }
        }

        // --- Effects ---

        int256 diffValueToSell = int256(_newAmountToSell) - int256(order.amountToSell);

        order.priceInUSD = _priceInUSD;

        emit OrderAmended(_orderId, _newAmountToSell, _priceInUSD, _newDeadline);

        // -- Interactions ---

        if (diffValueToSell > 0) {
            order.amountToSell = _newAmountToSell;

            IERC20(order.tokenToSell).safeTransferFrom(order.seller, address(this), uint256(diffValueToSell));
        } else if (diffValueToSell < 0) {
            order.amountToSell = _newAmountToSell;

            IERC20(order.tokenToSell).safeTransfer(order.seller, uint256(-diffValueToSell));
        } else {
            order.amountToSell = _newAmountToSell;
        }
    }

    /**
     * @dev This function is used to cancel the order by the seller
     * @param _orderId number of the orderId to cancel
     */
    function cancelSellOrder(uint256 _orderId) external {
        // --- Checks ---
        Order storage order = s_orders[_orderId];

        if (order.orderId == 0) {
            revert OrderBook__InvalidOrder();
        }
        if (order.seller != msg.sender) {
            revert OrderBook__InvalidSender();
        }

        if (order.isActive == false) {
            revert OrderBook__OrderInactive();
        }

        // --- Effects ---
        order.isActive = false;
        emit OrderCancelled(_orderId);

        // -- Interactions ---
        IERC20(order.tokenToSell).safeTransfer(order.seller, order.amountToSell);
    }

    /**
     * @dev This function is used to buy an active order (if the order is expired the function will revert)
     * @param _orderId the id of the order to buy
     */

    function buyOrder(uint256 _orderId) external {
        // --- Checks ---
        Order storage order = s_orders[_orderId];

        if (order.orderId == 0) {
            revert OrderBook__InvalidOrder();
        }
        if (order.seller == address(0)) {
            revert OrderBook__InvalidAddress();
        }
        if (block.timestamp > order.deadlineTimeStamp) {
            _orderCancelation(_orderId);
            emit OrderExpired(_orderId);
            return;
        }
        if (order.isActive == false) {
            revert OrderBook__OrderInactive();
        }

        if (order.priceInUSD > (IERC20(iDai).balanceOf(msg.sender))) {
            revert OrderBook__InsufficientFunds();
        }

        // --- Effects ---
        order.isActive = false;

        uint256 feeInDai = (order.priceInUSD * FEE) / PRECISION;
        uint256 feeInCrypto = (order.amountToSell * FEE) / PRECISION;

        s_totalFees[s_tokensAllowed[2]] += feeInDai; // We update the total fees in Dai
        s_totalFees[order.tokenToSell] += feeInCrypto; // We update the total fees in the respective token
        emit OrderFulfilled(_orderId, msg.sender, order.seller, order.tokenToSell, order.amountToSell);

        // -- Interactions ---
        iDai.safeTransferFrom(msg.sender, address(this), feeInDai); // The protocol receives the fee
        iDai.safeTransferFrom(msg.sender, order.seller, order.priceInUSD - feeInDai); // The seller receives the remaining amount
        IERC20(order.tokenToSell).safeTransfer(msg.sender, order.amountToSell - feeInCrypto); // The buyer receives the token minus the fee
    }

    /**
     * @dev This function is used to withdraw the fees of the protocol (can only be called by the owner)
     * @param _to the address to withdraw the fees
     * @param _tokenFeeToWithdraw the token to withdraw the fees (can be all tokens that are in the protocol)
     * @param _amountToWithdraw the amount to withdraw
     */

    function withdrawFees(address _to, uint256 _amountToWithdraw, address _tokenFeeToWithdraw) external onlyOwner {
        // --- Checks ---
        if (s_totalFees[_tokenFeeToWithdraw] == 0) {
            revert OrderBook__InvalidWithdrawAmount();
        }

        if (_to == address(0)) {
            revert OrderBook__InvalidAddress();
        }

        if (_amountToWithdraw > s_totalFees[_tokenFeeToWithdraw]) {
            revert OrderBook__InvalidWithdrawAmount();
        }

        // --- Effects ---

        uint256 feesRemaining = s_totalFees[_tokenFeeToWithdraw] - _amountToWithdraw;

        emit FeesWithdrawn(_to, _tokenFeeToWithdraw, _amountToWithdraw);

        s_totalFees[_tokenFeeToWithdraw] = feesRemaining;

        // -- Interactions ---

        IERC20(_tokenFeeToWithdraw).safeTransfer(_to, _amountToWithdraw);
    }

    /**
     * @dev This function is used to allow a new token to be traded (only the owner can call this function)
     * @param _token the address of the token to allow
     * @param _tokenSymbol the symbol of the token to allow
     */

    function allowNewToken(address _token, string memory _tokenSymbol) external onlyOwner {
        if (_token == address(0) || s_tokenAllowedToTrade[_token] == true) {
            revert OrderBook__InvalidTokenAddress();
        }

        s_tokenAllowedToTrade[_token] = true;
        s_tokenAddressToSymbol[_token] = _tokenSymbol;
        emit TokenAllowed(_token, _tokenSymbol);

        s_tokensAllowed.push(_token);
    }

    // --- Internal Functions ---

    /**
     * @dev This function is used to cancel an order that is expired by the timestamp, this function is called when someone tries to buy or amend some order that already expired.
     * @param _orderId the id of the order to cancel
     */
    function _orderCancelation(uint256 _orderId) internal {
        Order storage order = s_orders[_orderId];

        // -- Effects ---
        order.isActive = false;

        // -- Interactions ---
        IERC20(order.tokenToSell).safeTransfer(order.seller, order.amountToSell);
    }

    // --- Getter Functions ---
    function getOrderDetails(uint256 _orderId) external view returns (Order memory) {
        if (s_orders[_orderId].orderId == 0) {
            revert OrderBook__InvalidOrder();
        }
        return s_orders[_orderId];
    }

    function getOrderDetailsAsString(uint256 _orderId) public view returns (string memory details) {
        if (s_orders[_orderId].orderId == 0) {
            revert OrderBook__InvalidOrder();
        }
        Order storage order = s_orders[_orderId];

        string memory tokenSymbol = s_tokenAddressToSymbol[order.tokenToSell];

        // Looking for the order situation
        string memory status;
        if (order.isActive == true) {
            if (block.timestamp > order.deadlineTimeStamp) {
                status = "Order Expired (waiting for cancelation)";
            } else {
                status = "Order Active!";
            }
        } else {
            status = "Order Expired / Canceled!";
        }

        details = string(
            abi.encodePacked(
                "Order ID: ",
                order.orderId.toString(),
                "\n",
                "Token to sell: ",
                tokenSymbol,
                "\n",
                "Seller Address: ",
                Strings.toHexString(order.seller),
                "\n",
                "Amount to sell: ",
                order.amountToSell.toString(),
                "\n",
                "Price in USD: ",
                order.priceInUSD.toString(),
                "\n",
                "Deadline: ",
                order.deadlineTimeStamp.toString(),
                "\n",
                "Status: ",
                status
            )
        );

        return details;
    }

    function getTokenAddressAndSymbol(uint256 _index) external view returns (address, string memory) {
        if (_index >= s_tokensAllowed.length) {
            revert OrderBook__InvalidTokenIndex();
        }

        return (s_tokensAllowed[_index], s_tokenAddressToSymbol[s_tokensAllowed[_index]]);
    }

    function getTokenIsAllowToTrade(address _tokenAddress) external view returns (bool) {
        return s_tokenAllowedToTrade[_tokenAddress];
    }

    function getFeeValue() external pure returns (uint256) {
        return FEE;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getMaximumDeadline() external pure returns (uint256) {
        return MAX_DEADLINE_DURATION;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function getTotalFees(address _token) external view returns (uint256) {
        return s_totalFees[_token];
    }
}
