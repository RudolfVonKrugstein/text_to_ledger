import gleam/option
import gleam/regexp

pub type NamedCapture {
  NamedCapture(name: String, value: String)
}

/// Get contents of named capture groups in a regex match.
///
/// # Parameters:
///   regex: The regex with the capure groups.
///   over: The string to run the regex over.
///
/// # Result:
///   Lixt of matches, where every match is a list of the values
///   of the capture gorups in the same order as the input `names`.
@external(erlang, "regexp_ext_ffi", "capture_names")
@external(javascript, "../regexp_ext_ffi.mjs", "capture_names")
pub fn capture_names(
  regex regex: regexp.Regexp,
  over subject: String,
) -> List(List(NamedCapture))

/// Split a string after the first time the regex matches.
@external(erlang, "regexp_ext_ffi", "split_after")
@external(javascript, "../regexp_ext_ffi.mjs", "split_after")
pub fn split_after(
  regex regex: regexp.Regexp,
  over subject: String,
) -> option.Option(#(String, String))

/// Split a string before the first time the regex matches.
@external(erlang, "regexp_ext_ffi", "split_before")
@external(javascript, "../regexp_ext_ffi.mjs", "split_before")
pub fn split_before(
  regex regex: regexp.Regexp,
  over subject: String,
) -> option.Option(#(String, String))
