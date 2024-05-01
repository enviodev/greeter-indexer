@spice
type unchecksummedEthAddress = string

module QueryTypes = {
  @spice
  type blockFieldOptions =
    | @spice.as("number") Number
    | @spice.as("hash") Hash
    | @spice.as("parent_hash") ParentHash
    | @spice.as("nonce") Nonce
    | @spice.as("sha3_uncles") Sha3Uncles
    | @spice.as("logs_bloom") LogsBloom
    | @spice.as("transactions_root") TransactionsRoot
    | @spice.as("state_root") StateRoot
    | @spice.as("receipts_root") ReceiptsRoot
    | @spice.as("miner") Miner
    | @spice.as("difficulty") Difficulty
    | @spice.as("total_difficulty") TotalDifficulty
    | @spice.as("extra_data") ExtraData
    | @spice.as("size") Size
    | @spice.as("gas_limit") GasLimit
    | @spice.as("gas_used") GasUsed
    | @spice.as("timestamp") Timestamp
    | @spice.as("uncles") Uncles
    | @spice.as("base_fee_per_gas") BaseFeePerGas

  @spice
  type blockFieldSelection = array<blockFieldOptions>

  @spice
  type transactionFieldOptions =
    | @spice.as("block_hash") BlockHash
    | @spice.as("block_number") BlockNumber
    | @spice.as("from") From
    | @spice.as("gas") Gas
    | @spice.as("gas_price") GasPrice
    | @spice.as("hash") Hash
    | @spice.as("input") Input
    | @spice.as("nonce") Nonce
    | @spice.as("to") To
    | @spice.as("transaction_index") TransactionIndex
    | @spice.as("value") Value
    | @spice.as("v") V
    | @spice.as("r") R
    | @spice.as("s") S
    | @spice.as("max_priority_fee_per_gas") MaxPriorityFeePerGas
    | @spice.as("max_fee_per_gas") MaxFeePerGas
    | @spice.as("chain_id") ChainId
    | @spice.as("cumulative_gas_used") CumulativeGasUsed
    | @spice.as("effective_gas_price") EffectiveGasPrice
    | @spice.as("gas_used") GasUsed
    | @spice.as("contract_address") ContractAddress
    | @spice.as("logs_bloom") LogsBloom
    | @spice.as("type") Type
    | @spice.as("root") Root
    | @spice.as("status") Status
    | @spice.as("sighash") Sighash

  @spice
  type transactionFieldSelection = array<transactionFieldOptions>

  @spice
  type logFieldOptions =
    | @spice.as("removed") Removed
    | @spice.as("log_index") LogIndex
    | @spice.as("transaction_index") TransactionIndex
    | @spice.as("transaction_hash") TransactionHash
    | @spice.as("block_hash") BlockHash
    | @spice.as("block_number") BlockNumber
    | @spice.as("address") Address
    | @spice.as("data") Data
    | @spice.as("topic0") Topic0
    | @spice.as("topic1") Topic1
    | @spice.as("topic2") Topic2
    | @spice.as("topic3") Topic3

  @spice
  type logFieldSelection = array<logFieldOptions>

  @spice
  type fieldSelection = {
    block?: blockFieldSelection,
    transaction?: transactionFieldSelection,
    log?: logFieldSelection,
  }

  @spice
  type logParams = {
    address?: array<Ethers.ethAddress>,
    topics: array<array<Ethers.EventFilter.topic>>,
  }

  @spice
  type transactionParams = {
    from?: array<Ethers.ethAddress>,
    @spice.key("to")
    to_?: array<Ethers.ethAddress>,
    sighash?: array<string>,
  }

  @spice
  type postQueryBody = {
    @spice.key("from_block") fromBlock: int,
    @spice.key("to_block") toBlockExclusive?: int,
    logs?: array<logParams>,
    transactions?: array<transactionParams>,
    @spice.key("field_selection") fieldSelection: fieldSelection,
    @spice.key("max_num_logs") maxNumLogs?: int,
    @spice.key("include_all_blocks") includeAllBlocks?: bool,
  }
}

