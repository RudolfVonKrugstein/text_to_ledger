import data/extracted_data
import enricher/enricher
import extractor/extract_regex
import extractor/text/text_extractor
import extractor/text/text_extractor_config
import gleam/dict
import gleam/option.{None, Some}
import gleeunit/should
import input_loader/input_file
import regex/area_regex
import regex/regex
import regex/split_regex
import template/parser/parser

pub fn run_text_tractor_test() {
  // setup
  let example_text =
    "
    Before text
    value=123
    <trans>
    Transaction 1
    </trans>
    between
    <trans>
    Transaction 2
    </trans>
    After Text
    "
  let input_file =
    input_file.InputFile(
      loader: "test",
      name: "hame",
      title: "title",
      content: example_text,
      progress: 0,
      total_files: None,
    )
  let assert Ok(value_re) =
    regex.compile_with_default_opts("value=(?<value>[0-9]*)$")
  let assert Ok(trans_begin_re) = regex.compile("<trans>")
  let assert Ok(trans_end_re) = regex.compile("</trans>")
  let assert Ok(value_template) = parser.run("{value}")
  let config =
    text_extractor_config.TextExtractorConfig(
      sheet: enricher.Enricher(
        name: None,
        regexes: [extract_regex.ExtractRegex(value_re, on: "content")],
        values: dict.from_list([#("value", value_template)]),
      ),
      transaction_areas: area_regex.AreaSplit(
        start: split_regex.SplitAfter(trans_begin_re),
        end: Some(split_regex.SplitBefore(trans_end_re)),
        subarea: area_regex.FullArea,
      ),
    )

  // act
  let extractor = text_extractor.new(config)
  let assert Ok(#(sheet, trans)) = extractor.run(input_file)

  // test
  should.equal(
    extracted_data.ExtractedData(
      input: input_file,
      values: dict.from_list([#("value", "123")]),
    ),
    sheet,
  )
  should.equal(
    [
      extracted_data.ExtractedData(
        input: input_file.InputFile(
          ..input_file,
          content: "\n    Transaction 1\n    ",
        ),
        values: dict.from_list([#("value", "123")]),
      ),
      extracted_data.ExtractedData(
        input: input_file.InputFile(
          ..input_file,
          content: "\n    Transaction 2\n    ",
        ),
        values: dict.from_list([#("value", "123")]),
      ),
    ],
    trans,
  )
}
