import cli/common
import cli/config/config
import cli/error.{ExtractFromFileError, InputLoaderError}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import input_loader/input_loader
import shiny
import ui/progress
import utils/misc

fn extract_with_input_loader(
  loader: input_loader.InputLoader,
  config: config.Config,
) {
  input_loader.try_load_all(loader, fn(in_file) {
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
  })
}

pub fn run(input_loaders: List(input_loader.InputLoader), config: config.Config) {
  use input_loader <- list.try_map(input_loaders)

  use extracted <- result.try(extract_with_input_loader(input_loader, config))

  Ok(Nil)
}
