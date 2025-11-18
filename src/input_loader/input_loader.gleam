import gleam/option.{None, Some}
import gleam/result
import input_loader/error.{type InputLoaderError}
import input_loader/input_file.{type InputFile}

pub type InputLoader {
  InputLoader(
    next: fn() ->
      Result(option.Option(#(InputFile, InputLoader)), InputLoaderError),
  )
}

pub fn next(loader: InputLoader) {
  loader.next()
}

pub fn load_all(
  loader: InputLoader,
  f: fn(InputFile) -> res,
) -> Result(List(res), InputLoaderError) {
  use n <- result.try(next(loader))
  case n {
    None -> Ok([])
    Some(#(text, loader)) -> {
      use rest <- result.try(load_all(loader, f))
      Ok([f(text), ..rest])
    }
  }
}

pub type TryError(err) {
  LoaderError(InputLoaderError)
  FuncError(input: InputFile, err: err)
}

pub fn try_load_all(
  loader: InputLoader,
  f: fn(InputFile) -> Result(res, err),
) -> Result(List(res), TryError(err)) {
  use n <- result.try(next(loader) |> result.map_error(LoaderError))
  case n {
    None -> Ok([])
    Some(#(text, loader)) -> {
      use this <- result.try(f(text) |> result.map_error(FuncError(text, _)))
      use rest <- result.try(try_load_all(loader, f))
      Ok([this, ..rest])
    }
  }
}
