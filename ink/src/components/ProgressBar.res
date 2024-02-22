open Ink
@react.component
let make = (~percentage) => {
  let percentageStr = percentage->Int.toString->String.concat("%")
  <Box width=Str("100%") height=Num(5) borderStyle=Single>
    <Box width=Str(percentageStr) height=Str("100%") borderStyle=SingleDouble />
  </Box>
}

module TextProgressBar = {
  @react.component
  let make = (~current=5, ~end=10, ~width=36) => {
    let maxCount = width

    let fraction = current->Int.toFloat /. end->Int.toFloat
    let count =
      Math.min(Math.floor(maxCount->Int.toFloat *. fraction), maxCount->Int.toFloat)->Float.toInt

    <Text>
      <Text> {"█"->String.repeat(count)->React.string} </Text>
      <Text> {"░"->String.repeat(maxCount - count)->React.string} </Text>
    </Text>
  }
}
