module InMemoryStore = {
  type stringHasher<'val> = 'val => string

  type storeStateEntity<'entity, 'entityKey> = {
    dict: Js.Dict.t<Types.inMemoryStoreRowEntity<'entity>>,
    hasher: stringHasher<'entityKey>,
  }

  type storeStateMeta<'entity, 'entityKey> = {
    dict: Js.Dict.t<Types.inMemoryStoreRowMeta<'entity>>,
    hasher: stringHasher<'entityKey>,
  }

  module type StoreItem = {
    type t
    type key
    let hasher: stringHasher<key>
  }

  //Binding used for deep cloning stores in tests
  @val external structuredClone: 'a => 'a = "structuredClone"

  module MakeStoreEntity = (StoreItem: StoreItem) => {
    @genType
    type value = StoreItem.t
    @genType
    type key = StoreItem.key
    type t = storeStateEntity<value, key>

    let make = (): t => {dict: Js.Dict.empty(), hasher: StoreItem.hasher}

    let initValue = (
      // NOTE: This value is only set to true in the internals of the test framework to create the mockDb.
      ~allowOverWriteEntity=false,
      ~key: StoreItem.key,
      ~entity: option<StoreItem.t>,
      self: t,
    ) => {
      let shouldWriteEntity =
        allowOverWriteEntity || self.dict->Js.Dict.get(key->self.hasher)->Belt.Option.isNone

      //Only initialize a row in the case where it is none
      //or if allowOverWriteEntity is true (used for mockDb in test helpers)
      if shouldWriteEntity {
        let initialStoreRow: Types.inMemoryStoreRowEntity<StoreItem.t> = switch entity {
        | Some(entity) => InitialReadFromDb(AlreadySet(entity))
        | None => InitialReadFromDb(NotSet)
        }
        self.dict->Js.Dict.set(key->self.hasher, initialStoreRow)
      }
    }

    let set = (self: t, ~key: StoreItem.key, ~entity: Types.entityUpdate<StoreItem.t>) => {
      let mapKey = key->self.hasher
      let currentEntity = self.dict->Js.Dict.get(mapKey)
      let entityData: Types.inMemoryStoreRowEntity<StoreItem.t> = switch currentEntity {
      | Some(InitialReadFromDb(entity_read)) =>
        Updated({
          initial: Retrieved(entity_read),
          latest: entity,
          history: [],
        })
      | Some(Updated(previous_values))
        if !Config.shouldRollbackOnReorg ||
        //Rollback initial state cases should not save history
        !previous_values.latest.shouldSaveHistory ||
        // This prevents two db actions in the same event on the same entity from being recorded to the history table.
        previous_values.latest.eventIdentifier == entity.eventIdentifier =>
        Updated({
          ...previous_values,
          latest: entity,
        })
      | Some(Updated(previous_values)) =>
        Updated({
          initial: previous_values.initial,
          latest: entity,
          history: previous_values.history->Belt.Array.concat([previous_values.latest]),
        })
      | None =>
        Updated({
          initial: Unknown,
          latest: entity,
          history: [],
        })
      }
      self.dict->Js.Dict.set(mapKey, entityData)
    }

    let get = (self: t, key: StoreItem.key) =>
      self.dict
      ->Js.Dict.get(key->self.hasher)
      ->Belt.Option.flatMap(row => {
        switch row {
        | Updated({latest: {entityUpdateAction: Set(entity)}}) => Some(entity)
        | Updated({latest: {entityUpdateAction: Delete(_)}}) => None
        | InitialReadFromDb(AlreadySet(entity)) => Some(entity)
        | InitialReadFromDb(NotSet) => None
        }
      })

    let values = (self: t) => self.dict->Js.Dict.values

    let clone = (self: t) => {
      ...self,
      dict: self.dict->structuredClone,
    }
  }

  module MakeStoreMeta = (StoreItem: StoreItem) => {
    @genType
    type value = StoreItem.t
    @genType
    type key = StoreItem.key
    type t = storeStateMeta<value, key>

    let make = (): t => {dict: Js.Dict.empty(), hasher: StoreItem.hasher}

    let set = (self: t, ~key: StoreItem.key, ~entity: StoreItem.t) =>
      self.dict->Js.Dict.set(key->self.hasher, entity)

    let get = (self: t, key: StoreItem.key) =>
      self.dict->Js.Dict.get(key->self.hasher)->Belt.Option.map(row => row)

