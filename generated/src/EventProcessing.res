open Belt

let addEventToRawEvents = (
  event: Types.eventLog<'a>,
  ~inMemoryStore: IO.InMemoryStore.t,
  ~chainId,
  ~jsonSerializedParams: Js.Json.t,
  ~eventName: Types.eventName,
) => {
  let {
    blockNumber,
    logIndex,
    transactionIndex,
    transactionHash,
    srcAddress,
    blockHash,
    blockTimestamp,
  } = event

  let eventId = EventUtils.packEventIndex(~logIndex, ~blockNumber)
  let rawEvent: Types.rawEventsEntity = {
    chainId,
    eventId: eventId->Ethers.BigInt.toString,
    blockNumber,
    logIndex,
    transactionIndex,
    transactionHash,
    srcAddress,
    blockHash,
    blockTimestamp,
    eventType: eventName->Types.eventName_encode,
    params: jsonSerializedParams->Js.Json.stringify,
  }

  let eventIdStr = eventId->Ethers.BigInt.toString

  inMemoryStore.rawEvents->IO.InMemoryStore.RawEvents.set(
    ~key={chainId, eventId: eventIdStr},
    ~entity=rawEvent,
    ~dbOp=Set,
  )
}

let updateEventSyncState = (
  event: Types.eventLog<'a>,
  ~chainId,
  ~inMemoryStore: IO.InMemoryStore.t,
) => {
  let {blockNumber, logIndex, transactionIndex, blockTimestamp} = event
  let _ = inMemoryStore.eventSyncState->IO.InMemoryStore.EventSyncState.set(
    ~key=chainId,
    ~entity={
      chainId,
      blockTimestamp,
      blockNumber,
      logIndex,
      transactionIndex,
    },
    ~dbOp=Set,
  )
}

/** Construct an error object for the logger with event prameters*/
let getEventErr = (~msg, ~error, ~event: Types.eventLog<'a>, ~chainId, ~eventName) => {
  let eventInfoObj = {
    "eventName": eventName,
    "txHash": event.transactionHash,
    "blockNumber": event.blockNumber->Belt.Int.toString,
    "logIndex": event.logIndex->Belt.Int.toString,
    "transactionIndex": event.transactionIndex->Belt.Int.toString,
    "networkId": chainId,
  }
  {
    "msg": msg,
    "error": error,
    "event-details": eventInfoObj,
  }
}

/** Constructs an error object with a caught exception related to an event*/
let getEventErrWithExn = exn => {
  let (msg, error) = switch exn {
  | Js.Exn.Error(obj) =>
    switch Js.Exn.message(obj) {
    | Some(errMsg) =>
      Some((
        "Caught a JS exception in your ${eventName}.handler, please fix the error to keep the indexer running smoothly",
        errMsg,
      ))
    | None => None
    }
  | _ => None
  }->Belt.Option.getWithDefault((
    "Unknown error in your ${eventName}.handler, please review your code carefully and use the stack trace to help you find the issue.",
    "Unknown",
  ))

  getEventErr(~msg, ~error)
}

/** Constructs specific sync/async mismatch error */
let getSyncAsyncMismatchErr = (~event) =>
  getEventErr(
    ~error="Mismatched sync/async handler and context",
    ~msg="Unexpected mismatch between sync/async handler and context. Please contact the team.",
    ~event,
  )

/** Function composer for handling an event*/
let handleEvent = (
  ~inMemoryStore,
  ~chainId,
  ~serializer,
  ~context: Context.genericContextCreatorFunctions<'b, 'c, 'd>,
  ~handlerWithContextGetter: Handlers.handlerWithContextGetterSyncAsync<'a, 'b, 'c, 'd>,
  ~event,
  ~eventName,
  ~cb,
) => {
  event->updateEventSyncState(~chainId, ~inMemoryStore)

  let jsonSerializedParams = event.params->serializer

  event->addEventToRawEvents(~inMemoryStore, ~chainId, ~jsonSerializedParams, ~eventName)

  try {
    switch handlerWithContextGetter {
    | Sync({handler, contextGetter}) =>
      //Call the context getter here, ensures no stale values in the context
      //Since loaders and previous handlers have already run
      let context = contextGetter(context)
      handler(~event, ~context)
      cb(Ok())->ignore
    | Async({handler, contextGetter}) =>
      //Call the context getter here, ensures no stale values in the context
      //Since loaders and previous handlers have already run
      let context = contextGetter(context)
      handler(~event, ~context)
      ->Promise.thenResolve(_ => cb(Ok()))
      ->Promise.catch(exn => {
        cb(Error(exn))
        Promise.reject(exn)
      })
      ->ignore
    }
  } catch {
  // NOTE: we are only catching javascript errors here - please see docs on how to catch rescript errors too: https://rescript-lang.org/docs/manual/latest/exception
  | userCodeException =>
    let errorObj =
      userCodeException->getEventErrWithExn(
        ~event,
        ~chainId,
        ~eventName=eventName->Types.eventName_encode,
      )
    //Logger takes any type just currently bound to string
    let errorMessage = errorObj->Obj.magic

    context.log.errorWithExn(Js.Exn.asJsExn(userCodeException), errorMessage)
    cb(Error(userCodeException))->ignore
  }
}

