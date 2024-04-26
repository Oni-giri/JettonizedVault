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

contract JettonizedVault with Jetton {
    // Vault-specific data
    asset: Asset; // The master address of the asset used in the vault
    totalSupply: Int as coins;
    // Jetton-specific data
    owner: Address;
    ownWallet: Address; // The self wallet of the vault
    content: Cell; // The content of the vault Jetton
    mintable: Bool; // Whether the vault can mint new shares
    maxSupply: Int as coins; // The maximum supply of the vault Jettons
    protocolWallet: Address; // The wallet of the protocol

    // TODO: Move to a library
    // Constants
    const MAX_INT256: Int = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const MAX_COINS: Int = 0x199999999999999999999999999999;
    const DEPOSIT: Int = 1;
    const WITHDRAW: Int = 2;
    const COMPOUND_ASSET: Int = 3;
    const INCORRECT_ASSET: Int = 4;
    init(owner: Address, assetAddress: Address, content: Cell, protocolWallet: Address){
        self.owner = owner;
        self.asset = Asset{address: assetAddress};
        self.content = content;
        self.mintable = true;
        self.maxSupply = 0x199999999999999999999999999999;
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
        if (mode == self.DEPOSIT) {
            // Convert the asset to shares
            let shareAmount: Int = self._convertToShares(msg.amount);
            self._deposit(msg.amount);
            // TODO: check the payload for the destination
            self._mintShares(shareAmount, msg.from);
        } else if (mode == self.WITHDRAW) {
            // Convert the shares to the asset
            let assetAmount: Int = self._convertToAssets(msg.amount);
            self._withdraw(msg.from, assetAmount);
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
        self._sendToken(self.protocolWallet, amount, self.ownWallet);
    }

    // TODO: add a bounced handler for the asset

    // TODO: Move to a library
    // TODO: Response destination?
    // TODO: Forward payload?
    // TODO: Forward TON amount?

     fun _sendToken(to: Address, amount: Int, wallet: Address) {
        // We refund the asset to the sender
        send(SendParameters{
                to: wallet,
                value: amount,
                mode: SendRemainingValue,
                bounce: true,
                mode: SendIgnoreErrors, // don't stop in case of errors
                body: TokenTransfer{
                    queryId: 0,
                    amount: amount,
                    destination: to,
                    response_dest: null, // TODO: implement?
                    custom_payload: null,
                    forward_ton_amount: ton("0"), // TODO: implement
                    forward_payload: "Invalid transfer, refunding asset".asComment()
                }
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
                return self.REFUND;
            }
        }
    }

     fun _mintShares(amount: Int, to: Address) {
        require(self.mintable, "Minting is disabled");
        self.mint(to, amount, self.owner);
    }

     fun _withdraw(to: Address, amount: Int) {
        // TODO: implement
        self.burn(to, amount, self.owner);
    }

     fun _convertToShares(amount: Int): Int {
        // TODO: implement
    }

     fun _convertToAssets(shares: Int): Int {
        // TODO: implement
    }

    get fun asset(): Address {
        return self.asset.address;
    }

    get fun totalAssets(): Int {
        return self.asset.balance;
    }

    // How many shares will I get if I deposit this amount of assets?

    get fun convertToShares(amount: Int): Int {
        // TODO: implement
        self._convertToShares(amount);
        return amount;
    }

    // How many assets will I get if I redeem this amount of shares?

    get fun convertToAssets(shares: Int): Int {
        // TODO: implement
        return shares;
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

    get fun name(): String {
        return "Jettonized Vault";
    }
}