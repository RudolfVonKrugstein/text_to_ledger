import data/regex
import gleam/dynamic/decode
import gleam/option.{type Option}
import regexp_ext

pub type SplitRegex {
  SplitBefore(regex: regex.Regex)
  SplitAfter(regex: regex.Regex)
}

pub fn split_regex_decoder() -> decode.Decoder(SplitRegex) {
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

pub fn split(
  with regex: SplitRegex,
  over subject: String,
) -> Option(#(String, String)) {
  case regex {
    SplitBefore(regex) -> regexp_ext.split_before(regex.regexp, subject)
    SplitAfter(regex) -> regexp_ext.split_after(regex.regexp, subject)
  }
}

pub fn split_all(with regex: SplitRegex, over subject: String) -> List(String) {
  case regex {
    SplitBefore(regex) -> regexp_ext.split_before_all(regex.regexp, subject)
    SplitAfter(regex) -> regexp_ext.split_after_all(regex.regexp, subject)
  }
}
