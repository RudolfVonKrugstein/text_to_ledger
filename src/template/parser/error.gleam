import nibble
import nibble/lexer as nibble_lexer
import template/parser/lexer

pub type Error {
  LexerError(nibble_lexer.Error)
  ParseError(List(nibble.DeadEnd(lexer.Token, Nil)))
}
