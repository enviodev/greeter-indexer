open Belt

@genType 
type rawEventsKey = {
  chainId: int,
  eventId: string,
}

let hashRawEventsKey = (key: rawEventsKey) =>
  EventUtils.getEventIdKeyString(~chainId=key.chainId, ~eventId=key.eventId)

@genType 
type dynamicContractRegistryKey = {
  chainId: int,
  contractAddress: Ethers.ethAddress,
}

let hashDynamicContractRegistryKey = ({chainId, contractAddress}) =>
  EventUtils.getContractAddressKeyString(~chainId, ~contractAddress)

type t = {
  eventSyncState: InMemoryTable.t<int, TablesStatic.EventSyncState.t>,
  rawEvents: InMemoryTable.t<rawEventsKey, TablesStatic.RawEvents.t>,
  dynamicContractRegistry: InMemoryTable.t<
    dynamicContractRegistryKey,
    TablesStatic.DynamicContractRegistry.t,
  >,
  user: InMemoryTable.Entity.t<Entities.User.t>,
  rollBackEventIdentifier: option<Types.eventIdentifier>,
}

let makeWithRollBackEventIdentifier = (rollBackEventIdentifier): t => {
  eventSyncState: InMemoryTable.make(~hash=Int.toString),
  rawEvents: InMemoryTable.make(~hash=hashRawEventsKey),
  dynamicContractRegistry: InMemoryTable.make(~hash=hashDynamicContractRegistryKey),
  user: InMemoryTable.Entity.make(),
  rollBackEventIdentifier,
}

let make = () => makeWithRollBackEventIdentifier(None)

let clone = (self: t) => {
  eventSyncState: self.eventSyncState->InMemoryTable.clone,
  rawEvents: self.rawEvents->InMemoryTable.clone,
  dynamicContractRegistry: self.dynamicContractRegistry->InMemoryTable.clone,
  user: self.user->InMemoryTable.clone,
  rollBackEventIdentifier: self.rollBackEventIdentifier->InMemoryTable.structuredClone,
}
