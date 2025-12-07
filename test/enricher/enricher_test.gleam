import data/extracted_data
import enricher/enricher
import extractor/extract_regex
import gleam/dict
import gleam/option.{None, Some}
import gleeunit/should
import input_loader/input_file
import regex/regex
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
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
    )

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{val1}")
  let enricher =
    enricher.Enricher(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
    )

  // act
  let apply_res = enricher.apply(data, enricher)
  let try_apply_res = enricher.try_apply(data, enricher)
  let try_maybe_apply_res = enricher.try_maybe_apply(data, enricher)

  // test
  let expected_data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123"), #("out_var", "123")]),
    )
  should.equal(Ok(expected_data), apply_res)
  should.equal(Ok(Some(expected_data)), try_apply_res)
  should.equal(Ok(expected_data), try_maybe_apply_res)
}

pub fn no_match_apply_test() {
  // setup
  let data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
    )

  let assert Ok(re1) = regex.compile_with_default_opts("nomatch")
  let assert Ok(out_var_template) = parser.run("{val1}")
  let enricher =
    enricher.Enricher(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
    )

  // act
  let apply_res = enricher.apply(data, enricher)
  let try_apply_res = enricher.try_apply(data, enricher)
  let try_maybe_apply_res = enricher.try_maybe_apply(data, enricher)

  // test
  should.be_error(apply_res)
  should.equal(Ok(None), try_apply_res)
  should.equal(Ok(data), try_maybe_apply_res)
}

pub fn var_missing_apply_test() {
  // setup
  let data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
    )

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{val1}")
  let enricher =
    enricher.Enricher(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "not_existing")],
      values: dict.from_list([#("out_var", out_var_template)]),
    )

  // act
  let apply_res = enricher.apply(data, enricher)
  let try_apply_res = enricher.try_apply(data, enricher)
  let try_maybe_apply_res = enricher.try_maybe_apply(data, enricher)

  // test
  should.be_error(apply_res)
  should.equal(Ok(None), try_apply_res)
  should.equal(Ok(data), try_maybe_apply_res)
}

pub fn template_error_apply_test() {
  // setup
  let data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
    )

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{val1|c(1,2,3)}")
  let enricher =
    enricher.Enricher(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
    )

  // act
  let apply_res = enricher.apply(data, enricher)
  let try_apply_res = enricher.try_apply(data, enricher)
  let try_maybe_apply_res = enricher.try_maybe_apply(data, enricher)

  // test
  should.be_error(apply_res)
  should.be_error(try_apply_res)
  should.be_error(try_maybe_apply_res)
}

pub fn missing_capture_group_apply_test() {
  // setup
  let data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
    )

  let assert Ok(re1) = regex.compile_with_default_opts("value(?<val1>[0-9]*)$")
  let assert Ok(out_var_template) = parser.run("{missing_val}")
  let enricher =
    enricher.Enricher(
      name: Some("test"),
      regexes: [extract_regex.ExtractRegex(regex: re1, on: "in_var")],
      values: dict.from_list([#("out_var", out_var_template)]),
    )

  // act
  let apply_res = enricher.apply(data, enricher)
  let try_apply_res = enricher.try_apply(data, enricher)
  let try_maybe_apply_res = enricher.try_maybe_apply(data, enricher)

  // test
  should.be_error(apply_res)
  should.be_error(try_apply_res)
  should.be_error(try_maybe_apply_res)
}
