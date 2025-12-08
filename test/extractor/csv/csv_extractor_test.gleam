import data/extracted_data
import enricher/enricher
import extractor/csv/csv_column
import extractor/csv/csv_extractor
import extractor/csv/csv_extractor_config
import extractor/csv/csv_value
import extractor/extract_regex
import gleam/dict
import gleam/option.{None}
import gleeunit/should
import input_loader/input_file
import regex/regex
import template/parser/parser

pub fn run_csv_extractor_test() {
  // setup
  let example_csv =
    "
name,value
trans1,val1
trans2,val2
    "
  let input_file =
    input_file.InputFile(
      loader: "test",
      title: "title-with-value-123",
      name: "name",
      content: example_csv,
      progress: 0,
      total_files: None,
    )
  let assert Ok(value_re) =
    regex.compile_with_default_opts("value-(?<value>[0-9]*)$")
  let assert Ok(value_template) = parser.run("{value}")
  let config =
    csv_extractor_config.CsvExtractorConfig(
      sheet: enricher.Enricher(
        name: None,
        regexes: [extract_regex.ExtractRegex(value_re, on: "content")],
        values: dict.from_list([#("value", value_template)]),
      ),
      with_headers: True,
      seperator: ",",
      values: [
        csv_value.CsvValue(name: "name", column: csv_column.ByName("name")),
        csv_value.CsvValue(name: "value", column: csv_column.ByIndex(1)),
      ],
    )

  // act
  let extractor = csv_extractor.new(config)
  let assert Ok(#(sheet, trans)) = extractor.run(input_file)

  // test
  should.equal(
    extracted_data.ExtractedData(
      input: input_file.InputFile(..input_file, content: sheet.input.content),
      values: dict.from_list([#("value", "123")]),
    ),
    sheet,
  )
  should.equal(
    [
      extracted_data.ExtractedData(
        input: input_file.InputFile(..input_file, content: sheet.input.content),
        values: dict.from_list([#("name", "trans1"), #("value", "val1")]),
      ),
      extracted_data.ExtractedData(
        input: input_file.InputFile(..input_file, content: sheet.input.content),
        values: dict.from_list([#("name", "trans2"), #("value", "val2")]),
      ),
    ],
    trans,
  )
}
