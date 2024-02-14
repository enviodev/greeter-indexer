module InMemoryStore = {
  type stringHasher<'val> = 'val => string
  type storeState<'entity, 'entityKey> = {
    dict: Js.Dict.t<Types.inMemoryStoreRow<'entity>>,
    hasher: stringHasher<'entityKey>,
  }

  module type StoreItem = {
    type t
    type key
    let hasher: stringHasher<key>
  }

  //Binding used for deep cloning stores in tests
  @val external structuredClone: 'a => 'a = "structuredClone"

  module MakeStore = (StoreItem: StoreItem) => {
    @genType
    type value = StoreItem.t
    @genType
    type key = StoreItem.key
    type t = storeState<value, key>

    let make = (): t => {dict: Js.Dict.empty(), hasher: StoreItem.hasher}

    let set = (self: t, ~key: StoreItem.key, ~entity: Types.entityData<StoreItem.t>) => {
      let getOptEventIdentifier = (entity: Types.entityData<StoreItem.t>) => {
        switch entity {
        | Delete(_, eventIdentifier)
        | Set(_, eventIdentifier) =>
          Some(eventIdentifier)
        | Read(_) => None
        }
      }
      if Config.placeholder_is_near_head_of_chain_or_in_dev_mode {
        let mapKey = key->self.hasher
        let entityData: Types.inMemoryStoreRow<StoreItem.t> = switch self.dict->Js.Dict.get(
          mapKey,
        ) {
        | Some(existingEntityUpdate) =>
          switch entity {
          | Delete(_, eventIdentifier)
          | Set(_, eventIdentifier) =>
            // Use -1 as defaults for now
            let oldEntityIdentifier = getOptEventIdentifier(entity)->Belt.Option.getWithDefault({
              chainId: -1,
              timestamp: -1,
              blockNumber: -1,
              logIndex: -1,
            })
            if (
              eventIdentifier.blockNumber == oldEntityIdentifier.blockNumber &&
                eventIdentifier.logIndex == oldEntityIdentifier.logIndex
            ) {
              // If it is in the same event, override the current event with the new one
              {
                ...existingEntityUpdate,
                current: entity,
              }
            } else {
              // in a different event, add it to the histor.
              {
                current: entity,
                history: existingEntityUpdate.history->Belt.Array.concat([
                  existingEntityUpdate.current,
                ]),
              }
            }
          | Read(_) => {
              current: entity,
              history: existingEntityUpdate.history,
            }
          }
        | None => {
            current: entity,
            history: [],
          }
        }
        self.dict->Js.Dict.set(mapKey, entityData)
      } else {
        //Wont do for hackathon
        ()
      }
    }

    let get = (self: t, key: StoreItem.key) =>
      self.dict
      ->Js.Dict.get(key->self.hasher)
      ->Belt.Option.flatMap(row => {
        switch row.current {
        | Set(entity, _eventIdentifier) => Some(entity)
        | Delete(_key, _eventid) => None
        | Read(entity) => Some(entity)
        }
      })

    let values = (self: t) => self.dict->Js.Dict.values

    let clone = (self: t) => {
      ...self,
      dict: self.dict->structuredClone,
    }
  }

  module EventSyncState = MakeStore({
    type t = DbFunctions.EventSyncState.eventSyncState
    type key = int
    let hasher = Belt.Int.toString
  })

  @genType
  type rawEventsKey = {
    chainId: int,
    eventId: string,
  }

  module RawEvents = MakeStore({
    type t = Types.rawEventsEntity
    type key = rawEventsKey
    let hasher = (key: key) =>
      EventUtils.getEventIdKeyString(~chainId=key.chainId, ~eventId=key.eventId)
  })

  @genType
  type dynamicContractRegistryKey = {
    chainId: int,
    contractAddress: Ethers.ethAddress,
  }

  module DynamicContractRegistry = MakeStore({
    type t = Types.dynamicContractRegistryEntity
    type key = dynamicContractRegistryKey
    let hasher = ({chainId, contractAddress}) =>
      EventUtils.getContractAddressKeyString(~chainId, ~contractAddress)
  })

  module User = MakeStore({
    type t = Types.userEntity
    type key = string
    let hasher = Obj.magic
  })

  @genType
  type t = {
    eventSyncState: EventSyncState.t,
    rawEvents: RawEvents.t,
    dynamicContractRegistry: DynamicContractRegistry.t,
    user: User.t,
  }

  let make = (): t => {
    eventSyncState: EventSyncState.make(),
    rawEvents: RawEvents.make(),
    dynamicContractRegistry: DynamicContractRegistry.make(),
    user: User.make(),
  }

  let clone = (self: t) => {
    eventSyncState: self.eventSyncState->EventSyncState.clone,
    rawEvents: self.rawEvents->RawEvents.clone,
    dynamicContractRegistry: self.dynamicContractRegistry->DynamicContractRegistry.clone,
    user: self.user->User.clone,
  }
}

