import data/money.{type Money}
import gleam/time/calendar

/// A Bank Transaction extracted from the input dataz.
pub type BankTransaction {
  BankTransaction(
    subject: String,
    amount: Money,
    book_date: calendar.Date,
    exec_date: calendar.Date,
  )
}
