//// The day is definitly present

import gleam/int
import gleam/option
import gleam/result
import gleam/string

/// We are using our own Date type, because we are in
/// many cases dealing with fiscal dates, that can be invalid
/// (i.E. 20.2.2025).
pub type Date {
  Date(year: Int, month: Int, day: Int)
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
  WithYearAndMonth(month: Int, day: Int)
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
