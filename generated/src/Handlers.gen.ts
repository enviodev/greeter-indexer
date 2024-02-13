/* TypeScript file generated from Handlers.res by genType. */
/* eslint-disable import/first */


// @ts-ignore: Implicit any on import
const Curry = require('rescript/lib/js/curry.js');

// @ts-ignore: Implicit any on import
const HandlersBS = require('./Handlers.bs');

import type {GreeterContract_ClearGreetingEvent_eventArgs as Types_GreeterContract_ClearGreetingEvent_eventArgs} from './Types.gen';

import type {GreeterContract_ClearGreetingEvent_handlerContextAsync as Types_GreeterContract_ClearGreetingEvent_handlerContextAsync} from './Types.gen';

import type {GreeterContract_ClearGreetingEvent_handlerContext as Types_GreeterContract_ClearGreetingEvent_handlerContext} from './Types.gen';

import type {GreeterContract_ClearGreetingEvent_loaderContext as Types_GreeterContract_ClearGreetingEvent_loaderContext} from './Types.gen';

import type {GreeterContract_NewGreetingEvent_eventArgs as Types_GreeterContract_NewGreetingEvent_eventArgs} from './Types.gen';

import type {GreeterContract_NewGreetingEvent_handlerContextAsync as Types_GreeterContract_NewGreetingEvent_handlerContextAsync} from './Types.gen';

import type {GreeterContract_NewGreetingEvent_handlerContext as Types_GreeterContract_NewGreetingEvent_handlerContext} from './Types.gen';

import type {GreeterContract_NewGreetingEvent_loaderContext as Types_GreeterContract_NewGreetingEvent_loaderContext} from './Types.gen';

import type {eventLog as Types_eventLog} from './Types.gen';

import type {genericContextCreatorFunctions as Context_genericContextCreatorFunctions} from './Context.gen';

import type {t as SyncAsync_t} from './SyncAsync.gen';

// tslint:disable-next-line:interface-over-type-literal
export type handlerFunction<eventArgs,context,returned> = (_1:{ readonly event: Types_eventLog<eventArgs>; readonly context: context }) => returned;

// tslint:disable-next-line:interface-over-type-literal
export type handlerWithContextGetter<eventArgs,context,returned,loaderContext,handlerContextSync,handlerContextAsync> = { readonly handler: handlerFunction<eventArgs,context,returned>; readonly contextGetter: (_1:Context_genericContextCreatorFunctions<loaderContext,handlerContextSync,handlerContextAsync>) => context };

// tslint:disable-next-line:interface-over-type-literal
export type handlerWithContextGetterSyncAsync<eventArgs,loaderContext,handlerContextSync,handlerContextAsync> = SyncAsync_t<handlerWithContextGetter<eventArgs,handlerContextSync,void,loaderContext,handlerContextSync,handlerContextAsync>,handlerWithContextGetter<eventArgs,handlerContextAsync,Promise<void>,loaderContext,handlerContextSync,handlerContextAsync>>;

// tslint:disable-next-line:interface-over-type-literal
export type loader<eventArgs,loaderContext> = (_1:{ readonly event: Types_eventLog<eventArgs>; readonly context: loaderContext }) => void;

export const GreeterContract_NewGreeting_loader: (loader:loader<Types_GreeterContract_NewGreetingEvent_eventArgs,Types_GreeterContract_NewGreetingEvent_loaderContext>) => void = function (Arg1: any) {
  const result = HandlersBS.GreeterContract.NewGreeting.loader(function (Argevent: any, Argcontext: any) {
      const result1 = Arg1({event:Argevent, context:{log:{debug:Argcontext.log.debug, info:Argcontext.log.info, warn:Argcontext.log.warn, error:Argcontext.log.error, errorWithExn:function (Arg11: any, Arg2: any) {
          const result2 = Curry._2(Argcontext.log.errorWithExn, Arg11, Arg2);
          return result2
        }}, contractRegistration:Argcontext.contractRegistration, User:Argcontext.User}});
      return result1
    });
  return result
};

