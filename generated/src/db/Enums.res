// Graphql Enum Type Variants
type enumType<'a> = {
  name: string,
  variants: array<'a>,
}

let mkEnum = (~name, ~variants) => {
  name,
  variants,
}

module type Enum = {
  type t
  let enum: enumType<t>
}

module EventType = {
  @genType
  type t =
    | @as("Greeter_NewGreeting") Greeter_NewGreeting
    | @as("Greeter_ClearGreeting") Greeter_ClearGreeting

  let schema = S.union([S.literal(Greeter_NewGreeting), S.literal(Greeter_ClearGreeting)])

  let name = "EVENT_TYPE"
  let variants = [Greeter_NewGreeting, Greeter_ClearGreeting]
  let enum = mkEnum(~name, ~variants)
}

module ContractType = {
  @genType
  type t = | @as("Greeter") Greeter

  let name = "CONTRACT_TYPE"
  let variants = [Greeter]
  let enum = mkEnum(~name, ~variants)
}

module EntityType = {
  @genType
  type t = | @as("User") User

  let schema = S.union([S.literal(User)])

  let name = "ENTITY_TYPE"
  let variants = [User]

  let enum = mkEnum(~name, ~variants)
}

module Status = {
  @genType
  type t =
    | @as("PENDING") PENDING
    | @as("Deleted") Deleted
    | @as("created") Created

  let default = PENDING
  let schema: S.t<t> = S.union([S.literal(PENDING), S.literal(Deleted), S.literal(Created)])

  let name = "Status"
  let variants = [PENDING, Deleted, Created]
  let enum = mkEnum(~name, ~variants)
}

let allEnums: array<module(Enum)> = [
  module(EventType),
  module(ContractType),
  module(EntityType),
  module(Status),
]
