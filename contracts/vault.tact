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
  protocol: Address;
  owner: Address;
  maxSupply: Int;
  totalSupply: Int;
  content: Cell;
  mintable: Bool;
  autoDeposit: Bool;
  init(asset: Asset,
    protocolWallet: Address,
    protocol: Address,
    owner: Address,
    content: Cell,
    autoDeposit: Bool){
    self.owner = owner;
    self.asset = Asset{address: assetAddress};
    self.content = content;
    self.mintable = true;
    self.maxSupply = self.MAX_INT256;
    self.totalSupply = 0;
    self.protocolWallet = protocolWallet;
    self.protocol = protocol;
    self.autoDeposit = autoDeposit;
    // We deploy a wallet for the vault
    let walletAddress: Address = contractAddress(initOf JettonDefaultWallet(myAddress(),
        myAddress()
      )
    );
    self.ownWallet = walletAddress;
    send(SendParameters{
        // bounce is set to true by default
        to: walletAddress,
        value: ton("1"),
        mode: SendRemainingValue, // don't stop in case of errors
        code: init.code,
        data: init.data,
        body: "Initializing self wallet contract".asComment()
      };
    );
  }

  override fun _withdraw(amount: Int, to: Address) {
    // This implementation is here for testing only
    // Change it to your specific usage
    send(SendParameters{
        // bounce is set to true by default
        to: protocol,
        value: 0,
        mode: SendRemainingValue, // don't stop in case of errors
        body: Withdraw{amount: amount, to: address}.toCell()
      }
    );
  }

  override fun _deposit(value: Int) {
    _sendToken(protocol, value, protocolWallet);
  }

}
message Withdraw {
  amount: Int;
  to: Address;
}