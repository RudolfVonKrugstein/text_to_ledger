import cli/config
import cli/parameters
import data/ledger
import data/transaction_sheet
import dot_env
import extractor/enricher
import extractor/extracted_data
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import input_loader/directory_loader
import input_loader/input_file.{type InputFile}
import input_loader/input_loader
import input_loader/paperless_loader
import regex/area_regex
import simplifile

pub fn errors(results: List(Result(a, e))) -> List(e) {
  list.filter_map(results, fn(result) {
    case result {
      Error(e) -> Ok(e)
      Ok(v) -> Error(v)
    }
  })
}

fn extract_bank_statement_data(
  input_file: InputFile,
  sheet: enricher.Enricher,
  trans_areas: area_regex.AreaRegex,
) {
  // sheet data
  use sheet_data <- result.try(enricher.apply(
    extracted_data.empty(input_file),
    sheet,
  ))

  let transactions =
    area_regex.split(trans_areas, input_file.content)
    |> list.map(fn(content) {
      let input = input_file.InputFile(..input_file, content:)
      extracted_data.ExtractedData(..sheet_data, input:)
    })

  Ok(#(sheet_data, transactions))
}

pub fn find_matching_template(
  input_file: InputFile,
  templates: List(config.TemplateConfig),
) {
  let matches =
    templates
    |> list.map(fn(t) {
      extract_bank_statement_data(input_file, t.sheet, t.transaction_areas)
    })

  case result.values(matches) {
    [] ->
      Error(
        "no template matched the input text in "
        <> input_file.name
        <> ":\n"
        <> list.map(errors(matches), fn(e) { enricher.error_string(e) })
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
  use #(sheet, transactions) <- result.try(find_matching_template(
    input_file,
    config.templates,
  ))

  use sheet <- result.try(
    transaction_sheet.from_extracted_data(sheet)
    |> result.map_error(fn(e) { extracted_data.error_string(e) }),
  )

  use transactions <- result.try(
    list.try_map(transactions, fn(t) { ledger.from_extracted_data(t, sheet) })
    |> result.map_error(fn(e) { extracted_data.error_string(e) }),
  )

  Ok(#(sheet, transactions))
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
    |> result.map_error(fn(e) { "error loading config: " <> string.inspect(e) }),
  )

  use input_loader <- result.try(case config.input {
    config.InputDirectory(name, dir) -> {
      directory_loader.new(name, dir)
      |> result.map_error(fn(e) {
        "error creating directory loader for "
        <> dir
        <> ": "
        <> string.inspect(e)
      })
    }
    config.InputPaperless(
      name:,
      url:,
      token:,
      allowed_tags:,
      forbidden_tags:,
      document_types:,
    ) -> {
      paperless_loader.new(
        name,
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
  Ok(extracted)
  // use _ <- result.try(
  //   result.all(
  //     extracted
  //     |> list.map(fn(e) {
  //       let #(s, ts) = e
  //       sanity_check.sanity_checks(s, ts)
  //     }),
  //   )
  //   |> result.map_error(string.inspect),
  // )
  //
  // let transactions =
  //   extracted
  //   |> list.map(fn(e) {
  //     let #(_, transactions) = e
  //     transactions
  //   })
  //   |> list.flatten
  // Ok(Nil)
  // use ledger <- result.try(result.all(
  //   transactions
  //   |> list.map(fn(t) {
  //     matcher.try_match(config.extractors, t, ":")
  //     |> result.map_error(fn(e) {
  //       "Error trying to match transaction:\n" <> matcher.error_string(e)
  //     })
  //   }),
  // ))
  // Ok(ledger)
}
