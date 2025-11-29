import enricher/enricher
import extracted_data/extracted_data
import extractor/csv/csv_column
import extractor/csv/csv_extractor_config
import extractor/csv/csv_value
import extractor/extractor
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import gsv
import input_loader/input_file

fn get_transaction_data(
  input: extracted_data.ExtractedData,
  line_by_name: dict.Dict(String, String),
  line_by_index: List(String),
  values: List(csv_value.CsvValue),
) -> Result(extracted_data.ExtractedData, extractor.ExtractorError) {
  values
  |> list.try_fold(input, fn(input, csv_value) {
    use value <- result.try(
      case csv_value.column {
        csv_column.ByIndex(index) -> {
          list.drop(line_by_index, index)
          |> list.first
        }
        csv_column.ByName(name) -> dict.get(line_by_name, name)
      }
      |> result.map_error(fn(_) {
        extractor.CsvColumnNotFound(csv_value.column)
      }),
    )

    Ok(extracted_data.insert(input, csv_value.name, value))
  })
}

fn run(
  input: input_file.InputFile,
  config: csv_extractor_config.CsvExtractorConfig,
) -> Result(
  #(extracted_data.ExtractedData, List(extracted_data.ExtractedData)),
  extractor.ExtractorError,
) {
  use body <- result.try(case config.with_headers {
    False -> Ok(input.content)
    True -> {
      use #(_, body) <- result.try(
        string.split_once(input.content, "\n")
        |> result.map_error(fn(_) { extractor.CsvFileInvalid }),
      )
      Ok(body)
    }
  })

  use by_index <- result.try(
    gsv.to_lists(body, config.seperator)
    |> result.map_error(extractor.CsvError),
  )

  let by_index = case config.with_headers {
    True -> list.drop(by_index, 1)
    False -> by_index
  }

  use by_name <- result.try(case config.with_headers {
    False -> Ok(list.repeat(dict.new(), list.length(by_index)))
    True ->
      gsv.to_dicts(input.content, config.seperator)
      |> result.map_error(extractor.CsvError)
  })

  use sheet <- result.try(
    enricher.apply(
      extracted_data.empty(input_file.InputFile(..input, content: input.title)),
      config.sheet,
    )
    |> result.map_error(extractor.EnricherError),
  )

  use transactions <- result.try(
    list.zip(by_name, by_index)
    |> list.map(fn(c) {
      let #(by_name, by_index) = c
      get_transaction_data(sheet, by_name, by_index, config.values)
    })
    |> result.all,
  )

  Ok(#(sheet, transactions))
}

pub fn new(
  config: csv_extractor_config.CsvExtractorConfig,
) -> extractor.Extractor {
  extractor.Extractor(run(_, config))
}
