# 🪙 Crypto Orderbook

A simple decentralized on-chain orderbook system designed  to trade  crypto assets. This project supports create, amend,  buy and cancel orders at any time. 

---

## ✨ Features

- ✅ **Supports Multiple Tokens**: Trade between:
  - **WETH (Wrapped Ether)**
  - **WBTC (Wrapped Bitcoin)**
  - **DAI (Stablecoin)**
- 💰 **2% Fee**: A fixed fee is charged on all **successfully executed** trades.
- 🪙  **Tokens:** Besides the tokens mentioned above, it can be add new tokens in the future.
- ⌛ **Order Expiration**: Orders can be active until **3 days**.
- ❌ **Cancelable Orders**: Orders can be canceled at any time before expiration or fulfillment.
- 🔒 **Permissionless**: Anyone can place or match orders without intermediaries.

---

## 🔧 Tech Stack

| Layer        | Tech/Tool       |
|--------------|------------------|
| Smart Contracts | Solidity, Foundry |
| Local Dev Chain | Anvil |
| Supported Chains | ETH (Sepolia)
| Testing Tools | Forge |


---

## 📁 Project Structure

```
.
├── src/
│ └── Orderbook.sol # Main contract
├── script/
│ └── Deploy.s.sol # Deployment script
├── test/
│ └── Orderbook.t.sol # Core tests
├── foundry.toml # Foundry config
└── README.md
```

---

## 🛠️ Installation

### 1. Clone the repo:

```bash
git clone https://github.com/RodrigoAmorim954/Orderbook.git
cd crypto-orderbook
```
### 2. Install the necessary dependencies using make:
```
make install
```


## 🧪 Testing
Run the test suite with Foundry:
```
forge test
```
You can add flags like -vvvv for verbose output.

## 🧠 How It Works
### 🔄 OrderBook Functionality
**Create Order:** User submits a buy or sell order using one of the supported tokens placing the amount of tokens to sell and the total that the user wants to receive.

**Execution Fee:** A 2% fee is deducted from the successfull traded amount.

**Expiration:** The order can be active until 3 days. (timestamp-based).

**Amend:** The user can modify the order submited (can change the price, the quantity to sell or the expiration time).

**Cancellation:** The original order creator can cancel the order before expiration.


## 🔮 Future Improvements

Create Mocks of erc20 tokens  ~>  Okay

Initialize and Approval the tokens to be traded ??

Take the actual address contracts of the tokens in sepolia testnet (if they exists)


## 📄 License
This project is licensed under the MIT License.


