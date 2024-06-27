@genType
module Greeter = {
  module NewGreeting = RegisteredEvents.MakeRegister(Types.Greeter.NewGreeting)
  module ClearGreeting = RegisteredEvents.MakeRegister(Types.Greeter.ClearGreeting)
}
