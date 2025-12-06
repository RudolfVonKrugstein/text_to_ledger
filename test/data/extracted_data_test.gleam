import bigi
import data/date
import data/extracted_data
import data/money
import gleam/option.{None, Some}
import gleeunit/should
import input_loader/input_file.{InputFile}

pub fn get_string_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "value")

  // act
  let exists = extracted_data.get_string(data, "var")
  let not_exists = extracted_data.get_string(data, "var2")

  // test
  should.equal(Ok("value"), exists)
  should.equal(Error(extracted_data.KeyNotFound("var2")), not_exists)
}

pub fn get_optional_string_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "value")

  // act
  let exists = extracted_data.get_optional_string(data, "var")
  let not_exists = extracted_data.get_optional_string(data, "var2")

  // test
  should.equal(Some("value"), exists)
  should.equal(None, not_exists)
}

pub fn get_money_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "1.00 EUR")
    |> extracted_data.insert("wrong", "wrong")

  // act
  let exists = extracted_data.get_money(data, "var")
  let not_exists = extracted_data.get_money(data, "var2")
  let not_parsable = extracted_data.get_money(data, "wrong")

  // test
  should.equal(Ok(money.Money(bigi.from_int(100), 2, "EUR")), exists)
  should.equal(Error(extracted_data.KeyNotFound("var2")), not_exists)
  should.be_error(not_parsable)
}

pub fn get_optional_money_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "1.00 EUR")
    |> extracted_data.insert("wrong", "wrong")

  // act
  let exists = extracted_data.get_optional_money(data, "var")
  let not_exists = extracted_data.get_optional_money(data, "var2")
  let not_parsable = extracted_data.get_optional_money(data, "wrong")

  // test
  should.equal(Ok(Some(money.Money(bigi.from_int(100), 2, "EUR"))), exists)
  should.equal(Ok(None), not_exists)
  should.be_error(not_parsable)
}

pub fn get_trans_date_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "27.1")
    |> extracted_data.insert("wrong", "wrong")

  // act
  let exists = extracted_data.get_trans_date(data, "var")
  let not_exists = extracted_data.get_trans_date(data, "var2")
  let not_parsable = extracted_data.get_trans_date(data, "wrong")

  // test
  should.equal(Ok(date.WithDayAndMonth(1, 27)), exists)
  should.equal(Error(extracted_data.KeyNotFound("var2")), not_exists)
  should.be_error(not_parsable)
}

pub fn get_range_date_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "1.2025")
    |> extracted_data.insert("wrong", "wrong")

  // act
  let exists = extracted_data.get_range_date(data, "var")
  let not_exists = extracted_data.get_range_date(data, "var2")
  let not_parsable = extracted_data.get_range_date(data, "wrong")

  // test
  should.equal(Ok(date.WithYearAndMonth(2025, 1)), exists)
  should.equal(Error(extracted_data.KeyNotFound("var2")), not_exists)
  should.be_error(not_parsable)
}

pub fn get_optional_range_date_test() {
  // setup
  let data =
    extracted_data.empty(InputFile(
      loader: "test",
      name: "name",
      title: "title",
      content: "content",
      progress: 0,
      total_files: Some(1),
    ))
    |> extracted_data.insert("var", "1.2025")
    |> extracted_data.insert("wrong", "wrong")

  // act
  let exists = extracted_data.get_optional_range_date(data, "var")
  let not_exists = extracted_data.get_optional_range_date(data, "var2")
  let not_parsable = extracted_data.get_optional_range_date(data, "wrong")

  // test
  should.equal(Ok(Some(date.WithYearAndMonth(2025, 1))), exists)
  should.equal(Ok(None), not_exists)
  should.be_error(not_parsable)
}
