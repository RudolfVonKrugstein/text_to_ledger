import data/date.{
  Date, DayAndMonth, DayMonthYear, FullDate, MonthAndYear, MonthDayYear, OnlyDay,
  OnlyYear, WithDay, WithYear, YearMonthDay,
}
import gleam/list
import gleeunit/should

pub fn parse_date_test() {
  let cases = [
    #("1.2.2025", ".", DayMonthYear, Date(2025, 2, 1)),
    #("1/2/2025", "/", MonthDayYear, Date(2025, 1, 2)),
    #("2025#2#1", "#", YearMonthDay, Date(2025, 2, 1)),
  ]

  cases
  |> list.each(fn(c) {
    let #(text, sep, order, expected) = c

    should.equal(date.parse_full_date(text, sep, order), Ok(expected))
  })
}

pub fn parse_date_fail_test() {
  let cases = [
    #("1/2/2025", ".", DayMonthYear),
    #("2/2025", "/", DayMonthYear),
    #("1/2/2025", "/", YearMonthDay),
  ]

  cases
  |> list.each(fn(c) {
    let #(text, sep, order) = c

    should.be_error(date.parse_full_date(text, sep, order))
  })
}

pub fn parse_partial_date_test() {
  let cases = [
    #("1.2.2025", ".", WithDay, DayMonthYear, FullDate(Date(2025, 2, 1))),
    #("1.2.2025", ".", WithYear, DayMonthYear, FullDate(Date(2025, 2, 1))),
    #("1.2", ".", WithDay, DayMonthYear, DayAndMonth(2, 1)),
    #("2/1", "/", WithDay, YearMonthDay, DayAndMonth(2, 1)),
    #("2025/1", "/", WithYear, YearMonthDay, MonthAndYear(2025, 1)),
    #("2/2025", "/", WithYear, DayMonthYear, MonthAndYear(2025, 2)),
    #("1.2.", ".", WithDay, DayMonthYear, DayAndMonth(2, 1)),
    #("2/1/", "/", WithDay, YearMonthDay, DayAndMonth(2, 1)),
    #("1", ".", WithDay, DayMonthYear, OnlyDay(1)),
    #("2025", ".", WithYear, DayMonthYear, OnlyYear(2025)),
  ]

  cases
  |> list.each(fn(c) {
    let #(text, sep, pre, order, expected) = c

    should.equal(date.parse_partial_date(text, sep, pre, order), Ok(expected))
  })
}
