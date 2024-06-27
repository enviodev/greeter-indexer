open Table
open Enums.EntityType
type id = string

module type Entity = {
  type t
  let name: Enums.EntityType.t
  let schema: S.schema<t>
  let rowsSchema: S.schema<array<t>>
  let table: Table.table
}

let batchRead = (type entity, ~entityMod: module(Entity with type t = entity)) => {
  let module(EntityMod) = entityMod
  let {table, rowsSchema} = module(EntityMod)
  DbFunctionsEntities.makeReadEntities(~table, ~rowsSchema)
}

let batchSet = (type entity, ~entityMod: module(Entity with type t = entity)) => {
  let module(EntityMod) = entityMod
  let {table, rowsSchema} = module(EntityMod)
  DbFunctionsEntities.makeBatchSet(~table, ~rowsSchema)
}

let batchDelete = (type entity, ~entityMod: module(Entity with type t = entity)) => {
  let module(EntityMod) = entityMod
  let {table} = module(EntityMod)
  DbFunctionsEntities.makeBatchDelete(~table)
}

//shorthand for punning
let isPrimaryKey = true
let isNullable = true
let isArray = true
let isIndex = true

module User = {
  let name = User
  @genType
  type t = {
    greetings: array<string>,
    id: id,
    latestGreeting: string,
    numberOfGreetings: int,
  }

  let schema = S.object((. s) => {
    greetings: s.field("greetings", S.array(S.string)),
    id: s.field("id", S.string),
    latestGreeting: s.field("latestGreeting", S.string),
    numberOfGreetings: s.field("numberOfGreetings", S.int),
  })

  let rowsSchema = S.array(schema)

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "greetings", 
      Text,
      
      
      ~isArray,
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "latestGreeting", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "numberOfGreetings", 
      Integer,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", Timestamp, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 

type entity = 
  | User(User.t)

let makeGetter = (schema, accessor, json) => json->S.parseWith(. schema)->Belt.Result.map(accessor)

let getEntityParamsDecoder = (entityName: Enums.EntityType.t) =>
  switch entityName {
  | User => makeGetter(User.schema, e => User(e))
  }

let allTables: array<table> = [
  User.table,
]
let schema = Schema.make(allTables)
