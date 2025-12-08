import bigi
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// An amount of money, as it is found in bank transaction and belances of bank transactions.
pub type Money {
  Money(
    /// The amount in cents (or whatever thr small denomination of the currency is)
    amount: bigi.BigInt,
    /// The position of the decimal, counted from the lowest position
    decimal_pos: Int,
    /// The Currency as a short string in uppercase letters (like EUR or USD)
    currency: String,
  )
}

pub fn money_decoder() -> decode.Decoder(Money) {
  use amount <- decode.field("amount", decode.string)
  use amount <- decode.then(case bigi.from_string(amount) {
    Ok(a) -> decode.success(a)
    Error(_) ->
      decode.failure(bigi.zero(), "unable to parse integer: " <> amount)
  })
  use decimal_pos <- decode.field("decimal_pos", decode.int)
  use currency <- decode.field("currency", decode.string)
  decode.success(Money(amount:, decimal_pos:, currency:))
}

/// Bring to amounts to the same decimal
pub fn equalize_decimal(a: Money, b: Money) {
  case a.decimal_pos, b.decimal_pos {
    a_pos, b_pos if a_pos == b_pos -> #(a, b)
    a_pos, b_pos if a_pos < b_pos ->
      equalize_decimal(
        Money(
          ..a,
          amount: bigi.multiply(a.amount, bigi.from_int(10)),
          decimal_pos: a_pos + 1,
        ),
        b,
      )
    _, b_pos ->
      equalize_decimal(
        a,
        Money(
          ..b,
          amount: bigi.multiply(b.amount, bigi.from_int(10)),
          decimal_pos: b_pos + 1,
        ),
      )
  }
}

/// Add 2 amounts.
pub fn add(a: Money, b: Money) {
  let #(a, b) = equalize_decimal(a, b)
  Money(..a, amount: bigi.add(a.amount, b.amount))
}

/// Switch the sign of the amount.
pub fn negate(money: Money) {
  Money(..money, amount: bigi.negate(money.amount))
}

/// Compare 2 amounts
pub fn equal(a: Money, b: Money) {
  let #(a, b) = equalize_decimal(a, b)
  a == b
}

/// Print an amount in ledger compatible string.
pub fn to_string(money: Money) {
  let amount_str = bigi.to_string(money.amount)
  let amount_str = case money.decimal_pos {
    0 -> amount_str
    pos_from_end -> {
      let pos_from_start = string.length(amount_str) - pos_from_end
      string.drop_end(amount_str, pos_from_end)
      <> "."
      <> string.drop_start(amount_str, pos_from_start)
    }
  }

  amount_str <> " " <> money.currency
}

/// Parse a string, representing money.
///
/// The expected format is: XXX...[<decimal>YY] <CUR>
///
/// - XXX... is the the amount before the decimal (in any length).
/// - <decimal> is the decimal seperator given by the `decimal` parameter.
///   this part is optional, and if does not exist `decimal` should be `None`.
/// - <CUR> is the currency as a 3 letter code.
pub fn parse_money(
  text: String,
  decimal: Option(String),
  thousands: Option(String),
) {
  use #(amount, currency) <- result.try(case string.split(text, " ") {
    [amount, currency] -> {
      case string.length(currency) {
        3 | 2 | 1 -> Ok(#(amount, string.uppercase(currency)))
        _ ->
          Error(
            "invalid currency: "
            <> currency
            <> ", expecting 1-3 letter code (EUR, USD, DM, ...)",
          )
      }
    }
    _ ->
      Error(
        "invalid currency amount: "
        <> text
        <> ", expecting amount and currency seperated by space (example: 12.02 EUR)",
      )
  })

  use #(amount, decimal_pos) <- result.try(case decimal {
    None -> Ok(#(amount, 0))
    Some(decimal) ->
      case string.split(amount, decimal) {
        [amount] -> Ok(#(amount, 0))
        [amount, fraction] -> Ok(#(amount <> fraction, string.length(fraction)))
        _ -> Error("invalid currency amount: " <> amount)
      }
  })

  let amount = case thousands {
    None -> amount
    Some(sep) -> string.replace(amount, sep, "")
  }

  use amount <- result.try(
    bigi.from_string(amount)
    |> result.map_error(fn(_) { "invalid currency amount: " <> text }),
  )

  Ok(Money(amount:, decimal_pos:, currency:))
}

pub fn decode_money() {
  use amount <- decode.then(decode.string)
  case parse_money(amount, Some("."), None) {
    Error(e) -> decode.failure(Money(bigi.zero(), 0, ""), e)
    Ok(money) -> decode.success(money)
  }
}
