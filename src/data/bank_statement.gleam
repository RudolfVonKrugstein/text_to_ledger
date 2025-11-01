import data/money.{type Money}
import gleam/option.{type Option}
import gleam/time/calendar

/// A bank statement extracted from the input data.
///
/// All the data for the bank statement is optional.
/// If it is present it is used for sanity checks aand completing the transaction data.
pub type BankStatement {
  BankStatement(
    /// If this and end_date is present, it is checked if:
    /// * All transactions are inside the time range of there bank statements.
    /// * There is a continous list of bank statements, where the next start_date is the last ones end_date.
    ///
    /// Also when present it can complete the date data of the transactions as `bs_start_date_month` and `bs_start_date_year`.
    start_date: Option(calendar.Date),
    /// See start_date.
    end_date: Option(calendar.Date),
    /// The start amount for the bank statement.
    ///
    /// Used for sanity checks and completing the transaction data.
    start_amount: Option(Money),
    /// The end amount for the bank statement.
    ///
    /// Used for sanity checks and completing the transaction data.
    end_amount: Option(Money),
  )
}
