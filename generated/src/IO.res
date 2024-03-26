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

    // NOTE: calling initValue on an existing store item will override it. This function does no checks to make sure there isn't existing data that can get lost.
    let initValue = (self: t, ~key: StoreItem.key, ~entity: option<StoreItem.t>) => {
      let initialStoreRow: Types.inMemoryStoreRowEntity<StoreItem.t> = switch entity {
      | Some(entity) => InitialReadFromDb(AlreadySet(entity))
      | None => InitialReadFromDb(NotSet)
      }
      self.dict->Js.Dict.set(key->self.hasher, initialStoreRow)
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
      | Some(Updated(previous_values)) =>
        Updated({
          initial: previous_values.initial,
          latest: entity,
          history: Config.placeholder_is_near_head_of_chain_or_in_dev_mode
            ? previous_values.history->Belt.Array.concat([previous_values.latest])
            : [],
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
        | Updated({latest: Set(entity, _)}) => Some(entity)
        | Updated({latest: Delete(_)}) => None
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
  ~idsToLoad: LoadLayer.idsToLoad,
  ~dbReadFn: array<Belt.Set.String.value> => 'a,
  ~inMemStoreInitFn: ('b, ~key: 'c, ~entity: option<'d>) => unit,
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
        if Config.placeholder_is_near_head_of_chain_or_in_dev_mode {
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
  ~inMemStoreInitFn: ('b, ~key: 'c, ~entity: option<'a>) => unit,
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

let executeSetEntityWithHistory = (
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<'a>>,
  ~dbFunctionSet: (Postgres.sql, array<'b>) => promise<unit>,
  ~dbFunctionDelete: (Postgres.sql, array<string>) => promise<unit>,
  ~entityEncoder,
  ~entityType,
): promise<unit> => {
  let (entitiesToSet, idsToDelete, entityHistoriesToSet) = rows->Belt.Array.reduce(([], [], []), (
    (entitiesToSet, idsToDelete, entityHistoriesToSet),
    row,
  ) => {
    switch row {
    | Updated({latest, history}) =>
      let processEntity = (
        prev: (option<Types.eventIdentifier>, array<DbFunctions.entityHistoryItem>),
        entity: Types.entityUpdate<'a>,
      ) => {
        let processEntity = (
          eventIdentifier: Types.eventIdentifier,
          entity_id,
          params: option<string>,
        ) => {
          let (optPreviousEventIdentifier, entityHistory) = prev
          let entityHistory = switch optPreviousEventIdentifier {
          | Some(previousEventIdentifier) =>
            let historyItem: DbFunctions.entityHistoryItem = {
              chain_id: eventIdentifier.chainId,
              block_number: eventIdentifier.blockNumber,
              block_timestamp: eventIdentifier.blockTimestamp,
              log_index: eventIdentifier.logIndex,
              previous_chain_id: Some(previousEventIdentifier.chainId),
              previous_block_timestamp: Some(previousEventIdentifier.blockTimestamp),
              previous_block_number: Some(previousEventIdentifier.blockNumber),
              previous_log_index: Some(previousEventIdentifier.logIndex),
              entity_type: entityType,
              entity_id,
              params,
            }

            entityHistory->Belt.Array.concat([historyItem])
          | None =>
            let historyItem: DbFunctions.entityHistoryItem = {
              chain_id: eventIdentifier.chainId,
              block_number: eventIdentifier.blockNumber,
              block_timestamp: eventIdentifier.blockTimestamp,
              previous_chain_id: None,
              previous_block_timestamp: None,
              previous_block_number: None,
              previous_log_index: None,
              log_index: eventIdentifier.logIndex,
              entity_type: entityType,
              entity_id,
              params,
            }

            [historyItem]
          }

          (Some(eventIdentifier), entityHistory)
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
        }
      }

      let (_, entityHistory) =
        history->Belt.Array.concat([latest])->Belt.Array.reduce((None, []), processEntity)

      switch latest {
      | Set(entity, _eventIdentifier) => (
          entitiesToSet->Belt.Array.concat([entityEncoder(entity)]),
          idsToDelete,
          entityHistoriesToSet->Belt.Array.concat([entityHistory]),
        )
      | Delete(entityId, _eventIdentifier) => (
          entitiesToSet,
          idsToDelete->Belt.Array.concat([entityId]),
          entityHistoriesToSet->Belt.Array.concat([entityHistory]),
        )
      }
    | _ => (entitiesToSet, idsToDelete, entityHistoriesToSet)
    }
  })

  [
    sql->DbFunctions.EntityHistory.batchSet(
      ~entityHistoriesToSet=Belt.Array.concatMany(entityHistoriesToSet),
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
  ~entityEncoder,
  ~entityType as _,
): promise<unit> => {
  let (entitiesToSet, idsToDelete) = rows->Belt.Array.reduce(([], []), (
    (accumulatedSets, accumulatedDeletes),
    row,
  ) =>
    switch row {
    | Updated({latest: Set(entity, _eventIdentifier)}) => (
        Belt.Array.concat(accumulatedSets, [entityEncoder(entity)]),
        accumulatedDeletes,
      )
    | Updated({latest: Delete(entityId, _eventIdentifier)}) => (
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
  let entityDbExecutionComposer = Config.placeholder_is_near_head_of_chain_or_in_dev_mode
    ? executeDbFunctionsEntity
    : executeSetEntityWithHistory

  let placeholderDeleteFunction = (_sql: Postgres.sql, _ids: array<string>): promise<unit> =>
    Js.Promise.resolve()

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
    ~dbFunctionDelete=placeholderDeleteFunction,
    ~rows=inMemoryStore.user->InMemoryStore.User.values,
    ~entityEncoder=Types.userEntity_encode,
    ~entityType="User",
  )

  let res = await sql->Postgres.beginSql(sql => {
    [setEventSyncState, setRawEvents, setDynamicContracts, setUsers]->Belt.Array.map(dbFunc =>
      sql->dbFunc
    )
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
      blockTimestamp,
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
