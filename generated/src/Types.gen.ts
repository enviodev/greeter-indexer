/* TypeScript file generated from Types.res by genType. */
/* eslint-disable import/first */


import type {BigInt_t as Ethers_BigInt_t} from '../src/bindings/Ethers.gen';

import type {Json_t as Js_Json_t} from '../src/Js.shim';

import type {ethAddress as Ethers_ethAddress} from '../src/bindings/Ethers.gen';

import type {userLogger as Logs_userLogger} from './Logs.gen';

// tslint:disable-next-line:interface-over-type-literal
export type id = string;
export type Id = id;

// tslint:disable-next-line:interface-over-type-literal
export type userLoaderConfig = boolean;

// tslint:disable-next-line:interface-over-type-literal
export type entityRead = { tag: "UserRead"; value: id };

// tslint:disable-next-line:interface-over-type-literal
export type rawEventsEntity = {
  readonly chain_id: number; 
  readonly event_id: string; 
  readonly block_number: number; 
  readonly log_index: number; 
  readonly transaction_index: number; 
  readonly transaction_hash: string; 
  readonly src_address: Ethers_ethAddress; 
  readonly block_hash: string; 
  readonly block_timestamp: number; 
  readonly event_type: Js_Json_t; 
  readonly params: string
};

// tslint:disable-next-line:interface-over-type-literal
export type dynamicContractRegistryEntity = {
  readonly chain_id: number; 
  readonly event_id: Ethers_BigInt_t; 
  readonly contract_address: Ethers_ethAddress; 
  readonly contract_type: string
};

// tslint:disable-next-line:interface-over-type-literal
export type userEntity = {
  readonly id: id; 
  readonly greetings: string[]; 
  readonly latestGreeting: string; 
  readonly numberOfGreetings: number
};
export type UserEntity = userEntity;

// tslint:disable-next-line:interface-over-type-literal
export type dbOp = "Read" | "Set" | "Delete";

// tslint:disable-next-line:interface-over-type-literal
export type inMemoryStoreRow<a> = { readonly dbOp: dbOp; readonly entity: a };

// tslint:disable-next-line:interface-over-type-literal
export type eventLog<a> = {
  readonly params: a; 
  readonly chainId: number; 
  readonly txOrigin: (undefined | Ethers_ethAddress); 
  readonly blockNumber: number; 
  readonly blockTimestamp: number; 
  readonly blockHash: string; 
  readonly srcAddress: Ethers_ethAddress; 
  readonly transactionHash: string; 
  readonly transactionIndex: number; 
  readonly logIndex: number
};
export type EventLog<a> = eventLog<a>;

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_eventArgs = { readonly user: Ethers_ethAddress; readonly greeting: string };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_log = eventLog<GreeterContract_NewGreetingEvent_eventArgs>;
export type GreeterContract_NewGreeting_EventLog = GreeterContract_NewGreetingEvent_log;

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_userEntityHandlerContext = {
  readonly get: (_1:id) => (undefined | userEntity); 
  readonly set: (_1:userEntity) => void; 
  readonly delete: (_1:id) => void
};

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_userEntityHandlerContextAsync = {
  readonly get: (_1:id) => Promise<(undefined | userEntity)>; 
  readonly set: (_1:userEntity) => void; 
  readonly delete: (_1:id) => void
};

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_handlerContext = { readonly log: Logs_userLogger; readonly User: GreeterContract_NewGreetingEvent_userEntityHandlerContext };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_handlerContextAsync = { readonly log: Logs_userLogger; readonly User: GreeterContract_NewGreetingEvent_userEntityHandlerContextAsync };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_userEntityLoaderContext = { readonly load: (_1:id) => void };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_contractRegistrations = { readonly addGreeter: (_1:Ethers_ethAddress) => void };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_NewGreetingEvent_loaderContext = {
  readonly log: Logs_userLogger; 
  readonly contractRegistration: GreeterContract_NewGreetingEvent_contractRegistrations; 
  readonly User: GreeterContract_NewGreetingEvent_userEntityLoaderContext
};

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_eventArgs = { readonly user: Ethers_ethAddress };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_log = eventLog<GreeterContract_ClearGreetingEvent_eventArgs>;
export type GreeterContract_ClearGreeting_EventLog = GreeterContract_ClearGreetingEvent_log;

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_userEntityHandlerContext = {
  readonly get: (_1:id) => (undefined | userEntity); 
  readonly set: (_1:userEntity) => void; 
  readonly delete: (_1:id) => void
};

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_userEntityHandlerContextAsync = {
  readonly get: (_1:id) => Promise<(undefined | userEntity)>; 
  readonly set: (_1:userEntity) => void; 
  readonly delete: (_1:id) => void
};

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_handlerContext = { readonly log: Logs_userLogger; readonly User: GreeterContract_ClearGreetingEvent_userEntityHandlerContext };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_handlerContextAsync = { readonly log: Logs_userLogger; readonly User: GreeterContract_ClearGreetingEvent_userEntityHandlerContextAsync };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_userEntityLoaderContext = { readonly load: (_1:id) => void };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_contractRegistrations = { readonly addGreeter: (_1:Ethers_ethAddress) => void };

// tslint:disable-next-line:interface-over-type-literal
export type GreeterContract_ClearGreetingEvent_loaderContext = {
  readonly log: Logs_userLogger; 
  readonly contractRegistration: GreeterContract_ClearGreetingEvent_contractRegistrations; 
  readonly User: GreeterContract_ClearGreetingEvent_userEntityLoaderContext
};

// tslint:disable-next-line:interface-over-type-literal
export type chainId = number;
