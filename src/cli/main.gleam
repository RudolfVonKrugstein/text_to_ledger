import cli/command
import cli/config/config
import cli/config/input_config
import cli/error.{
  DecodeConfigError, EnricherError, ExtractFromFileError, ExtractedDataError,
  InputLoaderError, NoExtractorMatch, ParseParameterError, ReadConfigError,
  ToManyExtractorMatched, YamlParseError,
}
import cli/log
import data/ledger
import data/transaction_sheet
import dot_env
import enricher/enricher
import extracted_data/extracted_data
import extractor/extractor
import glaml
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import input_loader/input_file.{type InputFile}
import input_loader/input_loader
import simplifile
import yaml/yaml

pub fn errors(results: List(Result(a, e))) -> List(e) {
  list.filter_map(results, fn(result) {
    case result {
      Error(e) -> Ok(e)
      Ok(v) -> Error(v)
    }
  })
}

pub fn find_matching_extractor(
  input_file: InputFile,
  extractors: List(extractor.Extractor),
) {
  let matches =
    extractors
    |> list.map(fn(e) { e.run(input_file) })

  case result.values(matches) {
    [] -> Error(NoExtractorMatch(errors(matches)))
    [match] -> Ok(match)
    matches -> Error(ToManyExtractorMatched(list.length(matches)))
  }
}

pub fn extract_from_file(input_file: InputFile, config: config.Config) {
  use #(sheet, transactions) <- result.try(find_matching_extractor(
    input_file,
    config.extractors,
  ))

  use sheet <- result.try(
    transaction_sheet.from_extracted_data(sheet)
    |> result.map_error(ExtractedDataError(data: sheet, err: _)),
  )

  use transactions <- result.try(
    list.try_map(transactions, fn(trans) {
      list.try_fold(config.enrichers, trans, fn(trans, enricher) {
        use new_trans <- result.try(
          enricher.try_apply(trans, enricher)
          |> result.map_error(EnricherError),
        )
        case new_trans {
          None -> Ok(trans)
          Some(trans) -> Ok(trans)
        }
      })
    }),
  )

  use transactions <- result.try(
    list.try_map(transactions, fn(t) {
      ledger.from_extracted_data(t, sheet)
      |> result.map_error(ExtractedDataError(t, err: _))
    }),
  )

  Ok(#(sheet, transactions))
}

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

  use config <- result.try(
    simplifile.read(from: command.config)
    |> result.map_error(ReadConfigError(command.config, _)),
  )

  log.info("parsing config", [])

  // use config <- result.try(
  //   json.parse(config, config.config_decoder())
  //   |> result.map_error(DecodeConfigError(command.config, _)),
  // )
  use config_dynamic <- result.try(
    yaml.parse_string(config)
    |> result.map_error(YamlParseError(command.config, _)),
  )

  use config_dynamic <- result.try(
    list.first(config_dynamic)
    |> result.map_error(fn(_) {
      YamlParseError(
        command.config,
        glaml.ParsingError(
          "yaml file is contains no document",
          glaml.YamlErrorLoc(0, 0),
        ),
      )
    }),
  )

  use config <- result.try(
    decode.run(config_dynamic, config.config_decoder())
    |> result.map_error(fn(e) {
      DecodeConfigError(command.config, json.UnableToDecode(e))
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

  log.info("running extractor", [])

  case command {
    command.RunParameters(_) -> {
      use extracted <- result.try(
        input_loader.try_load_all(input_loader, fn(in_file) {
          log.info("extracting data from file", [
            #("file_id", in_file.name),
            #("progress", int.to_string(in_file.progress)),
            #("total_files", case in_file.total_files {
              None -> "?"
              Some(t) -> int.to_string(t)
            }),
          ])

          extract_from_file(in_file, config)
        })
        |> result.map_error(fn(te) {
          case te {
            input_loader.LoaderError(e) -> InputLoaderError(e)
            input_loader.FuncError(f, e) -> ExtractFromFileError(f, e)
          }
        }),
      )
      Ok(extracted)
    }
    command.TestEnrichersParameters(config:, extra_enrichers:) -> {
      todo
      //   log.info("loading all files", [])
      //
      //   let bar = progress.fancy_slim_arrow_bar()
      //
      //   let all_docs =
      //     input_loader.fold_load_all(input_loader, #(bar, []), fn(acc, file) {
      //       let #(bar, loaded) = acc
      //
      //       let bar = case file.total_files {
      //         None -> progress.tick(bar)
      //         Some(l) -> progress.with_length(bar, l) |> progress.tick
      //       }
      //
      //       progress.print_bar(bar)
      //
      //       [extracted_data.empty(in_file), ..loaded]
      //     })
      //
      //   log.info("running extractor on all files", [])
      //
      //   let bar =
      //     progress.fancy_slim_arrow_bar()
      //     |> progess.with_length(list.len(all_docs))
      //   list.try_fold(all_docs, #(bar, []), fn(acc, file) {
      //     let #(bar, finished) = acc
      //     let bar = progress.tick(bar)
      //
      //     extract_from_file(file, config)
      //   })
    }
  }
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
