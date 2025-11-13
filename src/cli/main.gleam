import cli/config
import cli/parameters
import data/matcher
import data/sanity_check
import dot_env
import extractor
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import input_loader/directory_loader
import input_loader/input_file.{type InputFile}
import input_loader/input_loader
import input_loader/paperless_loader
import simplifile

pub fn errors(results: List(Result(a, e))) -> List(e) {
  list.filter_map(results, fn(result) {
    case result {
      Error(e) -> Ok(e)
      Ok(v) -> Error(v)
    }
  })
}

pub fn find_matching_template(
  input_file: InputFile,
  templates: List(config.TemplateConfig),
) {
  let matches =
    templates
    |> list.map(fn(t) {
      extractor.extract_bank_statement_data(
        input_file,
        t.statement,
        t.transaction,
      )
    })

  case result.values(matches) {
    [] ->
      Error(
        "no template matched the input text in "
        <> input_file.name
        <> ":\n"
        <> list.map(errors(matches), fn(e) { extractor.error_string(e) })
        |> string.join("\n"),
      )
    [match] -> Ok(match)
    matches ->
      Error(
        int.to_string(list.length(matches))
        <> " templates matched the file, cannot decide which to use",
      )
  }
}

pub fn extract_from_file(input_file: InputFile, config: config.Config) {
  find_matching_template(input_file, config.templates)
}

pub fn cli() {
  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load

  use parameters <- result.try(parameters.parameters())

  use config <- result.try(
    simplifile.read(from: parameters.config)
    |> result.map_error(fn(e) {
      "unable to read config file "
      <> parameters.config
      <> ": "
      <> string.inspect(e)
    }),
  )
  use config <- result.try(
    json.parse(config, config.config_decoder())
    |> result.map_error(string.inspect),
  )

  use input_loader <- result.try(case config.input {
    config.InputDirectory(dir) -> {
      directory_loader.new(dir)
      |> result.map_error(string.inspect)
    }
    config.InputPaperless(
      url:,
      token:,
      allowed_tags:,
      forbidden_tags:,
      document_types:,
    ) -> {
      paperless_loader.new(
        url,
        token,
        allowed_tags,
        forbidden_tags,
        document_types,
      )
    }
  })

  use extracted <- result.try(
    input_loader.try_load_all(input_loader, fn(in_file) {
      extract_from_file(in_file, config)
    }),
  )

  use _ <- result.try(
    result.all(
      extracted
      |> list.map(fn(e) {
        let #(s, ts) = e
        sanity_check.sanity_checks(s, ts)
      }),
    )
    |> result.map_error(string.inspect),
  )

  let transactions =
    extracted
    |> list.map(fn(e) {
      let #(_, transactions) = e
      transactions
    })
    |> list.flatten

  use ledger <- result.try(result.all(
    transactions
    |> list.map(fn(t) {
      matcher.try_match(config.matchers, t, ":")
      |> result.map_error(fn(e) {
        "Error trying to match transaction:\n" <> matcher.error_string(e)
      })
    }),
  ))
  Ok(ledger)
}
