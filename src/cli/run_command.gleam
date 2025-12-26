import cli/common
import cli/config/config
import cli/error.{ExtractFromFileError, InputLoaderError}
import gleam/int
import gleam/io
import gleam/option.{None, Some}
import gleam/result
import input_loader/input_loader
import shiny
import ui/progress
import utils/misc

pub fn run(input_loader: input_loader.InputLoader, config: config.Config) {
  io.println("starting")
  io.println("...")

  use extracted <- result.try(
    input_loader.try_load_all(input_loader, fn(in_file) {
      misc.move_cursor_up(1)
      shiny.clear_line()
      misc.move_cursor_up(1)
      shiny.clear_line()
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
          io.println(progress.progress_bar(in_file.progress + 1, tf, 30))
        }
      }

      use #(_, ledgers) <- result.try(common.extract_from_file(in_file, config))

      Ok(ledgers)
    })
    |> result.map_error(fn(te) {
      case te {
        input_loader.LoaderError(e) -> InputLoaderError(e)
        input_loader.FuncError(f, e) -> ExtractFromFileError(f, e)
      }
    }),
  )
  Ok(Nil)
}
