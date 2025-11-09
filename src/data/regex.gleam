import gleam/dynamic/decode
import gleam/regexp
import gleam/result

pub type RegexWithOpts {
  RegexWithOpts(regex: regexp.Regexp, original: String, optional: Bool)
}

pub fn compile(regex: String, optional: Bool) {
  use compiled <- result.try(regexp.compile(regex, regexp.Options(False, True)))
  Ok(RegexWithOpts(compiled, regex, optional))
}

pub fn compile_with_default_opts(regex: String) {
  use compiled <- result.try(regexp.compile(regex, regexp.Options(False, True)))
  Ok(RegexWithOpts(compiled, regex, False))
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
  let compile_decode = fn(plain: String, optional: Bool) {
    case compile(plain, optional) {
      Ok(r) -> decode.success(r)
      Error(_e) -> {
        let assert Ok(zero) = compile_with_default_opts("")
        decode.failure(zero, "unable to compile regex: " <> plain)
      }
    }
  }

  decode.one_of(
    {
      // plain regex as string
      use plain <- decode.then(decode.string)
      compile_decode(plain, False)
    },
    [
      {
        use plain <- decode.field("regex", decode.string)
        use optional <- decode.optional_field("optional", False, decode.bool)
        compile_decode(plain, optional)
      },
    ],
  )
}
