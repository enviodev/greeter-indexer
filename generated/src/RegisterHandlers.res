@val external require: string => unit = "require"

let registerContractHandlers = (
  ~contractName,
  ~handlerPathRelativeToRoot,
  ~handlerPathRelativeToConfig,
) => {
  try {
    require("handlers/" ++ handlerPathRelativeToRoot)
  } catch {
  | exn =>
    let params = {
      "Contract Name": contractName,
      "Expected Handler Path": handlerPathRelativeToConfig,
      "Code": "EE500",
    }
    let logger = Logging.createChild(~params)

    let errHandler = exn->ErrorHandling.make(~msg="Failed to import handler file", ~logger)
    errHandler->ErrorHandling.log
    errHandler->ErrorHandling.raiseExn
  }
}

// TODO: Start only using config returned by registerAllHandlers instead of Config.getConfig and Config.setGenerated
%%private(
  let chains = [
    {
      Config.confirmedBlockThreshold: 200,
      syncSource: HyperSync("https://polygon.hypersync.xyz"),
      startBlock: 45336336,
      endBlock: None,
      chain: Chain_137,
      contracts: [
        {
          name: "Greeter",
          abi: Abis.greeterAbi->Ethers.makeAbi,
          addresses: [
            "0x9D02A17dE4E68545d3a58D3a20BbBE0399E05c9c"->Ethers.getAddressFromStringUnsafe,
          ],
          events: [Greeter_NewGreeting, Greeter_ClearGreeting],
        },
      ],
    },
    {
      Config.confirmedBlockThreshold: 200,
      syncSource: HyperSync("https://linea.hypersync.xyz"),
      startBlock: 367801,
      endBlock: None,
      chain: Chain_59144,
      contracts: [
        {
          name: "Greeter",
          abi: Abis.greeterAbi->Ethers.makeAbi,
          addresses: [
            "0xdEe21B97AB77a16B4b236F952e586cf8408CF32A"->Ethers.getAddressFromStringUnsafe,
          ],
          events: [Greeter_NewGreeting, Greeter_ClearGreeting],
        },
      ],
    },
  ]

  let config = Config.make(
    ~shouldRollbackOnReorg=false,
    ~shouldSaveFullHistory=false,
    ~shouldUseHypersyncClientDecoder=true,
    ~isUnorderedMultichainMode=false,
    ~chains,
  )
  Config.setGenerated(config)
)

let registerAllHandlers = () => {
  registerContractHandlers(
    ~contractName="Greeter",
    ~handlerPathRelativeToRoot="src/EventHandlers.ts",
    ~handlerPathRelativeToConfig="src/EventHandlers.ts",
  )
  config
}
