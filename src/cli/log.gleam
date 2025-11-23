import colored
import gleam/io
import gleam/list

pub fn error(msg: String, vars: List(#(String, String))) {
  io.println(colored.red("ERROR: " <> msg))

  list.each(vars, fn(var) {
    let #(key, value) = var
    io.println("  " <> key <> ": " <> value)
  })
}

pub fn info(msg: String, vars: List(#(String, String))) {
  io.println(colored.blue(msg))

  list.each(vars, fn(var) {
    let #(key, value) = var
    io.println("  " <> key <> ": " <> value)
  })
}
