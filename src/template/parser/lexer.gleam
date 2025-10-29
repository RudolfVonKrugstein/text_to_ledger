import gleam/regexp
import nibble/lexer

type Mode {
  // in free text
  TextMode
  // inside a variable
  VariableMode
  // inside the mods
  ModMode
  // inside the parameter-list
  ParameterMode
}

pub type Token {
  WhiteSpace
  TextToken(String)
  EscapedTextToken(String)
  LBraceToken
  RBraceToken
  VariableToken(name: String)
  PipeToken
  ModToken(name: String)
  LParanToken
  RParanToken
  CommaToken
  ParameterToken(String)
  EscapedParameterToken(String)
}

fn text() {
  use mode, lexeme, next <- lexer.custom

  case mode {
    TextMode -> {
      case next {
        "{" | "\\" | "" if lexeme != "\\" -> lexer.Keep(TextToken(lexeme), mode)
        _ -> lexer.Skip
      }
    }
    _ -> lexer.NoMatch
  }
}

fn escaped_text() {
  use mode, lexeme, _next <- lexer.custom

  case mode {
    TextMode -> {
      case lexeme {
        "\\" -> lexer.Skip
        "\\" <> _s -> lexer.Keep(EscapedTextToken(lexeme), mode)
        _ -> lexer.NoMatch
      }
    }
    _ -> lexer.NoMatch
  }
}

fn parameter() {
  use mode, lexeme, next <- lexer.custom

  case mode {
    ParameterMode -> {
      case next {
        "," | ")" | "\\" | "" if lexeme != "\\" ->
          lexer.Keep(ParameterToken(lexeme), mode)
        _ -> lexer.Skip
      }
    }
    _ -> lexer.NoMatch
  }
}

fn escaped_parameter() {
  use mode, lexeme, _next <- lexer.custom

  case mode {
    ParameterMode -> {
      case lexeme {
        "\\" -> lexer.Skip
        "\\" <> _s -> lexer.Keep(EscapedTextToken(lexeme), mode)
        _ -> lexer.NoMatch
      }
    }
    _ -> lexer.NoMatch
  }
}

fn variable() {
  use _mode, lexeme, next <- lexer.custom

  let assert Ok(r) =
    regexp.compile("[a-zA-Z][a-zA-Z0-9_]*", regexp.Options(False, False))
  let assert Ok(n) =
    regexp.compile("[a-zA-Z0-9_]", regexp.Options(False, False))

  case regexp.check(r, lexeme) {
    False -> lexer.NoMatch
    True ->
      case regexp.check(n, next) {
        False -> lexer.Keep(VariableToken(lexeme), VariableMode)
        True -> lexer.Skip
      }
  }
}

pub fn run(s: String) {
  let lexer =
    lexer.advanced(fn(mode) {
      case mode {
        TextMode -> [
          lexer.token("{", LBraceToken) |> lexer.into(fn(_) { VariableMode }),
          text(),
          escaped_text(),
        ]
        VariableMode -> [
          lexer.whitespace(WhiteSpace) |> lexer.ignore,
          lexer.token("}", RBraceToken) |> lexer.into(fn(_) { TextMode }),
          lexer.token("|", PipeToken) |> lexer.into(fn(_) { ModMode }),
          variable(),
        ]
        ModMode -> [
          lexer.whitespace(WhiteSpace) |> lexer.ignore,
          variable(),
          lexer.token("}", RBraceToken) |> lexer.into(fn(_) { TextMode }),
          lexer.token("|", PipeToken),
          lexer.token("(", LParanToken) |> lexer.into(fn(_) { ParameterMode }),
        ]
        ParameterMode -> [
          lexer.token(")", RParanToken) |> lexer.into(fn(_) { ModMode }),
          lexer.token(",", CommaToken),
          parameter(),
          escaped_parameter(),
        ]
      }
    })

  lexer.run_advanced(s, TextMode, lexer)
}
