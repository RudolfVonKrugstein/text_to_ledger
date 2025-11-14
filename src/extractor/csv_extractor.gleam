import extractor/enricher
import extractor/extracted_data
import extractor/extractor
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gsv
import input_loader/input_file

pub type CsvValue {
  CsvValue(name: String, column: CsvColumn)
}

pub type CsvColumn {
  ByIndex(index: Int)
  ByName(name: String)
}

pub type CsvExtractorConfig {
  CsvExtractorConfig(
    with_headers: Bool,
    seperator: String,
    sheet: enricher.Enricher,
    values: List(CsvValue),
  )
}

fn get_transaction_data(
  input: input_file.InputFile,
  line_by_name: dict.Dict(String, String),
  line_by_index: List(String),
  values: List(CsvValue),
) {
  use values <- result.try(
    values
    |> list.map(fn(csv_value) {
      use value <- result.try(case csv_value.column {
        ByIndex(index) -> {
          list.drop(line_by_index, index)
          |> list.first
          |> result.map_error(fn(_) {
            "unable to get value from column index " <> int.to_string(index)
          })
        }
        ByName(name) ->
          dict.get(line_by_name, name)
          |> result.map_error(fn(_) {
            "unable to get value from column " <> name
          })
      })

      Ok(#(csv_value.name, value))
    })
    |> result.all,
  )

  Ok(extracted_data.ExtractedData(input, dict.from_list(values)))
}

fn run(input: input_file.InputFile, config: CsvExtractorConfig) {
  use body <- result.try(case config.with_headers {
    False -> Ok(input.content)
    True -> {
      use #(_, body) <- result.try(
        string.split_once(input.content, "\n")
        |> result.map_error(fn(_) {
          "input file has not enough lines to be a csv with headers"
        }),
      )
      Ok(body)
    }
  })

  use by_index <- result.try(
    gsv.to_lists(body, config.seperator)
    |> result.map_error(fn(e) {
      case e {
        gsv.UnescapedQuote(line:) ->
          "unescaped quote in csv on line " <> int.to_string(line)
        gsv.MissingClosingQuote(starting_line:) ->
          "unescaped closing quote in csv started on line "
          <> int.to_string(starting_line)
      }
    }),
  )

  use by_name <- result.try(case config.with_headers {
    False -> Ok([])
    True ->
      gsv.to_dicts(input.content, config.seperator)
      |> result.map_error(fn(e) {
        case e {
          gsv.UnescapedQuote(line) ->
            "unescaped quote in csv on line " <> int.to_string(line)
          gsv.MissingClosingQuote(starting_line:) ->
            "unescaped closing quote in csv started on line "
            <> int.to_string(starting_line)
        }
      })
  })

  use sheet <- result.try(
    enricher.apply(
      extracted_data.empty(input_file.InputFile(..input, content: input.title)),
      config.sheet,
    )
    |> result.map_error(enricher.error_string),
  )

  use transactions <- result.try(
    list.zip(by_name, by_index)
    |> list.map(fn(c) {
      let #(by_name, by_index) = c
      get_transaction_data(input, by_name, by_index, config.values)
    })
    |> result.all,
  )

  Ok(#(sheet, transactions))
}

pub fn new(config: CsvExtractorConfig) -> extractor.Extractor {
  extractor.Extractor(run(_, config))
}
