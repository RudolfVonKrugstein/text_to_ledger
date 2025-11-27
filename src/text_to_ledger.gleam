import cli/error
import cli/main
import colored
import gleam/io

pub fn main() -> Nil {
  case main.cli() {
    Ok(_) -> io.println(colored.green("done, exiting"))
    Error(e) -> error.log(e)
  }
}
