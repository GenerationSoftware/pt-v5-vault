const fs = require('node:fs/promises');
console.log(fs);

const rpcUrl = process.env.OPTIMISM_RPC_URL;

const outFile = "./cache/txList.txt";

const vaults = ["0x29Cb69D4780B53c1e5CD4D2B817142D2e9890715", "0xE3B3a464ee575E8E25D2508918383b89c832f275"];
const withdrawEventTopic = "0xfbde797d201c681b91056529119e0b02407c7bb96a4a2c75c01fc9667232c8db";
const redeemMethodHash = "0xba087652";
const withdrawMethodHash = "0xb460af94";

const main = async () => {
  const withdrawEvents = await (await fetch(rpcUrl, {
    method: "POST",
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "eth_getLogs",
      id: 1,
      params: [
        {
          fromBlock: "0x" + (111036451).toString(16),
          address: vaults,
          topics: [
            withdrawEventTopic
          ],
        },
      ]
    })
  })).json();

  console.log(withdrawEvents);
  console.log(`found ${withdrawEvents.result.length} withdrawals`);

  for(let i = 0; i < withdrawEvents.result.length; i++) {
    const event = withdrawEvents.result[i];
    const assets = event.data.slice(2,66);
    const shares = event.data.slice(66,130);
    if (assets !== shares) {
      console.log("Undercollaterlized withdrawal!", event);
    }

    console.log(`(${i + 1}/${withdrawEvents.result.length}) Fetching tx for hash: ${event.transactionHash}`);
    const txInfoRes = await (await fetch(rpcUrl, {
      method: "POST",
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "eth_getTransactionByHash",
        id: 2,
        params: [event.transactionHash]
      })
    })).json();
    const txInfo = txInfoRes.result;
    console.log(txInfoRes);
    await new Promise((resolve) => {
      setTimeout(resolve, 1000);
    });

    await fs.appendFile(outFile, `${event.address}\n${txInfo.from}\n${txInfo.to}\n${txInfo.value}\n${event.transactionHash}\n${txInfo.input}\n`);
  }
}
main();