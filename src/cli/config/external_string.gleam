import dot_env/env
import gleam/dynamic/decode
import gleam/string
import simplifile

/// A String, that can also be loaded from an external source
pub fn decoder() {
  decode.one_of(decode.string, [
    {
      use var <- decode.field("env_var", decode.string)
      case env.get_string(var) {
        Ok(s) -> decode.success(s)
        Error(e) ->
          decode.failure("", "unable to load env var " <> var <> ": " <> e)
      }
    },
    {
      use file <- decode.field("file", decode.string)
      case simplifile.read(file) {
        Ok(s) -> decode.success(s)
        Error(e) ->
          decode.failure(
            "",
            "unable to load " <> file <> ": " <> string.inspect(e),
          )
      }
    },
  ])
}
