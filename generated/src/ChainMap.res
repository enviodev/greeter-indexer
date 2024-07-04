open Belt

module Chain = {
  type t =
    | Chain_137
    | Chain_59144

  let all = [Chain_137, Chain_59144]

  let toChainId = chain =>
    switch chain {
    | Chain_137 => 137
    | Chain_59144 => 59144
    }

  let toString = chain => chain->toChainId->Int.toString

  exception UndefinedChain(int)

  let fromChainId = chainId =>
    switch chainId {
    | 137 => Ok(Chain_137)
    | 59144 => Ok(Chain_59144)
    | c => Error(UndefinedChain(c))
    }

  module ChainIdCmp = Belt.Id.MakeComparableU({
    type t = t
    let cmp = (a, b) => Pervasives.compare(a->toChainId, b->toChainId)
  })
}

type t<'a> = Belt.Map.t<Chain.ChainIdCmp.t, 'a, Chain.ChainIdCmp.identity>

let make = (fn: Chain.t => 'a): t<'a> => {
  Chain.all
  ->Array.map(chainId => (chainId, chainId->fn))
  ->Map.fromArray(~id=module(Chain.ChainIdCmp))
}

let empty = () => []->Map.fromArray(~id=module(Chain.ChainIdCmp))

exception NotAllChainsDefined
let fromArray: array<(Chain.t, 'a)> => result<t<'a>, exn> = arr => {
  let map = arr->Map.fromArray(~id=module(Chain.ChainIdCmp))
  let hasAllChains = Chain.all->Array.reduce(true, (accum, chain) => {
    accum && map->Map.has(chain)
  })
  if hasAllChains {
    Ok(map)
  } else {
    Error(NotAllChainsDefined)
  }
}

exception UnexpectedChainDoesNoteExist(int)
let get: (t<'a>, Chain.t) => 'a = (self, chain) =>
  //Can safely get exn since all chains must be set
  switch Map.get(self, chain) {
  | Some(v) => v
  | None => UnexpectedChainDoesNoteExist(chain->Chain.toChainId)->raise
  }

let set: (t<'a>, Chain.t, 'a) => t<'a> = (map, chain, v) => Map.set(map, chain, v)
let values: t<'a> => array<'a> = map => Map.valuesToArray(map)
let keys: t<'a> => array<Chain.t> = map => Map.keysToArray(map)
let entries: t<'a> => array<(Chain.t, 'a)> = map => Map.toArray(map)
let map: (t<'a>, 'a => 'b) => t<'b> = (map, fn) => Map.map(map, fn)
let mapWithKey: (t<'a>, (Chain.t, 'a) => 'b) => t<'b> = (map, fn) => Map.mapWithKey(map, fn)
let reduce: (t<'a>, 'b, (Chain.t, 'a, 'b) => 'b) => 'b = (map, acc, fn) => Map.reduce(map, acc, fn)
let size: t<'a> => int = map => Map.size(map)
let update: (t<'a>, Chain.t, 'a => 'a) => t<'a> = (map, chain, updateFn) =>
  Map.update(map, chain, opt => opt->Option.map(updateFn))
