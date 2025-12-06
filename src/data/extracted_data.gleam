//// Extracted data is "raw" data extracted form an input document.
//// It is a list of variables with text values, that have been extracted
//// from input documents (text) using extractors and enrichers.
////
//// Extracted data is used to create output value, like ledger entries
//// from. To do that, this module provides various methods to create
//// different types of data form the values in the variables.

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

/// The type for extracted data.
pub type ExtractedData {
  ExtractedData(
    /// The input document, this data has been created from.
    input: input_file.InputFile,
    /// The values extracted (so far).
    /// This is a dict from the variable name to the variable value
    /// which is always a string at this point.
    /// To create other types of values from them, use the various
    /// functions provided in this module.
    values: dict.Dict(String, String),
  )
}

/// Error occured during extracting data.
pub type ExtractedDataError {
  KeyNotFound(key: String)
  UnableToParse(key: String, value: String, msg: String, value_type: String)
}

/// Empty (no varibale/values) extracted data.
/// This is the starting point for the extraction process.
pub fn empty(input: input_file.InputFile) {
  ExtractedData(input, dict.new())
}

/// Insert a value.
pub fn insert(data: ExtractedData, key: String, value: String) {
  ExtractedData(..data, values: dict.insert(data.values, key, value))
}

/// Change the input document, for the extracted data.
/// This is i.E. used to update the content of the input, because
/// the extracted data might only depend on a subset of the input text.
pub fn update_input(data: ExtractedData, input: input_file.InputFile) {
  ExtractedData(..data, input:)
}

/// Convert to a json object, i.E. to serialize to disc.
pub fn to_json(extracted_data: ExtractedData) -> json.Json {
  let ExtractedData(input:, values:) = extracted_data
  json.object([
    #("input", input_file.to_json(input)),
    #("values", json.dict(values, fn(string) { string }, json.string)),
  ])
}

/// Get extracted data from a json file.
pub fn decoder() -> decode.Decoder(ExtractedData) {
  use input <- decode.field("input", input_file.decoder())
  use values <- decode.field(
    "values",
    decode.dict(decode.string, decode.string),
  )
  decode.success(ExtractedData(input:, values:))
}

/// Return the string in a variable, or None if the variable does not exist.
///
/// # Arguments
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// `Some(val)` if the variable `var` exists (`val` is the value of the variable)
/// or `None` if the variable `var` does not exist.
pub fn get_optional_string(data: ExtractedData, var: String) {
  dict.get(data.values, var)
  |> option.from_result()
}

/// Return the string in variable `var`.
///
/// # Arguments
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// The string if the variable `var` exists, `KeyNotFound` error if not.
pub fn get_string(data: ExtractedData, var: String) {
  dict.get(data.values, var)
  |> result.map_error(fn(_) { KeyNotFound(var) })
}

/// Parse a variable `var` into a `Money` object.
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// The `Money` object if the variable `var` exists and can be parsed as money.
/// Other wise an error is returned.
pub fn get_money(data: ExtractedData, var: String) {
  use money <- result.try(get_string(data, var))

  money.parse_money(money, Some("."), None)
  |> result.map_error(UnableToParse(var, money, _, "money"))
}

/// Parse a variable `var` into a `Money` object.
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// The `Money` object, wrapped in `Some`, if the variable `var` exists and can be parsed as money.
/// If it cannot be parsed, `UnableToParse` error is returned.
/// If `var` does not exist None is returned.
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

/// Parse a variable `var` into a transaction date object.
/// A transaction date only contains optional a year.
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// The `PartialDateWithDay` object if `var` exists and can be parse.
/// Otherwise an error is returned.
pub fn get_trans_date(data: ExtractedData, var: String) {
  use date <- result.try(get_string(data, var))

  date.parse_partial_date_with_day(date, ".", date.DayMonthYear)
  |> result.map_error(UnableToParse(var, date, _, "date"))
}

/// Parse a variable `var` into a range date object.
/// A range date only contains optional a day.
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// The `PartialDateWithYear` object if `var` exists and can be parse.
/// Otherwise an error is returned.
pub fn get_range_date(data: ExtractedData, var: String) {
  use date <- result.try(get_string(data, var))

  date.parse_partial_date_with_year(date, ".", date.DayMonthYear)
  |> result.map_error(UnableToParse(var, date, _, "date"))
}

/// Parse a variable `var` into an optional range date object.
/// A range date only contains optional a day.
///
/// - data: The `ExtractedData` to get the value from.
/// - var: The name of the variable.
///
/// # Returns
///
/// The `PartialDateWithYear` object if `var` exists and can be parse.
/// If it cannot be parsed, `UnableToParse` error is returned.
/// If `var` does not exist None is returned.
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
