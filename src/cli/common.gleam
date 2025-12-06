import cli/config/config
import cli/error.{
  EnricherError, ExtractedDataError, NoExtractorMatch, ToManyExtractorMatched,
}
import data/extracted_data
import data/ledger
import data/transaction_sheet
import enricher/enricher
import extractor/extractor
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import input_loader/input_file.{type InputFile}

fn errors(results: List(Result(a, e))) -> List(e) {
  list.filter_map(results, fn(result) {
    case result {
      Error(e) -> Ok(e)
      Ok(v) -> Error(v)
    }
  })
}

fn find_matching_extractor(
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
      ledger.from_extracted_data(t)
      |> result.map_error(ExtractedDataError(t, err: _))
    }),
  )

  Ok(#(sheet, transactions))
}
