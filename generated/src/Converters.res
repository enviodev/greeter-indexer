exception UndefinedEvent(string)
let eventStringToEvent = (eventName: string, contractName: string): Types.eventName => {
  switch (eventName, contractName) {
  | ("NewGreeting", "Greeter") => Greeter_NewGreeting
  | ("ClearGreeting", "Greeter") => Greeter_ClearGreeting
  | _ => UndefinedEvent(eventName)->raise
  }
}

module Greeter = {
  let convertNewGreetingViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
    Types.GreeterContract.NewGreetingEvent.eventArgs,
  > = Obj.magic

  let convertNewGreetingLogDescription = (log: Ethers.logDescription<'a>): Ethers.logDescription<
    Types.GreeterContract.NewGreetingEvent.eventArgs,
  > => {
    //Convert from the ethersLog type with indexs as keys to named key value object
    let ethersLog: Ethers.logDescription<Types.GreeterContract.NewGreetingEvent.ethersEventArgs> =
      log->Obj.magic
    let {args, name, signature, topic} = ethersLog

    {
      name,
      signature,
      topic,
      args: {
        user: args.user,
        greeting: args.greeting,
      },
    }
  }

  let convertNewGreetingLog = (
    logDescription: Ethers.logDescription<Types.GreeterContract.NewGreetingEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
  ) => {
    let params: Types.GreeterContract.NewGreetingEvent.eventArgs = {
      user: logDescription.args.user,
      greeting: logDescription.args.greeting,
    }

    let newGreetingLog: Types.eventLog<Types.GreeterContract.NewGreetingEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.GreeterContract_NewGreeting(newGreetingLog)
  }
  let convertNewGreetingLogViem = (
    decodedEvent: Viem.decodedEvent<Types.GreeterContract.NewGreetingEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
  ) => {
    let params: Types.GreeterContract.NewGreetingEvent.eventArgs = {
      user: decodedEvent.args.user,
      greeting: decodedEvent.args.greeting,
    }

    let newGreetingLog: Types.eventLog<Types.GreeterContract.NewGreetingEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.GreeterContract_NewGreeting(newGreetingLog)
  }

  let convertNewGreetingDecodedEventParams = (
    decodedEvent: HyperSyncClient.Decoder.decodedEvent,
  ): Types.GreeterContract.NewGreetingEvent.eventArgs => {
    open Belt
    let fields = ["user", "greeting"]
    let values =
      Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
        HyperSyncClient.Decoder.toUnderlying,
      )
    Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
  }
  let convertClearGreetingViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
    Types.GreeterContract.ClearGreetingEvent.eventArgs,
  > = Obj.magic

  let convertClearGreetingLogDescription = (log: Ethers.logDescription<'a>): Ethers.logDescription<
    Types.GreeterContract.ClearGreetingEvent.eventArgs,
  > => {
    //Convert from the ethersLog type with indexs as keys to named key value object
    let ethersLog: Ethers.logDescription<Types.GreeterContract.ClearGreetingEvent.ethersEventArgs> =
      log->Obj.magic
    let {args, name, signature, topic} = ethersLog

    {
      name,
      signature,
      topic,
      args: {
        user: args.user,
      },
    }
  }

  let convertClearGreetingLog = (
    logDescription: Ethers.logDescription<Types.GreeterContract.ClearGreetingEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
  ) => {
    let params: Types.GreeterContract.ClearGreetingEvent.eventArgs = {
      user: logDescription.args.user,
    }

    let clearGreetingLog: Types.eventLog<Types.GreeterContract.ClearGreetingEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.GreeterContract_ClearGreeting(clearGreetingLog)
  }
  let convertClearGreetingLogViem = (
    decodedEvent: Viem.decodedEvent<Types.GreeterContract.ClearGreetingEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
  ) => {
    let params: Types.GreeterContract.ClearGreetingEvent.eventArgs = {
      user: decodedEvent.args.user,
    }

    let clearGreetingLog: Types.eventLog<Types.GreeterContract.ClearGreetingEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.GreeterContract_ClearGreeting(clearGreetingLog)
  }

  let convertClearGreetingDecodedEventParams = (
    decodedEvent: HyperSyncClient.Decoder.decodedEvent,
  ): Types.GreeterContract.ClearGreetingEvent.eventArgs => {
    open Belt
    let fields = ["user"]
    let values =
      Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
        HyperSyncClient.Decoder.toUnderlying,
      )
    Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
  }
}

