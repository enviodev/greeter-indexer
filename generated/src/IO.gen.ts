/* TypeScript file generated from IO.res by genType. */
/* eslint-disable import/first */


import type {EventSyncState_eventSyncState as DbFunctions_EventSyncState_eventSyncState} from './DbFunctions.gen';

import type {dynamicContractRegistryEntity as Types_dynamicContractRegistryEntity} from './Types.gen';

import type {ethAddress as Ethers_ethAddress} from '../src/bindings/Ethers.gen';

import type {inMemoryStoreRow as Types_inMemoryStoreRow} from './Types.gen';

import type {rawEventsEntity as Types_rawEventsEntity} from './Types.gen';

import type {userEntity as Types_userEntity} from './Types.gen';

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_stringHasher<val> = (_1:val) => string;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_storeState<entity,entityKey> = { readonly dict: {[id: string]: Types_inMemoryStoreRow<entity>}; readonly hasher: InMemoryStore_stringHasher<entityKey> };

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_EventSyncState_value = DbFunctions_EventSyncState_eventSyncState;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_EventSyncState_key = number;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_EventSyncState_t = InMemoryStore_storeState<InMemoryStore_EventSyncState_value,InMemoryStore_EventSyncState_key>;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_rawEventsKey = { readonly chainId: number; readonly eventId: string };

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_RawEvents_value = Types_rawEventsEntity;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_RawEvents_key = InMemoryStore_rawEventsKey;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_RawEvents_t = InMemoryStore_storeState<InMemoryStore_RawEvents_value,InMemoryStore_RawEvents_key>;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_dynamicContractRegistryKey = { readonly chainId: number; readonly contractAddress: Ethers_ethAddress };

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_DynamicContractRegistry_value = Types_dynamicContractRegistryEntity;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_DynamicContractRegistry_key = InMemoryStore_dynamicContractRegistryKey;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_DynamicContractRegistry_t = InMemoryStore_storeState<InMemoryStore_DynamicContractRegistry_value,InMemoryStore_DynamicContractRegistry_key>;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_User_value = Types_userEntity;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_User_key = string;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_User_t = InMemoryStore_storeState<InMemoryStore_User_value,InMemoryStore_User_key>;

// tslint:disable-next-line:interface-over-type-literal
export type InMemoryStore_t = {
  readonly eventSyncState: InMemoryStore_EventSyncState_t; 
  readonly rawEvents: InMemoryStore_RawEvents_t; 
  readonly dynamicContractRegistry: InMemoryStore_DynamicContractRegistry_t; 
  readonly user: InMemoryStore_User_t
};
