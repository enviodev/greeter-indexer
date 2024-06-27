// TODO: move to `eventFetching`

let greeterAbi = `
[{"type":"event","name":"ClearGreeting","inputs":[{"name":"user","type":"address","indexed":false}],"anonymous":false},{"type":"event","name":"NewGreeting","inputs":[{"name":"user","type":"address","indexed":false},{"name":"greeting","type":"string","indexed":false}],"anonymous":false}]
`->Js.Json.parseExn
