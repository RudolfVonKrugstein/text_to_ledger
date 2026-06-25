//// A Text extractor uses regex to extract the data.
////
//// - It splits the transactions in the document using regexes
////   marking beginning and end of the area.
//// - It extracts global/sheet values using a rule.

import data/extracted_data
import extractor/extractor
import extractor/text/text_extractor_config.{type TextExtractorConfig}
import gleam/list
import gleam/result
import input_loader/input_file
import regex/area_regex
import rule/rule

fn run(
  input: input_file.InputFile,
  config: TextExtractorConfig,
) -> Result(
  #(extracted_data.ExtractedData, List(extracted_data.ExtractedData)),
  extractor.ExtractRunError,
) {
  // sheet data
  let data =
    extracted_data.empty(input) |> extracted_data.with_extractor(config.name)
  use sheet_data <- result.try(
    rule.apply(data, config.sheet)
    |> result.map_error(fn(error) { extractor.RuleFailure(data:, error:) }),
  )

  let transactions =
    area_regex.split(config.transaction_areas, input.content)
    |> list.map(fn(content) {
      let input = input_file.InputFile(..input, content:)
      extracted_data.ExtractedData(..sheet_data, input:)
    })

  Ok(#(sheet_data, transactions))
}

pub fn new(config: TextExtractorConfig) {
  extractor.Extractor(config.name, run(_, config))
}
