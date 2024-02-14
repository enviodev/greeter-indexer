// db operations for raw_events:
const MAX_ITEMS_PER_QUERY = 500;

module.exports.readLatestSyncedEventOnChainId = (sql, chainId) => sql`
  SELECT *
  FROM public.event_sync_state
  WHERE chain_id = ${chainId}`;

module.exports.batchSetEventSyncState = (sql, entityDataArray) => {
  return sql`
    INSERT INTO public.event_sync_state
  ${sql(
    entityDataArray,
    "chain_id",
    "block_number",
    "log_index",
    "transaction_index",
    "block_timestamp"
  )}
    ON CONFLICT(chain_id) DO UPDATE
    SET
    "chain_id" = EXCLUDED."chain_id",
    "block_number" = EXCLUDED."block_number",
    "log_index" = EXCLUDED."log_index",
    "transaction_index" = EXCLUDED."transaction_index",
    "block_timestamp" = EXCLUDED."block_timestamp";
    `;
};

module.exports.setChainMetadata = (sql, entityDataArray) => {
  return (sql`
    INSERT INTO public.chain_metadata
  ${sql(
    entityDataArray,
    "chain_id",
    "start_block", // this is left out of the on conflict below as it only needs to be set once
    "block_height"
  )}
  ON CONFLICT(chain_id) DO UPDATE
  SET
  "chain_id" = EXCLUDED."chain_id",
  "block_height" = EXCLUDED."block_height";`).then(res => {
    
  }).catch(err => {
    console.log("errored", err)
  });
};

module.exports.readLatestRawEventsBlockNumberProcessedOnChainId = (
  sql,
  chainId
) => sql`
  SELECT block_number
  FROM "public"."raw_events"
  WHERE chain_id = ${chainId}
  ORDER BY event_id DESC
  LIMIT 1;`;

module.exports.readRawEventsEntities = (sql, entityIdArray) => sql`
  SELECT *
  FROM "public"."raw_events"
  WHERE (chain_id, event_id) IN ${sql(entityIdArray)}`;

module.exports.getRawEventsPageGtOrEqEventId = (
  sql,
  chainId,
  eventId,
  limit,
  contractAddresses
) => sql`
  SELECT *
  FROM "public"."raw_events"
  WHERE "chain_id" = ${chainId}
  AND "event_id" >= ${eventId}
  AND "src_address" IN ${sql(contractAddresses)}
  ORDER BY "event_id" ASC
  LIMIT ${limit}
`;

module.exports.getRawEventsPageWithinEventIdRangeInclusive = (
  sql,
  chainId,
  fromEventIdInclusive,
  toEventIdInclusive,
  limit,
  contractAddresses
) => sql`
  SELECT *
  FROM public.raw_events
  WHERE "chain_id" = ${chainId}
  AND "event_id" >= ${fromEventIdInclusive}
  AND "event_id" <= ${toEventIdInclusive}
  AND "src_address" IN ${sql(contractAddresses)}
  ORDER BY "event_id" ASC
  LIMIT ${limit}
`;

