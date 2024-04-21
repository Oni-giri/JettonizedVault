import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { DiamondMine } from '../wrappers/DiamondMine';
import '@ton/test-utils';

describe('DiamondMine', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let diamondMine: SandboxContract<DiamondMine>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        diamondMine = blockchain.openContract(await DiamondMine.fromInit(0n));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await diamondMine.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: diamondMine.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and diamondMine are ready to use
    });

    it('should increase counter', async () => {
        const increaseTimes = 3;
        for (let i = 0; i < increaseTimes; i++) {
            console.log(`increase ${i + 1}/${increaseTimes}`);

            const increaser = await blockchain.treasury('increaser' + i);

            const counterBefore = await diamondMine.getCounter();

            console.log('counter before increasing', counterBefore);

            const increaseBy = BigInt(Math.floor(Math.random() * 100));

            console.log('increasing by', increaseBy);

            const increaseResult = await diamondMine.send(
                increaser.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: 'Add',
                    queryId: 0n,
                    amount: increaseBy,
                }
            );

            expect(increaseResult.transactions).toHaveTransaction({
                from: increaser.address,
                to: diamondMine.address,
                success: true,
            });

            const counterAfter = await diamondMine.getCounter();

            console.log('counter after increasing', counterAfter);

            expect(counterAfter).toBe(counterBefore + increaseBy);
        }
    });
});
