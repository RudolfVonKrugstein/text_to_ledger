import gleam/option.{None, Some}
import gleam/result
import gleam/string
import nibble
import template/parser/error
import template/parser/lexer
import template/template

fn text() {
  use ts <- nibble.do(
    nibble.take_map_while1("text", fn(token) {
      case token {
        lexer.TextToken(t) -> Some(t)
        lexer.EscapedTextToken(t) -> Some(t)
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

fn mods() {
  nibble.many(mod())
}

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
  use parameters <- nibble.do(parameters())

  nibble.succeed(template.Mod(name, parameters))
}

fn parameters() {
  nibble.sequence(parameter(), nibble.token(lexer.CommaToken))
}

fn parameter() {
  nibble.take_map("parameter", fn(t) {
    case t {
      lexer.ParameterToken(p) -> Some(p)
      _ -> None
    }
  })
}

pub fn run(input: String) {
  use tokens <- result.try(
    lexer.run(input) |> result.map_error(error.LexerError),
  )

  let parser = nibble.many(nibble.one_of([variable(), text()]))

  nibble.run(echo tokens, parser) |> result.map_error(error.ParseError)
}
