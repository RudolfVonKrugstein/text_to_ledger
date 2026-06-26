import data/date
import data/ledger
import data/money
import data/transaction_sheet
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/order

pub type DateRange {
  DateRange(min: date.Date, max: date.Date)
}

pub type Gap {
  Gap(min_date: date.Date, max_date: date.Date)
}

pub type BalanceMismatch {
  BalanceMismatch(
    last_end_balance: money.Money,
    next_start_balance: money.Money,
    next_start_date: date.Date,
  )
}

pub type ContinuationResult {
  ContinuationResult(
    account: String,
    date_range: option.Option(DateRange),
    gaps: List(Gap),
    balance_mismatches: List(BalanceMismatch),
  )
}

pub fn by_start_date(sheets: List(transaction_sheet.TransactionSheet)) {
  case sheets {
    [] -> Some([])
    [sheet, ..sheets] ->
      case sheet.start_date {
        None -> {
          None
        }
        Some(d) ->
          case by_start_date(sheets) {
            None -> None
            Some(rest) -> Some([#(d, sheet), ..rest])
          }
      }
  }
}

pub fn all_have_end_date(sheets: List(transaction_sheet.TransactionSheet)) {
  case sheets {
    [] -> True
    [sheet, ..sheets] ->
      case sheet.end_date {
        None -> False
        _ -> all_have_end_date(sheets)
      }
  }
}

pub fn all_have_balances(sheets: List(transaction_sheet.TransactionSheet)) {
  case sheets {
    [] -> True
    [sheet, ..sheets] ->
      case sheet.start_balance, sheet.end_balance {
        None, _ | _, None -> False
        _, _ -> all_have_balances(sheets)
      }
  }
}

fn pair_with_next(l: List(a)) -> List(#(a, a)) {
  case l {
    [] -> []
    [_] -> []
    [a, b, ..rest] -> [#(a, b), ..pair_with_next([b, ..rest])]
  }
}

pub fn check_continuation(sheets: List(transaction_sheet.TransactionSheet)) {
  let by_account =
    list.fold(sheets, dict.new(), fn(res, sheet) {
      dict.upsert(res, sheet.account, fn(sheets) {
        [sheet, ..option.unwrap(sheets, [])]
      })
    })

  dict.to_list(by_account)
  |> list.map(fn(entry) {
    let #(account, sheets) = entry

    case by_start_date(sheets) {
      None | Some([]) ->
        ContinuationResult(
          account: account,
          date_range: None,
          gaps: [],
          balance_mismatches: [],
        )
      Some(sheets) -> {
        // sort by start date
        let sheets =
          list.sort(sheets, fn(a, b) {
            let #(ad, _) = a
            let #(bd, _) = b
            case ad == bd, date.is_after(ad, bd) {
              True, _ -> order.Eq
              _, True -> order.Gt
              _, False -> order.Lt
            }
          })

        let assert [#(min_date, _), ..] = sheets
        let assert Ok(#(last_min_date, last_sheet)) = list.last(sheets)

        let max_date = case last_sheet.end_date {
          None -> last_min_date
          Some(max_date) -> max_date
        }

        let gaps =
          list.fold(pair_with_next(sheets), [], fn(res, sheet_pair) {
            let #(#(_, asheet), #(bmin_date, _)) = sheet_pair
            case asheet.end_date {
              None -> res
              Some(end_date) -> {
                case
                  end_date == bmin_date || date.next_day(end_date) == bmin_date
                {
                  True -> res
                  False -> [Gap(end_date, bmin_date), ..res]
                }
              }
            }
          })

        let balance_mismatches =
          list.fold(pair_with_next(sheets), [], fn(res, sheet_pair) {
            let #(#(_, asheet), #(bmin_date, bsheet)) = sheet_pair
            case asheet.end_balance, bsheet.start_balance {
              Some(end_balance), Some(start_balance) ->
                case start_balance == end_balance {
                  True -> res
                  False -> [
                    BalanceMismatch(end_balance, start_balance, bmin_date),
                    ..res
                  ]
                }
              _, _ -> res
            }
          })

        ContinuationResult(
          account:,
          date_range: Some(DateRange(min_date, max_date)),
          gaps:,
          balance_mismatches:,
        )
      }
    }
  })
}