const batchSetRawEventsCore = (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."raw_events"
  ${sql(
    entityDataArray,
    "chain_id",
    "event_id",
    "block_number",
    "log_index",
    "transaction_index",
    "transaction_hash",
    "src_address",
    "block_hash",
    "block_timestamp",
    "event_type",
    "params"
  )}
    ON CONFLICT(chain_id, event_id) DO UPDATE
    SET
    "chain_id" = EXCLUDED."chain_id",
    "event_id" = EXCLUDED."event_id",
    "block_number" = EXCLUDED."block_number",
    "log_index" = EXCLUDED."log_index",
    "transaction_index" = EXCLUDED."transaction_index",
    "transaction_hash" = EXCLUDED."transaction_hash",
    "src_address" = EXCLUDED."src_address",
    "block_hash" = EXCLUDED."block_hash",
    "block_timestamp" = EXCLUDED."block_timestamp",
    "event_type" = EXCLUDED."event_type",
    "params" = EXCLUDED."params";`;
};

const chunkBatchQuery = (
  sql,
  entityDataArray,
  queryToExecute
) => {
  const promises = [];

  // Split entityDataArray into chunks of MAX_ITEMS_PER_QUERY
  for (let i = 0; i < entityDataArray.length; i += MAX_ITEMS_PER_QUERY) {
    const chunk = entityDataArray.slice(i, i + MAX_ITEMS_PER_QUERY);

    promises.push(queryToExecute(sql, chunk));
  }

  // Execute all promises
  return Promise.all(promises).catch(e => {
    console.error("Sql query failed", e);
    throw e;
    });
};
const arrayToSqlValues = (dataArray) => {
  return dataArray.map(item => {
    return `(${item.chain_id}, '${item.entity_id}', ${item.block_number}, ${item.log_index}, '${item.transaction_hash}', '${item.entity_type}', (SELECT block_number FROM "public"."entity_history" 
              WHERE entity_id = '${item.entity_id}'
              ORDER BY block_number DESC 
              LIMIT 1))`;
  }).join(', ');
}

function mergeArrays(array1, array2) {
  const array2Map = new Map(array2.map(item => [item.entity_id, item]));

  return array1.map(item => {
    const match = array2Map.get(item.entity_id);
    if (match) {
      return {
        ...item,
        previous_block_number: match.previous_block_number,
        previous_log_index: match.previous_log_index
      };
    }
    else {
      return item;
    }
  });
}

const fetchPreviousBlockNumbersAndLogIndices = async (sql, entityDataArray) => {
  const entityIds = entityDataArray.map(item => item.entity_id);
  const uniqueEntityIds = [...new Set(entityIds)]; // Remove duplicates

  const previousBlockNumbersAndLogIndices = await sql`
    SELECT entity_id, block_number as previous_block_number, log_index as previous_log_index
    FROM "public"."entity_history"
    WHERE (entity_id, block_number, log_index) IN (
      SELECT entity_id, MAX(block_number), MAX(log_index)
      FROM "public"."entity_history"
      WHERE entity_id = ANY(${sql.array(uniqueEntityIds)})
      GROUP BY entity_id
    )
  `;

  let merge = mergeArrays(entityDataArray, previousBlockNumbersAndLogIndices)

  return merge
};

const batchSetEntityHistory = async (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."entity_history"
  ${sql(
    entityDataArray,
    "chain_id",
    "entity_id",
    "block_timestamp",
    "block_number",
    "log_index",
    "transaction_hash",
    "entity_type",
    "previous_block_number",
    "previous_log_index",
    "params",
  )};`;
};

module.exports.batchSetEntityHistoryTable = async (
  sql,
  entityDataArrayWithPrev,
  entityDataArrayWithoutPrev,
) => {
  const result = await fetchPreviousBlockNumbersAndLogIndices(
    sql,
    entityDataArrayWithoutPrev,
  );
  const previousData = [...result, ...entityDataArrayWithPrev];
  return chunkBatchQuery(sql, previousData, batchSetEntityHistory);
};

module.exports.getRollbackDiff = (
  sql,
  blockTimestamp,
  chainId,
  blockNumber,
) => sql`
SELECT DISTINCT
    ON (
        COALESCE(old.entity_id, new.entity_id)
    ) COALESCE(old.entity_id, new.entity_id) AS entity_id,
    COALESCE(old.params, 'null') AS val,
    COALESCE(old.block_timestamp, 'null') AS block_timestamp,
    COALESCE(old.chain_id, 'null') AS chain_id,
    COALESCE(old.block_number, 'null') AS block_number,
    COALESCE(old.log_index, 'null') AS log_index,
    COALESCE(old.entity_type, new.entity_type) AS entity_type

FROM entity_history old
INNER JOIN
    entity_history next
    -- next should simply be a higher block multichain
    ON (
        next.block_timestamp > ${blockTimestamp}
        OR (next.block_timestamp = ${blockTimestamp} AND next.chain_id > ${chainId})
        OR (
            next.block_timestamp = ${blockTimestamp} AND next.chain_id = ${chainId} AND next.block_number >= ${blockNumber}
        )
    )
    -- old should be a lower block multichain
    AND (
        old.block_timestamp < ${blockTimestamp}
        OR (old.block_timestamp = ${blockTimestamp} AND old.chain_id < ${chainId})
        OR (old.block_timestamp = ${blockTimestamp} AND old.chain_id = ${chainId} AND old.block_number <= ${blockNumber})
    )
    -- old AND new ids AND entity types should match
    AND old.entity_id = next.entity_id
    AND old.entity_type = next.entity_type
    AND old.block_number = next.previous_block_number
FULL OUTER JOIN
    entity_history new
    ON old.entity_id = new.entity_id
    AND new.previous_block_number >= old.block_number
WHERE COALESCE(old.block_number, 0) <= ${blockNumber} AND COALESCE(new.block_number, ${blockNumber} + 1) >= ${blockNumber};
`;

