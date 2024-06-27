//*************
//***ENTITIES**
//*************
@genType.as("Id")
type id = string

@genType
type contractRegistrations = {
  //TODO only add contracts we've registered for the event in the config
  addGreeter: Ethers.ethAddress => unit,
}

@genType
type entityLoaderContext<'entity> = {get: id => promise<option<'entity>>}

@genType
type loaderContext = {
  log: Logs.userLogger,
  @as("User") user: entityLoaderContext<Entities.User.t>,
}

@genType
type entityHandlerContext<'entity> = {
  get: id => promise<option<'entity>>,
  set: 'entity => unit,
  deleteUnsafe: id => unit,
}

@genType
type handlerContext = {
  log: Logs.userLogger,
  @as("User") user: entityHandlerContext<Entities.User.t>,
}

//Re-exporting types for backwards compatability
@genType.as("User")
type user = Entities.User.t

type eventIdentifier = {
  chainId: int,
  blockTimestamp: int,
  blockNumber: int,
  logIndex: int,
}

type entityUpdateAction<'entityType> =
  | Set('entityType)
  | Delete

type entityUpdate<'entityType> = {
  eventIdentifier: eventIdentifier,
  shouldSaveHistory: bool,
  entityId: id,
  entityUpdateAction: entityUpdateAction<'entityType>,
}

let mkEntityUpdate = (~shouldSaveHistory=true, ~eventIdentifier, ~entityId, entityUpdateAction) => {
  entityId,
  shouldSaveHistory,
  eventIdentifier,
  entityUpdateAction,
}

type entityValueAtStartOfBatch<'entityType> =
  | NotSet // The entity isn't in the DB yet
  | AlreadySet('entityType)

type existingValueInDb<'entityType> =
  | Retrieved(entityValueAtStartOfBatch<'entityType>)
  // NOTE: We use an postgres function solve the issue of this entities previous value not being known.
  | Unknown

type updatedValue<'entityType> = {
  // Initial value within a batch
  initial: existingValueInDb<'entityType>,
  latest: entityUpdate<'entityType>,
  history: array<entityUpdate<'entityType>>,
}
@genType
type inMemoryStoreRowEntity<'entityType> =
  | Updated(updatedValue<'entityType>)
  | InitialReadFromDb(entityValueAtStartOfBatch<'entityType>) // This means there is no change from the db.

//*************
//**CONTRACTS**
//*************

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  txOrigin: option<Ethers.ethAddress>,
  txTo: option<Ethers.ethAddress>,
  blockNumber: int,
  blockTimestamp: int,
  blockHash: string,
  srcAddress: Ethers.ethAddress,
  transactionHash: string,
  transactionIndex: int,
  logIndex: int,
}

@genType
type eventName = Enums.EventType.t

let eventNameSchema = Enums.EventType.schema

let eventNameToString = (eventName: eventName) =>
  switch eventName {
  | Greeter_NewGreeting => "NewGreeting"
  | Greeter_ClearGreeting => "ClearGreeting"
  }

exception UnknownEvent(string, string)
let eventTopicToEventName = (contractName, topic0): Enums.EventType.t =>
  switch (contractName, topic0) {
  | ("Greeter", "0xcbc299eeb7a1a982d3674880645107c4fe48c3227163794e48540a7522722354") =>
    Greeter_NewGreeting
  | ("Greeter", "0xe1e180b6e25ff275b0367c82e362c09bda277674444b5549ebbd00406583882d") =>
    Greeter_ClearGreeting
  | (contractName, topic0) => UnknownEvent(contractName, topic0)->raise
  }

module type Event = {
  let eventName: Enums.EventType.t
  type eventArgs
  let eventArgsSchema: S.schema<eventArgs>
}

module Greeter = {
  module NewGreeting = {
    let eventName = Enums.EventType.Greeter_NewGreeting

    @genType
    type eventArgs = {
      user: Ethers.ethAddress,
      greeting: string,
    }

    let eventArgsSchema = S.object(s => {
      user: s.field("user", Ethers.ethAddressSchema),
      greeting: s.field("greeting", S.string),
    })

    @genType.as("Greeter_NewGreeting_EventLog")
    type log = eventLog<eventArgs>
  }

  module ClearGreeting = {
    let eventName = Enums.EventType.Greeter_ClearGreeting

    @genType
    type eventArgs = {user: Ethers.ethAddress}

    let eventArgsSchema = S.object(s => {
      user: s.field("user", Ethers.ethAddressSchema),
    })

    @genType.as("Greeter_ClearGreeting_EventLog")
    type log = eventLog<eventArgs>
  }
}

type event =
  | Greeter_NewGreeting(eventLog<Greeter.NewGreeting.eventArgs>)
  | Greeter_ClearGreeting(eventLog<Greeter.ClearGreeting.eventArgs>)

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

let mkEventBatchQueueItem = (
  ~hasRegisteredDynamicContracts=?,
  event,
  ~timestamp,
  ~chain,
  ~blockNumber,
  ~logIndex,
) => {
  timestamp,
  chain,
  blockNumber,
  logIndex,
  event,
  ?hasRegisteredDynamicContracts,
}
