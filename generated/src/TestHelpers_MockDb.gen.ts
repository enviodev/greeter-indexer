/* TypeScript file generated from TestHelpers_MockDb.res by genType. */
/* eslint-disable import/first */


// @ts-ignore: Implicit any on import
const TestHelpers_MockDbBS = require('./TestHelpers_MockDb.bs');

import type {EventSyncState_eventSyncState as DbFunctions_EventSyncState_eventSyncState} from './DbFunctions.gen';

import type {InMemoryStore_dynamicContractRegistryKey as IO_InMemoryStore_dynamicContractRegistryKey} from './IO.gen';

import type {InMemoryStore_rawEventsKey as IO_InMemoryStore_rawEventsKey} from './IO.gen';

import type {InMemoryStore_t as IO_InMemoryStore_t} from './IO.gen';

import type {chainId as Types_chainId} from './Types.gen';

import type {dynamicContractRegistryEntity as Types_dynamicContractRegistryEntity} from './Types.gen';

import type {rawEventsEntity as Types_rawEventsEntity} from './Types.gen';

import type {userEntity as Types_userEntity} from './Types.gen';

// tslint:disable-next-line:interface-over-type-literal
export type t = {
  readonly __dbInternal__: IO_InMemoryStore_t; 
  readonly entities: entities; 
  readonly rawEvents: storeOperations<IO_InMemoryStore_rawEventsKey,Types_rawEventsEntity>; 
  readonly eventSyncState: storeOperations<Types_chainId,DbFunctions_EventSyncState_eventSyncState>; 
  readonly dynamicContractRegistry: storeOperations<IO_InMemoryStore_dynamicContractRegistryKey,Types_dynamicContractRegistryEntity>
};

// tslint:disable-next-line:interface-over-type-literal
export type entities = { readonly User: entityStoreOperations<Types_userEntity> };

// tslint:disable-next-line:interface-over-type-literal
export type entityStoreOperations<entity> = storeOperations<string,entity>;

// tslint:disable-next-line:interface-over-type-literal
export type storeOperations<entityKey,entity> = {
  readonly getAll: () => entity[]; 
  readonly get: (_1:entityKey) => (undefined | entity); 
  readonly set: (_1:entity) => t; 
  readonly delete: (_1:entityKey) => t
};

export const createMockDb: () => t = TestHelpers_MockDbBS.createMockDb;
