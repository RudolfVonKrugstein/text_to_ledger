import cli/main
import gleam/io

pub fn main() -> Nil {
  let assert Ok(_) = main.cli()
  Nil
}
