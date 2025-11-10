//// Run sanity checks on the parsed data.

import data/bank_statement
import data/bank_transaction
import data/date.{type Date}
import data/money.{type Money}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type SanityError {
  TimeRangeMismatch(
    transaction: bank_transaction.BankTransaction,
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
  statement: bank_statement.BankStatement,
  transaction: bank_transaction.BankTransaction,
) {
  let after_start = case statement.start_date {
    None -> True
    Some(s) -> !date.is_before(transaction.booking_date, s)
  }
  let before_end = case statement.end_date {
    None -> True
    Some(e) -> !date.is_after(transaction.booking_date, e)
  }
  case after_start && before_end {
    True -> Ok(Nil)
    False ->
      Error(TimeRangeMismatch(
        transaction:,
        min: statement.start_date,
        max: statement.end_date,
      ))
  }
}

pub fn check_balance(
  statement: bank_statement.BankStatement,
  transactions: List(bank_transaction.BankTransaction),
) {
  case statement.start_amount, statement.end_amount {
    Some(start), Some(end) -> {
      let sum =
        list.fold(transactions, start, fn(acc, trans) {
          money.add(acc, trans.amount)
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
  statement: bank_statement.BankStatement,
  transactions: List(bank_transaction.BankTransaction),
) {
  case
    errors([
      check_balance(statement, transactions),
      ..list.map(transactions, fn(t) { check_time_range(statement, t) })
    ])
  {
    [] -> Ok(Nil)
    errors -> Error(errors)
  }
}
