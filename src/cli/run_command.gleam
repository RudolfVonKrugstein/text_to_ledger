import cli/common
import cli/config/config
import cli/error.{ExtractFromFileError, InputLoaderError}
import data/continuation_check
import data/ledger
import data/sanity_check
import data/transaction_sheet
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import input_loader/input_loader
import simplifile

fn clear_line() {
  io.print("\u{001B}[2K\r")
}

fn move_cursor_up(lines: Int) {
  io.print("\u{001B}[" <> int.to_string(lines) <> "A")
}

fn progress_bar(current: Int, total: Int, width: Int) -> String {
  let progress = case total {
    0 -> 0.0
    _ -> int.to_float(current) /. int.to_float(total)
  }
  let filled = float.round(progress *. int.to_float(width))
  let filled_str = string.repeat("█", filled)
  let empty_str = string.repeat("░", width - filled)
  let percentage = float.round(progress *. 100.0)
  "[" <> filled_str <> empty_str <> "] " <> int.to_string(percentage) <> "%"
}

fn extract_with_input_loader(
  loader: input_loader.InputLoader,
  config: config.Config,
) -> Result(
  List(#(transaction_sheet.TransactionSheet, List(ledger.LedgerEntry))),
  error.Error,
) {
  input_loader.try_load_all(loader, fn(in_file) {
    move_cursor_up(1)
    clear_line()
    move_cursor_up(1)
    clear_line()
    io.println(
      int.to_string(in_file.progress + 1)
      <> "/"
      <> case in_file.total_files {
        None -> "?"
        Some(tf) -> int.to_string(tf)
      }
      <> ": "
      <> in_file.name,
    )
    case in_file.total_files {
      None -> io.println("...")
      Some(tf) -> {
        io.println(progress_bar(in_file.progress + 1, tf, 30))
      }
    }

    common.extract_from_file(in_file, config)
  })
  |> result.map_error(fn(te) {
    case te {
      input_loader.LoaderError(e) -> InputLoaderError(e)
      input_loader.FuncError(f, e) -> ExtractFromFileError(f, e)
    }
  })
}

pub fn run(
  input_loaders: List(input_loader.InputLoader),
  config: config.Config,
  output: String,
) {
  use _ <- result.try(
    simplifile.write(output, "") |> result.map_error(error.WriteLedgerError),
  )

  use input_loader <- list.try_map(input_loaders)

  use extracted <- result.try(extract_with_input_loader(input_loader, config))

  echo list.map(extracted, fn(e) {
    let #(sheet, ledger) = e
    sanity_check.sanity_checks(sheet, ledger)
  })

  echo continuation_check.check_continuation(
    list.map(extracted, fn(e) {
      let #(sheet, _ledger) = e
      sheet
    }),
  )

  // print out!
  list.each(extracted, fn(e) {
    let #(_, ledger) = e
    list.each(ledger, fn(l) {
      simplifile.append(output, ledger.to_string(l) <> "\n")
    })
  })

  Ok(Nil)
}
