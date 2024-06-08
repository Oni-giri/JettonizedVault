// SPDX-License-Identifier: GPL-3.0-or-later
/**
    Note for the non-lawyers: The licence says that, if you fork:
    - The source code is made available to the public in source code form under the same license
    - The original author (@yakito_ri) must be attributed
**/

import "./jetton-wallet.tact";

message(0x7362d09c) TransferNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining;
}

message Withdraw {
    amount: Int;
}

// This is a mock contract to test the JettonizedVault contract
// It receives assets and allows to claim yield after some time.
// Because it's a mock, there are no checks, so don't use this in prod
contract MockProtocol {
    token: Address;
    balance: Int;

    init(token: Address) {
        self.token = token;
        self.balance = 0;
    }

    // We receive tokens as a deposit
  receive(msg: TransferNotification){
        self.balance = msg.amount;
    }

  receive(msg: Withdraw) {
    _sendToken(msg.from, msg.from, msg.amount, wallet);
  }

    fun _sendToken(to: Address, responseDestination: Address, amount: Int, wallet: Address) {
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


}