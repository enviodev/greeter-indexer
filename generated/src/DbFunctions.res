let config: Postgres.poolConfig = {
  ...Config.db,
  transform: {undefined: Js.null},
}
let sql = Postgres.makeSql(~config)

type chainId = int
type eventId = string
type blockNumberRow = {@as("block_number") blockNumber: int}

module ChainMetadata = {
  type chainMetadata = {
    @as("chain_id") chainId: int,
    @as("block_height") blockHeight: int,
    @as("start_block") startBlock: int,
  }

  @module("./DbFunctionsImplementation.js")
  external setChainMetadata: (Postgres.sql, chainMetadata) => promise<unit> = "setChainMetadata"

  let setChainMetadataRow = (~chainId, ~startBlock, ~blockHeight) => {
    sql->setChainMetadata({chainId, startBlock, blockHeight})
  }
}

module EventSyncState = {
  @genType
  type eventSyncState = {
    @as("chain_id") chainId: int,
    @as("block_number") blockNumber: int,
    @as("log_index") logIndex: int,
    @as("transaction_index") transactionIndex: int,
    @as("block_timestamp") blockTimestamp: int,
  }
  @module("./DbFunctionsImplementation.js")
  external readLatestSyncedEventOnChainIdArr: (
    Postgres.sql,
    ~chainId: int,
  ) => promise<array<eventSyncState>> = "readLatestSyncedEventOnChainId"

  let readLatestSyncedEventOnChainId = async (sql, ~chainId) => {
    let arr = await sql->readLatestSyncedEventOnChainIdArr(~chainId)
    arr->Belt.Array.get(0)
  }

  let getLatestProcessedBlockNumber = async (~chainId) => {
    let latestEventOpt = await sql->readLatestSyncedEventOnChainId(~chainId)
    latestEventOpt->Belt.Option.map(event => event.blockNumber)
  }

  @module("./DbFunctionsImplementation.js")
  external batchSet: (Postgres.sql, array<eventSyncState>) => promise<unit> =
    "batchSetEventSyncState"
}

module RawEvents = {
  type rawEventRowId = (chainId, eventId)
  @module("./DbFunctionsImplementation.js")
  external batchSet: (Postgres.sql, array<Types.rawEventsEntity>) => promise<unit> =
    "batchSetRawEvents"

  @module("./DbFunctionsImplementation.js")
  external batchDelete: (Postgres.sql, array<rawEventRowId>) => promise<unit> =
    "batchDeleteRawEvents"

  @module("./DbFunctionsImplementation.js")
  external readEntities: (
    Postgres.sql,
    array<rawEventRowId>,
  ) => promise<array<Types.rawEventsEntity>> = "readRawEventsEntities"

  @module("./DbFunctionsImplementation.js")
  external getRawEventsPageGtOrEqEventId: (
    Postgres.sql,
    ~chainId: chainId,
    ~eventId: Ethers.BigInt.t,
    ~limit: int,
    ~contractAddresses: array<Ethers.ethAddress>,
  ) => promise<array<Types.rawEventsEntity>> = "getRawEventsPageGtOrEqEventId"

  @module("./DbFunctionsImplementation.js")
  external getRawEventsPageWithinEventIdRangeInclusive: (
    Postgres.sql,
    ~chainId: chainId,
    ~fromEventIdInclusive: Ethers.BigInt.t,
    ~toEventIdInclusive: Ethers.BigInt.t,
    ~limit: int,
    ~contractAddresses: array<Ethers.ethAddress>,
  ) => promise<array<Types.rawEventsEntity>> = "getRawEventsPageWithinEventIdRangeInclusive"

  ///Returns an array with 1 block number (the highest processed on the given chainId)
  @module("./DbFunctionsImplementation.js")
  external readLatestRawEventsBlockNumberProcessedOnChainId: (
    Postgres.sql,
    chainId,
  ) => promise<array<blockNumberRow>> = "readLatestRawEventsBlockNumberProcessedOnChainId"

  let getLatestProcessedBlockNumber = async (~chainId) => {
    let row = await sql->readLatestRawEventsBlockNumberProcessedOnChainId(chainId)

    row->Belt.Array.get(0)->Belt.Option.map(row => row.blockNumber)
  }
}

module DynamicContractRegistry = {
  type contractAddress = Ethers.ethAddress
  type dynamicContractRegistryRowId = (chainId, contractAddress)
  @module("./DbFunctionsImplementation.js")
  external batchSet: (Postgres.sql, array<Types.dynamicContractRegistryEntity>) => promise<unit> =
    "batchSetDynamicContractRegistry"

  @module("./DbFunctionsImplementation.js")
  external batchDelete: (Postgres.sql, array<dynamicContractRegistryRowId>) => promise<unit> =
    "batchDeleteDynamicContractRegistry"

  @module("./DbFunctionsImplementation.js")
  external readEntities: (
    Postgres.sql,
    array<dynamicContractRegistryRowId>,
  ) => promise<array<Types.dynamicContractRegistryEntity>> = "readDynamicContractRegistryEntities"

  type contractTypeAndAddress = {
    @as("contract_address") contractAddress: Ethers.ethAddress,
    @as("contract_type") contractType: string,
    @as("event_id") eventId: Ethers.BigInt.t,
  }

