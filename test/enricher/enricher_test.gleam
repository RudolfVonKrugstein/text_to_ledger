import data/extracted_data
import enricher/enricher
import extractor/extract_regex
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
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
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

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
      matched_extractor: None,
      applied_enrichers: ["test"],
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
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

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
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

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
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

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

pub fn decode_single_enricher_test() {
  // Test decoding a single enricher
  let enricher_data =
    [
      #(dynamic.string("name"), dynamic.string("test_enricher")),
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

  let result = decode.run(enricher_data, enricher.decoder())

  should.be_ok(result)
  let assert Ok(enricher) = result

  // Verify the enricher was decoded correctly
  should.equal(enricher.name, Some("test_enricher"))
  should.equal(list.length(enricher.regexes), 1)
  should.equal(dict.size(enricher.values), 1)

  // Test that the enricher works correctly
  let data =
    extracted_data.empty(test_input)
    |> extracted_data.insert("in_var", "value123")

  let apply_result = enricher.apply(data, enricher)
  should.be_ok(apply_result)

  let assert Ok(result_data) = apply_result
  should.equal(dict.get(result_data.values, "out_var"), Ok("123"))
}

pub fn decode_with_children_no_children_test() {
  // Test decoding a single enricher using decode_list
  let enricher_data =
    [
      #(dynamic.string("name"), dynamic.string("test_enricher")),
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

  let dec = enricher.with_children_decoder()
  let result = decode.run(enricher_data, dec)

  should.be_ok(result)
  let assert Ok(enrichers) = result

  // Verify we got a list with one enricher
  should.equal(list.length(enrichers), 1)

  let assert [enricher] = enrichers

  // Verify the enricher was decoded correctly
  should.equal(enricher.name, Some("test_enricher"))
  should.equal(list.length(enricher.regexes), 1)
  should.equal(dict.size(enricher.values), 1)

  // Test that the enricher works correctly
  let data =
    extracted_data.ExtractedData(
      input: test_input,
      values: dict.from_list([#("in_var", "value123")]),
      matched_extractor: None,
      applied_enrichers: [],
    )

  let apply_result = enricher.apply(data, enricher)
  should.be_ok(apply_result)

  let assert Ok(result_data) = apply_result
  should.equal(dict.get(result_data.values, "out_var"), Ok("123"))
}

pub fn decode_with_children_test() {
  // Test decoding an enricher with child enrichers
  let enricher_data =
    [
      #(dynamic.string("name"), dynamic.string("parent_enricher")),
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

  let dec = enricher.with_children_decoder()
  let result = decode.run(enricher_data, dec)

  should.be_ok(result)
  let assert Ok(enrichers) = result

  // Verify we got a list with 2 enrichers
  should.equal(list.length(enrichers), 2)

  let assert [child1, child2] = enrichers

  // Verify child1 enricher
  should.equal(child1.name, Some("parent_enricher/child1"))
  should.equal(list.length(child1.regexes), 2)
  should.equal(dict.size(child1.values), 2)

  // Verify child2 enricher
  should.equal(child2.name, Some("parent_enricher/child2"))
  should.equal(list.length(child2.regexes), 2)
  should.equal(dict.size(child2.values), 2)
}