module.exports.batchSetRawEvents = (sql, entityDataArray) => {
  return chunkBatchQuery(
    sql,
    entityDataArray,
    batchSetRawEventsCore
  );
};

module.exports.batchDeleteRawEvents = (sql, entityIdArray) => sql`
  DELETE
  FROM "public"."raw_events"
  WHERE (chain_id, event_id) IN ${sql(entityIdArray)};`;
// end db operations for raw_events

module.exports.readDynamicContractsOnChainIdAtOrBeforeBlock = (
  sql,
  chainId,
  block_number
) => sql`
  SELECT c.contract_address, c.contract_type, c.event_id
  FROM "public"."dynamic_contract_registry" as c
  JOIN raw_events e ON c.chain_id = e.chain_id
  AND c.event_id = e.event_id
  WHERE e.block_number <= ${block_number} AND e.chain_id = ${chainId};`;

//Start db operations dynamic_contract_registry
module.exports.readDynamicContractRegistryEntities = (
  sql,
  entityIdArray
) => sql`
  SELECT *
  FROM "public"."dynamic_contract_registry"
  WHERE (chain_id, contract_address) IN ${sql(entityIdArray)}`;

const batchSetDynamicContractRegistryCore = (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."dynamic_contract_registry"
  ${sql(
    entityDataArray,
    "chain_id",
    "event_id",
    "contract_address",
    "contract_type"
  )}
    ON CONFLICT(chain_id, contract_address) DO UPDATE
    SET
    "chain_id" = EXCLUDED."chain_id",
    "event_id" = EXCLUDED."event_id",
    "contract_address" = EXCLUDED."contract_address",
    "contract_type" = EXCLUDED."contract_type";`;
};

module.exports.batchSetDynamicContractRegistry = (sql, entityDataArray) => {
  return chunkBatchQuery(
    sql,
    entityDataArray,
    batchSetDynamicContractRegistryCore
  );
};

module.exports.batchDeleteDynamicContractRegistry = (sql, entityIdArray) => sql`
  DELETE
  FROM "public"."dynamic_contract_registry"
  WHERE (chain_id, contract_address) IN ${sql(entityIdArray)};`;
// end db operations for dynamic_contract_registry

//////////////////////////////////////////////
// DB operations for User:
//////////////////////////////////////////////

module.exports.readUserEntities = (sql, entityIdArray) => sql`
SELECT 
"id",
"greetings",
"latestGreeting",
"numberOfGreetings"
FROM "public"."User"
WHERE id IN ${sql(entityIdArray)};`;

const batchSetUserCore = (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."User"
${sql(entityDataArray,
    "id",
    "greetings",
    "latestGreeting",
    "numberOfGreetings"
  )}
  ON CONFLICT(id) DO UPDATE
  SET
  "id" = EXCLUDED."id",
  "greetings" = EXCLUDED."greetings",
  "latestGreeting" = EXCLUDED."latestGreeting",
  "numberOfGreetings" = EXCLUDED."numberOfGreetings"
  `;
}

module.exports.batchSetUser = (sql, entityDataArray) => {

  return chunkBatchQuery(
    sql, 
    entityDataArray, 
    batchSetUserCore
  );
}

module.exports.batchDeleteUser = (sql, entityIdArray) => sql`
DELETE
FROM "public"."User"
WHERE id IN ${sql(entityIdArray)};`
// end db operations for User

