import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import input_loader/error.{type InputLoaderError, ReadDirectoryError}
import input_loader/input_file.{type InputFile, InputFile}
import input_loader/input_loader.{type InputLoader, InputLoader}
import simplifile

fn rec_list_files(
  dir: String,
  listing: List(String),
) -> Result(List(String), InputLoaderError) {
  case listing {
    [] -> Ok([])
    [f, ..rest] -> {
      use rest <- result.try(rec_list_files(dir, rest))

      let path = dir <> "/" <> f
      use is_dir <- result.try(
        simplifile.is_directory(path)
        |> result.map_error(ReadDirectoryError(path, _)),
      )
      case is_dir {
        False -> Ok([f, ..rest])
        True -> {
          use sublisting <- result.try(
            simplifile.read_directory(path)
            |> result.map_error(ReadDirectoryError(path, _)),
          )
          let sublisting = list.map(sublisting, fn(d) { f <> "/" <> d })
          use subdir <- result.try(rec_list_files(dir, sublisting))
          Ok(list.append(subdir, rest))
        }
      }
    }
  }
}

fn rec_read_directory(dir: String) {
  use listing <- result.try(
    simplifile.read_directory(dir)
    |> result.map_error(ReadDirectoryError(dir, _)),
  )
  rec_list_files(dir, listing)
}

fn next_impl(
  progress: Int,
  loader_name: String,
  dir: String,
  all: List(String),
) -> Result(Option(#(InputFile, InputLoader)), InputLoaderError) {
  let dir = case string.ends_with(dir, "/") {
    False -> dir
    True -> string.drop_end(dir, 1)
  }
  case all {
    [] -> Ok(None)
    [f, ..rest] -> {
      use content <- result.try(
        simplifile.read(dir <> "/" <> f)
        |> result.map_error(ReadDirectoryError(f, _)),
      )
      let assert Ok(first_char) = string.first(content)
      let assert Ok(#(_, content)) = string.split_once(content, first_char)
      Ok(
        Some(#(
          InputFile(
            name: dir <> "/" <> f,
            loader: loader_name,
            title: f,
            content: content,
            progress: progress,
            total_files: Some(list.length(all) + progress),
          ),
          InputLoader(fn() { next_impl(progress + 1, loader_name, dir, rest) }),
        )),
      )
    }
  }
}

pub fn new(name: String, dir: String) {
  use files <- result.try(rec_read_directory(dir))
  Ok(InputLoader(next: fn() { next_impl(0, name, dir, files) }))
}