    let values = (self: t) => self.dict->Js.Dict.values

    let clone = (self: t) => {
      ...self,
      dict: self.dict->structuredClone,
    }
  }

  module EventSyncState = MakeStoreMeta({
    type t = DbFunctions.EventSyncState.eventSyncState
    type key = int
    let hasher = Belt.Int.toString
  })

  @genType
  type rawEventsKey = {
    chainId: int,
    eventId: string,
  }

  module RawEvents = MakeStoreMeta({
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

  module DynamicContractRegistry = MakeStoreMeta({
    type t = Types.dynamicContractRegistryEntity
    type key = dynamicContractRegistryKey
    let hasher = ({chainId, contractAddress}) =>
      EventUtils.getContractAddressKeyString(~chainId, ~contractAddress)
  })

  module User = MakeStoreEntity({
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
    rollBackEventIdentifier: option<Types.eventIdentifier>,
  }

  let makeWithRollBackEventIdentifier = (rollBackEventIdentifier): t => {
    eventSyncState: EventSyncState.make(),
    rawEvents: RawEvents.make(),
    dynamicContractRegistry: DynamicContractRegistry.make(),
    user: User.make(),
    rollBackEventIdentifier,
  }

  let make = () => makeWithRollBackEventIdentifier(None)

  let clone = (self: t) => {
    eventSyncState: self.eventSyncState->EventSyncState.clone,
    rawEvents: self.rawEvents->RawEvents.clone,
    dynamicContractRegistry: self.dynamicContractRegistry->DynamicContractRegistry.clone,
    user: self.user->User.clone,
    rollBackEventIdentifier: self.rollBackEventIdentifier->structuredClone,
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
  ~idsToLoad: LoadLayer.idsToLoad,
  ~dbReadFn: array<Belt.Set.String.value> => 'a,
  ~inMemStoreInitFn: (~allowOverWriteEntity: bool=?, ~key: 'c, ~entity: option<'d>, 'b) => unit,
  ~store: 'b,
  ~getEntiyId: 'd => 'c,
  ~unit: 'e,
  ~then: ('a, Belt.Array.t<'d> => unit) => 'e,
) => {
  idsToLoad,
  executor: idsToLoad => {
    switch idsToLoad->Belt.Set.String.toArray {
    | [] => unit //Check if there are values so we don't create an unnecessary empty query
    | idsToLoadArray =>
      idsToLoadArray
      ->dbReadFn
      ->then(entities => {
        entities->Belt.Array.forEach(entity => {
          store->inMemStoreInitFn(~key=entity->getEntiyId, ~entity=Some(entity))
        })
        if Config.shouldRollbackOnReorg {
          let setOfIdsNotSavedToDb =
            idsToLoad->Belt.Set.String.removeMany(entities->Belt.Array.map(getEntiyId))
          setOfIdsNotSavedToDb
          ->Belt.Set.String.toArray
          ->Belt.Array.forEach(entityId => {
            store->inMemStoreInitFn(~key=entityId, ~entity=None)
          })
        }
      })
    }
  },
}

/**
Specifically create an sql executor with async functionality
*/
let makeSqlEntityExecuter = (
  ~idsToLoad: LoadLayer.idsToLoad,
  ~dbReadFn: (Postgres.sql, array<Belt.Set.String.value>) => Promise.t<Belt.Array.t<'a>>,
  ~inMemStoreInitFn: (~allowOverWriteEntity: bool=?, ~key: 'c, ~entity: option<'a>, 'b) => unit,
  ~store: 'b,
  ~getEntiyId: 'a => 'c,
) => {
  makeEntityExecuterComposer(
    ~dbReadFn=DbFunctions.sql->dbReadFn,
    ~idsToLoad,
    ~getEntiyId,
    ~store,
    ~inMemStoreInitFn,
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
      ~inMemStoreInitFn=InMemoryStore.User.initValue,
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
  ~items: array<'a>,
  ~dbFunction: (Postgres.sql, array<'a>) => promise<unit>,
) => {
  if items->Array.length > 0 {
    sql->dbFunction(items)
  } else {
    Promise.resolve()
  }
}

let getEntityHistoryItems = (entityUpdates, ~entitySchema, ~entityType) => {
  let (_, entityHistoryItems) = entityUpdates->Belt.Array.reduce((None, []), (
    prev: (option<Types.eventIdentifier>, array<DbFunctions.entityHistoryItem>),
    entity: Types.entityUpdate<'a>,
  ) => {
    let (optPreviousEventIdentifier, entityHistoryItems) = prev

    let {eventIdentifier, shouldSaveHistory, entityUpdateAction} = entity
    let entityHistoryItems = if shouldSaveHistory {
      let mapPrev = Belt.Option.map(optPreviousEventIdentifier)
      let (entity_id, params) = switch entityUpdateAction {
      | Set(entity) => (
          (entity->Obj.magic)["id"],
          Some(entity->S.serializeOrRaiseWith(entitySchema)),
        )
      | Delete(event_id) => (event_id, None)
      }
      let historyItem: DbFunctions.entityHistoryItem = {
        chain_id: eventIdentifier.chainId,
        block_number: eventIdentifier.blockNumber,
        block_timestamp: eventIdentifier.blockTimestamp,
        log_index: eventIdentifier.logIndex,
        previous_chain_id: mapPrev(prev => prev.chainId),
        previous_block_timestamp: mapPrev(prev => prev.blockTimestamp),
        previous_block_number: mapPrev(prev => prev.blockNumber),
        previous_log_index: mapPrev(prev => prev.logIndex),
        entity_type: entityType,
        entity_id,
        params,
      }
      entityHistoryItems->Belt.Array.concat([historyItem])
    } else {
      entityHistoryItems
    }

    (Some(eventIdentifier), entityHistoryItems)
  })

  entityHistoryItems
}

let executeSetEntityWithHistory = (
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<'a>>,
  ~dbFunctionSet: (Postgres.sql, array<'b>) => promise<unit>,
  ~dbFunctionDelete: (Postgres.sql, array<string>) => promise<unit>,
  ~entitySchema,
  ~entityType,
): promise<unit> => {
  let (entitiesToSet, idsToDelete, entityHistoryItemsToSet) = rows->Belt.Array.reduce(
    ([], [], []),
    ((entitiesToSet, idsToDelete, entityHistoryItemsToSet), row) => {
      switch row {
      | Updated({latest, history}) =>
        let entityHistoryItems =
          history->Belt.Array.concat([latest])->getEntityHistoryItems(~entitySchema, ~entityType)

        switch latest.entityUpdateAction {
        | Set(entity) => (
            entitiesToSet->Belt.Array.concat([entity]),
            idsToDelete,
            entityHistoryItemsToSet->Belt.Array.concat([entityHistoryItems]),
          )
        | Delete(entityId) => (
            entitiesToSet,
            idsToDelete->Belt.Array.concat([entityId]),
            entityHistoryItemsToSet->Belt.Array.concat([entityHistoryItems]),
          )
        }
      | _ => (entitiesToSet, idsToDelete, entityHistoryItemsToSet)
      }
    },
  )

  [
    sql->DbFunctions.EntityHistory.batchSet(
      ~entityHistoriesToSet=Belt.Array.concatMany(entityHistoryItemsToSet),
    ),
    if entitiesToSet->Array.length > 0 {
      sql->dbFunctionSet(entitiesToSet)
    } else {
      Promise.resolve()
    },
    if idsToDelete->Array.length > 0 {
      sql->dbFunctionDelete(idsToDelete)
    } else {
      Promise.resolve()
    },
  ]
  ->Promise.all
  ->Promise.thenResolve(_ => ())
}

let executeDbFunctionsEntity = (
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<'a>>,
  ~dbFunctionSet: (Postgres.sql, array<'b>) => promise<unit>,
  ~dbFunctionDelete: (Postgres.sql, array<string>) => promise<unit>,
  ~entitySchema as _,
  ~entityType as _,
): promise<unit> => {
  let (entitiesToSet, idsToDelete) = rows->Belt.Array.reduce(([], []), (
    (accumulatedSets, accumulatedDeletes),
    row,
  ) =>
    switch row {
    | Updated({latest: {entityUpdateAction: Set(entity)}}) => (
        Belt.Array.concat(accumulatedSets, [entity]),
        accumulatedDeletes,
      )
    | Updated({latest: {entityUpdateAction: Delete(entityId)}}) => (
        accumulatedSets,
        Belt.Array.concat(accumulatedDeletes, [entityId]),
      )
    | _ => (accumulatedSets, accumulatedDeletes)
    }
  )

  let promises =
    (entitiesToSet->Array.length > 0 ? [sql->dbFunctionSet(entitiesToSet)] : [])->Belt.Array.concat(
      idsToDelete->Array.length > 0 ? [sql->dbFunctionDelete(idsToDelete)] : [],
    )

  promises->Promise.all->Promise.thenResolve(_ => ())
}

let executeBatch = async (sql, ~inMemoryStore: InMemoryStore.t) => {
  let entityDbExecutionComposer = Config.shouldRollbackOnReorg
    ? executeSetEntityWithHistory
    : executeDbFunctionsEntity

  let setEventSyncState = executeSet(
    ~dbFunction=DbFunctions.EventSyncState.batchSet,
    ~items=inMemoryStore.eventSyncState->InMemoryStore.EventSyncState.values,
  )

  let setRawEvents = executeSet(
    ~dbFunction=DbFunctions.RawEvents.batchSet,
    ~items=inMemoryStore.rawEvents->InMemoryStore.RawEvents.values,
  )

  let setDynamicContracts = executeSet(
    ~dbFunction=DbFunctions.DynamicContractRegistry.batchSet,
    ~items=inMemoryStore.dynamicContractRegistry->InMemoryStore.DynamicContractRegistry.values,
  )

  let setUsers = entityDbExecutionComposer(
    ~dbFunctionSet=DbFunctions.User.batchSet,
    ~dbFunctionDelete=DbFunctions.User.batchDelete,
    ~rows=inMemoryStore.user->InMemoryStore.User.values,
    ~entitySchema=Types.userEntitySchema,
    ~entityType="User",
  )

  //In the event of a rollback, rollback all meta tables based on the given
  //valid event identifier, where all rows created after this eventIdentifier should
  //be deleted
  let rollbackTables = switch inMemoryStore.rollBackEventIdentifier {
  | Some(eventIdentifier) =>
    [
      DbFunctions.EntityHistory.deleteAllEntityHistoryAfterEventIdentifier,
      DbFunctions.RawEvents.deleteAllRawEventsAfterEventIdentifier,
      DbFunctions.DynamicContractRegistry.deleteAllDynamicContractRegistrationsAfterEventIdentifier,
    ]->Belt.Array.map(fn => fn(~eventIdentifier))
  | None => []
  }

  let res = await sql->Postgres.beginSql(sql => {
    Belt.Array.concat(
      //Rollback tables need to happen first in the traction
      rollbackTables,
      [setEventSyncState, setRawEvents, setDynamicContracts, setUsers],
    )->Belt.Array.map(dbFunc => sql->dbFunc)
  })

  res
}

module RollBack = {
  exception DecodeError(S.error)
  let rollBack = async (~chainId, ~blockTimestamp, ~blockNumber, ~logIndex) => {
    let reorgData = switch await DbFunctions.sql->DbFunctions.EntityHistory.getRollbackDiff(
      ~chainId,
      ~blockTimestamp,
      ~blockNumber,
    ) {
    | Ok(v) => v
    | Error(exn) =>
      exn
      ->DecodeError
      ->ErrorHandling.logAndRaise(~msg="Failed to get rollback diff from entity history")
    }

    let rollBackEventIdentifier: Types.eventIdentifier = {
      chainId,
      blockTimestamp,
      blockNumber,
      logIndex,
    }

    let inMemStore = InMemoryStore.makeWithRollBackEventIdentifier(Some(rollBackEventIdentifier))

    reorgData->Belt.Array.forEach(e => {
      switch e {
      //Where previousEntity is Some,
      //set the value with the eventIdentifier that set that value initially
      | {previousEntity: Some({entity: UserEntity(entity), eventIdentifier}), entityId} =>
        inMemStore.user->InMemoryStore.User.set(
          ~entity=Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~shouldSaveHistory=false),
          ~key=entityId,
        )
      //Where previousEntity is None,
      //delete it with the eventIdentifier of the rollback event
      | {previousEntity: None, entityType: User, entityId} =>
        inMemStore.user->InMemoryStore.User.set(
          ~entity=Delete(entityId)->Types.mkEntityUpdate(
            ~eventIdentifier=rollBackEventIdentifier,
            ~shouldSaveHistory=false,
          ),
          ~key=entityId,
        )
      }
    })

    inMemStore
  }
}
