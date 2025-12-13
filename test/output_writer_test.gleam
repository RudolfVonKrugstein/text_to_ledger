import bigi
import data/date
import data/ledger
import data/money
import filepath
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit/should
import input_loader/input_file
import output_writer
import simplifile
import temporary

fn example_entries(num: Int) {
  list.map(list.range(1, num + 1), fn(index) {
    ledger.new(
      input_file.InputFile(
        loader: "loader",
        name: "name",
        title: "title",
        content: "content",
        progress: index,
        total_files: None,
      ),
      None,
      date.Date(2025, 1, index),
      "payee" <> int.to_string(index),
      "comment",
      #("source_account", "target_account"),
      money.Money(bigi.from_int(100 * index), decimal_pos: 2, currency: "EUR"),
    )
  })
}

pub fn write_single_ledger_file_test() {
  // setup
  use out_dir <- temporary.create(temporary.directory())

  let entries = example_entries(3)

  // act
  let assert Ok(writer) =
    output_writer.new(out_dir, "main.ledger", output_writer.Create)
  let assert Ok(writer) =
    list.try_fold(entries, writer, fn(writer, entry) {
      output_writer.write(writer, entry)
    })
  let assert Ok(_) = output_writer.finish(writer)

  // test
  let assert Ok(content) =
    simplifile.read(filepath.join(out_dir, "main.ledger"))
  use entry <- list.each(entries)
  should.be_true(string.contains(
    does: string.trim(content),
    contain: ledger.to_string(entry),
  ))
}

pub fn cannot_create_in_non_empty_dir() {
  // setup
  use out_dir <- temporary.create(temporary.directory())
  let assert Ok(_) =
    simplifile.write(filepath.join(out_dir, "test.ledger"), "stuff")

  // act
  let res = output_writer.new(out_dir, "main.ledger", output_writer.Create)

  // test
  should.be_error(res)
}

pub fn can_append_in_non_empty_dir() {
  // setup
  use out_dir <- temporary.create(temporary.directory())
  let assert Ok(_) =
    simplifile.write(filepath.join(out_dir, "test.ledger"), "stuff")

  // act
  let res = output_writer.new(out_dir, "main.ledger", output_writer.Append)

  // test
  should.be_ok(res)
}

pub fn can_overwrite_in_non_empty_dir() {
  // setup
  use out_dir <- temporary.create(temporary.directory())
  let assert Ok(_) =
    simplifile.write(filepath.join(out_dir, "test.ledger"), "stuff")

  // act
  let res = output_writer.new(out_dir, "main.ledger", output_writer.Overwrite)
  let assert Ok(files) = simplifile.get_files(out_dir)

  // test
  should.be_ok(res)
  should.equal([], files)
}
