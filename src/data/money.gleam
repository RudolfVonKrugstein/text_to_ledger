import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// An amount of money, as it is found in bank transaction and belances of bank transactions.
pub type Money {
  Money(
    /// The amount in cents (or whatever thr small denomination of the currency is)
    amount: Int,
    /// The Currency as a short string in uppercase letters (like EUR or USD)
    currency: String,
  )
}

/// Parse a string, represnting money.
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
        3 -> Ok(#(amount, string.uppercase(currency)))
        _ ->
          Error(
            "invalid currency: "
            <> currency
            <> ", expecting 3 letter code (EUR, USD, ...)",
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

  use #(full_amount, fraction_amount) <- result.try(case decimal {
    None -> Ok(#("0", amount))
    Some(decimal) -> {
      case string.split(amount, decimal) {
        [full_amount, fraction_amount] -> Ok(#(full_amount, fraction_amount))
        _ ->
          Error(
            "invalid currency amount: "
            <> text
            <> ", decimal seperator not found ("
            <> decimal
            <> ")",
          )
      }
    }
  })
  let full_amount = case thousands {
    None -> full_amount
    Some(sep) -> string.replace(full_amount, sep, "")
  }

  use full_amount <- result.try(
    int.parse(full_amount)
    |> result.map_error(fn(_) { "invalid currency amount: " <> text }),
  )

  use fraction_amount <- result.try(
    int.parse(fraction_amount)
    |> result.map_error(fn(_) { "invalid currency amount: " <> text }),
  )

  Ok(Money(full_amount * 100 + fraction_amount, currency))
}
