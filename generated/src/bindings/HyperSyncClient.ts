import { HypersyncClient } from "@envio-dev/hypersync-client";

let client = HypersyncClient.new({ url: "https://polygon.hypersync.xyz" });

const main = async () => {
  let res = await client.sendEventsReq({
    fromBlock: 0,
    fieldSelection: { block: ["blockNumber"] },
  });
};
