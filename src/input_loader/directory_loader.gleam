import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import input_loader/input_loader.{
  type InputFile, type InputLoader, InputFile, InputLoader,
}
import simplifile

fn rec_list_files(dir: String, listing: List(String)) {
  case listing {
    [] -> Ok([])
    [f, ..rest] -> {
      use rest <- result.try(rec_list_files(dir, rest))

      let path = dir <> "/" <> f
      use is_dir <- result.try(simplifile.is_directory(path))
      case is_dir {
        False -> Ok([path, ..rest])
        True -> {
          use sublisting <- result.try(simplifile.read_directory(path))
          Ok(list.flatten([sublisting, rest]))
        }
      }
    }
  }
}

fn rec_read_directory(dir: String) {
  use listing <- result.try(simplifile.read_directory(dir))
  rec_list_files(dir, listing)
}

fn next_impl(
  all: List(String),
) -> Result(Option(#(InputFile, InputLoader)), String) {
  case all {
    [] -> Ok(None)
    [f, ..rest] -> {
      use content <- result.try(
        simplifile.read(f)
        |> result.map_error(fn(e) {
          "unable to read " <> f <> ": " <> string.inspect(e)
        }),
      )
      Ok(Some(#(InputFile(f, content), InputLoader(fn() { next_impl(rest) }))))
    }
  }
}

pub fn new(dir: String) {
  use files <- result.try(rec_read_directory(dir))
  Ok(InputLoader(fn() { next_impl(files) }))
}
