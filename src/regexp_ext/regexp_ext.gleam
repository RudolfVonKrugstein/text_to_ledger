import gleam/option
import gleam/regexp

@external(erlang, "regexp_ext_ffi", "names")
pub fn names(regex: regexp.Regexp) -> List(String)

@external(erlang, "regexp_ext_ffi", "capture_names")
pub fn capture_names(
  regex: regexp.Regexp,
  subject: String,
  names: List(String),
) -> option.Option(List(List(String)))
