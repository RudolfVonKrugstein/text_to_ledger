import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleeunit/should
import regexp_ext.{NamedCapture}

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

pub fn string_split_after_test() {
  let cases = [
    #("ab", "helloabbye", Some(#("helloab", "bye"))),
    #("ab", "hellobye", None),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, expected) = c

    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.split_after(regex, text), expected)
  })
}

pub fn string_split_before_test() {
  let cases = [
    #("ab", "helloabbye", Some(#("hello", "abbye"))),
    #("ab", "hellobye", None),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, expected) = c

    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.split_before(regex, text), expected)
  })
}

pub fn string_split_match_test() {
  let cases = [
    #("ab", "helloabbye", Some(#("hello", "ab", "bye"))),
    #("ab", "hellobye", None),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, expected) = c

    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.split_match(regex, text), expected)
  })
}

pub fn string_split_after_all_test() {
  let cases = [
    #("\\|", "hello|bye", ["hello|", "bye"]),
    #("\\|", "|bye", ["|", "bye"]),
    #("\\|", "hello|", ["hello|"]),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, expected) = c

    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.split_after_all(regex, text), expected)
  })
}

pub fn string_split_before_all_test() {
  let cases = [
    #("\\|", "hello|bye", ["hello", "|bye"]),
    #("\\|", "|bye", ["", "|bye"]),
    #("\\|", "hello|", ["hello", "|"]),
  ]

  list.each(cases, fn(c) {
    let #(regex, text, expected) = c

    let assert Ok(regex) = regexp.compile(regex, regexp.Options(True, True))
    should.equal(regexp_ext.split_before_all(regex, text), expected)
  })
}
