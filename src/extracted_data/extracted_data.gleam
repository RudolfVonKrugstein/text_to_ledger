import data/date
import data/money
import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import input_loader/input_file

pub type ExtractedData {
  ExtractedData(input: input_file.InputFile, values: dict.Dict(String, String))
}

pub type ExtractedDataError {
  KeyNotFound(key: String)
  UnableToParse(key: String, value: String, msg: String, value_type: String)
}

pub fn empty(input: input_file.InputFile) {
  ExtractedData(input, dict.new())
}

pub fn to_string(data: ExtractedData) {
  "input file:\n"
  <> input_file.to_string(data.input)
  <> "\nvalues:\n"
  <> list.map(dict.to_list(data.values), fn(v) {
    let #(k, v) = v
    "  " <> k <> ": " <> v
  })
  |> string.join("\n")
}

pub fn to_json(extracted_data: ExtractedData) -> json.Json {
  let ExtractedData(input:, values:) = extracted_data
  json.object([
    #("input", input_file.to_json(input)),
    #("values", json.dict(values, fn(string) { string }, json.string)),
  ])
}

pub fn decoder() -> decode.Decoder(ExtractedData) {
  use input <- decode.field("input", input_file.decoder())
  use values <- decode.field(
    "values",
    decode.dict(decode.string, decode.string),
  )
  decode.success(ExtractedData(input:, values:))
}

pub fn get_optional_string(data: ExtractedData, var: String) {
  dict.get(data.values, var)
  |> option.from_result()
}

pub fn get_string(data: ExtractedData, var: String) {
  dict.get(data.values, var)
  |> result.map_error(fn(_) { KeyNotFound(var) })
}

pub fn get_money(data: ExtractedData, var: String) {
  use money <- result.try(get_string(data, var))

  money.parse_money(money, Some("."), None)
  |> result.map_error(UnableToParse(var, money, _, "money"))
}

pub fn get_optional_money(data: ExtractedData, var: String) {
  case get_optional_string(data, var) {
    None -> Ok(None)
    Some(money) -> {
      money.parse_money(money, Some("."), None)
      |> result.map(Some)
      |> result.map_error(UnableToParse(var, money, _, "money"))
    }
  }
}

pub fn get_trans_date(data: ExtractedData, var: String) {
  use date <- result.try(get_string(data, var))

  date.parse_partial_date_with_day(date, ".", date.DayMonthYear)
  |> result.map_error(UnableToParse(var, date, _, "date"))
}

pub fn get_range_date(data: ExtractedData, var: String) {
  use date <- result.try(get_string(data, var))

  date.parse_partial_date_with_year(date, ".", date.DayMonthYear)
  |> result.map_error(UnableToParse(var, date, _, "date"))
}

pub fn get_optional_range_date(data: ExtractedData, var: String) {
  case get_optional_string(data, var) {
    None -> Ok(None)
    Some(date) -> {
      date.parse_partial_date_with_year(date, ".", date.DayMonthYear)
      |> result.map(Some)
      |> result.map_error(UnableToParse(var, date, _, "date"))
    }
  }
}
