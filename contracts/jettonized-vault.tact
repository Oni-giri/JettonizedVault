// SPDX-License-Identifier: GPL-3.0-or-later
/**
    Note for the non-lawyers: The licence says that, if you fork:
    - The source code is made available to the public in source code form under the same license
    - The original author (@yakito_ri) must be attributed
**/

import "@stdlib/ownable";
struct Asset {
    address: Address;
    balance: Int as int256 = 0;
}
message(0x7362d09c) Deposit {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}

contract JettonizedVault with OwnableTransferable {
    owner: Address;
    asset: Asset;
    // TODO: Move to a library
    const MAX_INT256: Int = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const decimals: Int = 9;
    init(owner: Address, assetAddress: Address, decimals: Int){
        self.owner = owner;
        self.asset = Asset{address: assetAddress};
    }

    // The deposit mechanism is called when the vault is notified of an incoming transfer
    receive(msg: Deposit) {
        
    }

    get fun asset(): Address {
        return self.asset.address;
    }

    get fun totalAssets(): Int {
        return self.asset.balance;
    }

    get fun convertToShares(amount: Int): Int {
        // TODO: implement
        return amount;
    }

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
}