module LoadLayer = {
  /**The ids to load for a particular entity*/
  type idsToLoad = Belt.Set.String.t

  /**
  A round of entities to load from the DB. Depending on what entities come back
  and the dataLoaded "actions" that get run after the entities are loaded up. It
  could mean another load layer is created based of values that are returned
  */
  type rec t = {
    //A an array of getters to run after the entities with idsToLoad have been loaded
    dataLoadedActionsGetters: dataLoadedActionsGetters,
    //A unique list of ids that need to be loaded for entity user
    userIdsToLoad: idsToLoad,
  }
  //An action that gets run after the data is loaded in from the db to the in memory store
  //the action will derive values from the loaded data and update the next load layer
  and dataLoadedAction = t => t
  //A getter function that returns an array of actions that need to be run
  //Actions will fetch values from the in memory store and update a load layer
  and dataLoadedActionsGetter = unit => array<dataLoadedAction>
  //An array of getter functions for dataLoadedActions
  and dataLoadedActionsGetters = array<dataLoadedActionsGetter>

  /**Instantiates a load layer*/
  let emptyLoadLayer = () => {
    userIdsToLoad: Belt.Set.String.empty,
    dataLoadedActionsGetters: [],
  }

  /* Helper to append an ID to load for a given entity to the loadLayer */
  let extendIdsToLoad = (idsToLoad: idsToLoad, entityId: Types.id): idsToLoad =>
    idsToLoad->Belt.Set.String.add(entityId)

  /* Helper to append a getter for DataLoadedActions to load for a given entity to the loadLayer */
  let extendDataLoadedActionsGetters = (
    dataLoadedActionsGetters: dataLoadedActionsGetters,
    newDataLoadedActionsGetters: dataLoadedActionsGetters,
  ): dataLoadedActionsGetters =>
    dataLoadedActionsGetters->Belt.Array.concat(newDataLoadedActionsGetters)
}

//remove warning 39 for unused "rec" flag in case of no other related loaders
/**
Loader functions for each entity. The loader function extends a load layer with the given id and config.
*/
@warning("-39")
let rec userLinkedEntityLoader = (
  loadLayer: LoadLayer.t,
  ~entityId: string,
  ~inMemoryStore: InMemoryStore.t,
  ~userLoaderConfig: Types.userLoaderConfig,
): LoadLayer.t => {
  //No dataLoaded actions need to happen on the in memory
  //since there are no relational non-derivedfrom params
  let _ = inMemoryStore //ignore inMemoryStore and stop warning

  //In this case the "userLoaderConfig" type is a boolean.
  if !userLoaderConfig {
    //If userLoaderConfig is false, don't load the entity
    //simply return the current load layer
    loadLayer
  } else {
    //If userLoaderConfig is true,
    //extend the entity ids to load field
    //There can be no dataLoadedActionsGetters to add since this type does not contain
    //any non derived from relational params
    {
      ...loadLayer,
      userIdsToLoad: loadLayer.userIdsToLoad->LoadLayer.extendIdsToLoad(entityId),
    }
  }
}

