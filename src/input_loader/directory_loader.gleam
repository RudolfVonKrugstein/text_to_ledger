import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import input_loader/error.{type InputLoaderError, ReadDirectoryError}
import input_loader/input_file.{type InputFile, InputFile}
import input_loader/input_loader.{type InputLoader, InputLoader}
import simplifile

fn next_impl(
  progress: Int,
  loader_name: String,
  all: List(String),
) -> Result(Option(#(InputFile, InputLoader)), InputLoaderError) {
  case all {
    [] -> Ok(None)
    [f, ..rest] -> {
      use content <- result.try(
        simplifile.read(f)
        |> result.map_error(ReadDirectoryError(f, _)),
      )
      let assert Ok(first_char) = string.first(content)
      let assert Ok(#(_, content)) = string.split_once(content, first_char)
      Ok(
        Some(#(
          InputFile(
            name: f,
            loader: loader_name,
            title: f,
            content: content,
            progress: progress,
            total_files: Some(list.length(all) + progress),
          ),
          InputLoader(fn() { next_impl(progress + 1, loader_name, rest) }),
        )),
      )
    }
  }
}

pub fn new(name: String, dir: String) {
  use files <- result.try(
    simplifile.get_files(dir)
    |> result.map_error(fn(e) { ReadDirectoryError(path: dir, error: e) }),
  )
  Ok(InputLoader(next: fn() { next_impl(0, name, files) }))
}
