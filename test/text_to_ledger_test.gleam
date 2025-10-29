import gleam/list
import gleeunit
import gleeunit/should
import template/parser/parser
import template/template

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn text_to_ledger_test() {
  let cases = [
    #("hello", Ok([template.Literal("hello")])),
    #("hello\\{", Ok([template.Literal("hello\\{")])),
    #(
      "hello{var}",
      Ok([template.Literal("hello"), template.Variable("var", [])]),
    ),
    #(
      "hello{var}good \\nbye",
      Ok([
        template.Literal("hello"),
        template.Variable("var", []),
        template.Literal("good \\nbye"),
      ]),
    ),
    #(
      "{var1}text1{var2}text",
      Ok([
        template.Variable("var1", []),
        template.Literal("text1"),
        template.Variable("var2", []),
        template.Literal("text2"),
      ]),
    ),
  ]

  use #(input, expected) <- list.map(cases)

  let result = parser.run(input)

  should.equal(result, expected)
}
