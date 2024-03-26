type entityGetters = {getUser: Types.id => promise<array<Types.userEntity>>}

@genType
type genericContextCreatorFunctions<'loaderContext, 'handlerContextSync, 'handlerContextAsync> = {
  logger: Pino.t,
  log: Logs.userLogger,
  getLoaderContext: unit => 'loaderContext,
  getHandlerContextSync: unit => 'handlerContextSync,
  getHandlerContextAsync: unit => 'handlerContextAsync,
  getEntitiesToLoad: unit => array<Types.entityRead>,
  getAddedDynamicContractRegistrations: unit => array<Types.dynamicContractRegistryEntity>,
}

type contextCreator<'eventArgs, 'loaderContext, 'handlerContext, 'handlerContextAsync> = (
  ~inMemoryStore: IO.InMemoryStore.t,
  ~chainId: int,
  ~event: Types.eventLog<'eventArgs>,
  ~logger: Pino.t,
  ~asyncGetters: entityGetters,
) => genericContextCreatorFunctions<'loaderContext, 'handlerContext, 'handlerContextAsync>

let getEventIdentifier = (event: Types.eventLog<'a>, ~chainId): Types.eventIdentifier => {
  chainId,
  blockTimestamp: event.blockTimestamp,
  blockNumber: event.blockNumber,
  logIndex: event.logIndex,
}

exception UnableToLoadNonNullableLinkedEntity(string)
exception LinkedEntityNotAvailableInSyncHandler(string)

