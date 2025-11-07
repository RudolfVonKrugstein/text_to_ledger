import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/string

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
  with regex: regexp.Regexp,
  over subject: String,
) -> List(List(NamedCapture))

/// Split a string after the first time the regex matches.
@external(erlang, "regexp_ext_ffi", "split_after")
@external(javascript, "../regexp_ext_ffi.mjs", "split_after")
pub fn split_after(
  with regex: regexp.Regexp,
  over subject: String,
) -> Option(#(String, String))

/// Split a string before the first time the regex matches.
@external(erlang, "regexp_ext_ffi", "split_before")
@external(javascript, "../regexp_ext_ffi.mjs", "split_before")
pub fn split_before(
  with regex: regexp.Regexp,
  over subject: String,
) -> Option(#(String, String))

/// Split a string returning before, the match and after
@external(erlang, "regexp_ext_ffi", "split_match")
@external(javascript, "../regexp_ext_ffi.mjs", "split_match")
pub fn split_match(
  with regex: regexp.Regexp,
  over subject: String,
) -> Option(#(String, String, String))

pub fn split_after_all(with regex: regexp.Regexp, over subject: String) {
  case split_after(regex, subject) {
    None -> [subject]
    Some(#("", rest)) -> {
      case string.pop_grapheme(rest) {
        Error(_) -> []
        Ok(#(s, rest)) -> [s, ..split_after_all(regex, rest)]
      }
    }
    Some(#(before, "")) -> [before]
    Some(#(before, rest)) -> [before, ..split_after_all(regex, rest)]
  }
}

pub fn split_before_all(with regex: regexp.Regexp, over subject: String) {
  case split_match(regex, subject) {
    None -> [subject]
    Some(#("", "", rest)) -> {
      case string.pop_grapheme(rest) {
        Error(_) -> []
        Ok(#(s, rest)) -> [s, ..split_after_all(regex, rest)]
      }
    }
    Some(#(before, "", "")) -> [before]
    Some(#(before, match, "")) -> [before, match]
    Some(#(before, match, rest)) -> {
      case split_before_all(regex, rest) {
        [] -> [before, match]
        [next, ..rest] -> [before, match <> next, ..rest]
      }
    }
  }
}

pub type SplitRegex {
  SplitBefore(regex: regexp.Regexp)
  SplitAfter(regex: regexp.Regexp)
}

pub fn split(
  with regex: SplitRegex,
  over subject: String,
) -> Option(#(String, String)) {
  case regex {
    SplitBefore(regex) -> split_before(regex, subject)
    SplitAfter(regex) -> split_after(regex, subject)
  }
}

pub fn split_all(with regex: SplitRegex, over subject: String) -> List(String) {
  case regex {
    SplitBefore(regex) -> split_before_all(regex, subject)
    SplitAfter(regex) -> split_after_all(regex, subject)
  }
}