/**
Creates and populates a load layer with the current in memory store and an array of entityRead variants
*/
let getLoadLayer = (~entityBatch: array<Types.entityRead>, ~inMemoryStore) => {
  entityBatch->Belt.Array.reduce(LoadLayer.emptyLoadLayer(), (loadLayer, readEntity) => {
    switch readEntity {
    | UserRead(entityId) =>
      loadLayer->userLinkedEntityLoader(~entityId, ~inMemoryStore, ~userLoaderConfig=true)
    }
  })
}

/**
Represents whether a deeper layer needs to be executed or whether the last layer
has been executed
*/
type nextLayer = NextLayer(LoadLayer.t) | LastLayer

let getNextLayer = (~loadLayer: LoadLayer.t) =>
  switch loadLayer.dataLoadedActionsGetters {
  | [] => LastLayer
  | dataLoadedActionsGetters =>
    dataLoadedActionsGetters
    ->Belt.Array.reduce(LoadLayer.emptyLoadLayer(), (loadLayer, getLoadedActions) => {
      //call getLoadedActions returns array of of actions to run against the load layer
      getLoadedActions()->Belt.Array.reduce(loadLayer, (loadLayer, action) => {
        action(loadLayer)
      })
    })
    ->NextLayer
  }

/**
Used for composing a loadlayer executor
*/
type entityExecutor<'executorRes> = {
  idsToLoad: LoadLayer.idsToLoad,
  executor: LoadLayer.idsToLoad => 'executorRes,
}

/**
Compose an execute load layer function. Used to compose an executor
for a postgres db or a mock db in the testing framework.
*/
let executeLoadLayerComposer = (
  ~entityExecutors: array<entityExecutor<'exectuorRes>>,
  ~handleResponses: array<'exectuorRes> => 'nextLoadlayer,
) => {
  entityExecutors
  ->Belt.Array.map(({idsToLoad, executor}) => {
    idsToLoad->executor
  })
  ->handleResponses
}

/**Recursively load layers with execute fn composer. Can be used with async or sync functions*/
let rec executeNestedLoadLayersComposer = (
  ~loadLayer,
  ~inMemoryStore,
  //Could be an execution function that is async or sync
  ~executeLoadLayerFn,
  //A call back function, for async or sync
  ~then,
  //Unit value, either wrapped in a promise or not
  ~unit,
) => {
  executeLoadLayerFn(~loadLayer, ~inMemoryStore)->then(res =>
    switch res {
    | LastLayer => unit
    | NextLayer(loadLayer) =>
      executeNestedLoadLayersComposer(~loadLayer, ~inMemoryStore, ~executeLoadLayerFn, ~then, ~unit)
    }
  )
}

/**Load all entities in the entity batch from the db to the inMemoryStore */
let loadEntitiesToInMemStoreComposer = (
  ~entityBatch,
  ~inMemoryStore,
  ~executeLoadLayerFn,
  ~then,
  ~unit,
) => {
  executeNestedLoadLayersComposer(
    ~inMemoryStore,
    ~loadLayer=getLoadLayer(~inMemoryStore, ~entityBatch),
    ~executeLoadLayerFn,
    ~then,
    ~unit,
  )
}

let makeEntityExecuterComposer = (
  ~idsToLoad,
  ~dbReadFn,
  ~inMemStoreSetFn,
  ~store,
  ~getEntiyId,
  ~unit,
  ~then,
) => {
  idsToLoad,
  executor: idsToLoad => {
    switch idsToLoad->Belt.Set.String.toArray {
    | [] => unit //Check if there are values so we don't create an unnecessary empty query
    | idsToLoad =>
      idsToLoad
      ->dbReadFn
      ->then(entities =>
        entities->Belt.Array.forEach(entity => {
          store->inMemStoreSetFn(~key=entity->getEntiyId, ~entity=Types.Read(entity))
        })
      )
    }
  },
}

