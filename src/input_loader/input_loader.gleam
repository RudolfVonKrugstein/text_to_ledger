import gleam/option.{None, Some}
import gleam/result

pub type InputLoader {
  InputLoader(
    next: fn() -> Result(option.Option(#(InputFile, InputLoader)), String),
  )
}

pub type InputFile {
  InputFile(name: String, content: String)
}

pub fn next(loader: InputLoader) {
  loader.next()
}

pub fn load_all(
  loader: InputLoader,
  f: fn(InputFile) -> res,
) -> Result(List(res), String) {
  use n <- result.try(next(loader))
  case n {
    None -> Ok([])
    Some(#(text, loader)) -> {
      use rest <- result.try(load_all(loader, f))
      Ok([f(text), ..rest])
    }
  }
}

pub fn try_load_all(
  loader: InputLoader,
  f: fn(InputFile) -> Result(res, String),
) -> Result(List(res), String) {
  use n <- result.try(next(loader))
  case n {
    None -> Ok([])
    Some(#(text, loader)) -> {
      use this <- result.try(f(text))
      use rest <- result.try(try_load_all(loader, f))
      Ok([this, ..rest])
    }
  }
}
