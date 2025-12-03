//// A `SplitRegex` allows spliting a string without
//// removing the matched part and at the same time
//// specifing if the split should occure before or after
//// the match.

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/result
import regex/regex
import regexp_ext

/// SplitRegex holds the regex and the information if the split should occure before or after.
pub type SplitRegex {
  SplitBefore(regex: regex.Regex)
  SplitAfter(regex: regex.Regex)
}

/// Compile a split regex, that splits before the match.
pub fn compile_before(regex: String) {
  use regex <- result.try(regex.compile(regex))
  Ok(SplitBefore(regex:))
}

/// Compile a split regex, that splits after the match.
pub fn compile_after(regex: String) {
  use regex <- result.try(regex.compile(regex))
  Ok(SplitAfter(regex:))
}

/// Decode form a dynamic, for example in `json.parse`
pub fn decoder() -> decode.Decoder(SplitRegex) {
  decode.one_of(regex.regex_decoder() |> decode.map(SplitBefore), [
    {
      use variant <- decode.field("split", decode.string)
      use regex <- decode.field("regex", regex.regex_decoder())
      case variant {
        "after" -> decode.success(SplitAfter(regex))
        _ -> decode.success(SplitBefore(regex))
      }
    },
  ])
}

/// split a string using the regex once.
///
/// # Parameters
///
/// - `with`: The regex used for spliting.
/// - `over`: The string to split.
///
/// # Returns
///
/// A tuple with the string before and after the split.
pub fn split(
  with regex: SplitRegex,
  over subject: String,
) -> Option(#(String, String)) {
  case regex {
    SplitBefore(regex) -> regexp_ext.split_before(regex.regexp, subject)
    SplitAfter(regex) -> regexp_ext.split_after(regex.regexp, subject)
  }
}

/// split a string using the regex as often as possible.
///
/// # Parameters
///
/// - `with`: The regex used for spliting.
/// - `over`: The string to split.
///
/// # Returns
///
/// A list, with all the parts of `over` split up.
pub fn split_all(with regex: SplitRegex, over subject: String) -> List(String) {
  case regex {
    SplitBefore(regex) -> regexp_ext.split_before_all(regex.regexp, subject)
    SplitAfter(regex) -> regexp_ext.split_after_all(regex.regexp, subject)
  }
}