/**
Specifically create an sql executor with async functionality
*/
let makeSqlEntityExecuter = (~idsToLoad, ~dbReadFn, ~inMemStoreSetFn, ~store, ~getEntiyId) => {
  makeEntityExecuterComposer(
    ~dbReadFn=DbFunctions.sql->dbReadFn,
    ~idsToLoad,
    ~getEntiyId,
    ~store,
    ~inMemStoreSetFn,
    ~then=Promise.thenResolve,
    ~unit=Promise.resolve(),
  )
}

/**
Executes a single load layer using the async sql functions
*/
let executeSqlLoadLayer = (~loadLayer: LoadLayer.t, ~inMemoryStore: InMemoryStore.t) => {
  let entityExecutors = [
    makeSqlEntityExecuter(
      ~idsToLoad=loadLayer.userIdsToLoad,
      ~dbReadFn=DbFunctions.User.readEntities,
      ~inMemStoreSetFn=InMemoryStore.User.set,
      ~store=inMemoryStore.user,
      ~getEntiyId=entity => entity.id,
    ),
  ]
  let handleResponses = responses => {
    responses
    ->Promise.all
    ->Promise.thenResolve(_ => {
      getNextLayer(~loadLayer)
    })
  }

  executeLoadLayerComposer(~entityExecutors, ~handleResponses)
}

/**Execute loading of entities using sql*/
let loadEntitiesToInMemStore = (~entityBatch, ~inMemoryStore) => {
  loadEntitiesToInMemStoreComposer(
    ~inMemoryStore,
    ~entityBatch,
    ~executeLoadLayerFn=executeSqlLoadLayer,
    ~then=Promise.then,
    ~unit=Promise.resolve(),
  )
}