let eventRouter = (item: Context.eventRouterEventAndContext, ~inMemoryStore, ~cb) => {
  let {event, chainId} = item

  switch event {
  | GreeterContract_NewGreetingWithContext(event, context) =>
    handleEvent(
      ~event,
      ~eventName=Greeter_NewGreeting,
      ~serializer=Types.GreeterContract.NewGreetingEvent.eventArgs_encode,
      ~handlerWithContextGetter=Handlers.GreeterContract.NewGreeting.getHandler(),
      ~chainId,
      ~inMemoryStore,
      ~cb,
      ~context,
    )

  | GreeterContract_ClearGreetingWithContext(event, context) =>
    handleEvent(
      ~event,
      ~eventName=Greeter_ClearGreeting,
      ~serializer=Types.GreeterContract.ClearGreetingEvent.eventArgs_encode,
      ~handlerWithContextGetter=Handlers.GreeterContract.ClearGreeting.getHandler(),
      ~chainId,
      ~inMemoryStore,
      ~cb,
      ~context,
    )
  }
}

let asyncGetters: Context.entityGetters = {
  getUser: id => DbFunctions.User.readEntities(DbFunctions.sql, [id]),
}

type dynamicContractRegistration = {
  registeringEventBlockNumber: int,
  registeringEventLogIndex: int,
  registeringEventChain: ChainMap.Chain.t,
  dynamicContracts: array<Types.dynamicContractRegistryEntity>,
}

type dynamicContractRegistrations = {
  //Its better to apply these in reverse so that we register them with
  //the fetcher from latest to earliest. That way there are less recursions
  registrationsReversed: list<dynamicContractRegistration>,
  unprocessedBatchReversed: list<Types.eventBatchQueueItem>,
  //Once a single registration happens, the rest of the batches
  //loaders should be run on an isolated in memory store so that
  //they don't affect state of the batch that will be processed
  inMemoryStore: IO.InMemoryStore.t,
}

type loadResponse<'a> = {
  val: 'a,
  dynamicContractRegistrations: option<dynamicContractRegistrations>,
}

type getReadEntitiesRes = loadResponse<
  array<(array<Types.entityRead>, Context.eventRouterEventAndContext)>,
>

