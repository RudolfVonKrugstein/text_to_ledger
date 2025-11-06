import data/money.{Money}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should

pub fn parse_money_test() {
  let cases = [
    #("1,120.02 USD", Some("."), Some(","), Money(112_002, "USD")),
    #("12.02 EUR", Some("."), None, Money(1202, "EUR")),
    #("12 ITL", None, None, Money(12, "ITL")),
  ]

  list.each(cases, fn(c) {
    let #(text, decimal, thousands, expected) = c

    should.equal(money.parse_money(text, decimal, thousands), Ok(expected))
  })
}

pub fn parse_money_fails_test() {
  let cases = [
    #("1,120.02  USD", Some("."), Some(",")),
    #("12,02 EUR", Some("."), None),
    #("12 ITLL", None, None),
    #("12  ITL", None, None),
  ]

  list.each(cases, fn(c) {
    let #(text, decimal, thousands) = c

    should.be_error(money.parse_money(text, decimal, thousands))
  })
}
