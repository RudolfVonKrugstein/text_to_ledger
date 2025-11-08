//// The day is definitly present

import gleam/dynamic/decode
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// We are using our own Date type, because we are in
/// many cases dealing with fiscal dates, that can be invalid
/// (i.E. 20.2.2025).
pub type Date {
  Date(year: Int, month: Int, day: Int)
}

pub fn to_string(date: Date) {
  string.pad_start(int.to_string(date.year), 4, "0")
  <> "/"
  <> string.pad_start(int.to_string(date.month), 2, "0")
  <> "/"
  <> string.pad_start(int.to_string(date.day), 2, "0")
}

/// A date, where not all information is available (like "5.12").
pub type PartialDateWithDay {
  OnlyDay(day: Int)
  WithDayAndMonth(month: Int, day: Int)
  WithDayFullDate(date: Date)
}

/// A date, where not all information is available (like "5.12").
pub type PartialDateWithYear {
  OnlyYear(year: Int)
  WithYearAndMonth(year: Int, month: Int)
  WithYearFullDate(date: Date)
}

/// The order, in which the elements of a date can be for parsing.
pub type ParseDateOrder {
  DayMonthYear
  MonthDayYear
  YearMonthDay
}

// Brings the seperated parts of a date in a common order,
// which is #(year, month, day)
fn canonical_date_order(one: a, two: a, three: a, order: ParseDateOrder) {
  case order {
    DayMonthYear -> #(three, two, one)
    MonthDayYear -> #(three, one, two)
    YearMonthDay -> #(one, two, three)
  }
}

// Brings the seperated parts of a date in a common order,
// which is #(month, day)
fn canonical_date_order_month_day(one: a, two: a, order: ParseDateOrder) {
  case order {
    DayMonthYear -> #(two, one)
    MonthDayYear -> #(one, two)
    YearMonthDay -> #(one, two)
  }
}

// Brings the seperated parts of a date in a common order,
// which is #(year, month)
fn canonical_date_order_year_month(one: a, two: a, order: ParseDateOrder) {
  case order {
    DayMonthYear -> #(two, one)
    MonthDayYear -> #(two, one)
    YearMonthDay -> #(one, two)
  }
}

// Checks if the date is valid as a financial date.
//
// It does not have to be a real date, but day and month must be in
// a valid range (1<=day<=31, 1<=month<=12).
pub fn is_fiscal_valid_date(date: Date) -> Result(Date, String) {
  case date {
    Date(_, _, day) if day < 1 || day > 31 ->
      Error("invalid date, day (" <> int.to_string(day) <> ") not in range")
    Date(_, month, _) if month < 1 || month > 12 ->
      Error("invalid date, month (" <> int.to_string(month) <> ") not in range")
    _ -> Ok(date)
  }
}

fn parse_day(text: String) {
  use day <- result.try(
    int.parse(text)
    |> result.map_error(fn(_) {
      "invalid date: " <> text <> ", unable to parse day"
    }),
  )
  case day {
    day if day < 1 || day > 31 ->
      Error("invalid date, day (" <> text <> ") not in range")
    _ -> Ok(day)
  }
}

fn parse_month(text: String) {
  use month <- result.try(
    int.parse(text)
    |> result.map_error(fn(_) {
      "invalid date: " <> text <> ", unable to parse month"
    }),
  )
  case month {
    day if day < 1 || day > 12 ->
      Error("invalid date, month (" <> text <> ") not in range")
    _ -> Ok(month)
  }
}

fn parse_year(text: String) {
  use year <- result.try(
    int.parse(text)
    |> result.map_error(fn(_) {
      "invalid date: " <> text <> ", unable to parse year"
    }),
  )
  Ok(year)
}

/// Parse a full date.
///
/// # Arguments:
/// - `text` is the input that is parsed.
/// - `seperator` is the symbol, between the elements of the date.
/// - `order` is the order, in which the date is expected.
pub fn parse_full_date(
  text: String,
  seperator: String,
  order: ParseDateOrder,
) -> Result(Date, String) {
  case string.split(text, seperator) {
    [one, two, three] -> {
      let #(year, month, day) = canonical_date_order(one, two, three, order)

      use day <- result.try(parse_day(day))
      use month <- result.try(parse_month(month))
      use year <- result.try(parse_year(year))

      is_fiscal_valid_date(Date(year, month, day))
    }
    _ -> Error("invalid date: " <> text)
  }
}