/**
Composer for getting entitiesToLoad and dynamicContractRegistrations for a given event
*/
let composeGetReadEntity = (
  ~event,
  ~contextCreator,
  ~inMemoryStore,
  ~logger,
  ~asyncGetters,
  ~getLoader,
  ~item: Types.eventBatchQueueItem,
  ~entitiesToLoad,
  ~dynamicContractRegistrations: option<dynamicContractRegistrations>,
  ~eventWithContextAccessor,
  ~eventName,
  ~checkContractIsRegistered,
) => {
  let {chain} = item
  let chainId = chain->ChainMap.Chain.toChainId
  //If there are dynamic contracts, context loader should use the cloned in memory store
  //Otherwise we can use the passed in one
  let inMemoryStore =
    dynamicContractRegistrations->Option.mapWithDefault(inMemoryStore, d => d.inMemoryStore)

  let contextHelper: Context.genericContextCreatorFunctions<'a, 'b, 'c> = contextCreator(
    ~inMemoryStore,
    ~chainId,
    ~event,
    ~logger,
    ~asyncGetters,
  )

  let context = contextHelper.getLoaderContext()

  let loader = getLoader()

  try {
    loader(~event, ~context)
  } catch {
  // NOTE: we are only catching javascript errors here - please see docs on how to catch rescript errors too: https://rescript-lang.org/docs/manual/latest/exception
  | userCodeException =>
    let errorObj = userCodeException->getEventErrWithExn(~event, ~chainId, ~eventName)
    // NOTE: we could use the user `uerror` function instead rather than using a system error. This is debatable.
    logger->Logging.childErrorWithExn(userCodeException, errorObj)
  }

  let dynamicContracts = if item.hasRegisteredDynamicContracts->Option.getWithDefault(false) {
    //If an item has already been registered, it would have been
    //put back on the arbitrary events queue and is now being reprocessed
    []
  } else {
    contextHelper.getAddedDynamicContractRegistrations()->Array.keep(({
      contractAddress,
      contractType,
    }) => {
      !checkContractIsRegistered(~chain, ~contractAddress, ~contractName=contractType)
    })
  }

  let addToDynamicContractRegistrations = (
    ~registrationsReversed,
    ~unprocessedBatchReversed,
    ~inMemoryStore,
  ) => {
    //If there are any dynamic contract registrations, put this item in the unprocessedBatch flagged
    //with "hasRegisteredDynamicContracts" and return the same list of entitiesToLoad without the
    //current item
    let unprocessedBatchReversed = list{
      {...item, hasRegisteredDynamicContracts: true},
      ...unprocessedBatchReversed,
    }

    let dynamicContractRegistration = {
      dynamicContracts,
      registeringEventBlockNumber: event.blockNumber,
      registeringEventLogIndex: event.logIndex,
      registeringEventChain: chain,
    }
    let dynamicContractRegistrations = {
      unprocessedBatchReversed,
      registrationsReversed: list{dynamicContractRegistration, ...registrationsReversed},
      inMemoryStore,
    }->Some
    {val: entitiesToLoad, dynamicContractRegistrations}
  }

  switch dynamicContractRegistrations {
  | None =>
    if dynamicContracts->Array.length > 0 {
      //Clone the inMemoryStore
      let inMemoryStoreDeepClone = inMemoryStore->IO.InMemoryStore.clone

      addToDynamicContractRegistrations(
        ~registrationsReversed=list{},
        ~unprocessedBatchReversed=list{},
        ~inMemoryStore=inMemoryStoreDeepClone,
      )
    } else {
      //If there are no dynamic contract registrations, get the entities to load and
      //return a context with the event for the handlers
      let entitiesToLoad = entitiesToLoad->Array.concat([
        (
          contextHelper.getEntitiesToLoad(),
          (
            {
              chainId,
              event: eventWithContextAccessor(event, contextHelper),
            }: Context.eventRouterEventAndContext
          ),
        ),
      ])

      {val: entitiesToLoad, dynamicContractRegistrations: None}
    }
  | Some({unprocessedBatchReversed, registrationsReversed, inMemoryStore}) =>
    if dynamicContracts->Array.length > 0 {
      addToDynamicContractRegistrations(
        ~registrationsReversed,
        ~unprocessedBatchReversed,
        ~inMemoryStore,
      )
    } else {
      let unprocessedBatchReversed = list{item, ...unprocessedBatchReversed}

      let dynamicContractRegistrations = {
        unprocessedBatchReversed,
        registrationsReversed,
        inMemoryStore,
      }->Some
      {val: entitiesToLoad, dynamicContractRegistrations}
    }
  }
}

let rec getReadEntitiesInternal = (
  ~inMemoryStore,
  ~logger,
  ~entitiesToLoad,
  ~checkContractIsRegistered,
  ~dynamicContractRegistrations=None,
  eventBatch: list<Types.eventBatchQueueItem>,
): getReadEntitiesRes => {
  switch eventBatch {
  | list{} => {val: entitiesToLoad, dynamicContractRegistrations}
  | list{item, ...tail} => {
      let composer = composeGetReadEntity(
        ~entitiesToLoad,
        ~asyncGetters,
        ~inMemoryStore,
        ~logger,
        ~item,
        ~checkContractIsRegistered,
        ~dynamicContractRegistrations,
      )

      let res = switch item.event {
      | GreeterContract_NewGreeting(event) =>
        composer(
          ~event,
          ~contextCreator=Context.GreeterContract.NewGreetingEvent.contextCreator,
          ~getLoader=Handlers.GreeterContract.NewGreeting.getLoader,
          ~eventWithContextAccessor=Context.greeterContract_NewGreetingWithContext,
          ~eventName="Greeter.NewGreeting",
        )
      | GreeterContract_ClearGreeting(event) =>
        composer(
          ~event,
          ~contextCreator=Context.GreeterContract.ClearGreetingEvent.contextCreator,
          ~getLoader=Handlers.GreeterContract.ClearGreeting.getLoader,
          ~eventWithContextAccessor=Context.greeterContract_ClearGreetingWithContext,
          ~eventName="Greeter.ClearGreeting",
        )
      }

      //else keep getting read entities from batch
      tail->getReadEntitiesInternal(
        ~inMemoryStore,
        ~logger,
        ~entitiesToLoad=res.val,
        ~checkContractIsRegistered,
        ~dynamicContractRegistrations=res.dynamicContractRegistrations,
      )
    }
  }
}