exception ParseError(Ethers.Interface.parseLogError)
exception UnregisteredContract(Ethers.ethAddress)

let parseEventEthers = (
  ~log,
  ~blockTimestamp,
  ~contractInterfaceManager,
  ~chainId,
  ~txOrigin,
): Belt.Result.t<Types.event, _> => {
  let logDescriptionResult = contractInterfaceManager->ContractInterfaceManager.parseLogEthers(~log)
  switch logDescriptionResult {
  | Error(e) =>
    switch e {
    | ParseError(parseError) => ParseError(parseError)
    | UndefinedInterface(contractAddress) => UnregisteredContract(contractAddress)
    }->Error

  | Ok(logDescription) =>
    switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
      ~contractAddress=log.address,
    ) {
    | None => Error(UnregisteredContract(log.address))
    | Some(contractName) =>
      let event = switch eventStringToEvent(logDescription.name, contractName) {
      | Greeter_NewGreeting =>
        logDescription
        ->Greeter.convertNewGreetingLogDescription
        ->Greeter.convertNewGreetingLog(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      | Greeter_ClearGreeting =>
        logDescription
        ->Greeter.convertClearGreetingLogDescription
        ->Greeter.convertClearGreetingLog(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      }

      Ok(event)
    }
  }
}

let makeEventLog = (
  params: 'args,
  ~log: Ethers.log,
  ~blockTimestamp: int,
  ~chainId: int,
  ~txOrigin: option<Ethers.ethAddress>,
): Types.eventLog<'args> => {
  chainId,
  params,
  txOrigin,
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
): result<Types.event, _> => {
  switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
    ~contractAddress=log.address,
  ) {
  | None => Error(UnregisteredContract(log.address))
  | Some(contractName) =>
    let event = switch Types.eventTopicToEventName(contractName, log.topics[0]) {
    | Greeter_NewGreeting =>
      event
      ->Greeter.convertNewGreetingDecodedEventParams
      ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      ->Types.GreeterContract_NewGreeting
    | Greeter_ClearGreeting =>
      event
      ->Greeter.convertClearGreetingDecodedEventParams
      ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      ->Types.GreeterContract_ClearGreeting
    }
    Ok(event)
  }
}

let parseEvent = (
  ~log,
  ~blockTimestamp,
  ~contractInterfaceManager,
  ~chainId,
  ~txOrigin,
): Belt.Result.t<Types.event, _> => {
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
        ->Greeter.convertNewGreetingViemDecodedEvent
        ->Greeter.convertNewGreetingLogViem(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      | Greeter_ClearGreeting =>
        decodedEvent
        ->Greeter.convertClearGreetingViemDecodedEvent
        ->Greeter.convertClearGreetingLogViem(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      }

      Ok(event)
    }
  }
}

let decodeRawEventWith = (
  rawEvent: Types.rawEventsEntity,
  ~decoder: Spice.decoder<'a>,
  ~variantAccessor: Types.eventLog<'a> => Types.event,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
): Spice.result<Types.eventBatchQueueItem> => {
  switch rawEvent.params->Js.Json.parseExn {
  | exception exn =>
    let message =
      exn
      ->Js.Exn.asJsExn
      ->Belt.Option.flatMap(jsexn => jsexn->Js.Exn.message)
      ->Belt.Option.getWithDefault("No message on exn")

    Spice.error(`Failed at JSON.parse. Error: ${message}`, rawEvent.params->Obj.magic)
  | v => Ok(v)
  }
  ->Belt.Result.flatMap(json => {
    json->decoder
  })
  ->Belt.Result.map(params => {
    let event = {
      chainId: rawEvent.chainId,
      txOrigin,
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
  rawEvent: Types.rawEventsEntity,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
): Spice.result<Types.eventBatchQueueItem> => {
  rawEvent.eventType
  ->Types.eventName_decode
  ->Belt.Result.flatMap(eventName => {
    switch eventName {
    | Greeter_NewGreeting =>
      rawEvent->decodeRawEventWith(
        ~decoder=Types.GreeterContract.NewGreetingEvent.eventArgs_decode,
        ~variantAccessor=Types.greeterContract_NewGreeting,
        ~chain,
        ~txOrigin,
      )
    | Greeter_ClearGreeting =>
      rawEvent->decodeRawEventWith(
        ~decoder=Types.GreeterContract.ClearGreetingEvent.eventArgs_decode,
        ~variantAccessor=Types.greeterContract_ClearGreeting,
        ~chain,
        ~txOrigin,
      )
    }
  })
}