  ///Returns an array with 1 block number (the highest processed on the given chainId)
  @module("./DbFunctionsImplementation.js")
  external readDynamicContractsOnChainIdAtOrBeforeBlock: (
    Postgres.sql,
    ~chainId: chainId,
    ~startBlock: int,
  ) => promise<array<contractTypeAndAddress>> = "readDynamicContractsOnChainIdAtOrBeforeBlock"
}

@spice
type entityHistoryItem = {
  chain_id: int,
  previous_block_number: option<int>,
  previous_log_index: option<int>,
  block_timestamp: int,
  block_number: int,
  log_index: int,
  transaction_hash: string,
  entity_type: string,
  entity_id: string,
  params: option<string>,
}

module EntityHistory = {
  @module("./DbFunctionsImplementation.js")
  external batchSetInternal: (
    Postgres.sql,
    ~withPrev: array<Js.Json.t>,
    ~withoutPrev: array<entityHistoryItem>,
  ) => promise<unit> = "batchSetEntityHistoryTable"

  let batchSet = (~withPrev) => {
    //Encode null for for the with prev types so that it's not undefined
    batchSetInternal(~withPrev=withPrev->Belt.Array.map(entityHistoryItem_encode))
  }

  /**
  Ther raw response of a single row returned from postgres
  with the getRollbackDiff query
  */
  @spice
  type rollbackDiffResponseRaw = {
    entity_type: Types.entityName,
    entity_id: string,
    chain_id: option<int>,
    block_timestamp: option<int>,
    block_number: option<int>,
    log_index: option<int>,
    val: option<Js.Json.t>,
  }

  /**
  If there was an entity previously set with the rollback diff
  this is the entity value and its event eventIdentifier
  */
  type previousEntity = {
    eventIdentifier: Types.eventIdentifier,
    entity: Types.entity,
  }

  /**
  A sanitized version of the rollbackDiffResponseRaw, that
  represents valid state for rescript use
  */
  type rollbackDiffResponse = {
    entityType: Types.entityName,
    entityId: string,
    previousEntity: option<previousEntity>,
  }

  /**
  Takes the raw response from "getRollbackDiffInternal" and sanitizes
  it into "rollbackDiffResponse" type
  */
  let rollbackDiffResponse_decode = (json: Js.Json.t) => {
    json
    ->rollbackDiffResponseRaw_decode
    ->Belt.Result.flatMap(raw => {
      switch raw {
      | {
          val: Some(val),
          chain_id: Some(chainId),
          block_number: Some(blockNumber),
          block_timestamp: Some(timestamp),
          log_index: Some(logIndex),
          entity_type,
        } =>
        entity_type
        ->Types.getEntityParamsDecoder(val)
        ->Belt.Result.map(entity => {
          let eventIdentifier: Types.eventIdentifier = {
            chainId,
            timestamp,
            blockNumber,
            logIndex,
          }

          Some({entity, eventIdentifier})
        })
      | _ => Ok(None)
      }->Belt.Result.map(previousEntity => {
        entityType: raw.entity_type,
        entityId: raw.entity_id,
        previousEntity,
      })
    })
  }

  /**
  Decodes an array of raw rollback diff responses
  */
  let rollbackDiffResponseArr_decode = (jsonArr: array<Js.Json.t>) => {
    jsonArr->Belt.Array.map(rollbackDiffResponse_decode)->Utils.mapArrayOfResults
  }

  /**
  Gets unsanitized raw response from postgres
  */
  @module("./DbFunctionsImplementation.js")
  external getRollbackDiffInternal: (
    Postgres.sql,
    ~blockTimestamp: int,
    ~chainId: int,
    ~blockNumber: int,
  ) => promise<array<Js.Json.t>> = "getRollbackDiff"

  /**
  Gets sanitized array of rollbackDiffResponse from postgres
  */
  let getRollbackDiff = (sql, ~blockTimestamp: int, ~chainId: int, ~blockNumber: int) =>
    getRollbackDiffInternal(sql, ~blockTimestamp, ~chainId, ~blockNumber)->Promise.thenResolve(
      rollbackDiffResponseArr_decode,
    )
}

module User = {
  open Types

  let decodeUnsafe = (entityJson: Js.Json.t): userEntity => {
    let entityDecoded = switch entityJson->userEntity_decode {
    | Ok(v) => Ok(v)
    | Error(e) =>
      Logging.error({
        "err": e,
        "msg": "EE700: Unable to parse row from database of entity user using spice",
        "raw_unparsed_object": entityJson,
      })
      Error(e)
    }->Belt.Result.getExn

    entityDecoded
  }

  @module("./DbFunctionsImplementation.js")
  external batchSet: (Postgres.sql, array<Js.Json.t>) => promise<unit> = "batchSetUser"

  @module("./DbFunctionsImplementation.js")
  external batchDelete: (Postgres.sql, array<Types.id>) => promise<unit> = "batchDeleteUser"

  @module("./DbFunctionsImplementation.js")
  external readEntitiesFromDb: (Postgres.sql, array<Types.id>) => promise<array<Js.Json.t>> =
    "readUserEntities"

  let readEntities = async (sql: Postgres.sql, ids: array<Types.id>): array<userEntity> => {
    let res = await readEntitiesFromDb(sql, ids)
    res->Belt.Array.map(entityJson => entityJson->decodeUnsafe)
  }
}
