let sql = Postgres.makeSql(~config=Config.db->Obj.magic /* TODO: make this have the correct type */)

module EventSyncState = {
  let createEventSyncStateTable: unit => promise<unit> = async () => {
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.event_sync_state (
        chain_id INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        transaction_index INTEGER NOT NULL,
        block_timestamp INTEGER NOT NULL,
        PRIMARY KEY (chain_id)
      );
      `")
  }

  let dropEventSyncStateTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.event_sync_state;
    `")
  }
}

module ChainMetadata = {
  let createChainMetadataTable: unit => promise<unit> = async () => {
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.chain_metadata (
        chain_id INTEGER NOT NULL,
        start_block INTEGER NOT NULL,
        block_height INTEGER NOT NULL,
        PRIMARY KEY (chain_id)
      );
      `")
  }

  let dropChainMetadataTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.chain_metadata;
    `")
  }
}

module PersistedState = {
  let createPersistedStateTable: unit => promise<unit> = async () => {
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.persisted_state (
        id SERIAL PRIMARY KEY,
        envio_version TEXT NOT NULL, 
        config_hash TEXT NOT NULL,
        schema_hash TEXT NOT NULL,
        handler_files_hash TEXT NOT NULL,
        abi_files_hash TEXT NOT NULL
      );
      `")
  }

  let dropPersistedStateTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.persisted_state;
    `")
  }
}

module SyncBatchMetadata = {
  let createSyncBatchTable: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.sync_batch (
        chain_id INTEGER NOT NULL,
        block_timestamp_range_end INTEGER NOT NULL,
        block_number_range_end INTEGER NOT NULL,
        block_hash_range_end TEXT NOT NULL,
        PRIMARY KEY (chain_id, block_number_range_end)
      );
      `")
  }

  @@warning("-21")
  let dropSyncStateTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.sync_batch;
    `")
  }
  @@warning("+21")
}

