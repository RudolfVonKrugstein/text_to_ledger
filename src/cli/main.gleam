import cli/config
import cli/parameters
import gleam/json
import gleam/result
import gleam/string
import simplifile

pub fn cli() {
  use parameters <- result.try(parameters.parameters())

  use config <- result.try(
    simplifile.read(from: parameters.config) |> result.map_error(string.inspect),
  )
  use config <- result.try(
    json.parse(config, config.config_decoder())
    |> result.map_error(string.inspect),
  )
  todo
}
