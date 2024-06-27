exception UndefinedEvent(string)
let eventStringToEvent = (eventName: string, contractName: string): Types.eventName => {
  switch (eventName, contractName) {
    | ("NewGreeting", "Greeter") => Greeter_NewGreeting
    | ("ClearGreeting", "Greeter") => Greeter_ClearGreeting
    | _ => UndefinedEvent(eventName)->raise
  }
}

module Greeter = {
  module NewGreeting = {
    let convertViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
      Types.Greeter.NewGreeting.eventArgs,
    > = Obj.magic

    let convertLogViem = (
      decodedEvent: Viem.decodedEvent<Types.Greeter.NewGreeting.eventArgs>,
      ~log: Ethers.log,
      ~blockTimestamp: int,
      ~chainId: int,
      ~txOrigin: option<Ethers.ethAddress>,
      ~txTo: option<Ethers.ethAddress>,
    ) => {
      let params: Types.Greeter.NewGreeting.eventArgs = 
      {
          user: decodedEvent.args.user,
          greeting: decodedEvent.args.greeting,
      }

      let eventLog: Types.eventLog<Types.Greeter.NewGreeting.eventArgs> = {
        params,
        chainId,
        txOrigin,
        txTo,
        blockNumber: log.blockNumber,
        blockTimestamp,
        blockHash: log.blockHash,
        srcAddress: log.address,
        transactionHash: log.transactionHash,
        transactionIndex: log.transactionIndex,
        logIndex: log.logIndex,
      }

      Types.Greeter_NewGreeting(eventLog)
    }

    let convertDecodedEventParams = ( 
      decodedEvent: HyperSyncClient.Decoder.decodedEvent,
    ): Types.Greeter.NewGreeting.eventArgs => {
      
      open Belt
      let fields = [
          "user",
          "greeting",
      ]
      let values =
        Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
          HyperSyncClient.Decoder.toUnderlying,
        )
      Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
    }
  }
  module ClearGreeting = {
    let convertViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
      Types.Greeter.ClearGreeting.eventArgs,
    > = Obj.magic

    let convertLogViem = (
      decodedEvent: Viem.decodedEvent<Types.Greeter.ClearGreeting.eventArgs>,
      ~log: Ethers.log,
      ~blockTimestamp: int,
      ~chainId: int,
      ~txOrigin: option<Ethers.ethAddress>,
      ~txTo: option<Ethers.ethAddress>,
    ) => {
      let params: Types.Greeter.ClearGreeting.eventArgs = 
      {
          user: decodedEvent.args.user,
      }

      let eventLog: Types.eventLog<Types.Greeter.ClearGreeting.eventArgs> = {
        params,
        chainId,
        txOrigin,
        txTo,
        blockNumber: log.blockNumber,
        blockTimestamp,
        blockHash: log.blockHash,
        srcAddress: log.address,
        transactionHash: log.transactionHash,
        transactionIndex: log.transactionIndex,
        logIndex: log.logIndex,
      }

      Types.Greeter_ClearGreeting(eventLog)
    }

    let convertDecodedEventParams = ( 
      decodedEvent: HyperSyncClient.Decoder.decodedEvent,
    ): Types.Greeter.ClearGreeting.eventArgs => {
      
      open Belt
      let fields = [
          "user",
      ]
      let values =
        Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
          HyperSyncClient.Decoder.toUnderlying,
        )
      Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
    }
  }
}


exception ParseError(Ethers.Interface.parseLogError)
exception UnregisteredContract(Ethers.ethAddress)

let makeEventLog = (
  params: 'args,
  ~log: Ethers.log,
  ~blockTimestamp: int,
  ~chainId: int,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): Types.eventLog<'args> => {
  chainId,
  params,
  txOrigin,
  txTo,
  blockNumber: log.blockNumber,
  blockTimestamp,
  blockHash: log.blockHash,
  srcAddress: log.address,
  transactionHash: log.transactionHash,
  transactionIndex: log.transactionIndex,
  logIndex: log.logIndex,
}

