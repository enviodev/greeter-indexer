// Graphql Enum Type Variants
@genType.as("Status")
type status = | @as("PENDING") PENDING | @as("Deleted") Deleted | @as("created") Created
let statusDefault = PENDING
let statusSchema: S.t<status> = S.union([
  S.literal(PENDING),
  S.literal(Deleted),
  S.literal(Created),
])
