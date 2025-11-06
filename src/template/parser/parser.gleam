import gleam/option.{None, Some}
import gleam/result
import gleam/string
import nibble
import template/parser/error
import template/parser/lexer
import template/template

/// Unescape an escape sequence.
///
/// These are the "normal" escape sequences, you find everywhere. If it is not one of them, they are just the chracter following the escape chracter.
fn unescape(in: String) {
  case in {
    "\\n" -> "\n"
    "\\t" -> "\t"
    "\\r" -> "\r"
    "\\" <> s -> s
    _ -> in
  }
}

/// Parse all coming text tokens, expect at least one.
fn text() {
  use ts <- nibble.do(
    nibble.take_map_while1("text", fn(token) {
      case token {
        lexer.TextToken(t) -> Some(t)
        lexer.EscapedTextToken(t) -> Some(unescape(t))
        _ -> None
      }
    }),
  )

  let t = string.concat(ts)
  case t {
    "" -> nibble.fail("no text or escape text found")
    _ -> nibble.succeed(template.Literal(t))
  }
}

/// Parse a variable, including all modifications .
fn variable() {
  use _ <- nibble.do(nibble.token(lexer.LBraceToken))
  use variable <- nibble.do(
    nibble.take_map("variable", fn(token) {
      case token {
        lexer.VariableToken(t) -> Some(t)
        _ -> None
      }
    }),
  )
  use mods <- nibble.do(mods())
  use _ <- nibble.do(nibble.token(lexer.RBraceToken))

  nibble.succeed(template.Variable(variable, mods))
}

/// Parse modifications after a variable.
fn mods() {
  nibble.many(mod())
}

/// Parse a single modification.
fn mod() {
  use _ <- nibble.do(nibble.token(lexer.PipeToken))
  use name <- nibble.do(
    nibble.take_map("mod name", fn(token) {
      case token {
        lexer.ModToken(t) -> Some(t)
        _ -> None
      }
    }),
  )
  use parameters <- nibble.do(nibble.or(parameters(), []))

  nibble.succeed(template.Mod(name, parameters))
}

/// Parse the parameter list of a modification.
fn parameters() {
  use _ <- nibble.do(nibble.token(lexer.LParanToken))

  use ps <- nibble.do(nibble.sequence(
    parameter(),
    nibble.token(lexer.CommaToken),
  ))

  use _ <- nibble.do(nibble.token(lexer.RParanToken))

  nibble.succeed(ps)
}

/// Parse a single modification parameter.
fn parameter() {
  use ts <- nibble.do(
    nibble.take_map_while1("parameter", fn(t) {
      case t {
        lexer.ParameterToken(p) -> Some(p)
        lexer.EscapedParameterToken(p) -> Some(unescape(p))
        _ -> None
      }
    }),
  )

  let t = string.concat(ts)
  nibble.succeed(t)
}

/// Run the parser on an input string.
pub fn run(input: String) -> Result(template.Template, error.Error) {
  use tokens <- result.try(
    lexer.run(input) |> result.map_error(error.LexerError),
  )

  let parser = nibble.many(nibble.one_of([variable(), text()]))

  use parts <- result.try(
    nibble.run(tokens, parser) |> result.map_error(error.ParseError),
  )

  Ok(template.Template(parts:))
}
