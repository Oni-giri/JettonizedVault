// SPDX-License-Identifier: GPL-3.0-or-later
/**
    Note for the non-lawyers: The licence says that, if you fork:
    - The source code is made available to the public in source code form under the same license
    - The original author (@yakito_ri) must be attributed
**/

import "@stdlib/ownable";
import "@stdlib/deploy";
import "./jetton-wallet.tact";
struct Asset {
    address: Address;
    balance: Int as coins = 0;
}
message(0x7362d09c) TransferNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}

contract JV with Jetton {
    // Vault-specific data
    asset: Asset;
    // Jetton-specific data
    owner: Address;
    ownWallet: Address; // The self wallet of the vault
    content: Cell; // The content of the vault Jetton
    mintable: Bool; // Whether the vault can mint new shares
    maxSupply: Int as coins; 
    totalSupply: Int as coins; 
    protocolWallet: Address; // The wallet of the protocol

    // Constants
    const MAX_INT256: Int = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const MAX_COINS: Int = 0x199999999999999999999999999999;
    const DEPOSIT: Int = 1;
    const WITHDRAW: Int = 2;
    const COMPOUND_ASSET: Int = 3;
    const INCORRECT_ASSET: Int = 4;
    const DECIMAL_FACTOR: Int = 1000000000;
    init(owner: Address, assetAddress: Address, content: Cell, protocolWallet: Address){
        self.owner = owner;
        self.asset = Asset{address: assetAddress};
        self.content = content;
        self.mintable = true;
        self.maxSupply = self.MAX_INT256;
        self.totalSupply = 0;
        self.protocolWallet = protocolWallet;
        // We deploy a wallet for the vault
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), myAddress());
        let walletAddress: Address = contractAddress(init);
        let value: Int = ton("1");
        send(SendParameters{
                // bounce is set to true by default
                to: walletAddress,
                value: value,
                mode: SendIgnoreErrors, // don't stop in case of errors
                code: init.code,
                data: init.data,
                body: "Initializing self wallet contract".asComment()
            }
        );
        self.ownWallet = walletAddress;
    }

    /**
        The vault interaction mechanism is called when the vault is notified of an incoming transfer
        - If it's the underlying asset, it's converted to shares
        - If it's shares, it's converted to the underlying asset
        - If it's an unrecognized token, the contract refunds it.
    **/
    receive(msg: TransferNotification){
        // We check first that the transfer is coming from a wallet holding the asset
        let mode: Int = self._checkAsset(msg.from, sender());

        // If we received assets, we mint shares to the sender
        if (mode == self.DEPOSIT) {
            // Convert the asset to shares
            let shareAmount: Int = self._convertToShares(msg.amount);
            // Deposit the asset
            self._deposit(msg.amount);
            // We check the payload to see if we need to forward the shares to another address
            if(msg.forward_payload.bits() != 36){
                self._mintShares(shareAmount, msg.from);
            } else {
                self._mintShares(shareAmount, msg.forward_payload.loadAddress());
            }
        } else if (mode == self.WITHDRAW) {
            self._withdraw(self._convertToAssets(msg.amount), 
            msg.from);
            self.totalSupply = self.totalSupply - msg.amount; // Update total supply
        } else if (mode == self.COMPOUND_ASSET) {
            // Compound the asset
            self._compound(msg.amount);
        } else if (mode == self.INCORRECT_ASSET) {
            // Refund the asset
            // TODO: Response destination?
            // TODO: Forward payload?
            // TODO: Forward TON amount?
            self._sendToken(msg.from, msg.amount, sender());
        }
    }

     fun _deposit(amount: Int) {
        self.asset.balance += amount;
        self._sendToken(self.protocolWallet, amount, self.ownWallet);
    }

     fun _withdraw(amount: Int, to: Address) {
        self.asset.balance -= amount;
        // Implement withdraw function with the mock wallet
    }

     fun _compound(amount: Int) {
        self.asset.balance += amount;
        // Implement compound function 
    }

    fun _burn(amount: Int, from: Address) {
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
                response_destination: self.owner // TODO: implement?
            }.toCell()
        });
    }

    // TODO: add a bounced handler for the asset

    // TODO: Move to a library
    // TODO: Response destination?
    // TODO: Forward payload?
    // TODO: Forward TON amount?

    // TODO: Check params
     fun _sendToken(to: Address, amount: Int, wallet: Address) {
        let payload: Cell? = emptyCell();
        send(SendParameters{
                to: wallet,
                value: amount,
                mode: SendRemainingValue,
                bounce: true,
                body: TokenTransfer{
                    queryId: 0,
                    amount: amount,
                    destination: to,
                    response_destination: to, 
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

    // How many assets will I get if I redeem this amount of shares?

    get fun convertToAssets(shares: Int): Int {
        return self._convertToAssets(shares);
    }

    // TODO: Move to a trait?

    get fun maxMintableShares(): Int {
        return self.MAX_INT256;
    }

    // TODO: Move to a trait?

    get fun maxRedeemableAssets(): Int {
        return self.MAX_INT256;
    }

    // TODO: Move to a trait?

    get fun maxDeposit(): Int {
        return self.MAX_INT256;
    }

    // TODO: Move to a trait?

    get fun maxWithdraw(): Int {
        return self.MAX_INT256;
    }
}