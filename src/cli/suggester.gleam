//// Optional external "suggester" that proposes a YAML rule for a
//// transaction that could not be classified. Configured by the
//// `suggester:` block in the main YAML config:
////
//// ```yaml
//// suggester:
////   command: ["bash", "/path/to/suggest.sh"]
//// ```
////
//// The command receives a set of context files via environment variables —
//// caller-chosen names point at temp files populated with the corresponding
//// content. In addition, `T2L_SUGGESTION_FILE` points at a file the command
//// must write its suggestion to.
////
//// stdin/stdout/stderr are inherited from the terminal so the user can see
//// the command's progress and debug it. The contents of
//// `T2L_SUGGESTION_FILE` are used as the seed for the editor.

import gleam/bit_array
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}

pub type Suggester {
  Suggester(command: List(String), example_count: Option(Int))
}

pub fn decoder() -> decode.Decoder(Suggester) {
  use command <- decode.field("command", decode.list(decode.string))
  use example_count <- decode.optional_field(
    "example_count",
    option.None,
    decode.optional(decode.int),
  )
  decode.success(Suggester(command:, example_count:))
}

/// Run the suggester. Each `(env_var_name, content)` pair becomes a temp file;
/// its path is exposed to the command via the named environment variable. The
/// command writes its suggestion to `T2L_SUGGESTION_FILE` and that file's
/// contents are returned as a UTF-8 string.
pub fn suggest(
  s: Suggester,
  inputs: List(#(String, String)),
) -> Result(String, String) {
  let ffi_inputs =
    list.map(inputs, fn(kv) { #(kv.0, bit_array.from_string(kv.1)) })
  case run_ffi(s.command, ffi_inputs) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(s) -> Ok(s)
        Error(_) -> Error("suggester returned non-UTF-8 output")
      }
    Error(e) -> Error(e)
  }
}

@external(erlang, "suggester_ffi", "run")
fn run_ffi(
  args: List(String),
  inputs: List(#(String, BitArray)),
) -> Result(BitArray, String)
