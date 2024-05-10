// SPDX-License-Identifier: GPL-3.0-or-later
/**
    Note for the non-lawyers: The licence says that, if you fork:
    - The source code is made available to the public in source code form under the same license
    - The original author (@yakito_ri) must be attributed
**/

import "./Jettonized-vault.tact";

contract Vault with JettonizedVault {
    asset: Asset;
    ownWallet: Address;
    protocolWallet: Address;
    owner: Address;
    maxSupply: Int;
    totalSupply: Int;
    content: Cell;
    mintable: Bool;

    init(asset: Asset, protocolWallet: Address, owner: Address, content: Cell) {
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
                mode: SendRemainingValue, // don't stop in case of errors
                code: init.code,
                data: init.data,
                body: "Initializing self wallet contract".asComment()
            }
        );
        self.ownWallet = walletAddress;
    }

    override fun _deposit(value: Int) {
        
    }

    

}