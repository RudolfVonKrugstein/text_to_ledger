import gleam/dynamic/decode
import regex/regex

pub type ExtractRegex {
  ExtractRegex(regex: regex.RegexWithOpts, on: String)
}

pub fn extract_regex_decoder() -> decode.Decoder(ExtractRegex) {
  decode.one_of(
    {
      use regex <- decode.then(regex.regex_opt_decoder())

      decode.success(ExtractRegex(regex:, on: "content"))
    },
    [
      {
        use regex <- decode.field("regex", regex.regex_opt_decoder())
        use on <- decode.optional_field("on", "content", decode.string)
        decode.success(ExtractRegex(regex:, on:))
      },
    ],
  )
}