module RawEventsTable = {
  let createEventTypeEnum: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_type') THEN
          CREATE TYPE EVENT_TYPE AS ENUM(
          'Greeter_NewGreeting',
          'Greeter_ClearGreeting'
          );
        END IF;
      END $$;
      `")
  }

  let createRawEventsTable: unit => promise<unit> = async () => {
    let _ = await createEventTypeEnum()

    @warning("-21")
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.raw_events (
        chain_id INTEGER NOT NULL,
        event_id NUMERIC NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        transaction_index INTEGER NOT NULL,
        transaction_hash TEXT NOT NULL,
        src_address TEXT NOT NULL,
        block_hash TEXT NOT NULL,
        block_timestamp INTEGER NOT NULL,
        event_type EVENT_TYPE NOT NULL,
        params JSON NOT NULL,
        db_write_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (chain_id, event_id)
      );
      `")
  }

  @@warning("-21")
  let dropRawEventsTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.raw_events;
    `")
    let _ = await %raw("sql`
      DROP TYPE IF EXISTS EVENT_TYPE CASCADE;
    `")
  }
  @@warning("+21")
}

module DynamicContractRegistryTable = {
  let createDynamicContractRegistryTable: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contract_type') THEN
          CREATE TYPE CONTRACT_TYPE AS ENUM (
          'Greeter'
          );
        END IF;
      END $$;
      `")

    @warning("-21")
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.dynamic_contract_registry (
        chain_id INTEGER NOT NULL,
        event_id NUMERIC NOT NULL,
        contract_address TEXT NOT NULL,
        contract_type CONTRACT_TYPE NOT NULL,
        PRIMARY KEY (chain_id, contract_address)
      );
      `")
  }

  @@warning("-21")
  let dropDynamicContractRegistryTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.dynamic_contract_registry;
    `")
    let _ = await %raw("sql`
      DROP TYPE IF EXISTS EVENT_TYPE CASCADE;
    `")
  }
  @@warning("+21")
}

module EntityHistory = {
  let createEntityTypeEnum: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entity_type') THEN
          CREATE TYPE ENTITY_TYPE AS ENUM(
            'User'
          );
        END IF;
      END $$;
      `")
  }

  let createEntityHistoryTable: unit => promise<unit> = async () => {
    let _ = await createEntityTypeEnum()

    // NULL for an `entity_id` means that the entity was deleted.
    await %raw("sql`
      CREATE TABLE \"public\".\"entity_history\" (
        chain_id INTEGER NOT NULL,
        previous_block_number INTEGER,
        previous_log_index INTEGER,
        block_timestamp INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        params JSON,
        transaction_hash TEXT NOT NULL,
        entity_type ENTITY_TYPE NOT NULL,
        entity_id TEXT,
        PRIMARY KEY (entity_id, chain_id, block_number, log_index, entity_type));
      `")
  }

  @@warning("-21")
  let dropEntityHistoryTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.entity_history;
    `")
    let _ = await %raw("sql`
      DROP TYPE IF EXISTS ENTITY_TYPE CASCADE;
    `")
  }
  @@warning("+21")

  // NULL for an `entity_id` means that the entity was deleted.
  let createEntityHistoryPostgresFunction: unit => promise<unit> = async () => {
    await %raw("sql`
    CREATE OR REPLACE FUNCTION get_entity_history_filter(
        sort_chain_id integer,
        start_block integer,
        start_log_index integer,
        end_block integer,
        end_log_index integer
    )
    RETURNS SETOF entity_history_filter AS $$
    BEGIN
        RETURN QUERY
        SELECT
            DISTINCT ON (coalesce(old.entity_id, new.entity_id))
            coalesce(old.entity_id, new.entity_id) as entity_id,
            new.chain_id as chain_id,
            coalesce(old.params, 'null') as old_val,
            coalesce(new.params, 'null') as new_val,
            new.block_number as block_number,
            old.block_number as previous_block_number,
            new.log_index as log_index,
            old.log_index as previous_log_index,
            new.entity_type as entity_type
        FROM
            entity_history old
            INNER JOIN entity_history next ON 
            sort_chain_id = next.chain_id 
            AND
            (
                next.block_number > start_block
                OR (
                    next.block_number = start_block
                    AND next.log_index >= start_log_index
                )
            )
            AND (
                old.block_number < start_block
                OR (
                    old.block_number = start_block
                    AND old.log_index <= start_log_index
                )
            )
            AND (
                next.block_number < end_block
                OR (
                    next.block_number = end_block
                    AND next.log_index <= end_log_index
                )
            )
            AND old.chain_id = next.chain_id
            AND old.entity_id = next.entity_id
            AND old.entity_type = next.entity_type
            AND old.block_number = next.previous_block_number
            AND old.log_index = next.previous_log_index
            FULL OUTER JOIN entity_history new ON old.entity_id = new.entity_id
            AND sort_chain_id = new.chain_id
            AND (
                new.previous_block_number > old.block_number
                OR (
                    new.previous_block_number = old.block_number
                    AND new.previous_log_index >= old.log_index
                )
            )
            AND (
                new.block_number < end_block
                OR (
                    new.block_number = end_block
                    AND new.log_index <= end_log_index
                )
            )
        WHERE
            sort_chain_id = new.chain_id
            AND 
            (
                new.block_number <= end_block
                OR (
                    new.block_number = end_block
                    AND new.log_index <= end_log_index
                )
            )
            AND (
                coalesce(old.block_number, 0) <= start_block
                OR (
                    old.block_number = start_block
                    AND old.log_index <= start_log_index
                )
            )
            AND (
                coalesce(new.block_number, start_block + 1) > start_block
                OR (
                    new.block_number = start_block
                    AND new.log_index > start_log_index
                )
            )
        ORDER BY
            coalesce(old.entity_id, new.entity_id),
            new.block_number DESC,
            new.log_index DESC;
    END;
    $$ LANGUAGE plpgsql STABLE;
    `")
  }

  // This table is purely for the sake of viewing the diffs generated by the postgres function. It will never be written to during the application.
  let createEntityHistoryFilterTable: unit => promise<unit> = async () => {
    // NULL for an `entity_id` means that the entity was deleted.
    await %raw("sql`
      CREATE TABLE \"public\".\"entity_history_filter\" (
          entity_id TEXT NOT NULL,
          chain_id INTEGER NOT NULL,
          old_val JSON,
          new_val JSON,
          block_number INTEGER NOT NULL,
          block_timestamp INTEGER NOT NULL,
          previous_block_number INTEGER,
          log_index INTEGER NOT NULL,
          previous_log_index INTEGER,
          entity_type ENTITY_TYPE NOT NULL,
          PRIMARY KEY (entity_id, chain_id, block_number,previous_block_number, previous_log_index, log_index)
          );
      `")
  }

  // NOTE: didn't add 'delete' functions here - delete functions aren't being used currently.
}
module User = {
  let createUserTable: unit => promise<unit> = async () => {
    await %raw("sql`
      CREATE TABLE \"public\".\"User\" (
        \"id\" text NOT NULL,
        \"greetings\" text[] NOT NULL,
        \"latestGreeting\" text NOT NULL,
        \"numberOfGreetings\" integer NOT NULL,
        db_write_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
        PRIMARY KEY (\"id\"));`")
  }

  let createUserHistoryTable: unit => promise<unit> = async () => {
    // Rather using chain_id + log_index + block_number and not also "transaction_hash TEXT NOT NULL"
    await %raw("sql`
      CREATE TABLE \"public\".\"User_history\" (
        chain_id INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        \"id\" text NOT NULL,
        \"greetings\" text[] NOT NULL,
        \"latestGreeting\" text NOT NULL,
        \"numberOfGreetings\" integer NOT NULL,
        db_write_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
        PRIMARY KEY (\"id\", chain_id, block_number, log_index));`")
  }

  let deleteUserTable: unit => promise<unit> = async () => {
    // NOTE: we can refine the `IF EXISTS` part because this now prints to the terminal if the table doesn't exist (which isn't nice for the developer).
    await %raw("sql`DROP TABLE IF EXISTS \"public\".\"User\";`")
  }
}

