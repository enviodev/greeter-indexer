 open Ink
@react.component
let make = (~percentage) => {
  let percentageStr = percentage->Js.Int.toString ++ "%"
  <Box width=Str("100%") height=Num(5) borderStyle=Single>
    <Box width=Str(percentageStr) height=Str("100%") borderStyle=SingleDouble />
  </Box>
}

module TextProgressBar = {
  @react.component
  let make = (~current=5, ~end=10, ~width=36, ()) => {
    let maxCount = width

    let fraction = current->Js.Int.toFloat /. end->Js.Int.toFloat
    let count = Js.Math.min_int(
      Js.Math.floor_float(maxCount->Js.Int.toFloat *. fraction)->Belt.Float.toInt,
      maxCount,
    )
    <Text>
      <Text> {"█"->Js.String2.repeat(count)->React.string} </Text>
      <Text> {"░"->Js.String2.repeat(maxCount - count)->React.string} </Text>
    </Text>
  }
}
