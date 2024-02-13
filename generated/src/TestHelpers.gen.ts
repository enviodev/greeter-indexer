/* TypeScript file generated from TestHelpers.res by genType. */
/* eslint-disable import/first */


// @ts-ignore: Implicit any on import
const TestHelpersBS = require('./TestHelpers.bs');

import type {GreeterContract_ClearGreetingEvent_eventArgs as Types_GreeterContract_ClearGreetingEvent_eventArgs} from './Types.gen';

import type {GreeterContract_NewGreetingEvent_eventArgs as Types_GreeterContract_NewGreetingEvent_eventArgs} from './Types.gen';

import type {ethAddress as Ethers_ethAddress} from '../src/bindings/Ethers.gen';

import type {eventLog as Types_eventLog} from './Types.gen';

import type {t as TestHelpers_MockDb_t} from './TestHelpers_MockDb.gen';

// tslint:disable-next-line:interface-over-type-literal
export type EventFunctions_eventProcessorArgs<eventArgs> = {
  readonly event: Types_eventLog<eventArgs>; 
  readonly mockDb: TestHelpers_MockDb_t; 
  readonly chainId?: number
};

// tslint:disable-next-line:interface-over-type-literal
export type EventFunctions_mockEventData = {
  readonly blockNumber?: number; 
  readonly blockTimestamp?: number; 
  readonly blockHash?: string; 
  readonly chainId?: number; 
  readonly srcAddress?: Ethers_ethAddress; 
  readonly transactionHash?: string; 
  readonly transactionIndex?: number; 
  readonly txOrigin?: (undefined | Ethers_ethAddress); 
  readonly logIndex?: number
};

// tslint:disable-next-line:interface-over-type-literal
export type Greeter_NewGreeting_createMockArgs = {
  readonly user?: Ethers_ethAddress; 
  readonly greeting?: string; 
  readonly mockEventData?: EventFunctions_mockEventData
};

// tslint:disable-next-line:interface-over-type-literal
export type Greeter_ClearGreeting_createMockArgs = { readonly user?: Ethers_ethAddress; readonly mockEventData?: EventFunctions_mockEventData };

export const MockDb_createMockDb: () => TestHelpers_MockDb_t = TestHelpersBS.MockDb.createMockDb;

export const Greeter_NewGreeting_processEvent: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_NewGreetingEvent_eventArgs>) => TestHelpers_MockDb_t = TestHelpersBS.Greeter.NewGreeting.processEvent;

export const Greeter_NewGreeting_processEventAsync: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_NewGreetingEvent_eventArgs>) => Promise<TestHelpers_MockDb_t> = TestHelpersBS.Greeter.NewGreeting.processEventAsync;

export const Greeter_NewGreeting_createMockEvent: (args:Greeter_NewGreeting_createMockArgs) => Types_eventLog<Types_GreeterContract_NewGreetingEvent_eventArgs> = TestHelpersBS.Greeter.NewGreeting.createMockEvent;

export const Greeter_ClearGreeting_processEvent: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_ClearGreetingEvent_eventArgs>) => TestHelpers_MockDb_t = TestHelpersBS.Greeter.ClearGreeting.processEvent;

export const Greeter_ClearGreeting_processEventAsync: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_ClearGreetingEvent_eventArgs>) => Promise<TestHelpers_MockDb_t> = TestHelpersBS.Greeter.ClearGreeting.processEventAsync;

export const Greeter_ClearGreeting_createMockEvent: (args:Greeter_ClearGreeting_createMockArgs) => Types_eventLog<Types_GreeterContract_ClearGreetingEvent_eventArgs> = TestHelpersBS.Greeter.ClearGreeting.createMockEvent;

export const Greeter: { ClearGreeting: {
  processEvent: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_ClearGreetingEvent_eventArgs>) => TestHelpers_MockDb_t; 
  processEventAsync: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_ClearGreetingEvent_eventArgs>) => Promise<TestHelpers_MockDb_t>; 
  createMockEvent: (args:Greeter_ClearGreeting_createMockArgs) => Types_eventLog<Types_GreeterContract_ClearGreetingEvent_eventArgs>
}; NewGreeting: {
  processEvent: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_NewGreetingEvent_eventArgs>) => TestHelpers_MockDb_t; 
  processEventAsync: (_1:EventFunctions_eventProcessorArgs<Types_GreeterContract_NewGreetingEvent_eventArgs>) => Promise<TestHelpers_MockDb_t>; 
  createMockEvent: (args:Greeter_NewGreeting_createMockArgs) => Types_eventLog<Types_GreeterContract_NewGreetingEvent_eventArgs>
} } = TestHelpersBS.Greeter

export const MockDb: { createMockDb: () => TestHelpers_MockDb_t } = TestHelpersBS.MockDb
