import gleam/list
import gleeunit/should
import template/parser/parser
import template/template

pub fn template_parse_ok_test() {
  let cases = [
    #("hello", [template.Literal("hello")]),
    #("hello\\{", [template.Literal("hello\\{")]),
    #("hello{var}", [template.Literal("hello"), template.Variable("var", [])]),
    #("hello{var}good \\nbye", [
      template.Literal("hello"),
      template.Variable("var", []),
      template.Literal("good \nbye"),
    ]),
    #("{var1}text1{var2}text2", [
      template.Variable("var1", []),
      template.Literal("text1"),
      template.Variable("var2", []),
      template.Literal("text2"),
    ]),
    #("{var1|mod}", [
      template.Variable("var1", [template.Mod("mod", [])]),
    ]),
    #("{var1|mod(p)}", [
      template.Variable("var1", [template.Mod("mod", ["p"])]),
    ]),
    #("{var1|mod(p )}", [
      template.Variable("var1", [template.Mod("mod", ["p "])]),
    ]),
    #("{var1|mod( p, x )}", [
      template.Variable("var1", [template.Mod("mod", [" p", " x "])]),
    ]),
    #("{var1|mod( p, x\\, )}", [
      template.Variable("var1", [template.Mod("mod", [" p", " x, "])]),
    ]),
    #("{var1|mod( p, x\\, )|mod2( \\)} )}", [
      template.Variable("var1", [
        template.Mod("mod", [" p", " x, "]),
        template.Mod("mod2", [" )} "]),
      ]),
    ]),
  ]

  use #(input, expected) <- list.map(cases)

  let result = parser.run(input)

  should.equal(result, Ok(expected))
}

pub fn templeta_parse_fail_test() {
  let cases = ["hello{", "{var(}", "\\"]

  use input <- list.map(cases)

  let result = parser.run(input)

  should.be_error(result)
}
