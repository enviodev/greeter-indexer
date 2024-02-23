open Ink
open Belt

module App = {
  type chain = {
    chainId: int,
    firstEventBlockNumber: int,
    latestFetchedBlockNumber: int,
    currentBlockHeight: int,
    latestProcessedBlock: int,
  }
  type appState = {chainData: array<chain>}

  @react.component
  let make = (~appState: appState) => {
    <Box flexDirection={Column}>
      {appState.chainData
      ->Array.mapWithIndex((
        i,
        {
          firstEventBlockNumber,
          latestFetchedBlockNumber,
          currentBlockHeight,
          latestProcessedBlock,
          chainId,
        },
      ) => {
        <Box key={i->Int.toString} flexDirection={Column}>
          <Text color=Primary> {chainId->React.int} </Text>
          <Text> {firstEventBlockNumber->React.int} </Text>
          <Text> {latestProcessedBlock->React.int} </Text>
          <Box flexDirection={Row}>
            <Text> {latestFetchedBlockNumber->React.int} </Text>
            <Text> {"/"->React.string} </Text>
            <Text> {currentBlockHeight->React.int} </Text>
          </Box>
          <ProgressBar.TextProgressBar
            current={latestFetchedBlockNumber - firstEventBlockNumber}
            end={currentBlockHeight - firstEventBlockNumber}
          />
          <Newline />
        </Box>
      })
      ->React.array}
    </Box>
  }
}

let startApp = appState => {
  let {rerender} = render(<App appState />)
  appState => {
    rerender(<App appState />)
  }
}
