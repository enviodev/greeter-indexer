@val external import: string => promise<unit> = "import"

// @module external importEventHandlers: unit = "../../src/EventHandlers"

// importEventHandlers

let registerContractHandlers = async (
  ~contractName,
  ~handlerPathRelativeToGeneratedSrc,
  ~handlerPathRelativeToConfig,
) => {
  try {
    await import(handlerPathRelativeToGeneratedSrc)
  } catch {
  | exn =>
    let params = {
      "Contract Name": contractName,
      "Expected Handler Path": handlerPathRelativeToConfig,
      "Code": "EE500",
    }
    let logger = Logging.createChild(~params)

    let errHandler = exn->ErrorHandling.make(~msg="Failed to import handler file", ~logger)
    errHandler->ErrorHandling.log
    errHandler->ErrorHandling.raiseExn
  }
}

let registerAllHandlers = async () => {
  await registerContractHandlers(
    ~contractName="Greeter",
     ~handlerPathRelativeToGeneratedSrc="../../src/EventHandlers.ts",
    ~handlerPathRelativeToConfig="src/EventHandlers.ts",
  )
}
