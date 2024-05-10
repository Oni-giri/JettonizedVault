// SPDX-License-Identifier: GPL-3.0-or-later
/**
    Note for the non-lawyers: The licence says that, if you fork:
    - The source code is made available to the public in source code form under the same license
    - The original author (@yakito_ri) must be attributed
**/

import "@stdlib/ownable";
import "./jetton-wallet.tact";
struct Asset {
    address: Address;
    balance: Int as coins = 0;
}
trait JettonizedVault with Jetton {
    asset: Asset;
    ownWallet: Address;
    protocolWallet: Address;
    owner: Address;
    maxSupply: Int;
    totalSupply: Int;
    content: Cell;
    mintable: Bool;
    const MAX_INT256: Int = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const MAX_COINS: Int = 0x199999999999999999999999999999;
    const DEPOSIT: Int = 1;
    const WITHDRAW: Int = 2;
    const COMPOUND_ASSET: Int = 3;
    const INCORRECT_ASSET: Int = 4;
    const DECIMAL_FACTOR: Int = 1000000000;

    /**
        The vault interaction mechanism is called when the vault is notified of an incoming transfer
        - If it's the underlying asset, it's converted to shares
        - If it's shares, it's converted to the underlying asset
        - If it's an unrecognized token, the contract refunds it.
    **/
    receive(msg: TransferNotification){
        let mode: Int = self._checkAsset(msg.from, sender());
        if (mode == self.DEPOSIT) {
            let shareAmount: Int = self._convertToShares(msg.amount);
            self.asset.balance += msg.amount;
            self._deposit(msg.amount);
            if (msg.forward_payload.bits() != 36) {
                self._mintShares(shareAmount, msg.from);
            } else {
                self._mintShares(shareAmount, msg.forward_payload.loadAddress());
            }
        } else if (mode == self.WITHDRAW) {
            self.asset.balance -= msg.amount;
            self.totalSupply = (self.totalSupply - msg.amount);
            self._burnShares(msg.amount, msg.from);
            // Add logic to add a recipient
            self._withdraw(self._convertToAssets(msg.amount), msg.from);
        } else if (mode == self.COMPOUND_ASSET) {
            self._compound(msg.amount);
        } else if (mode == self.INCORRECT_ASSET) {
            // self._sendToken(msg.from, msg.from, msg.amount, sender());
            throw(42);
        }
    }

    fun _burnShares(amount: Int, responseDestination: Address) {
        // Burn tokens
        send(SendParameters{  
            to: self.ownWallet,
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: TokenBurn{
                queryId: 0,
                amount: amount,
                owner: myAddress(),
                response_destination: responseDestination
            }.toCell()
        });
    }

     fun _sendToken(to: Address, responseDestination: Address, amount: Int, wallet: Address) {
        // TODO: Add gas check
        let payload: Cell = emptyCell();
        send(SendParameters{
                to: wallet,
                value: amount,
                mode: SendRemainingValue,
                bounce: true,
                body: TokenTransfer{
                    queryId: 0,
                    amount: amount,
                    destination: to,
                    response_destination: responseDestination,
                    custom_payload: payload,
                    forward_ton_amount: ton("0"),
                    forward_payload: emptySlice()
                }.toCell()
            }
        );
    }

    fun _checkAsset(depositor: Address, senderWallet: Address): Int {
        // We get the initial state of the asset jetton wallet for the depositor
        let assetInit: StateInit = initOf JettonDefaultWallet(self.asset.address, depositor);
        if (contractAddress(assetInit) == senderWallet) {
            return self.DEPOSIT;
        } else {
            let sharesInit: StateInit = initOf JettonDefaultWallet(self.ownWallet, self.asset.address);
            if (contractAddress(sharesInit) == self.ownWallet) {
                return self.WITHDRAW;
            } else {
                return self.INCORRECT_ASSET;
            }
        }
    }

    fun _checkRecipient(from: Address, payload: Slice): Address {
        if (payload.bits() == 36) {
            return payload.loadAddress();
        } else {
            return from;
        }
    }

    fun _mintShares(amount: Int, to: Address) {
        require(self.mintable, "Minting is disabled");
        self.mint(to, amount, self.owner);
    }

    fun _convertToShares(amount: Int): Int {
        return (amount * self.totalSupply * self.DECIMAL_FACTOR / self.asset.balance) / self.DECIMAL_FACTOR;
    }

    fun _convertToAssets(shares: Int): Int {
        return (shares * self.asset.balance * self.DECIMAL_FACTOR / self.totalSupply) / self.DECIMAL_FACTOR;
    }

    get fun asset(): Address {
        return self.asset.address;
    }

    get fun totalAssets(): Int {
        return self.asset.balance;
    }

    get fun convertToShares(amount: Int): Int {
        return self._convertToShares(amount);
    }

    get fun convertToAssets(shares: Int): Int {
        return self._convertToAssets(shares);
    }

    get fun maxRedeemableAssets(): Int {
        return self.MAX_INT256;
    }

    get fun maxDeposit(): Int {
        return self.MAX_INT256;
    }

    get fun maxWithdraw(): Int {
        return self.MAX_INT256;
    }

    abstract fun _deposit(amount: Int);

    abstract fun _withdraw(amount: Int, to: Address);

    abstract fun _compound(amount: Int);
}
message(0x7362d09c) TransferNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}