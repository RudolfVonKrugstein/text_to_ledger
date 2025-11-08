import data/date.{
  Date, DayMonthYear, MonthDayYear, OnlyDay, OnlyYear, WithDayAndMonth,
  WithDayFullDate, WithYearAndMonth, WithYearFullDate, YearMonthDay,
}
import gleam/list
import gleam/option.{None, Some}
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
    #("1.2.2025", ".", DayMonthYear, WithDayFullDate(Date(2025, 2, 1))),
    #("1.2", ".", DayMonthYear, WithDayAndMonth(2, 1)),
    #("2/1", "/", YearMonthDay, WithDayAndMonth(2, 1)),
    #("1.2.", ".", DayMonthYear, WithDayAndMonth(2, 1)),
    #("2/1/", "/", YearMonthDay, WithDayAndMonth(2, 1)),
    #("1", ".", DayMonthYear, OnlyDay(1)),
  ]

  cases
  |> list.each(fn(c) {
    let #(text, sep, order, expected) = c

    should.equal(
      date.parse_partial_date_with_day(text, sep, order),
      Ok(expected),
    )
  })
}

pub fn parse_partial_date_with_year_test() {
  let cases = [
    #("1.2.2025", ".", DayMonthYear, WithYearFullDate(Date(2025, 2, 1))),
    #("2025/1", "/", YearMonthDay, WithYearAndMonth(2025, 1)),
    #("2/2025", "/", DayMonthYear, WithYearAndMonth(2025, 2)),
    #("2025", ".", DayMonthYear, OnlyYear(2025)),
  ]

  cases
  |> list.each(fn(c) {
    let #(text, sep, order, expected) = c

    should.equal(
      date.parse_partial_date_with_year(text, sep, order),
      Ok(expected),
    )
  })
}

pub fn find_date_in_range_test() {
  let cases = [
    #(
      OnlyDay(3),
      Some(Date(2025, 12, 1)),
      Some(Date(2025, 12, 31)),
      Date(2025, 12, 3),
    ),
    #(OnlyDay(3), Some(Date(2025, 12, 1)), None, Date(2025, 12, 3)),
    #(OnlyDay(3), None, Some(Date(2025, 12, 31)), Date(2025, 12, 3)),
  ]

  cases
  |> list.each(fn(c) {
    let #(in_date, min, max, expected) = c

    should.equal(date.full_date_from_range(in_date, min, max), Ok(expected))
  })
}
