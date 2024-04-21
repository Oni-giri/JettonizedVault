import { toNano } from '@ton/core';
import { DiamondMine } from '../wrappers/DiamondMine';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const diamondMine = provider.open(await DiamondMine.fromInit(BigInt(Math.floor(Math.random() * 10000))));

    await diamondMine.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(diamondMine.address);

    console.log('ID', await diamondMine.getId());
}