let convertDecodedEvent = (
  event: HyperSyncClient.Decoder.decodedEvent,
  ~contractInterfaceManager,
  ~log: Ethers.log,
  ~blockTimestamp,
  ~chainId,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): result<Types.event, _> => {
  switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
    ~contractAddress=log.address,
  ) {
  | None => Error(UnregisteredContract(log.address))
  | Some(contractName) =>
    let event = switch Types.eventTopicToEventName(contractName, log.topics[0]) {
        | Greeter_NewGreeting =>
            event
            ->Greeter.NewGreeting.convertDecodedEventParams
            ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
            ->Types.Greeter_NewGreeting
        | Greeter_ClearGreeting =>
            event
            ->Greeter.ClearGreeting.convertDecodedEventParams
            ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
            ->Types.Greeter_ClearGreeting
    }
    Ok(event)
  }
}

let parseEvent = (~log, ~blockTimestamp, ~contractInterfaceManager, ~chainId, ~txOrigin, ~txTo): Belt.Result.t<
  Types.event,
  _,
> => {
 let decodedEventResult = contractInterfaceManager->ContractInterfaceManager.parseLogViem(~log)
  switch decodedEventResult {
  | Error(e) =>
    switch e {
    | ParseError(parseError) => ParseError(parseError)
    | UndefinedInterface(contractAddress) => UnregisteredContract(contractAddress)
    }->Error

  | Ok(decodedEvent) =>
    switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
      ~contractAddress=log.address,
    ) {
    | None => Error(UnregisteredContract(log.address))
    | Some(contractName) =>
      let event = switch eventStringToEvent(decodedEvent.eventName, contractName) {
        | Greeter_NewGreeting =>
            decodedEvent
            ->Greeter.NewGreeting.convertViemDecodedEvent
            ->Greeter.NewGreeting.convertLogViem(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
        | Greeter_ClearGreeting =>
            decodedEvent
            ->Greeter.ClearGreeting.convertViemDecodedEvent
            ->Greeter.ClearGreeting.convertLogViem(~log, ~blockTimestamp, ~chainId, ~txOrigin, ~txTo)
      }

      Ok(event)
    }
  }
}

let decodeRawEventWith = (
  rawEvent: TablesStatic.RawEvents.t,
  ~schema: S.t<'a>,
  ~variantAccessor: Types.eventLog<'a> => Types.event,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): result<Types.eventBatchQueueItem, S.error> => {
  rawEvent.params
  ->S.parseJsonStringWith(schema)
  ->Belt.Result.map(params => {
    let event = {
      chainId: rawEvent.chainId,
      txOrigin,
      txTo,
      blockNumber: rawEvent.blockNumber,
      blockTimestamp: rawEvent.blockTimestamp,
      blockHash: rawEvent.blockHash,
      srcAddress: rawEvent.srcAddress,
      transactionHash: rawEvent.transactionHash,
      transactionIndex: rawEvent.transactionIndex,
      logIndex: rawEvent.logIndex,
      params,
    }->variantAccessor

    let queueItem: Types.eventBatchQueueItem = {
      timestamp: rawEvent.blockTimestamp,
      chain,
      blockNumber: rawEvent.blockNumber,
      logIndex: rawEvent.logIndex,
      event,
    }

    queueItem
  })
}


let parseRawEvent = (
  rawEvent: TablesStatic.RawEvents.t,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
  ~txTo: option<Ethers.ethAddress>,
): result<Types.eventBatchQueueItem, S.error> => {
  switch rawEvent.eventType {
      | Greeter_NewGreeting =>
      rawEvent->decodeRawEventWith(
        ~schema=Types.Greeter.NewGreeting.eventArgsSchema,
        ~variantAccessor=event => Types.Greeter_NewGreeting(event),
        ~chain,
        ~txOrigin,
        ~txTo,
      )
      | Greeter_ClearGreeting =>
      rawEvent->decodeRawEventWith(
        ~schema=Types.Greeter.ClearGreeting.eventArgsSchema,
        ~variantAccessor=event => Types.Greeter_ClearGreeting(event),
        ~chain,
        ~txOrigin,
        ~txTo,
      )
  }
}
