import cli/config/config
import cli/config/input_config
import cli/parameters
import data/ledger
import data/transaction_sheet
import dot_env
import enricher/enricher
import extracted_data/extracted_data
import extractor/extractor
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import glight
import input_loader/error as input_error
import input_loader/input_file.{type InputFile}
import input_loader/input_loader
import simplifile

pub type Error {
  ParseParameterError(msg: String)
  ReadConfigError(file: String, error: simplifile.FileError)
  DecodeConfigError(file: String, error: json.DecodeError)
  InputLoaderError(err: input_error.InputLoaderError)
  ExtractFromFileError(file: InputFile, err: ExtractFromFileError)
}

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

pub type ExtractFromFileError {
  ExtractorError(err: extractor.ExtractorError)
  NoExtractorMatch(errors: List(extractor.ExtractorError))
  ToManyExtractorMatched(num: Int)
  ExtractedDataError(err: extracted_data.ExtractedDataError)
  EnricherError(err: enricher.EnricherError)
}

pub fn extract_from_file(input_file: InputFile, config: config.Config) {
  use #(sheet, transactions) <- result.try(find_matching_extractor(
    input_file,
    config.extractors,
  ))

  use sheet <- result.try(
    transaction_sheet.from_extracted_data(sheet)
    |> result.map_error(ExtractedDataError),
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
    list.try_map(transactions, fn(t) { ledger.from_extracted_data(t, sheet) })
    |> result.map_error(ExtractedDataError),
  )

  Ok(#(sheet, transactions))
}

pub fn cli() {
  let log = glight.logger()
  log |> glight.debug("loading environment variables using dot_env")

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load

  log |> glight.debug("parsing input parameters")

  use parameters <- result.try(
    parameters.parameters() |> result.map_error(ParseParameterError),
  )

  log
  |> glight.with("config", parameters.config)
  |> glight.debug("parsed input parameters")

  log
  |> glight.with("config_file", parameters.config)
  |> glight.info("loading config")

  use config <- result.try(
    simplifile.read(from: parameters.config)
    |> result.map_error(ReadConfigError(parameters.config, _)),
  )

  log |> glight.debug("parsing config")

  use config <- result.try(
    json.parse(config, config.config_decoder())
    |> result.map_error(DecodeConfigError(parameters.config, _)),
  )

  log
  |> glight.with("name", config.input.name)
  |> glight.with("type", input_config.name(config.input))
  |> glight.info("creating input loader")

  use input_loader <- result.try(
    input_config.create_input_loader(config.input)
    |> result.map_error(InputLoaderError),
  )

  log
  |> glight.info("running extractor")

  use extracted <- result.try(
    input_loader.try_load_all(input_loader, fn(in_file) {
      log
      |> glight.with("file_id", in_file.name)
      |> glight.info("extracting data from file")

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
