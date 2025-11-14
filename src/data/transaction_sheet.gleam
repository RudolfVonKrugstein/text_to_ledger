import data/date
import data/money.{type Money}
import extractor/extracted_data
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result
import input_loader/input_file.{type InputFile}

/// Data of an transaction sheet (i.E. a bank statement) extracted from the input data.
///
/// All the data for the sheet is optional.
/// If it is present it is used for sanity checks aand completing the transaction data.
pub type TransactionSheet {
  TransactionSheet(
    /// The document this comes from
    origin: InputFile,
    /// If this and end_date is present, it is checked if:
    /// * All transactions are inside the time range of there bank statements.
    /// * There is a continous list of bank statements, where the next start_date is the last ones end_date.
    ///
    /// Also when present it can complete the date data of the transactions as `bs_start_date_month` and `bs_start_date_year`.
    start_date: Option(date.Date),
    /// See start_date.
    end_date: Option(date.Date),
    /// The start amount for the bank statement.
    ///
    /// Used for sanity checks and completing the transaction data.
    start_balance: Option(Money),
    /// The end amount for the bank statement.
    ///
    /// Used for sanity checks and completing the transaction data.
    end_balance: Option(Money),
  )
}

pub fn transaction_sheet_decoder() -> decode.Decoder(TransactionSheet) {
  use origin <- decode.field("origin", input_file.decoder())
  use start_date <- decode.optional_field(
    "start_date",
    None,
    decode.optional(date.decode_full_date()),
  )
  use end_date <- decode.optional_field(
    "end_date",
    None,
    decode.optional(date.decode_full_date()),
  )
  use start_balance <- decode.optional_field(
    "start_balance",
    None,
    decode.optional(money.decode_money()),
  )
  use end_balance <- decode.optional_field(
    "end_balance",
    None,
    decode.optional(money.decode_money()),
  )
  decode.success(TransactionSheet(
    origin:,
    start_date:,
    end_date:,
    start_balance:,
    end_balance:,
  ))
}

pub fn from_extracted_data(data: extracted_data.ExtractedData) {
  use start_date <- result.try(extracted_data.get_optional_range_date(
    data,
    "start_date",
  ))
  let start_date = start_date |> option.map(date.first_possible_date)

  use end_date <- result.try(extracted_data.get_optional_range_date(
    data,
    "end_date",
  ))
  let end_date = end_date |> option.map(date.last_possible_date)

  use start_balance <- result.try(extracted_data.get_optional_money(
    data,
    "start_balance",
  ))
  use end_balance <- result.try(extracted_data.get_optional_money(
    data,
    "end_balance",
  ))
  Ok(TransactionSheet(
    origin: data.input,
    start_date:,
    end_date:,
    start_balance:,
    end_balance:,
  ))
}
