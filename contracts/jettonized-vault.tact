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
    max_supply: Int as coins; // The maximum supply of the vault Jettons
    // TODO: Move to a library
    // Constants
    const MAX_INT256: Int = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const MAX_COINS: Int = 0x199999999999999999999999999999;
    const DEPOSIT: Int = 1;
    const WITHDRAW: Int = 2;
    init(owner: Address, assetAddress: Address, content: Cell){
        self.owner = owner;
        self.asset = Asset{address: assetAddress};
        self.content = content;
        self.mintable = true;
        self.max_supply = 0x199999999999999999999999999999;
        self.totalSupply = 0;
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

    // The vault interaction mechanism is called when the vault is notified of an incoming transfer
    // If the incoming transfer is the underlying asset, it's converted to shares
    // If the incoming transfer is shares, it's converted to the underlying asset
    receive(msg: TransferNotification){
        // We check first that the transfer is coming from a wallet holding the asset
        let mode: Int = _checkAsset(msg.from, msg.sender);
        if(mode == DEPOSIT) {
            // Convert the asset to shares
            let shareAmount: Int = _convertToShares(msg.amount);
            _mintShares(shareAmount, msg.from);
        } else if(mode == WITHDRAW) {
            // Convert the shares to the asset
            let assetAmount: Int = _convertToAssets(msg.amount);
            // Transfer the asset
            _withdraw(msg.from, assetAmount);
        }
    }

    fun _checkAsset(depositor: Address, senderWallet: Address): Int {

        // We get the initial state of the asset jetton wallet for the depositor
        let assetInit: StateInit = initOf JettonDefaultWallet(self.asset.address, depositor);
        if(contractAddress(assetInit) == senderWallet){
            return DEPOSIT;
        } else {
            let sharesInit: StateInit = initOf JettonDefaultWallet(sharesJetton, self.asset.address);
            if(contractAddress(sharesInit) == sharesJetton){
                return WITHDRAW;
            } else {
                throw("Invalid asset");
            }
        }
    }

     fun _mintShares(amount: Int, to: Address) {
        require(self.mintable, "Minting is disabled");
        self.mint(to, amount, self.owner);
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