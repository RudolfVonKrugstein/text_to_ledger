import gleeunit/should
import template/template.{Template}

pub fn template_render_test() {
  // setup
  let input = Template([template.Literal("test")])

  // act
  let result = template.render(input, [])

  // test
  should.equal(result, "test")
}
