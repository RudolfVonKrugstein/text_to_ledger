import data/regex
import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/regexp
import regexp_ext/regexp_ext

pub type SplitRegex {
  SplitBefore(regex: regexp.Regexp)
  SplitAfter(regex: regexp.Regexp)
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
    SplitBefore(regex) -> regexp_ext.split_before(regex, subject)
    SplitAfter(regex) -> regexp_ext.split_after(regex, subject)
  }
}

pub fn split_all(with regex: SplitRegex, over subject: String) -> List(String) {
  case regex {
    SplitBefore(regex) -> regexp_ext.split_before_all(regex, subject)
    SplitAfter(regex) -> regexp_ext.split_after_all(regex, subject)
  }
}