export const GreeterContract_NewGreeting_handler: (handler:handlerFunction<Types_GreeterContract_NewGreetingEvent_eventArgs,Types_GreeterContract_NewGreetingEvent_handlerContext,void>) => void = function (Arg1: any) {
  const result = HandlersBS.GreeterContract.NewGreeting.handler(function (Argevent: any, Argcontext: any) {
      const result1 = Arg1({event:Argevent, context:{log:{debug:Argcontext.log.debug, info:Argcontext.log.info, warn:Argcontext.log.warn, error:Argcontext.log.error, errorWithExn:function (Arg11: any, Arg2: any) {
          const result2 = Curry._2(Argcontext.log.errorWithExn, Arg11, Arg2);
          return result2
        }}, User:Argcontext.User}});
      return result1
    });
  return result
};

export const GreeterContract_NewGreeting_handlerAsync: (handler:handlerFunction<Types_GreeterContract_NewGreetingEvent_eventArgs,Types_GreeterContract_NewGreetingEvent_handlerContextAsync,Promise<void>>) => void = function (Arg1: any) {
  const result = HandlersBS.GreeterContract.NewGreeting.handlerAsync(function (Argevent: any, Argcontext: any) {
      const result1 = Arg1({event:Argevent, context:{log:{debug:Argcontext.log.debug, info:Argcontext.log.info, warn:Argcontext.log.warn, error:Argcontext.log.error, errorWithExn:function (Arg11: any, Arg2: any) {
          const result2 = Curry._2(Argcontext.log.errorWithExn, Arg11, Arg2);
          return result2
        }}, User:Argcontext.User}});
      return result1
    });
  return result
};

export const GreeterContract_ClearGreeting_loader: (loader:loader<Types_GreeterContract_ClearGreetingEvent_eventArgs,Types_GreeterContract_ClearGreetingEvent_loaderContext>) => void = function (Arg1: any) {
  const result = HandlersBS.GreeterContract.ClearGreeting.loader(function (Argevent: any, Argcontext: any) {
      const result1 = Arg1({event:Argevent, context:{log:{debug:Argcontext.log.debug, info:Argcontext.log.info, warn:Argcontext.log.warn, error:Argcontext.log.error, errorWithExn:function (Arg11: any, Arg2: any) {
          const result2 = Curry._2(Argcontext.log.errorWithExn, Arg11, Arg2);
          return result2
        }}, contractRegistration:Argcontext.contractRegistration, User:Argcontext.User}});
      return result1
    });
  return result
};

export const GreeterContract_ClearGreeting_handler: (handler:handlerFunction<Types_GreeterContract_ClearGreetingEvent_eventArgs,Types_GreeterContract_ClearGreetingEvent_handlerContext,void>) => void = function (Arg1: any) {
  const result = HandlersBS.GreeterContract.ClearGreeting.handler(function (Argevent: any, Argcontext: any) {
      const result1 = Arg1({event:Argevent, context:{log:{debug:Argcontext.log.debug, info:Argcontext.log.info, warn:Argcontext.log.warn, error:Argcontext.log.error, errorWithExn:function (Arg11: any, Arg2: any) {
          const result2 = Curry._2(Argcontext.log.errorWithExn, Arg11, Arg2);
          return result2
        }}, User:Argcontext.User}});
      return result1
    });
  return result
};

export const GreeterContract_ClearGreeting_handlerAsync: (handler:handlerFunction<Types_GreeterContract_ClearGreetingEvent_eventArgs,Types_GreeterContract_ClearGreetingEvent_handlerContextAsync,Promise<void>>) => void = function (Arg1: any) {
  const result = HandlersBS.GreeterContract.ClearGreeting.handlerAsync(function (Argevent: any, Argcontext: any) {
      const result1 = Arg1({event:Argevent, context:{log:{debug:Argcontext.log.debug, info:Argcontext.log.info, warn:Argcontext.log.warn, error:Argcontext.log.error, errorWithExn:function (Arg11: any, Arg2: any) {
          const result2 = Curry._2(Argcontext.log.errorWithExn, Arg11, Arg2);
          return result2
        }}, User:Argcontext.User}});
      return result1
    });
  return result
};
