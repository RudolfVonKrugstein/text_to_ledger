//// Optional external "suggester" that proposes a YAML rule for a
//// transaction that could not be classified. Configured by the
//// `suggester:` block in the main YAML config:
////
//// ```yaml
//// suggester:
////   command: ["bash", "/path/to/suggest.sh"]
//// ```
////
//// The command is invoked with two environment variables:
////   - `T2L_PROMPT_FILE`: path to a file containing the prompt
////   - `T2L_SUGGESTION_FILE`: path the command must write its suggestion to
////
//// stdin/stdout/stderr are inherited from the terminal so the user can see
//// the command's progress and debug it. The contents of
//// `T2L_SUGGESTION_FILE` are used as the seed for the editor.

import gleam/bit_array
import gleam/dynamic/decode

pub type Suggester {
  Suggester(command: List(String))
}

pub fn decoder() -> decode.Decoder(Suggester) {
  use command <- decode.field("command", decode.list(decode.string))
  decode.success(Suggester(command:))
}

/// Run the suggester. The prompt is written to a temp file whose path is
/// passed via `T2L_PROMPT_FILE`; the command is expected to write its
/// suggestion to the path in `T2L_SUGGESTION_FILE`. That file's contents
/// are returned as a UTF-8 string.
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
