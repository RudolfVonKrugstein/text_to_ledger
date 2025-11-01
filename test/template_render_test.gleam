import gleeunit/should
import template/template.{Template}

pub fn simple_template_render_test() {
  // setup
  let input = Template([template.Literal("test")])

  // act
  let result = template.render(input, [])

  // test
  should.equal(result, Ok("test"))
}

pub fn two_literals_template_render_test() {
  // setup
  let input = Template([template.Literal("test"), template.Literal("2")])

  // act
  let result = template.render(input, [])

  // test
  should.equal(result, Ok("test2"))
}

pub fn single_var_template_render_test() {
  // setup
  let input = Template([template.Variable("test", [])])

  // act
  let result = template.render(input, [#("test", ["val"])])

  // test
  should.equal(result, Ok("val"))
}
