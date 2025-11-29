import cli/command
import cli/config/config
import cli/config/input_config
import cli/error.{InputLoaderError, ParseParameterError, YamlParseError}
import cli/log
import cli/run_command
import cli/test_enrichers_command
import dot_env
import glaml
import gleam/list
import gleam/result
import yaml/yaml

pub fn cli() {
  log.info("loading environment variables using dot_env", [])

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load

  log.info("parsing cli parameters", [])

  use command <- result.try(
    command.parse() |> result.map_error(ParseParameterError),
  )

  log.info("loading config file", [#("config_file", command.config)])

  use configs <- result.try(
    yaml.parse_file(command.config, config.decoder())
    |> result.map_error(YamlParseError(command.config, _)),
  )

  use config <- result.try(
    list.first(configs)
    |> result.map_error(fn(_) {
      YamlParseError(
        command.config,
        yaml.YamlError(glaml.ParsingError(
          "yaml file is contains no document",
          glaml.YamlErrorLoc(0, 0),
        )),
      )
    }),
  )

  log.info("creating input loader", [
    #("name", config.input.name),
    #("type", input_config.name(config.input)),
  ])

  use input_loader <- result.try(
    input_config.create_input_loader(config.input)
    |> result.map_error(InputLoaderError),
  )

  log.info("running command", [])

  case command {
    command.RunParameters(_) -> {
      run_command.run(input_loader, config)
    }
    command.TestEnrichersParameters(config: _, extra_enrichers:) -> {
      test_enrichers_command.run(input_loader, config, extra_enrichers)
    }
  }
}
