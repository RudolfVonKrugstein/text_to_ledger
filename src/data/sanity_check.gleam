//// Run sanity checks on the parsed data.

import data/date.{type Date}
import data/ledger
import data/money.{type Money}
import data/transaction_sheet
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type SanityError {
  TimeRangeMismatch(
    transaction: ledger.LedgerEntry,
    min: Option(Date),
    max: Option(Date),
  )
  BalanceMismatch(
    transaction_sum: Money,
    start_balance: Money,
    end_balance: Money,
  )
}

pub fn check_time_range(
  sheet: transaction_sheet.TransactionSheet,
  transaction: ledger.LedgerEntry,
) {
  let after_start = case sheet.start_date {
    None -> True
    Some(s) -> !date.is_before(transaction.date, s)
  }
  let before_end = case sheet.end_date {
    None -> True
    Some(e) -> !date.is_after(transaction.date, e)
  }
  case after_start && before_end {
    True -> Ok(Nil)
    False ->
      Error(TimeRangeMismatch(
        transaction:,
        min: sheet.start_date,
        max: sheet.end_date,
      ))
  }
}

pub fn check_balance(
  sheet: transaction_sheet.TransactionSheet,
  transactions: List(ledger.LedgerEntry),
) {
  case sheet.start_balance, sheet.end_balance {
    Some(start), Some(end) -> {
      let sum =
        list.fold(transactions, start, fn(acc, trans) {
          money.add(
            acc,
            result.unwrap(
              list.first(trans.lines) |> result.map(fn(l) { l.amount }),
              money.Money(0, 0, ""),
            ),
          )
        })
      case money.equal(sum, end) {
        True -> Ok(Nil)
        False -> Error(BalanceMismatch(sum, start, end))
      }
    }
    _, _ -> Ok(Nil)
  }
}

fn errors(vals: List(Result(a, e))) -> List(e) {
  vals
  |> list.map(fn(v) {
    case v {
      Ok(_) -> None
      Error(e) -> Some(e)
    }
  })
  |> option.values()
}

pub fn sanity_checks(
  sheet: transaction_sheet.TransactionSheet,
  transactions: List(ledger.LedgerEntry),
) {
  case
    errors([
      check_balance(sheet, transactions),
      ..list.map(transactions, fn(t) { check_time_range(sheet, t) })
    ])
  {
    [] -> Ok(Nil)
    errors -> Error(errors)
  }
}
