import gleam/list
import gleam/option.{Some}
import gleeunit/should
import regex/area_regex.{AreaSplit, FullArea}
import regex/regex
import regex/split_regex

fn fc_b(r: String) {
  let assert Ok(r) = regex.compile(r)
  split_regex.SplitBefore(r)
}

fn fc_a(r: String) {
  let assert Ok(r) = regex.compile(r)
  split_regex.SplitAfter(r)
}

pub fn split_test() {
  let cases = [
    #("ab cd ed", FullArea, ["ab cd ed"]),
    #(
      "s mid e",
      AreaSplit(start: fc_b("s"), end: option.None, subarea: FullArea),
      [
        "s mid e",
      ],
    ),
    #(
      "s mid e",
      AreaSplit(start: fc_b("s"), end: Some(fc_a("e")), subarea: FullArea),
      [
        "s mid e",
      ],
    ),
    #(
      "s mid e",
      AreaSplit(start: fc_a("s"), end: Some(fc_b("e")), subarea: FullArea),
      [
        " mid ",
      ],
    ),
    #(
      "before s mid e after",
      AreaSplit(start: fc_b("s"), end: Some(fc_a("e")), subarea: FullArea),
      [
        "s mid e",
      ],
    ),
  ]

  cases
  |> list.map(fn(c) {
    let #(input, regex, expected) = c

    should.equal(area_regex.split(regex, input), expected)
  })
}