pub fn decode_full_date() {
  use date <- decode.then(decode.string)
  case parse_full_date(date, "/", YearMonthDay) {
    Error(e) -> decode.failure(Date(1, 1, 1979), e)
    Ok(date) -> decode.success(date)
  }
}

/// Parse a partial date, resulting in a date with not all information
/// filled, but assume the year is always present (see the `PartialDateWithYear` type).
///
/// # Arguments:
/// - `text`: The text to parse.
/// - `seperator` is the symbol, between the elements of the date.
/// - `order` is the order, in which the date is expected.
pub fn parse_partial_date_with_year(
  text: String,
  seperator: String,
  order: ParseDateOrder,
) -> Result(PartialDateWithYear, String) {
  case string.split(text, seperator) {
    [one] | [one, ""] -> parse_year(one) |> result.map(OnlyYear)
    [one, two] | [one, two, ""] -> {
      let #(year, month) = canonical_date_order_year_month(one, two, order)

      use month <- result.try(parse_month(month))
      use year <- result.try(parse_year(year))

      Ok(WithYearAndMonth(year, month))
    }
    [_, _, _] -> {
      use date <- result.try(parse_full_date(text, seperator, order))
      Ok(WithYearFullDate(date))
    }
    _ -> Error("unable to parse partial date: " <> text)
  }
}

/// Parse a partial date, resulting in a date with not all information
/// filled, but assume the day is alwasy present (see the `PartialDateWithDay` type).
///
/// # Arguments:
/// - `text`: The text to parse.
/// - `seperator` is the symbol, between the elements of the date.
/// - `order` is the order, in which the date is expected.
pub fn parse_partial_date_with_day(
  text: String,
  seperator: String,
  order: ParseDateOrder,
) -> Result(PartialDateWithDay, String) {
  case string.split(text, seperator) {
    [one] | [one, ""] -> parse_day(one) |> result.map(OnlyDay)
    [one, two] | [one, two, ""] -> {
      let #(month, day) = canonical_date_order_month_day(one, two, order)

      use month <- result.try(parse_month(month))
      use day <- result.try(parse_day(day))

      Ok(WithDayAndMonth(month, day))
    }
    [_, _, _] -> {
      use date <- result.try(parse_full_date(text, seperator, order))
      Ok(WithDayFullDate(date))
    }
    _ -> Error("unable to parse partial date: " <> text)
  }
}

/// Find the first (earliest) full date that this partial date
/// could represent.
///
/// This basically means, we return the beginning of the month or
/// year.
pub fn first_possible_date(date: PartialDateWithYear) {
  case date {
    OnlyYear(year:) -> Date(year, 1, 1)
    WithYearAndMonth(year:, month:) -> Date(year, month, 1)
    WithYearFullDate(date:) -> date
  }
}

/// Find the last (latest) full date that this partial date
/// could represent.
///
/// This basically means, we return the end of the month or
/// year.
pub fn last_possible_date(date: PartialDateWithYear) {
  case date {
    OnlyYear(year:) -> Date(year, 12, 31)
    WithYearAndMonth(year:, month:) ->
      Date(year, month, days_in_month(year, month))
    WithYearFullDate(date:) -> date
  }
}

/// Returns the number of days in a month.
fn days_in_month(year: Int, month: Int) {
  case month {
    2 ->
      case is_leap_year(year) {
        True -> 29
        False -> 28
      }
    1 | 3 | 5 | 6 | 8 | 10 | 12 -> 31
    _ -> 30
  }
}

/// Test, if the given year is a leap year.
fn is_leap_year(year: Int) -> Bool {
  // Its a leap year if it is devideable by 4 ...
  case year % 4 == 0 {
    True ->
      // .. but not if it is devidiable by 100 ...
      case year % 100 == 0 {
        True ->
          // .. except if it is devidable by 400!
          case year % 400 == 0 {
            True -> True
            False -> False
          }
        False -> True
      }
    False -> False
  }
}

/// Checks if the `date` is later than the date given by `min`.
pub fn is_after(date: Date, min: Date) {
  case date, min {
    Date(year, _, _), Date(min_year, _, _) if year > min_year -> True
    Date(year, _, _), Date(min_year, _, _) if year < min_year -> False
    Date(_, month, _), Date(_, min_month, _) if month > min_month -> True
    Date(_, month, _), Date(_, min_month, _) if month < min_month -> False
    Date(_, _, day), Date(_, _, min_day) if day > min_day -> True
    _, _ -> False
  }
}

