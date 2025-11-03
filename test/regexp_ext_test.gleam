import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleeunit/should
import regexp_ext/regexp_ext

pub fn names_test() {
  let cases = [
    #("(?<name>.*)", ["name"]),
    #("(?<name>.*)(?<name2>)", ["name", "name2"]),
  ]

  list.each(cases, fn(c) {
    let #(regex, expected) = c
    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.names(regex), expected)
  })
}

pub fn capture_names_test() {
  let cases = [
    #("(?<name>.*)", "hello", ["name"], Some([["hello"], [""]])),
    #(
      "(?<name>.*)(?<name2>ab)",
      "helloab",
      ["name", "name2"],
      Some([["hello"], ["ab"]]),
    ),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, name_list, expected) = c
    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.capture_names(regex, text, name_list), expected)
  })
}
