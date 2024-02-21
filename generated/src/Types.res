//*************
//***ENTITIES**
//*************
@spice @genType.as("Id")
type id = string

@@warning("-30")
@genType
type rec userLoaderConfig = bool

@@warning("+30")
@genType
type entityRead = UserRead(id)

@genType
type rawEventsEntity = {
  @as("chain_id") chainId: int,
  @as("event_id") eventId: string,
  @as("block_number") blockNumber: int,
  @as("log_index") logIndex: int,
  @as("transaction_index") transactionIndex: int,
  @as("transaction_hash") transactionHash: string,
  @as("src_address") srcAddress: Ethers.ethAddress,
  @as("block_hash") blockHash: string,
  @as("block_timestamp") blockTimestamp: int,
  @as("event_type") eventType: Js.Json.t,
  params: string,
}

@genType
type dynamicContractRegistryEntity = {
  @as("chain_id") chainId: int,
  @as("event_id") eventId: Ethers.BigInt.t,
  @as("contract_address") contractAddress: Ethers.ethAddress,
  @as("contract_type") contractType: string,
}

@spice @genType.as("UserEntity")
type userEntity = {
  numberOfGreetings: int,
  latestGreeting: string,
  id: id,
  greetings: array<string>,
}

type entity = UserEntity(userEntity)

type dbOp = Read | Set | Delete

@genType
type inMemoryStoreRow<'a> = {
  dbOp: dbOp,
  entity: 'a,
}

//*************
//**CONTRACTS**
//*************

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  txOrigin: option<Ethers.ethAddress>,
  blockNumber: int,
  blockTimestamp: int,
  blockHash: string,
  srcAddress: Ethers.ethAddress,
  transactionHash: string,
  transactionIndex: int,
  logIndex: int,
}

module GreeterContract = {
  module NewGreetingEvent = {
    //Note: each parameter is using a binding of its index to help with binding in ethers
    //This handles both unamed params and also named params that clash with reserved keywords
    //eg. if an event param is called "values" it will clash since eventArgs will have a '.values()' iterator
    type ethersEventArgs = {
      @as("0") user: Ethers.ethAddress,
      @as("1") greeting: string,
    }

    @spice @genType
    type eventArgs = {
      user: Ethers.ethAddress,
      greeting: string,
    }

    @genType.as("GreeterContract_NewGreeting_EventLog")
    type log = eventLog<eventArgs>

    // Entity: User
    type userEntityHandlerContext = {
      get: id => option<userEntity>,
      set: userEntity => unit,
      delete: id => unit,
    }

    type userEntityHandlerContextAsync = {
      get: id => promise<option<userEntity>>,
      set: userEntity => unit,
      delete: id => unit,
    }

    @genType
    type handlerContext = {
      log: Logs.userLogger,
      @as("User") user: userEntityHandlerContext,
    }
    @genType
    type handlerContextAsync = {
      log: Logs.userLogger,
      @as("User") user: userEntityHandlerContextAsync,
    }

    @genType
    type userEntityLoaderContext = {load: id => unit}

    @genType
    type contractRegistrations = {
      //TODO only add contracts we've registered for the event in the config
      addGreeter: Ethers.ethAddress => unit,
    }
    @genType
    type loaderContext = {
      log: Logs.userLogger,
      contractRegistration: contractRegistrations,
      @as("User") user: userEntityLoaderContext,
    }
  }
  module ClearGreetingEvent = {
    //Note: each parameter is using a binding of its index to help with binding in ethers
    //This handles both unamed params and also named params that clash with reserved keywords
    //eg. if an event param is called "values" it will clash since eventArgs will have a '.values()' iterator
    type ethersEventArgs = {@as("0") user: Ethers.ethAddress}

    @spice @genType
    type eventArgs = {user: Ethers.ethAddress}

    @genType.as("GreeterContract_ClearGreeting_EventLog")
    type log = eventLog<eventArgs>

    // Entity: User
    type userEntityHandlerContext = {
      get: id => option<userEntity>,
      set: userEntity => unit,
      delete: id => unit,
    }

    type userEntityHandlerContextAsync = {
      get: id => promise<option<userEntity>>,
      set: userEntity => unit,
      delete: id => unit,
    }

    @genType
    type handlerContext = {
      log: Logs.userLogger,
      @as("User") user: userEntityHandlerContext,
    }
    @genType
    type handlerContextAsync = {
      log: Logs.userLogger,
      @as("User") user: userEntityHandlerContextAsync,
    }

    @genType
    type userEntityLoaderContext = {load: id => unit}

    @genType
    type contractRegistrations = {
      //TODO only add contracts we've registered for the event in the config
      addGreeter: Ethers.ethAddress => unit,
    }
    @genType
    type loaderContext = {
      log: Logs.userLogger,
      contractRegistration: contractRegistrations,
      @as("User") user: userEntityLoaderContext,
    }
  }
}

@deriving(accessors)
type event =
  | GreeterContract_NewGreeting(eventLog<GreeterContract.NewGreetingEvent.eventArgs>)
  | GreeterContract_ClearGreeting(eventLog<GreeterContract.ClearGreetingEvent.eventArgs>)

@spice
type eventName =
  | @spice.as("Greeter_NewGreeting") Greeter_NewGreeting
  | @spice.as("Greeter_ClearGreeting") Greeter_ClearGreeting

let eventNameToString = (eventName: eventName) =>
  switch eventName {
  | Greeter_NewGreeting => "NewGreeting"
  | Greeter_ClearGreeting => "ClearGreeting"
  }

exception UnknownEvent(string, string)
let eventTopicToEventName = (contractName, topic0) =>
  switch (contractName, topic0) {
  | ("Greeter", "0xcbc299eeb7a1a982d3674880645107c4fe48c3227163794e48540a7522722354") =>
    Greeter_NewGreeting
  | ("Greeter", "0xe1e180b6e25ff275b0367c82e362c09bda277674444b5549ebbd00406583882d") =>
    Greeter_ClearGreeting
  | (contractName, topic0) => UnknownEvent(contractName, topic0)->raise
  }

@genType
type chainId = int

type eventBatchQueueItem = {
  timestamp: int,
  chain: ChainMap.Chain.t,
  blockNumber: int,
  logIndex: int,
  event: event,
  //Default to false, if an event needs to
  //be reprocessed after it has loaded dynamic contracts
  //This gets set to true and does not try and reload events
  hasRegisteredDynamicContracts?: bool,
}