/// Checks if the `date` is earlier than the date given by `min`.
pub fn is_before(date: Date, max: Date) {
  case date, max {
    Date(year, _, _), Date(max_year, _, _) if year < max_year -> True
    Date(year, _, _), Date(max_year, _, _) if year > max_year -> False
    Date(_, month, _), Date(_, max_month, _) if month < max_month -> True
    Date(_, month, _), Date(_, max_month, _) if month > max_month -> False
    Date(_, _, day), Date(_, _, max_day) if day < max_day -> True
    _, _ -> False
  }
}

/// Checks if the date is in the given range.
///
/// `min` and `max` are both optional. If they are `None`, that end is not checked.
pub fn date_is_in_range(date: Date, min: Option(Date), max: Option(Date)) {
  case
    option.map(min, fn(min) { !is_before(date, min) }),
    option.map(max, fn(max) { !is_after(date, max) })
  {
    Some(False), _ -> False
    _, Some(False) -> False
    _, _ -> True
  }
}

/// Incease the month by one.
fn next_month(date: Date) {
  case date.month {
    12 -> Date(..date, month: 1)
    _ -> Date(..date, month: date.month + 1)
  }
}

/// Decrease the month by one.
fn prev_month(date: Date) {
  case date.month {
    1 -> Date(..date, month: 12)
    _ -> Date(..date, month: date.month - 1)
  }
}

/// Find the first (earliest day) after `min`, that
/// can be represented by the partial `date`.
fn first_date_after(date: PartialDateWithDay, min: Date) {
  case date {
    OnlyDay(day:) if day >= min.day -> Ok(Date(..min, day:))
    OnlyDay(day:) -> {
      let next_month = next_month(min)
      Ok(Date(..next_month, day:))
    }
    WithDayAndMonth(month:, day:)
      if month > min.month || month == min.month && day >= min.day
    -> Ok(Date(min.year, month, day))
    WithDayAndMonth(month:, day:) -> Ok(Date(min.year + 1, month, day))
    WithDayFullDate(date) ->
      case !is_before(date, min) {
        True -> Ok(date)
        False -> Error(to_string(date) <> " is after " <> to_string(min))
      }
  }
}

/// Find the first (latest day) before `max`, that
/// can be represented by the partial `date`.
fn first_date_before(date: PartialDateWithDay, max: Date) {
  case date {
    OnlyDay(day:) if day <= max.day -> Ok(Date(..max, day:))
    OnlyDay(day:) -> {
      let prev_month = prev_month(max)
      Ok(Date(..prev_month, day:))
    }
    WithDayAndMonth(month:, day:)
      if month < max.month || month == max.month && day <= max.day
    -> Ok(Date(max.year, month, day))
    WithDayAndMonth(month:, day:) -> Ok(Date(max.year + 1, month, day))
    WithDayFullDate(date) ->
      case !is_after(date, max) {
        True -> Ok(date)
        False -> Error(to_string(date) <> " is before " <> to_string(max))
      }
  }
}

/// Complete the date `date` by finding a date between
/// `min` and `max` that can be represnted by the partial date `date`.
///
/// If `min` or `max` is `None`, the range check at that boundary is ignored.
/// If both `min` and `max` are missing, and `date` is not already complete
/// the function fails.
/// Also if no date between `min` and `max` is found, the function also fails.
pub fn full_date_from_range(
  date: PartialDateWithDay,
  min: Option(Date),
  max: Option(Date),
) {
  case min, max {
    Some(min), max -> {
      use test_date <- result.try(first_date_after(date, min))

      case option.map(max, fn(max) { !is_after(test_date, max) }) {
        None | Some(True) -> Ok(test_date)
        _ ->
          Error(
            "cannot find day for "
            <> string.inspect(date)
            <> " between "
            <> to_string(min)
            <> case max {
              Some(max) -> " and " <> to_string(max)
              None -> " (no upper limit)"
            },
          )
      }
    }
    None, Some(max) -> first_date_before(date, max)
    None, None ->
      case date {
        WithDayFullDate(date) -> Ok(date)
        _ -> Error("date is incomplete and no boundaries are given")
      }
  }
}