let executeSet = (
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRow<'a>>,
  ~dbFunction: (Postgres.sql, array<'b>) => promise<unit>,
) => {
  let executeSets = rows->Belt.Array.keepMap(row =>
    switch row.current {
    | Set(entity, _) => Some(entity)
    | _ => None
    }
  )

  if executeSets->Array.length > 0 {
    sql->dbFunction(executeSets)
  } else {
    Promise.resolve()
  }
}

let executeDelete = (
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRow<'a>>,
  ~dbFunction: (Postgres.sql, array<'b>) => promise<unit>,
) => {
  // TODO: implement me please (after hackathon)
  let _ = rows
  let _ = sql
  let _ = dbFunction
  Promise.resolve()
}

let executeSetSchemaEntity = (
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRow<'a>>,
  ~dbFunction: (Postgres.sql, array<'b>) => promise<unit>,
  ~entityEncoder,
  ~entityType,
) => {
  let historyArrayWithPrev = ref([])
  let historyArrayWithoutPrev = ref([])

  let executeSets = rows->Belt.Array.keepMap(row =>
    switch row.current {
    | Set(entity, _eventIdentifier) => {
        let _ =
          row.history
          ->Belt.Array.concat([row.current])
          ->Belt.Array.reduce(None, (optPrev: option<(int, int)>, entity) => {
            let processEntity = (
              eventIdentifier: Types.eventIdentifier,
              entity_id,
              params: option<string>,
            ) => {
              switch optPrev {
              | Some((previous_block_number, previous_log_index)) =>
                let historyItem: DbFunctions.entityHistoryItem = {
                  chain_id: eventIdentifier.chainId,
                  block_timestamp: eventIdentifier.timestamp,
                  block_number: eventIdentifier.blockNumber,
                  previous_block_number: Some(previous_block_number),
                  previous_log_index: Some(previous_log_index),
                  log_index: eventIdentifier.logIndex,
                  transaction_hash: "string",
                  entity_type: entityType,
                  entity_id,
                  params,
                }
                historyArrayWithPrev :=
                  historyArrayWithPrev.contents->Belt.Array.concat([historyItem])
              | None =>
                let historyItem: DbFunctions.entityHistoryItem = {
                  chain_id: eventIdentifier.chainId,
                  block_timestamp: eventIdentifier.timestamp,
                  block_number: eventIdentifier.blockNumber,
                  previous_block_number: None,
                  previous_log_index: None,
                  log_index: eventIdentifier.logIndex,
                  transaction_hash: "string",
                  entity_type: entityType,
                  entity_id,
                  params,
                }
                historyArrayWithoutPrev :=
                  historyArrayWithoutPrev.contents->Belt.Array.concat([historyItem])
              }

              Some((eventIdentifier.blockNumber, eventIdentifier.logIndex))
            }
            switch entity {
            | Set(entity, eventIdentifier) =>
              processEntity(
                (eventIdentifier: Types.eventIdentifier),
                (entity->Obj.magic)["id"],
                Some(entity->entityEncoder->Js.Json.stringify),
              )
            | Delete(entityId, eventIdentifier) =>
              processEntity((eventIdentifier: Types.eventIdentifier), entityId, None)
            | Read(_) =>
              Js.log("This IS an impossible state")
              None
            }
          })
        Some(entity->entityEncoder)
      }
    | _ => None
    }
  )

  if executeSets->Array.length > 0 {
    [
      sql->dbFunction(executeSets),
      sql->DbFunctions.EntityHistory.batchSet(
        ~withPrev=historyArrayWithPrev.contents,
        ~withoutPrev=historyArrayWithoutPrev.contents,
      ),
    ]
    ->Promise.all
    ->Promise.thenResolve(_ => ())
  } else {
    Promise.resolve()
  }
}

let executeBatch = async (sql, ~inMemoryStore: InMemoryStore.t) => {
  let setEventSyncState = executeSet(
    ~dbFunction=DbFunctions.EventSyncState.batchSet,
    ~rows=inMemoryStore.eventSyncState->InMemoryStore.EventSyncState.values,
  )

  let setRawEvents = executeSet(
    ~dbFunction=DbFunctions.RawEvents.batchSet,
    ~rows=inMemoryStore.rawEvents->InMemoryStore.RawEvents.values,
  )

  let setDynamicContracts = executeSet(
    ~dbFunction=DbFunctions.DynamicContractRegistry.batchSet,
    ~rows=inMemoryStore.dynamicContractRegistry->InMemoryStore.DynamicContractRegistry.values,
  )

  let deleteUsers = executeDelete(
    ~dbFunction=DbFunctions.User.batchDelete,
    ~rows=inMemoryStore.user->InMemoryStore.User.values,
  )

  let setUsers = executeSetSchemaEntity(
    ~dbFunction=DbFunctions.User.batchSet,
    ~rows=inMemoryStore.user->InMemoryStore.User.values,
    ~entityEncoder=Types.userEntity_encode,
    ~entityType="User",
  )

  let res = await sql->Postgres.beginSql(sql => {
    [
      setEventSyncState,
      setRawEvents,
      setDynamicContracts,
      deleteUsers,
      setUsers,
    ]->Belt.Array.map(dbFunc => sql->dbFunc)
  })

  res
}

module RollBack = {
  let rollBack = async (~chainId, ~blockTimestamp, ~blockNumber, ~logIndex) => {
    let reorgData =
      (await DbFunctions.sql
      ->DbFunctions.EntityHistory.getRollbackDiff(~chainId, ~blockTimestamp, ~blockNumber))
      ->Belt.Result.getExn

    let rollBackEventIdentifier: Types.eventIdentifier = {
      chainId,
      timestamp: blockTimestamp,
      blockNumber,
      logIndex,
    }

    let inMemStore = InMemoryStore.make()

    reorgData->Belt.Array.forEach(e => {
      switch e {
      //Where previousEntity is Some,
      //set the value with the eventIdentifier that set that value initially
      | {previousEntity: Some({entity: UserEntity(entity), eventIdentifier}), entityId} =>
        inMemStore.user->InMemoryStore.User.set(~entity=Set(entity, eventIdentifier), ~key=entityId)
      //Where previousEntity is None,
      //delete it with the eventIdentifier of the rollback event
      | {previousEntity: None, entityType: User, entityId} =>
        inMemStore.user->InMemoryStore.User.set(
          ~entity=Delete(entityId, rollBackEventIdentifier),
          ~key=entityId,
        )
      }
    })

    inMemStore
  }
}
