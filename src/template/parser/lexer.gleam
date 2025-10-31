import gleam/list
import gleam/regexp
import nibble/lexer

// Lexing mode we can be in, making the returned
// tokens much easier to parse.
// I.E. in text mode, almost everything is just copied to the output making it very different from variable mode.
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

/// Free text, adding almost anything to the output except for if one of the `stops` characters occure.
///
/// The `trans` function created the output token from the parsed text.
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

/// Escaped text is the escape character (\) followed by some other character.
///
/// The `trans` function creates the output token from the parsed text.
fn escaped_text(trans: fn(String) -> Token) {
  use mode, lexeme, _next <- lexer.custom

  case lexeme {
    "\\" -> lexer.Skip
    "\\" <> _s -> lexer.Keep(trans(lexeme), mode)
    _ -> lexer.NoMatch
  }
}

/// A name for a variable or a modification. Names begin with a character and only contain characters, numbers and the undersore.
///
/// The `trans` function creates the output token from the parsed text.
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

/// Run the lexer producing the Tokens.
pub fn run(s: String) {
  let lexer =
    lexer.advanced(fn(mode) {
      case mode {
        // In text mode almost everything is parsed into simple text tokens.
        TextMode -> [
          lexer.token("{", LBraceToken) |> lexer.into(fn(_) { VariableMode }),
          text(TextToken, ["\\", "{"]),
          escaped_text(EscapedTextToken),
        ]
        // Variable mode (inside of braces), whitspaces are ignored and we exepct a variable name.
        VariableMode -> [
          lexer.whitespace(WhiteSpace) |> lexer.ignore,
          lexer.token("}", RBraceToken) |> lexer.into(fn(_) { TextMode }),
          lexer.token("|", PipeToken) |> lexer.into(fn(_) { ModMode }),
          name(VariableToken),
        ]
        // Modifications are just a name with an optional parameter list in parantheses.
        ModMode -> [
          lexer.whitespace(WhiteSpace) |> lexer.ignore,
          name(ModToken),
          lexer.token("}", RBraceToken) |> lexer.into(fn(_) { TextMode }),
          lexer.token("|", PipeToken),
          lexer.token("(", LParanToken) |> lexer.into(fn(_) { ParameterMode }),
        ]
        // A parameter is free text, as in text mode, but stop but other characters.
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
