open Ink

module Demo = {
  @react.component
  let make = () => {
    let (state, setState) = React.useState(_ => 1)

    React.useEffect0(() => {
      let interval = Js.Global.setInterval(() => {
        setState(prev => prev + 1)
      }, 500)

      Some(() => Js.Global.clearInterval(interval))
    })
    <Text color=Primary> {state->React.int} </Text>
  }
}

render(<Demo />)->ignore
