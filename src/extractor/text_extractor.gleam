import extractor/enricher
import extractor/extracted_data
import extractor/extractor
import gleam/list
import gleam/result
import input_loader/input_file
import regex/area_regex

pub type TextExtractorConfig {
  TextExtractorConfig(
    sheet: enricher.Enricher,
    transaction_areas: area_regex.AreaRegex,
  )
}

fn run(input: input_file.InputFile, config: TextExtractorConfig) {
  // sheet data
  use sheet_data <- result.try(
    enricher.apply(extracted_data.empty(input), config.sheet)
    |> result.map_error(enricher.error_string),
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
