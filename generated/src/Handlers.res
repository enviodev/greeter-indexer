type functionRegister = Loader | Handler

let mapFunctionRegisterName = (functionRegister: functionRegister) => {
  switch functionRegister {
  | Loader => "Loader"
  | Handler => "Handler"
  }
}

// This set makes sure that the warning doesn't print for every event of a type, but rather only prints the first time.
let hasPrintedWarning = Set.make()

@genType
type handlerFunction<'eventArgs, 'context, 'returned> = (
  ~event: Types.eventLog<'eventArgs>,
  ~context: 'context,
) => 'returned

@genType
type handlerWithContextGetter<
  'eventArgs,
  'context,
  'returned,
  'loaderContext,
  'handlerContextSync,
  'handlerContextAsync,
> = {
  handler: handlerFunction<'eventArgs, 'context, 'returned>,
  contextGetter: Context.genericContextCreatorFunctions<
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  > => 'context,
}

@genType
type handlerWithContextGetterSyncAsync<
  'eventArgs,
  'loaderContext,
  'handlerContextSync,
  'handlerContextAsync,
> = SyncAsync.t<
  handlerWithContextGetter<
    'eventArgs,
    'handlerContextSync,
    unit,
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  >,
  handlerWithContextGetter<
    'eventArgs,
    'handlerContextAsync,
    promise<unit>,
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  >,
>

@genType
type loader<'eventArgs, 'loaderContext> = (
  ~event: Types.eventLog<'eventArgs>,
  ~context: 'loaderContext,
) => unit

let getDefaultLoaderHandler: (
  ~functionRegister: functionRegister,
  ~eventName: string,
  ~event: 'a,
  ~context: 'b,
) => unit = (~functionRegister, ~eventName, ~event as _, ~context as _) => {
  let functionName = mapFunctionRegisterName(functionRegister)

  // Here we use this key to prevent flooding the users terminal with
  let repeatKey = `${eventName}-${functionName}`
  if !(hasPrintedWarning->Set.has(repeatKey)) {
    // Here are docs on the 'terminal hyperlink' formatting that I use to link to the docs: https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
    Logging.warn(
      `Skipped ${eventName} in the ${functionName}, as there is no ${functionName} registered. You need to implement a ${eventName}${functionName} method in your handler file or ignore this warning if you don't intend to implement it. Here are our docs on this topic: \\u001b]8;;https://docs.envio.dev/docs/event-handlers\u0007https://docs.envio.dev/docs/event-handlers\u001b]8;;\u0007`,
    )
    let _ = hasPrintedWarning->Set.add(repeatKey)
  }
}

let getDefaultLoaderHandlerWithContextGetter = (~functionRegister, ~eventName) => SyncAsync.Sync({
  handler: getDefaultLoaderHandler(~functionRegister, ~eventName),
  contextGetter: ctx => ctx.getHandlerContextSync(),
})

module GreeterContract = {
  module NewGreeting = {
    open Types.GreeterContract.NewGreetingEvent

    type handlerWithContextGetter = handlerWithContextGetterSyncAsync<
      eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    %%private(
      let newGreetingLoader: ref<option<loader<eventArgs, loaderContext>>> = ref(None)
      let newGreetingHandler: ref<option<handlerWithContextGetter>> = ref(None)
    )

    @genType
    let loader = loader => {
      newGreetingLoader := Some(loader)
    }

    @genType
    let handler = handler => {
      newGreetingHandler := Some(Sync({handler, contextGetter: ctx => ctx.getHandlerContextSync()}))
    }

    // Silence the "this statement never returns (or has an unsound type.)" warning in the case that the user hasn't specified `isAsync` in their config file yet.
    @warning("-21") @genType
    let handlerAsync = handler => {
      newGreetingHandler :=
        Some(Async({handler, contextGetter: ctx => ctx.getHandlerContextAsync()}))
    }

    let getLoader = () =>
      newGreetingLoader.contents->Belt.Option.getWithDefault(
        getDefaultLoaderHandler(~eventName="NewGreeting", ~functionRegister=Loader),
      )

    let getHandler = () =>
      switch newGreetingHandler.contents {
      | Some(handler) => handler
      | None =>
        getDefaultLoaderHandlerWithContextGetter(
          ~eventName="NewGreeting",
          ~functionRegister=Handler,
        )
      }

    let handlerIsAsync = () => getHandler()->SyncAsync.isAsync
  }
  module ClearGreeting = {
    open Types.GreeterContract.ClearGreetingEvent

    type handlerWithContextGetter = handlerWithContextGetterSyncAsync<
      eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    %%private(
      let clearGreetingLoader: ref<option<loader<eventArgs, loaderContext>>> = ref(None)
      let clearGreetingHandler: ref<option<handlerWithContextGetter>> = ref(None)
    )

    @genType
    let loader = loader => {
      clearGreetingLoader := Some(loader)
    }

    @genType
    let handler = handler => {
      clearGreetingHandler :=
        Some(Sync({handler, contextGetter: ctx => ctx.getHandlerContextSync()}))
    }

    // Silence the "this statement never returns (or has an unsound type.)" warning in the case that the user hasn't specified `isAsync` in their config file yet.
    @warning("-21") @genType
    let handlerAsync = handler => {
      Js.Exn.raiseError("Please add 'isAsync: true' to your config.yaml file to enable Async Mode.")

      clearGreetingHandler :=
        Some(Async({handler, contextGetter: ctx => ctx.getHandlerContextAsync()}))
    }

    let getLoader = () =>
      clearGreetingLoader.contents->Belt.Option.getWithDefault(
        getDefaultLoaderHandler(~eventName="ClearGreeting", ~functionRegister=Loader),
      )

    let getHandler = () =>
      switch clearGreetingHandler.contents {
      | Some(handler) => handler
      | None =>
        getDefaultLoaderHandlerWithContextGetter(
          ~eventName="ClearGreeting",
          ~functionRegister=Handler,
        )
      }

    let handlerIsAsync = () => getHandler()->SyncAsync.isAsync
  }
}
