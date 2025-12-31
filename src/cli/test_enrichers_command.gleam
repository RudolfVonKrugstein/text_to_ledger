import cli/common
import cli/config/config
import cli/error
import cli/log
import data/extracted_data.{type ExtractedData}
import data/ledger
import enricher/enricher
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import input_loader/input_file
import input_loader/input_loader
import shiny
import ui/progress
import utils/misc

type InterimResult {
  IterimResult(
    files: List(input_file.InputFile),
    matched: #(List(ExtractedData), List(error.Error)),
    enriched: List(ExtractedData),
    ledger: #(List(ledger.LedgerEntry), List(error.Error)),
  )
}

pub fn map_collect_oks_and_errors(
  l: List(i),
  f: fn(i) -> Result(r, e),
) -> #(List(r), List(e)) {
  io.println("")
  let num_in = list.length(l)
  list.index_fold(l, #([], []), fn(res, in, progress) {
    let #(oks, errors) = res

    // clear the old line
    misc.move_cursor_up(1)
    shiny.clear_line()
    // print the status line
    io.println(
      progress.progress_bar(progress + 1, num_in, 30)
      <> " ("
      <> int.to_string(progress + 1)
      <> "/"
      <> int.to_string(num_in)
      <> ")",
    )

    case f(in) {
      Error(e) -> #(oks, [e, ..errors])
      Ok(d) -> #([d, ..oks], errors)
    }
  })
}

pub fn run(
  input_loaders: List(input_loader.InputLoader),
  config: config.Config,
  extra_enrichers: String,
) {
  log.info("loading all input file into memory", [])
  io.println("")

  use input_loader <- list.try_map(input_loaders)

  use in_files <- result.try(
    input_loader.load_all(input_loader, fn(in_file) {
      // clear the old line
      misc.move_cursor_up(1)
      shiny.clear_line()
      // print the status line
      case in_file.total_files {
        None -> io.println("...")
        Some(tf) -> {
          io.println(progress.progress_bar(in_file.progress + 1, tf, 30))
        }
      }
      in_file
    })
    |> result.map_error(error.InputLoaderError),
  )

  let num_in_files = list.length(in_files)
  log.info("loaded input files", [
    #("#files", int.to_string(num_in_files)),
  ])

  log.info("finding extractors", [])
  io.println("")

  let #(extracted, extract_errors) =
    map_collect_oks_and_errors(in_files, fn(in_file) {
      common.find_matching_extractor(in_file, config.extractors)
      |> result.map_error(fn(e) { error.ExtractFromFileError(in_file, e) })
    })

  log.info("found extractors", [
    #("#success", int.to_string(list.length(extracted))),
    #("#fails", int.to_string(list.length(extract_errors))),
  ])

  use _ <- result.try(case extract_errors {
    [] -> Ok(Nil)
    [e, ..] -> Error(e)
  })

  let transactions =
    extracted
    |> list.map(fn(e) {
      let #(_, ts) = e
      ts
    })
    |> list.flatten

  let num_transactions = list.length(transactions)
  log.info("running enrichers", [
    #("#transactions", int.to_string(num_transactions)),
    #("#enrichers", int.to_string(list.length(config.enrichers))),
  ])

  let #(enriched, enricher_errors) =
    map_collect_oks_and_errors(transactions, fn(transaction) {
      list.try_fold(config.enrichers, transaction, fn(transaction, enricher) {
        enricher.try_maybe_apply(transaction, enricher)
      })
    })

  log.info("enriched transactions", [
    #("#success", int.to_string(list.length(enriched))),
    #("#fails", int.to_string(list.length(enricher_errors))),
  ])

  log.info("converting to ledger", [
    #("#transactions", int.to_string(list.length(enriched))),
  ])
  let #(ledgers, ledger_errors) =
    map_collect_oks_and_errors(enriched, fn(transaction) {
      ledger.from_extracted_data(transaction)
    })
  log.info("converted to ledger", [
    #("#success", int.to_string(list.length(ledgers))),
    #("#fails", int.to_string(list.length(ledger_errors))),
  ])

  // let assert Ok(fs) = file_watcher.start(extra_enrichers)
  // file_watcher.wait_for_event(fs)

  log.info("done waiting", [])

  Ok(Nil)
}
