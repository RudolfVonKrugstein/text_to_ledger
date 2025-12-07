//// A Text extractor uses regex to extract the data.
////
//// - It splits the transactions in the document using regexes
////   marking beginning and end of the area.
//// - It extracts global/sheet values using an enricher.

import data/extracted_data
import enricher/enricher
import extractor/extractor
import extractor/text/text_extractor_config.{type TextExtractorConfig}
import gleam/list
import gleam/result
import input_loader/input_file
import regex/area_regex

fn run(
  input: input_file.InputFile,
  config: TextExtractorConfig,
) -> Result(
  #(extracted_data.ExtractedData, List(extracted_data.ExtractedData)),
  extractor.ExtractorError,
) {
  // sheet data
  use sheet_data <- result.try(
    enricher.apply(extracted_data.empty(input), config.sheet)
    |> result.map_error(extractor.EnricherError),
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
  extractor.Extractor(run(_, config))
}
