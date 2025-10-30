import gleam/list
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

fn text(trans: fn(String) -> Token, stops: List(String)) {
  use mode, lexeme, next <- lexer.custom

  case lexeme {
    "" -> lexer.Skip
    "\\" <> _s -> lexer.NoMatch
    _ ->
      case list.any(["", ..stops], fn(s) { s == next }) {
        True -> lexer.Keep(trans(lexeme), mode)
        False -> lexer.Skip
      }
  }
}

fn escaped_text(trans: fn(String) -> Token) {
  use mode, lexeme, _next <- lexer.custom

  case lexeme {
    "\\" -> lexer.Skip
    "\\" <> _s -> lexer.Keep(trans(lexeme), mode)
    _ -> lexer.NoMatch
  }
}

fn name(trans: fn(String) -> Token) {
  use mode, lexeme, next <- lexer.custom

  let assert Ok(r) =
    regexp.compile("[a-zA-Z][a-zA-Z0-9_]*", regexp.Options(False, False))
  let assert Ok(n) =
    regexp.compile("[a-zA-Z0-9_]", regexp.Options(False, False))

  case regexp.check(r, lexeme) {
    False -> lexer.NoMatch
    True ->
      case regexp.check(n, next) {
        False -> lexer.Keep(trans(lexeme), mode)
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
          text(TextToken, ["\\", "{"]),
          escaped_text(EscapedTextToken),
        ]
        VariableMode -> [
          lexer.whitespace(WhiteSpace) |> lexer.ignore,
          lexer.token("}", RBraceToken) |> lexer.into(fn(_) { TextMode }),
          lexer.token("|", PipeToken) |> lexer.into(fn(_) { ModMode }),
          name(VariableToken),
        ]
        ModMode -> [
          lexer.whitespace(WhiteSpace) |> lexer.ignore,
          name(ModToken),
          lexer.token("}", RBraceToken) |> lexer.into(fn(_) { TextMode }),
          lexer.token("|", PipeToken),
          lexer.token("(", LParanToken) |> lexer.into(fn(_) { ParameterMode }),
        ]
        ParameterMode -> [
          lexer.token(")", RParanToken) |> lexer.into(fn(_) { ModMode }),
          lexer.token(",", CommaToken),
          text(ParameterToken, ["\\", ")", ","]),
          escaped_text(EscapedParameterToken),
        ]
      }
    })

  lexer.run_advanced(s, TextMode, lexer)
}
