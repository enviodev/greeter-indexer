open Ink

module Demo = {
  @react.component
  let make = () => {
    let (state, setState) = React.useState(_ => 1)

    React.useEffect0(() => {
      let interval = Js.Global.setInterval(() => {
        setState(prev => prev + 1)
      }, 500)
      let _ = Js.Global.setInterval(() => Js.log("test"), 200)
      Some(() => Js.Global.clearInterval(interval))
    })
    <Box>
      <Text color=Primary> {state->React.int} </Text>
      <ProgressBar.TextProgressBar current=state end=100 />
    </Box>
  }
}


render(<Demo />, ~options={})->ignore
