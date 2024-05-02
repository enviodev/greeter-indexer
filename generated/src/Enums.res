// Graphql Enum Type Variants
@spice @genType.as("Status")
type status = [
  | @spice.as("PENDING") #PENDING
  | @spice.as("Deleted") #Deleted
  | @spice.as("created") #Created
]
let statusDefault = #PENDING
let statusSchema: S.t<status> = S.union([
  S.literal(#PENDING),
  S.literal(#Deleted),
  S.literal("created")->S.variant((. _) => #Created),
])
