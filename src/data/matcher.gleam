import data/bank_transaction.{type BankTransaction}
import data/ledger
import data/money
import data/regex
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp

/// A matcher matches a transaction to a ledger entry
pub type Matcher {
  Matcher(
    name: String,
    source_accounts: Option(List(String)),
    target_account: String,
    text: Option(String),
    regex: regex.Regex,
  )
}

pub type Matchers =
  List(Matcher)

pub fn matcher_to_json(matcher: Matcher) -> json.Json {
  let Matcher(name:, source_accounts:, target_account:, text:, regex:) = matcher
  json.object([
    #("name", json.string(name)),
    #("source_accounts", case source_accounts {
      None -> json.null()
      Some(value) -> json.array(value, json.string)
    }),
    #("target_account", json.string(target_account)),
    #("text", case text {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("regex", json.string(regex.original)),
  ])
}

pub fn matcher_decoder() -> decode.Decoder(Matcher) {
  use name <- decode.field("name", decode.string)
  use source_accounts <- decode.optional_field(
    "source_accounts",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use target_account <- decode.field("target_account", decode.string)
  use text <- decode.optional_field(
    "text",
    None,
    decode.optional(decode.string),
  )
  use regex <- decode.field("regex", regex.regex_decoder())
  decode.success(Matcher(
    name:,
    source_accounts:,
    target_account:,
    text:,
    regex:,
  ))
}

/// Return if a transaction matches.
pub fn check_single_match(
  matcher: Matcher,
  transaction: BankTransaction,
  transaction_account: String,
) {
  // check the source account
  let valid_source = case matcher.source_accounts {
    None -> True
    Some(accounts) -> list.contains(accounts, transaction_account)
  }
  case valid_source {
    True -> regexp.check(matcher.regex.regexp, transaction.subject)
    False -> False
  }
}

/// Return if a transaction matches.
pub fn check_match(
  matchers: Matchers,
  transaction: BankTransaction,
  transaction_account: String,
) {
  list.any(matchers, check_single_match(_, transaction, transaction_account))
}

/// Return the ledger entry, if the transaction matches.
pub fn try_single_match(
  matcher: Matcher,
  transaction: BankTransaction,
  transaction_account: String,
) {
  case check_single_match(matcher, transaction, transaction_account) {
    False -> None
    True ->
      Some(
        ledger.LedgerEntry(
          date: transaction.booking_date,
          subject: option.unwrap(matcher.text, matcher.name),
          comment: "matcher: " <> matcher.name,
          lines: [
            ledger.LedgerEntryLine(transaction_account, transaction.amount, ""),
            ledger.LedgerEntryLine(
              transaction_account,
              money.negate(transaction.amount),
              "",
            ),
          ],
        ),
      )
  }
}

pub fn try_match(
  matchers: Matchers,
  transaction: BankTransaction,
  transaction_account: String,
) {
  case
    list.find(matchers, check_single_match(_, transaction, transaction_account))
  {
    Error(_) -> Error("no matcher matched transaction")
    Ok(matcher) -> {
      Ok(
        ledger.LedgerEntry(
          date: transaction.booking_date,
          subject: option.unwrap(matcher.text, matcher.name),
          comment: "matcher: " <> matcher.name,
          lines: [
            ledger.LedgerEntryLine(transaction_account, transaction.amount, ""),
            ledger.LedgerEntryLine(
              transaction_account,
              money.negate(transaction.amount),
              "",
            ),
          ],
        ),
      )
    }
  }
}