module GreeterContract = {
  module NewGreetingEvent = {
    type loaderContext = Types.GreeterContract.NewGreetingEvent.loaderContext
    type handlerContext = Types.GreeterContract.NewGreetingEvent.handlerContext
    type handlerContextAsync = Types.GreeterContract.NewGreetingEvent.handlerContextAsync
    type context = genericContextCreatorFunctions<
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    let contextCreator: contextCreator<
      Types.GreeterContract.NewGreetingEvent.eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    > = (~inMemoryStore, ~chainId, ~event, ~logger, ~asyncGetters) => {
      let eventIdentifier = event->getEventIdentifier(~chainId)
      // NOTE: we could optimise this code to onle create a logger if there was a log called.
      let logger = logger->Logging.createChildFrom(
        ~logger=_,
        ~params={
          "context": "Greeter.NewGreeting",
          "chainId": chainId,
          "block": event.blockNumber,
          "logIndex": event.logIndex,
          "txHash": event.transactionHash,
        },
      )

      let contextLogger: Logs.userLogger = {
        info: (message: string) => logger->Logging.uinfo(message),
        debug: (message: string) => logger->Logging.udebug(message),
        warn: (message: string) => logger->Logging.uwarn(message),
        error: (message: string) => logger->Logging.uerror(message),
        errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
          logger->Logging.uerrorWithExn(exn, message),
      }

      let optSetOfIds_user: Set.t<Types.id> = Set.make()

      let entitiesToLoad: array<Types.entityRead> = []

      let addedDynamicContractRegistrations: array<Types.dynamicContractRegistryEntity> = []

      //Loader context can be defined as a value and the getter can return that value

      @warning("-16")
      let loaderContext: loaderContext = {
        log: contextLogger,
        contractRegistration: {
          //TODO only add contracts we've registered for the event in the config
          addGreeter: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              contractAddress,
              contractType: "Greeter",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
            )
          },
        },
        user: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_user->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.UserRead(id))
          },
        },
      }

      //handler context must be defined as a getter functoin so that it can construct the context
      //without stale values whenever it is used
      let getHandlerContextSync: unit => handlerContext = () => {
        {
          log: contextLogger,
          user: {
            set: entity => {
              inMemoryStore.user->IO.InMemoryStore.User.set(
                ~key=entity.id,
                ~entity=Set(entity, eventIdentifier),
              )
            },
            delete: id =>
              Logging.warn(`[unimplemented delete] can't delete entity(user) with ID ${id}.`),
            get: (id: Types.id) => {
              if optSetOfIds_user->Set.has(id) {
                inMemoryStore.user->IO.InMemoryStore.User.get(id)
              } else {
                Logging.warn(
                  `The loader for a "User" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.user.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.user->IO.InMemoryStore.User.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
        }
      }

      let getHandlerContextAsync = (): handlerContextAsync => {
        {
          log: contextLogger,
          user: {
            set: entity => {
              inMemoryStore.user->IO.InMemoryStore.User.set(
                ~key=entity.id,
                ~entity=Set(entity, eventIdentifier),
              )
            },
            delete: id =>
              Logging.warn(`[unimplemented delete] can't delete entity(user) with ID ${id}.`),
            get: async (id: Types.id) => {
              if optSetOfIds_user->Set.has(id) {
                inMemoryStore.user->IO.InMemoryStore.User.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.user->IO.InMemoryStore.User.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getUser(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.User.initValue(inMemoryStore.user, ~key=id, ~entity=optEntity)

                  optEntity
                }
              }
            },
          },
        }
      }

      {
        logger,
        log: contextLogger,
        getEntitiesToLoad: () => entitiesToLoad,
        getAddedDynamicContractRegistrations: () => addedDynamicContractRegistrations,
        getLoaderContext: () => loaderContext,
        getHandlerContextSync,
        getHandlerContextAsync,
      }
    }
  }

  module ClearGreetingEvent = {
    type loaderContext = Types.GreeterContract.ClearGreetingEvent.loaderContext
    type handlerContext = Types.GreeterContract.ClearGreetingEvent.handlerContext
    type handlerContextAsync = Types.GreeterContract.ClearGreetingEvent.handlerContextAsync
    type context = genericContextCreatorFunctions<
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    let contextCreator: contextCreator<
      Types.GreeterContract.ClearGreetingEvent.eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    > = (~inMemoryStore, ~chainId, ~event, ~logger, ~asyncGetters) => {
      let eventIdentifier = event->getEventIdentifier(~chainId)
      // NOTE: we could optimise this code to onle create a logger if there was a log called.
      let logger = logger->Logging.createChildFrom(
        ~logger=_,
        ~params={
          "context": "Greeter.ClearGreeting",
          "chainId": chainId,
          "block": event.blockNumber,
          "logIndex": event.logIndex,
          "txHash": event.transactionHash,
        },
      )

      let contextLogger: Logs.userLogger = {
        info: (message: string) => logger->Logging.uinfo(message),
        debug: (message: string) => logger->Logging.udebug(message),
        warn: (message: string) => logger->Logging.uwarn(message),
        error: (message: string) => logger->Logging.uerror(message),
        errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
          logger->Logging.uerrorWithExn(exn, message),
      }

      let optSetOfIds_user: Set.t<Types.id> = Set.make()

      let entitiesToLoad: array<Types.entityRead> = []

      let addedDynamicContractRegistrations: array<Types.dynamicContractRegistryEntity> = []

      //Loader context can be defined as a value and the getter can return that value

      @warning("-16")
      let loaderContext: loaderContext = {
        log: contextLogger,
        contractRegistration: {
          //TODO only add contracts we've registered for the event in the config
          addGreeter: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              contractAddress,
              contractType: "Greeter",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
            )
          },
        },
        user: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_user->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.UserRead(id))
          },
        },
      }

      //handler context must be defined as a getter functoin so that it can construct the context
      //without stale values whenever it is used
      let getHandlerContextSync: unit => handlerContext = () => {
        {
          log: contextLogger,
          user: {
            set: entity => {
              inMemoryStore.user->IO.InMemoryStore.User.set(
                ~key=entity.id,
                ~entity=Set(entity, eventIdentifier),
              )
            },
            delete: id =>
              Logging.warn(`[unimplemented delete] can't delete entity(user) with ID ${id}.`),
            get: (id: Types.id) => {
              if optSetOfIds_user->Set.has(id) {
                inMemoryStore.user->IO.InMemoryStore.User.get(id)
              } else {
                Logging.warn(
                  `The loader for a "User" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.user.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.user->IO.InMemoryStore.User.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
        }
      }

      let getHandlerContextAsync = (): handlerContextAsync => {
        {
          log: contextLogger,
          user: {
            set: entity => {
              inMemoryStore.user->IO.InMemoryStore.User.set(
                ~key=entity.id,
                ~entity=Set(entity, eventIdentifier),
              )
            },
            delete: id =>
              Logging.warn(`[unimplemented delete] can't delete entity(user) with ID ${id}.`),
            get: async (id: Types.id) => {
              if optSetOfIds_user->Set.has(id) {
                inMemoryStore.user->IO.InMemoryStore.User.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.user->IO.InMemoryStore.User.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getUser(id)

                  let optEntity = entities->Belt.Array.get(0)

                  IO.InMemoryStore.User.initValue(inMemoryStore.user, ~key=id, ~entity=optEntity)

                  optEntity
                }
              }
            },
          },
        }
      }

      {
        logger,
        log: contextLogger,
        getEntitiesToLoad: () => entitiesToLoad,
        getAddedDynamicContractRegistrations: () => addedDynamicContractRegistrations,
        getLoaderContext: () => loaderContext,
        getHandlerContextSync,
        getHandlerContextAsync,
      }
    }
  }
}

@deriving(accessors)
type eventAndContext =
  | GreeterContract_NewGreetingWithContext(
      Types.eventLog<Types.GreeterContract.NewGreetingEvent.eventArgs>,
      GreeterContract.NewGreetingEvent.context,
    )
  | GreeterContract_ClearGreetingWithContext(
      Types.eventLog<Types.GreeterContract.ClearGreetingEvent.eventArgs>,
      GreeterContract.ClearGreetingEvent.context,
    )

type eventRouterEventAndContext = {
  chainId: int,
  event: eventAndContext,
}
