import gleam/dict
import gleeunit/should
import template/template.{Template}

pub fn simple_template_render_test() {
  // setup
  let input = Template([template.Literal("test")])

  // act
  let result = template.render(input, dict.new())

  // test
  should.equal(result, Ok("test"))
}

pub fn two_literals_template_render_test() {
  // setup
  let input = Template([template.Literal("test"), template.Literal("2")])

  // act
  let result = template.render(input, dict.new())

  // test
  should.equal(result, Ok("test2"))
}

pub fn single_var_template_render_test() {
  // setup
  let input = Template([template.Variable("test", [])])

  // act
  let result = template.render(input, dict.from_list([#("test", ["val"])]))

  // test
  should.equal(result, Ok("val"))
}

pub fn same_mod_render_test() {
  // setup
  let input = Template([template.Variable("test", [template.Mod("same", [])])])

  // act
  let result = template.render(input, dict.from_list([#("test", ["val"])]))

  // test
  should.equal(result, Ok("val"))
}

pub fn same_mod_multi_var_render_test() {
  // setup
  let input = Template([template.Variable("test", [template.Mod("same", [])])])

  // act
  let result =
    template.render(input, dict.from_list([#("test", ["val", "val"])]))

  // test
  should.equal(result, Ok("val"))
}

pub fn same_mod_multi_var_render_fail_test() {
  // setup
  let input = Template([template.Variable("test", [template.Mod("same", [])])])

  // act
  let result =
    template.render(input, dict.from_list([#("test", ["val", "val2"])]))

  // test
  should.be_error(result)
}

pub fn same_mod_parameter_render_fail_test() {
  // setup
  let input =
    Template([template.Variable("test", [template.Mod("same", ["para"])])])

  // act
  let result =
    template.render(input, dict.from_list([#("test", ["val", "val2"])]))

  // test
  should.be_error(result)
}