let deleteAllTables: unit => promise<unit> = async () => {
  // await EntityHistory.dropEntityHistoryTable()

  Logging.trace("Dropping all tables")
  // NOTE: we can refine the `IF EXISTS` part because this now prints to the terminal if the table doesn't exist (which isn't nice for the developer).

  @warning("-21")
  await (
    %raw(
      "sql.unsafe`DROP SCHEMA public CASCADE;CREATE SCHEMA public;GRANT ALL ON SCHEMA public TO postgres;GRANT ALL ON SCHEMA public TO public;`"
    )
  )
}

let deleteAllTablesExceptRawEventsAndDynamicContractRegistry: unit => promise<unit> = async () => {
  // NOTE: we can refine the `IF EXISTS` part because this now prints to the terminal if the table doesn't exist (which isn't nice for the developer).

  @warning("-21")
  await (
    %raw("sql.unsafe`
    DO $$ 
    DECLARE
        table_name_var text;
    BEGIN
        FOR table_name_var IN (SELECT table_name
                           FROM information_schema.tables
                           WHERE table_schema = 'public'
                           AND table_name != 'raw_events'
                           AND table_name != 'dynamic_contract_registry') 
        LOOP
            EXECUTE 'DROP TABLE IF EXISTS ' || table_name_var || ' CASCADE';
        END LOOP;
    END $$;
  `")
  )
}

type t
@module external process: t = "process"

type exitCode = Success | Failure
@send external exit: (t, exitCode) => unit = "exit"

// TODO: all the migration steps should run as a single transaction
let runUpMigrations = async (~shouldExit) => {
  let exitCode = ref(Success)
  await PersistedState.createPersistedStateTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating persisted_state table`)->Promise.resolve
  })

  await EventSyncState.createEventSyncStateTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating event_sync_state table`)->Promise.resolve
  })
  await ChainMetadata.createChainMetadataTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating chain_metadata table`)->Promise.resolve
  })

  await EntityHistory.createEntityHistoryTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating entity history table`)->Promise.resolve
  })
  await EntityHistory.createEntityHistoryFilterTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating entity history filter table`)->Promise.resolve
  })
  await EntityHistory.createEntityHistoryPostgresFunction()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(
      err,
      `EE800: Error creating entity history db function table`,
    )->Promise.resolve
  })
  await SyncBatchMetadata.createSyncBatchTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating sync_batch table`)->Promise.resolve
  })
  await RawEventsTable.createRawEventsTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating raw_events table`)->Promise.resolve
  })
  await DynamicContractRegistryTable.createDynamicContractRegistryTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE801: Error creating dynamic_contracts table`)->Promise.resolve
  })
  // TODO: catch and handle query errors
  await User.createUserTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE802: Error creating User table`)->Promise.resolve
  })
  await User.createUserHistoryTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE802: Error creating User entity history table`)->Promise.resolve
  })
  await TrackTables.trackAllTables()->Promise.catch(err => {
    Logging.errorWithExn(err, `EE803: Error tracking tables`)->Promise.resolve
  })
  if shouldExit {
    process->exit(exitCode.contents)
  }
  exitCode.contents
}

let runDownMigrations = async (~shouldExit, ~shouldDropRawEvents) => {
  let exitCode = ref(Success)

  //
  // await User.deleteUserTable()
  //

  // NOTE: For now delete any remaining tables.
  if shouldDropRawEvents {
    await deleteAllTables()->Promise.catch(err => {
      exitCode := Failure
      Logging.errorWithExn(err, "EE804: Error dropping entity tables")->Promise.resolve
    })
  } else {
    await deleteAllTablesExceptRawEventsAndDynamicContractRegistry()->Promise.catch(err => {
      exitCode := Failure
      Logging.errorWithExn(
        err,
        "EE805: Error dropping entity tables except for raw events",
      )->Promise.resolve
    })
  }
  if shouldExit {
    process->exit(exitCode.contents)
  }
  exitCode.contents
}

let setupDb = async (~shouldDropRawEvents) => {
  Logging.info("Provisioning Database")
  // TODO: we should make a hash of the schema file (that gets stored in the DB) and either drop the tables and create new ones or keep this migration.
  //       for now we always run the down migration.
  // if (process.env.MIGRATE === "force" || hash_of_schema_file !== hash_of_current_schema)
  let exitCodeDown = await runDownMigrations(~shouldExit=false, ~shouldDropRawEvents)
  // else
  //   await clearDb()

  let exitCodeUp = await runUpMigrations(~shouldExit=false)

  let exitCode = switch (exitCodeDown, exitCodeUp) {
  | (Success, Success) => Success
  | _ => Failure
  }

  process->exit(exitCode)
}
