import gleam/list
import gleam/regexp
import gleeunit/should
import regexp_ext/regexp_ext.{NamedCapture}

pub fn capture_names_test() {
  let cases = [
    #("(?<name>.+)", "hello", [[NamedCapture("name", "hello")]]),
    #("(?<name>.*)(?<name2>ab)", "helloab", [
      [NamedCapture("name", "hello"), NamedCapture("name2", "ab")],
    ]),
    #("(?<name>[^-]+)-", "hello-ab-end", [
      [NamedCapture("name", "hello")],
      [NamedCapture("name", "ab")],
    ]),
    #("ab", "ab", [[]]),
    #("ab", "ba", []),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, expected) = c
    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.capture_names(regex, text), expected)
  })
}
