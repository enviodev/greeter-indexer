type contract = {
  name: string,
  abi: Ethers.abi,
  addresses: array<Ethers.ethAddress>,
  events: array<Types.eventName>,
}

type syncConfig = {
  initialBlockInterval: int,
  backoffMultiplicative: float,
  accelerationAdditive: int,
  intervalCeiling: int,
  backoffMillis: int,
  queryTimeoutMillis: int,
}

type serverUrl = string

type rpcConfig = {
  provider: Ethers.JsonRpcProvider.t,
  syncConfig: syncConfig,
}

/**
A generic type where for different values of HyperSync and Rpc.
Where first param 'a represents the value for hypersync and the second
param 'b for rpc
*/
type source<'a, 'b> = HyperSync('a) | Rpc('b)

type syncSource = source<serverUrl, rpcConfig>

type chainConfig = {
  syncSource: syncSource,
  startBlock: int,
  confirmedBlockThreshold: int,
  chain: ChainMap.Chain.t,
  contracts: array<contract>,
}

type chainConfigs = ChainMap.t<chainConfig>

// Logging:
%%private(let envSafe = EnvSafe.make())

let getLogLevelConfig = (~name, ~default): Pino.logLevel =>
  envSafe->EnvSafe.get(
    ~name,
    ~struct=S.union([
      S.literalVariant(String("trace"), #trace),
      S.literalVariant(String("debug"), #debug),
      S.literalVariant(String("info"), #info),
      S.literalVariant(String("warn"), #warn),
      S.literalVariant(String("error"), #error),
      S.literalVariant(String("fatal"), #fatal),
      S.literalVariant(String("udebug"), #udebug),
      S.literalVariant(String("uinfo"), #uinfo),
      S.literalVariant(String("uwarn"), #uwarn),
      S.literalVariant(String("uerror"), #uerror),
      S.literalVariant(String(""), default),
      S.literalVariant(EmptyOption, default),
    ]),
    (),
  )

let configIsUnorderedMultichainMode = false

/**
Used for backwards compatability
*/
let unstable__temp_unordered_head_mode = envSafe->EnvSafe.get(
  ~name="UNSTABLE__TEMP_UNORDERED_HEAD_MODE",
  ~struct=S.bool(),
  ~devFallback=false,
  (),
)

let isUnorderedMultichainMode =
  envSafe->EnvSafe.get(
    ~name="UNORDERED_MULTICHAIN_MODE",
    ~struct=S.bool(),
    ~devFallback=configIsUnorderedMultichainMode || unstable__temp_unordered_head_mode,
    (),
  )

let logFilePath =
  envSafe->EnvSafe.get(~name="LOG_FILE", ~struct=S.string(), ~devFallback="logs/envio.log", ())
let userLogLevel = getLogLevelConfig(~name="LOG_LEVEL", ~default=#info)
let defaultFileLogLevel = getLogLevelConfig(~name="FILE_LOG_LEVEL", ~default=#trace)

type logStrategyType = EcsFile | EcsConsole | FileOnly | ConsoleRaw | ConsolePretty | Both
let logStrategy = envSafe->EnvSafe.get(
  ~name="LOG_STRATEGY",
  ~struct=S.union([
    S.literalVariant(String("ecs-file"), EcsFile),
    S.literalVariant(String("ecs-console"), EcsConsole),
    S.literalVariant(String("file-only"), FileOnly),
    S.literalVariant(String("console-raw"), ConsoleRaw),
    S.literalVariant(String("console-pretty"), ConsolePretty),
    S.literalVariant(String("both-prettyconsole"), Both),
    // Two default values are pretty print to the console only.
    S.literalVariant(String(""), ConsolePretty),
    S.literalVariant(EmptyOption, ConsolePretty),
  ]),
  (),
)

let db: Postgres.poolConfig = {
  host: envSafe->EnvSafe.get(
    ~name="ENVIO_PG_HOST",
    ~struct=S.string(),
    ~devFallback="localhost",
    (),
  ),
  port: envSafe->EnvSafe.get(
    ~name="ENVIO_PG_PORT",
    ~struct=S.int()->S.Int.port(),
    ~devFallback=5433,
    (),
  ),
  user: envSafe->EnvSafe.get(
    ~name="ENVIO_PG_USER",
    ~struct=S.string(),
    ~devFallback="postgres",
    (),
  ),
  password: envSafe->EnvSafe.get(
    ~name="ENVIO_POSTGRES_PASSWORD",
    ~struct=S.string(),
    ~devFallback="testing",
    (),
  ),
  database: envSafe->EnvSafe.get(
    ~name="ENVIO_PG_DATABASE",
    ~struct=S.string(),
    ~devFallback="envio-dev",
    (),
  ),
  ssl: envSafe->EnvSafe.get(
    ~name="ENVIO_PG_SSL_MODE",
    ~struct=S.string(),
    //this is a dev fallback option for local deployments, shouldn't run in the prod env
    //the SSL modes should be provided as string otherwise as 'require' | 'allow' | 'prefer' | 'verify-full'
    ~devFallback=false->Obj.magic,
    (),
  ),
  // TODO: think how we want to pipe these logs to pino.
  onnotice: userLogLevel == #warn || userLogLevel == #error ? None : Some(() => ()),
}

let getSyncConfig = ({
  initialBlockInterval,
  backoffMultiplicative,
  accelerationAdditive,
  intervalCeiling,
  backoffMillis,
  queryTimeoutMillis,
}) => {
  initialBlockInterval: EnvUtils.getIntEnvVar(
    ~envSafe,
    "UNSTABLE__SYNC_CONFIG_INITIAL_BLOCK_INTERVAL",
    ~fallback=initialBlockInterval,
  ),
  // After an RPC error, how much to scale back the number of blocks requested at once
  backoffMultiplicative: EnvUtils.getFloatEnvVar(
    ~envSafe,
    "UNSTABLE__SYNC_CONFIG_BACKOFF_MULTIPLICATIVE",
    ~fallback=backoffMultiplicative,
  ),
  // Without RPC errors or timeouts, how much to increase the number of blocks requested by for the next batch
  accelerationAdditive: EnvUtils.getIntEnvVar(
    ~envSafe,
    "UNSTABLE__SYNC_CONFIG_ACCELERATION_ADDITIVE",
    ~fallback=accelerationAdditive,
  ),
  // Do not further increase the block interval past this limit
  intervalCeiling: EnvUtils.getIntEnvVar(
    ~envSafe,
    "UNSTABLE__SYNC_CONFIG_INTERVAL_CEILING",
    ~fallback=intervalCeiling,
  ),
  // After an error, how long to wait before retrying
  backoffMillis,
  // How long to wait before cancelling an RPC request
  queryTimeoutMillis,
}

let getConfig = (chain: ChainMap.Chain.t) =>
  switch chain {
  | Chain_137 => {
      confirmedBlockThreshold: 200, //TODO: This is currently hardcoded, it should be determined per chain
      syncSource: HyperSync("https://polygon.hypersync.xyz"),
      startBlock: 45336336,
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
    }
  | Chain_59144 => {
      confirmedBlockThreshold: 200, //TODO: This is currently hardcoded, it should be determined per chain
      syncSource: HyperSync("https://linea.hypersync.xyz"),
      startBlock: 367801,
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
    }
  }

let config: chainConfigs = ChainMap.make(getConfig)

let metricsPort =
  envSafe->EnvSafe.get(~name="METRICS_PORT", ~struct=S.int()->S.Int.port(), ~devFallback=9898, ())

// You need to close the envSafe after you're done with it so that it immediately tells you about your  misconfigured environment on startup.
envSafe->EnvSafe.close()