module ResponseTypes = {
  // TODO: Should we use S.nullable or S.null (?)dule ResponseTypes = {
  //Note all fields marked as "nullable" are not explicitly null since
  //the are option fields and nulls will be deserialized to option when
  //in an optional field with spice
  type blockData = {
    number?: int,
    hash?: string,
    parentHash?: string,
    nonce?: int, //nullable
    sha3Uncles?: string,
    logsBloom?: string,
    transactionsRoot?: string,
    stateRoot?: string,
    receiptsRoot?: string,
    miner?: unchecksummedEthAddress,
    difficulty?: Ethers.BigInt.t, //nullable
    totalDifficulty?: Ethers.BigInt.t, //nullable
    extraData?: string,
    size?: Ethers.BigInt.t,
    gasLimit?: Ethers.BigInt.t,
    gasUsed?: Ethers.BigInt.t,
    timestamp?: Ethers.BigInt.t,
    uncles?: string, //nullable
    baseFeePerGas?: Ethers.BigInt.t, //nullable
  }

  let blockDataSchema = S.object((. s) => {
    number: ?s.field("number", S.nullable(S.int)),
    hash: ?s.field("hash", S.nullable(S.string)),
    parentHash: ?s.field("parent_hash", S.nullable(S.string)),
    nonce: ?s.field("nonce", S.nullable(S.int)),
    sha3Uncles: ?s.field("sha3_uncles", S.nullable(S.string)),
    logsBloom: ?s.field("logs_bloom", S.nullable(S.string)),
    transactionsRoot: ?s.field("transactions_root", S.nullable(S.string)),
    stateRoot: ?s.field("state_root", S.nullable(S.string)),
    receiptsRoot: ?s.field("receipts_root", S.nullable(S.string)),
    miner: ?s.field("miner", S.nullable(S.string)),
    difficulty: ?s.field("difficulty", S.nullable(Ethers.BigInt.schema)),
    totalDifficulty: ?s.field("total_difficulty", S.nullable(Ethers.BigInt.schema)),
    extraData: ?s.field("extra_data", S.nullable(S.string)),
    size: ?s.field("size", S.nullable(Ethers.BigInt.schema)),
    gasLimit: ?s.field("gas_limit", S.nullable(Ethers.BigInt.schema)),
    gasUsed: ?s.field("gas_used", S.nullable(Ethers.BigInt.schema)),
    timestamp: ?s.field("timestamp", S.nullable(Ethers.BigInt.schema)),
    uncles: ?s.field("unclus", S.nullable(S.string)),
    baseFeePerGas: ?s.field("base_fee_per_gas", S.nullable(Ethers.BigInt.schema)),
  })

  // TODO: Should we use S.nullable or S.null (?)
  //Note all fields marked as "nullable" are not explicitly null since
  //the are option fields and nulls will be deserialized to option when
  //in an optional field with spice
  type transactionData = {
    blockHash?: string,
    blockNumber?: int,
    from?: unchecksummedEthAddress, //nullable
    gas?: Ethers.BigInt.t,
    gasPrice?: Ethers.BigInt.t, //nullable
    hash?: string,
    input?: string,
    nonce?: int,
    to?: unchecksummedEthAddress, //nullable
    transactionIndex?: int,
    value?: Ethers.BigInt.t,
    v?: string, //nullable
    r?: string, //nullable
    s?: string, //nullable
    maxPriorityFeePerGas?: Ethers.BigInt.t, //nullable
    maxFeePerGas?: Ethers.BigInt.t, //nullable
    chainId?: int, //nullable
    cumulativeGasUsed?: Ethers.BigInt.t,
    effectiveGasPrice?: Ethers.BigInt.t,
    gasUsed?: Ethers.BigInt.t,
    contractAddress?: unchecksummedEthAddress, //nullable
    logsBoom?: string,
    type_?: int, //nullable
    root?: string, //nullable
    status?: int, //nullable
    sighash?: string, //nullable
  }

