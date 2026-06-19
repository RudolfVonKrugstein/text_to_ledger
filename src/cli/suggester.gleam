//// Optional external "suggester" that proposes a YAML rule for a
//// transaction that could not be classified. Configured by the
//// `suggester:` block in the main YAML config:
////
//// ```yaml
//// suggester:
////   command: ["ollama", "run", "qwen2.5:3b"]
//// ```
////
//// The command is invoked with the prompt redirected to its stdin and its
//// stdout is captured and used as the seed for the editor.

import gleam/bit_array
import gleam/dynamic/decode

pub type Suggester {
  Suggester(command: List(String))
}

pub fn decoder() -> decode.Decoder(Suggester) {
  use command <- decode.field("command", decode.list(decode.string))
  decode.success(Suggester(command:))
}

/// Run the suggester. The prompt is piped to the command's stdin; whatever
/// is written to stdout (plus stderr) is returned as a UTF-8 string.
pub fn suggest(s: Suggester, prompt: String) -> Result(String, String) {
  case run_ffi(s.command, bit_array.from_string(prompt)) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(s) -> Ok(s)
        Error(_) -> Error("suggester returned non-UTF-8 output")
      }
    Error(e) -> Error(e)
  }
}

@external(erlang, "suggester_ffi", "run")
fn run_ffi(args: List(String), input: BitArray) -> Result(BitArray, String)
