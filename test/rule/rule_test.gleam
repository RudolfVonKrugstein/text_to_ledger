import data/extracted_data
import extractor/extract_regex
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import input_loader/input_file
import regex/regex
import rule/rule
import template/parser/parser

const test_input = input_file.InputFile(
  loader: "loader",
  name: "name",
  title: "tile",
  content: "content",
  progress: 0,
  total_files: Some(1),
)

pub fn successfull_apply_test() {
  // setup
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{val1}")
  let rule =
    rule.Rule(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
      final: False,
    )

  // act
  let apply_res = rule.apply(data, rule)
  let try_apply_res = rule.try_apply(data, rule)
  let try_maybe_apply_res = rule.try_maybe_apply(data, rule)

  // test
  let expected_data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123"), #("out_var", "123")]),
      matched_extractor: None,
      applied_rules: ["test"],
      finalized: False,
    )
  should.equal(Ok(expected_data), apply_res)
  should.equal(Ok(Some(expected_data)), try_apply_res)
  should.equal(Ok(expected_data), try_maybe_apply_res)
}

pub fn no_match_apply_test() {
  // setup
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let assert Ok(re1) = regex.compile_with_default_opts("nomatch")
  let assert Ok(out_var_template) = parser.run("{val1}")
  let rule =
    rule.Rule(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
      final: False,
    )

  // act
  let apply_res = rule.apply(data, rule)
  let try_apply_res = rule.try_apply(data, rule)
  let try_maybe_apply_res = rule.try_maybe_apply(data, rule)

  // test
  should.be_error(apply_res)
  should.equal(Ok(None), try_apply_res)
  should.equal(Ok(data), try_maybe_apply_res)
}

pub fn var_missing_apply_test() {
  // setup
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{val1}")
  let rule =
    rule.Rule(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "not_existing")],
      values: dict.from_list([#("out_var", out_var_template)]),
      final: False,
    )

  // act
  let apply_res = rule.apply(data, rule)
  let try_apply_res = rule.try_apply(data, rule)
  let try_maybe_apply_res = rule.try_maybe_apply(data, rule)

  // test
  should.be_error(apply_res)
  should.equal(Ok(None), try_apply_res)
  should.equal(Ok(data), try_maybe_apply_res)
}

pub fn template_error_apply_test() {
  // setup
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{val1|c(1,2,3)}")
  let rule =
    rule.Rule(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
      final: False,
    )

  // act
  let apply_res = rule.apply(data, rule)
  let try_apply_res = rule.try_apply(data, rule)
  let try_maybe_apply_res = rule.try_maybe_apply(data, rule)

  // test
  should.be_error(apply_res)
  should.be_error(try_apply_res)
  should.be_error(try_maybe_apply_res)
}

pub fn missing_capture_group_apply_test() {
  // setup
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{missing_val}")
  let rule =
    rule.Rule(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
      final: False,
    )

  // act
  let apply_res = rule.apply(data, rule)
  let try_apply_res = rule.try_apply(data, rule)
  let try_maybe_apply_res = rule.try_maybe_apply(data, rule)

  // test
  should.be_error(apply_res)
  should.be_error(try_apply_res)
  should.be_error(try_maybe_apply_res)
}

pub fn decode_single_rule_test() {
  // Test decoding a single rule
  let rule_data =
    [
      #(dynamic.string("name"), dynamic.string("test_rule")),
      #(
        dynamic.string("regexes"),
        dynamic.properties([
          #(dynamic.string("in_var"), dynamic.string("value(?<val1>[0-9]*)$")),
        ]),
      ),
      #(
        dynamic.string("values"),
        dynamic.properties([
          #(dynamic.string("out_var"), dynamic.string("{val1}")),
        ]),
      ),
    ]
    |> dynamic.properties

  let result = decode.run(rule_data, rule.decoder())

  should.be_ok(result)
  let assert Ok(rule) = result

  // Verify the rule was decoded correctly
  should.equal(rule.name, Some("test_rule"))
  should.equal(list.length(rule.regexes), 1)
  should.equal(dict.size(rule.values), 1)

  // Test that the rule works correctly
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let apply_result = rule.apply(data, rule)
  should.be_ok(apply_result)

  let assert Ok(result_data) = apply_result
  should.equal(dict.get(result_data.values, "out_var"), Ok("123"))
}

