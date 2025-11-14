import gleam/dynamic/decode
import gleam/option.{type Option, None}
import regex/regex

pub type ExtractRegex {
  ExtractRegex(regex: regex.RegexWithOpts, on: Option(String))
}

pub fn extract_regex_decoder() -> decode.Decoder(ExtractRegex) {
  decode.one_of(
    {
      use regex <- decode.then(regex.regex_opt_decoder())

      decode.success(ExtractRegex(regex:, on: None))
    },
    [
      {
        use regex <- decode.field("regex", regex.regex_opt_decoder())
        use on <- decode.optional_field(
          "on",
          None,
          decode.optional(decode.string),
        )
        decode.success(ExtractRegex(regex:, on:))
      },
    ],
  )
}
