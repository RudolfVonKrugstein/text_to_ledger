import nibble
import nibble/lexer as nibble_lexer
import template/parser/lexer

/// Errors, that can occure during parsing.
/// Basicly the errors from the nibble lexer and parser are passed through.
pub type Error {
  /// And error occured during lexing.,
  LexerError(nibble_lexer.Error)
  /// An error occured during parsing.
  ParseError(List(nibble.DeadEnd(lexer.Token, Nil)))
}
