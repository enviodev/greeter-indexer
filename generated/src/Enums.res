// Graphql Enum Type Variants
@genType.as("Status")
type status = [
  | #PENDING
  | #Deleted
  | #Created
]
let statusDefault = #PENDING
let statusSchema: S.t<status> = S.union([
  S.literal(#PENDING),
  S.literal(#Deleted),
  S.literal("created")->S.variant((. _) => #Created),
])