  let transactionDataSchema = S.object((. s) => {
    blockHash: ?s.field("block_hash", S.nullable(S.string)),
    blockNumber: ?s.field("block_number", S.nullable(S.int)),
    from: ?s.field("from", S.nullable(S.string)),
    gas: ?s.field("nonce", S.nullable(Ethers.BigInt.schema)),
    gasPrice: ?s.field("gas_price", S.nullable(Ethers.BigInt.schema)),
    hash: ?s.field("hash", S.nullable(S.string)),
    input: ?s.field("input", S.nullable(S.string)),
    nonce: ?s.field("nonce", S.nullable(S.int)),
    to: ?s.field("to", S.nullable(S.string)),
    transactionIndex: ?s.field("transaction_index", S.nullable(S.int)),
    value: ?s.field("nonce", S.nullable(Ethers.BigInt.schema)),
    v: ?s.field("v", S.nullable(S.string)),
    r: ?s.field("r", S.nullable(S.string)),
    s: ?s.field("s", S.nullable(S.string)),
    maxPriorityFeePerGas: ?s.field("max_priority_fee_per_gas", S.nullable(Ethers.BigInt.schema)),
    maxFeePerGas: ?s.field("max_fee_per_gas", S.nullable(Ethers.BigInt.schema)),
    chainId: ?s.field("chain_id", S.nullable(S.int)),
    cumulativeGasUsed: ?s.field("cumulative_gas_used", S.nullable(Ethers.BigInt.schema)),
    effectiveGasPrice: ?s.field("effective_gas_price", S.nullable(Ethers.BigInt.schema)),
    gasUsed: ?s.field("gas_used", S.nullable(Ethers.BigInt.schema)),
    contractAddress: ?s.field("contract_address", S.nullable(S.string)),
    logsBoom: ?s.field("logs_bloom", S.nullable(S.string)),
    type_: ?s.field("type", S.nullable(S.int)),
    root: ?s.field("root", S.nullable(S.string)),
    status: ?s.field("status", S.nullable(S.int)),
    sighash: ?s.field("sighash", S.nullable(S.string)),
  })

  // TODO: Should we use S.nullable or S.null (?)
  //Note all fields marked as "nullable" are not explicitly null since
  //the are option fields and nulls will be deserialized to option when
  //in an optional field with spice
  type logData = {
    removed?: bool, //nullable
    index?: int,
    transactionIndex?: int,
    transactionHash?: string,
    blockHash?: string,
    blockNumber?: int,
    address?: unchecksummedEthAddress,
    data?: string,
    topic0?: Ethers.EventFilter.topic, //nullable
    topic1?: Ethers.EventFilter.topic, //nullable
    topic2?: Ethers.EventFilter.topic, //nullable
    topic3?: Ethers.EventFilter.topic, //nullable
  }

  let logDataSchema = S.object((. s) => {
    removed: ?s.field("removed", S.nullable(S.bool)),
    index: ?s.field("log_index", S.nullable(S.int)),
    transactionIndex: ?s.field("transaction_index", S.nullable(S.int)),
    transactionHash: ?s.field("transaction_hash", S.nullable(S.string)),
    blockHash: ?s.field("block_hash", S.nullable(S.string)),
    blockNumber: ?s.field("block_number", S.nullable(S.int)),
    address: ?s.field("address", S.nullable(S.string)),
    data: ?s.field("data", S.nullable(S.string)),
    topic0: ?s.field("topic0", S.nullable(S.string)),
    topic1: ?s.field("topic1", S.nullable(S.string)),
    topic2: ?s.field("topic2", S.nullable(S.string)),
    topic3: ?s.field("topic3", S.nullable(S.string)),
  })

  // TODO: Should we use S.nullable or S.null (?)dule ResponseTypes = {
  type data = {
    blocks?: array<blockData>,
    transactions?: array<transactionData>,
    logs?: array<logData>,
  }

  let dataSchema = S.object((. s) => {
    blocks: ?s.field("blocks", S.array(blockDataSchema)->S.nullable),
    transactions: ?s.field("transactions", S.array(transactionDataSchema)->S.nullable),
    logs: ?s.field("logs", S.array(logDataSchema)->S.nullable),
  })

  type queryResponse = {
    data: array<data>,
    archiveHeight: int,
    nextBlock: int,
    totalTime: int,
  }

  let queryResponseSchema = S.object((. s) => {
    data: s.field("data", S.array(dataSchema)),
    archiveHeight: s.field("archive_height", S.int),
    nextBlock: s.field("next_block", S.int),
    totalTime: s.field("total_execution_time", S.int),
  })
}

let executeHyperSyncQuery = (~serverUrl, ~postQueryBody: QueryTypes.postQueryBody): promise<
  result<ResponseTypes.queryResponse, QueryHelpers.queryError>,
> => {
  QueryHelpers.executeFetchRequest(
    ~endpoint=serverUrl ++ "/query",
    ~method=#POST,
    ~bodyAndEncoder=(postQueryBody, QueryTypes.postQueryBody_encode),
    ~responseSchema=ResponseTypes.queryResponseSchema,
    (),
  )
}

let getArchiveHeight = {
  let responseSchema = S.object((. s) => s.field("height", S.int))

  async (~serverUrl): result<int, QueryHelpers.queryError> => {
    await QueryHelpers.executeFetchRequest(
      ~endpoint=serverUrl ++ "/height",
      ~method=#GET,
      ~responseSchema,
      (),
    )
  }
}