let getReadEntities = getReadEntitiesInternal(~entitiesToLoad=[])

let loadReadEntities = async (
  ~inMemoryStore,
  ~eventBatch: list<Types.eventBatchQueueItem>,
  ~checkContractIsRegistered,
  ~logger: Pino.t,
): loadResponse<array<Context.eventRouterEventAndContext>> => {
  let {val: entitiesToLoad, dynamicContractRegistrations} =
    eventBatch->getReadEntities(~inMemoryStore, ~logger, ~checkContractIsRegistered)

  let (readEntitiesGrouped, contexts): (
    array<array<Types.entityRead>>,
    array<Context.eventRouterEventAndContext>,
  ) =
    entitiesToLoad->Array.unzip

  let readEntities = readEntitiesGrouped->Belt.Array.concatMany

  await IO.loadEntitiesToInMemStore(~inMemoryStore, ~entityBatch=readEntities)

  {val: contexts, dynamicContractRegistrations}
}

let registerProcessEventBatchMetrics = (
  ~logger,
  ~batchSize,
  ~loadDuration,
  ~handlerDuration,
  ~dbWriteDuration,
) => {
  logger->Logging.childTrace({
    "message": "Finished processing batch",
    "batch_size": batchSize,
    "loader_time_elapsed": loadDuration,
    "handlers_time_elapsed": handlerDuration,
    "write_time_elapsed": dbWriteDuration,
  })

  Prometheus.incrementLoadEntityDurationCounter(~duration=loadDuration)

  Prometheus.incrementEventRouterDurationCounter(~duration=handlerDuration)

  Prometheus.incrementExecuteBatchDurationCounter(~duration=dbWriteDuration)

  Prometheus.incrementEventsProcessedCounter(~number=batchSize)
}

let processEventBatch = async (
  ~eventBatch: list<Types.eventBatchQueueItem>,
  ~inMemoryStore: IO.InMemoryStore.t,
  ~checkContractIsRegistered,
) => {
  let logger = Logging.createChild(
    ~params={
      "context": "batch",
    },
  )

  let timeRef = Hrtime.makeTimer()

  let {val: eventBatchAndContext, dynamicContractRegistrations} = await loadReadEntities(
    ~inMemoryStore,
    ~eventBatch,
    ~logger,
    ~checkContractIsRegistered,
  )

  let elapsedAfterLoad = timeRef->Hrtime.timeSince->Hrtime.toMillis->Hrtime.intFromMillis

  await eventBatchAndContext->Belt.Array.reduce(Promise.resolve(), async (
    previousPromise,
    event,
  ) => {
    await previousPromise
    await Promise.make((resolve, reject) =>
      event->eventRouter(
        ~inMemoryStore,
        ~cb={
          res =>
            switch res {
            | Ok() => resolve(. ())
            | Error(exn) => reject(. exn)
            }
        },
      )
    )
  })

  let elapsedTimeAfterProcess = timeRef->Hrtime.timeSince->Hrtime.toMillis->Hrtime.intFromMillis
  await DbFunctions.sql->IO.executeBatch(~inMemoryStore)

  let elapsedTimeAfterDbWrite = timeRef->Hrtime.timeSince->Hrtime.toMillis->Hrtime.intFromMillis

  registerProcessEventBatchMetrics(
    ~logger,
    ~batchSize=eventBatchAndContext->Array.length,
    ~loadDuration=elapsedAfterLoad,
    ~handlerDuration=elapsedTimeAfterProcess - elapsedAfterLoad,
    ~dbWriteDuration=elapsedTimeAfterDbWrite - elapsedTimeAfterProcess,
  )

  {val: (), dynamicContractRegistrations}
}