pub fn decode_with_children_no_children_test() {
  // Test decoding a single rule using decode_list
  let rule_data =
    [
      #(dynamic.string("name"), dynamic.string("test_rule")),
      #(
        dynamic.string("regexes"),
        dynamic.properties([
          #(dynamic.string("in_var"), dynamic.string("value(?<val1>[0-9]*)$")),
        ]),
      ),
      #(
        dynamic.string("values"),
        dynamic.properties([
          #(dynamic.string("out_var"), dynamic.string("{val1}")),
        ]),
      ),
    ]
    |> dynamic.properties

  let dec = rule.with_children_decoder()
  let result = decode.run(rule_data, dec)

  should.be_ok(result)
  let assert Ok(rules) = result

  // Verify we got a list with one rule
  should.equal(list.length(rules), 1)

  let assert [rule] = rules

  // Verify the rule was decoded correctly
  should.equal(rule.name, Some("test_rule"))
  should.equal(list.length(rule.regexes), 1)
  should.equal(dict.size(rule.values), 1)

  // Test that the rule works correctly
  let data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
      matched_extractor: None,
      applied_rules: [],
      finalized: False,
    )

  let apply_result = rule.apply(data, rule)
  should.be_ok(apply_result)

  let assert Ok(result_data) = apply_result
  should.equal(dict.get(result_data.values, "out_var"), Ok("123"))
}

pub fn decode_with_children_test() {
  // Test decoding a rule with child rules
  let rule_data =
    [
      #(dynamic.string("name"), dynamic.string("parent_rule")),
      #(
        dynamic.string("regexes"),
        dynamic.properties([
          #(dynamic.string("in_var"), dynamic.string("value(?<val1>[0-9]*)$")),
        ]),
      ),
      #(
        dynamic.string("values"),
        dynamic.properties([
          #(dynamic.string("out_var"), dynamic.string("{val1}")),
        ]),
      ),
      #(
        dynamic.string("children"),
        dynamic.list([
          dynamic.properties([
            #(dynamic.string("name"), dynamic.string("child1")),
            #(
              dynamic.string("regexes"),
              dynamic.properties([
                #(
                  dynamic.string("out_var"),
                  dynamic.string("(?<doubled>[0-9]+)"),
                ),
              ]),
            ),
            #(
              dynamic.string("values"),
              dynamic.properties([
                #(
                  dynamic.string("doubled_var"),
                  dynamic.string("{doubled}{doubled}"),
                ),
              ]),
            ),
          ]),
          dynamic.properties([
            #(dynamic.string("name"), dynamic.string("child2")),
            #(
              dynamic.string("regexes"),
              dynamic.properties([
                #(
                  dynamic.string("out_var"),
                  dynamic.string("(?<tripled>[0-9]+)"),
                ),
              ]),
            ),
            #(
              dynamic.string("values"),
              dynamic.properties([
                #(
                  dynamic.string("tripled_var"),
                  dynamic.string("{tripled}{tripled}{tripled}"),
                ),
              ]),
            ),
          ]),
        ]),
      ),
    ]
    |> dynamic.properties

  let dec = rule.with_children_decoder()
  let result = decode.run(rule_data, dec)

  should.be_ok(result)
  let assert Ok(rules) = result

  // Verify we got a list with 2 rules
  should.equal(list.length(rules), 2)

  let assert [child1, child2] = rules

  // Verify child1 rule
  should.equal(child1.name, Some("parent_rule/child1"))
  should.equal(list.length(child1.regexes), 2)
  should.equal(dict.size(child1.values), 2)

  // Verify child2 rule
  should.equal(child2.name, Some("parent_rule/child2"))
  should.equal(list.length(child2.regexes), 2)
  should.equal(dict.size(child2.values), 2)
}
