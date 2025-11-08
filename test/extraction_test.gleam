import data/bank_statement
import data/bank_transaction
import data/date
import data/money
import extractor
import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleeunit/should
import regexp_ext/regexp_ext

pub fn data_extraction_test() {
  let input =
    "Cool Bank - DE12456
Start Amount: 2.25 H on the 1.12.2025
Final Amount: 2.00 S on the 31.12.2025

3. 3. Transaction 1 0.25 S
Details
5. 6. Transaction 2 2.00 S
Details
More Details

Something else

28. 31. Transaction 3 0.01 H
29. 31. Transaction 4 2.01 S

End
"

  let assert Ok(bs_regexes) =
    result.all(
      list.map(
        [
          "Cool Bank - (?<an>DE[0-9]{5})\n",
          "Start Amount: (?<sa_big>[0-9]+)\\.(?<sa_small>[0-9]{2}) (?<sa_sign>[HS]) on the (?<sd>[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{4})",
          "Final Amount: (?<fa_big>[0-9]+)\\.(?<fa_small>[0-9]{2}) (?<fa_sign>[HS]) on the (?<fd>[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{4})",
        ],
        fn(r) { regexp.compile(r, regexp.Options(False, False)) },
      ),
    )

  let assert Ok(trans_regexes) =
    result.all(
      list.map(
        [
          "^(?<bd>[0-9]{1,2})\\. (?<ed>[0-9]{1,2})\\. (?<line1>[^\\n]+) (?<a_big>[0-9])+\\.(?<a_small>[0-9]{2}) (?<a_sign>[HS])(?<lines>(.|\\n)*)$",
        ],
        fn(r) { regexp.compile(r, regexp.Options(False, True)) },
      ),
    )

  let assert Ok(start_trans_regex) =
    regexp.compile(
      "[0-9]{1,2}\\. [0-9]{1,2}\\. [^\\n]+ [0-9]+\\.[0-9]{2} [HS]",
      regexp.Options(False, False),
    )
  let assert Ok(end_trans_regex) =
    regexp.compile("\\n\\n", regexp.Options(False, True))

  let assert Ok(bs_template) =
    bank_statement.parse_template(
      regexes: bs_regexes,
      bank: Some("CoolBank"),
      account: "{an}",
      starts_with: Some("{sa_sign|r(H,+)|r(S,-)}{sa_big}.{sa_small} EUR"),
      ends_with: Some("{fa_sign|r(H,+)|r(S,-)}{fa_big}.{fa_small} EUR"),
      starts_at: Some("{sd}"),
      ends_at: Some("{fd}"),
    )

  let assert Ok(trans_template) =
    bank_transaction.parse_template(
      regexes: trans_regexes,
      start: regexp_ext.SplitBefore(start_trans_regex),
      end: regexp_ext.SplitBefore(end_trans_regex),
      booking_date: Some("{bd}"),
      execution_date: "{ed}",
      amount: "{a_sign|r(H,+)|r(S,-)}{a_big}.{a_small} EUR",
      subject: "{line1|same}{lines|replace(\\n,)}",
    )

  // Act
  let assert Ok(#(statement, transactions)) =
    extractor.extract_bank_statement_data(input, bs_template, trans_template)

  // Test
  should.equal(
    statement,
    bank_statement.BankStatement(
      bank: Some("CoolBank"),
      account: "DE12456",
      start_date: Some(date.Date(2025, 12, 1)),
      end_date: Some(date.Date(2025, 12, 31)),
      start_amount: Some(money.Money(225, "EUR")),
      end_amount: Some(money.Money(-200, "EUR")),
    ),
  )

  should.equal(list.length(transactions), 4)
  should.equal(
    list.first(transactions),
    Ok(bank_transaction.BankTransaction(
      subject: "Transaction 1Details",
      amount: money.Money(-25, "EUR"),
      booking_date: Some(date.Date(2025, 12, 3)),
      execution_date: date.Date(2025, 12, 3),
    )),
  )
  should.equal(
    transactions |> list.drop(1) |> list.first,
    Ok(bank_transaction.BankTransaction(
      subject: "Transaction 2DetailsMore Details",
      amount: money.Money(-200, "EUR"),
      booking_date: Some(date.Date(2025, 12, 5)),
      execution_date: date.Date(2025, 12, 6),
    )),
  )
  should.equal(
    transactions |> list.drop(2) |> list.first,
    Ok(bank_transaction.BankTransaction(
      subject: "Transaction 3",
      amount: money.Money(1, "EUR"),
      booking_date: Some(date.Date(2025, 12, 28)),
      execution_date: date.Date(2025, 12, 31),
    )),
  )
  should.equal(
    transactions |> list.drop(3) |> list.first,
    Ok(bank_transaction.BankTransaction(
      subject: "Transaction 4",
      amount: money.Money(-201, "EUR"),
      booking_date: Some(date.Date(2025, 12, 29)),
      execution_date: date.Date(2025, 12, 31),
    )),
  )
}
