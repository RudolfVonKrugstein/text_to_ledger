import gleam/dynamic/decode
import gleam/regexp

pub type RegexWithOpts {
  RegexWithOpts(regex: regexp.Regexp, optional: Bool)
}

pub fn with_default_opts(regex: regexp.Regexp) {
  RegexWithOpts(regex, False)
}

/// Decode a regex from a string
pub fn regex_decoder() {
  use regex <- decode.then(decode.string)
  case regexp.compile(regex, regexp.Options(False, True)) {
    Error(_e) -> {
      let assert Ok(zero) = regexp.compile("", regexp.Options(False, True))
      decode.failure(zero, "unable to compile regex: " <> regex)
    }
    Ok(regex) -> decode.success(regex)
  }
}

pub fn regex_opt_decoder() {
  decode.one_of(
    {
      // plain regex as string
      use regex <- decode.then(regex_decoder())
      decode.success(RegexWithOpts(regex, False))
    },
    [
      {
        use regex <- decode.field("regex", regex_decoder())
        use optional <- decode.optional_field("optional", False, decode.bool)
        decode.success(RegexWithOpts(regex, optional))
      },
    ],
  )
}
