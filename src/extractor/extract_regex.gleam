import gleam/dynamic/decode
import regex/regex

pub type ExtractRegex {
  ExtractRegex(regex: regex.RegexWithOpts, on: String)
}

pub fn decoder(default_on: String) -> decode.Decoder(ExtractRegex) {
  decode.one_of(
    {
      use on <- decode.optional_field("on", default_on, decode.string)

      use regex <- decode.then(regex.regex_opt_decoder())

      decode.success(ExtractRegex(regex:, on:))
    },
    [
      {
        regex.regex_opt_decoder()
        |> decode.map(fn(regex) { ExtractRegex(regex:, on: default_on) })
      },
    ],
  )
}
