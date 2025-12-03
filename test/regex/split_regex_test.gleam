import gleam/option.{None, Some}
import gleeunit/should
import regex/split_regex

pub fn split_once_test() {
  let assert Ok(split_before) = split_regex.compile_before("b")
  let assert Ok(split_after) = split_regex.compile_after("b")

  should.equal(split_regex.split(split_before, "abc"), Some(#("a", "bc")))
  should.equal(split_regex.split(split_after, "abc"), Some(#("ab", "c")))
  should.equal(split_regex.split(split_after, "ac"), None)
}

pub fn split_all_test() {
  let assert Ok(split_before) = split_regex.compile_before("b")
  let assert Ok(split_after) = split_regex.compile_after("b")

  should.equal(split_regex.split_all(split_before, "abcbd"), ["a", "bc", "bd"])
  should.equal(split_regex.split_all(split_after, "abcbd"), ["ab", "cb", "d"])
  should.equal(split_regex.split_all(split_after, "ac"), ["ac"])
}
