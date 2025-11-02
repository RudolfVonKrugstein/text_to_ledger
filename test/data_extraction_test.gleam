import data/bank_transaction
import data/money
import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleam/time/calendar
import gleeunit/should
import template/template

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
          "^Cool Bank - (?<an>DE[0-9]{6})$",
          "^StartAmount: (?<sa_big>[0-9]+)\\.(?<sa_small>[0-9]{2}) (?<sa_sign>[HS]) on the (?<sd>[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{4})$",
          "^FinalAmount: (?<fa_big>[0-9]+)\\.(?<fa_small>[0-9]{2}) (?<fa_sign>[HS]) on the (?<fd>[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{4})$",
        ],
        fn(r) { regexp.compile(r, regexp.Options(False, False)) },
      ),
    )

  let assert Ok(trans_regexes) =
    result.all(
      list.map(
        [
          "^(?<bd>[0-9]{1,2})\\. (?<ed>[0-9]{1,2}) (?<line1>[^\\n]+) (?<a_big>[0-9])+\\.(?<a_small>[0-9]{2}) (?<a_sign>)\\n(?<lines>[^\\n]+\\n)*",
        ],
        fn(r) { regexp.compile(r, regexp.Options(False, True)) },
      ),
    )

  let assert Ok(start_trans_regex) =
    regexp.compile(
      "^[0-9]{1,2})\\. [0-9]{1,2} [^\\n]+ [0-9]+\\.[0-9] [HS]$",
      regexp.Options(False, False),
    )
  let assert Ok(after_trans_regex) =
    regexp.compile("\\n\\n", regexp.Options(False, True))

  let assert Ok(bs_template) =
    bank_statement.render_template(
      regexes: bs_regexes,
      bank: Some("CoolBank"),
      account: Some("{an}"),
      start_date: Some("{sa_sign|r(H,+)|r(S,-)}{sa_big}.{sa_small}"),
      end_date: Some("{fa_sign|r(H,+)|r(S,-)}{fa_big}.{fa_small}"),
      start_amount: Some("{sd} EUR"),
      end_amount: Some("{fd} EUR"),
    )

  let assert Ok(trans_template) =
    bank_transaction.render_template(
      regexes: trans_regexes,
      start_regex: bank_transaction.StartWith(start_trans_regex),
      end_regex: bank_transaction.EndBefore(end_trans_tegex),
      booking_date: Some("{bd}"),
      execution_date: "{bd}",
      amount: "{a_sign|r(H,+)|r(S,-)}{a_big}.{a_small} EUR",
      subject: "{line1|same} {lines|concat( )}",
    )

  // Act
  let #(statement, transactions) =
    extractor.extract_bank_statement_data(bs_template, trans_template)

  // Test
  should.equal(
    statement,
    BankStatement(
      bank: Some("CoolBank"),
      account: Some("DE12456"),
      start_date: Some(calendar.Date(1, calendar.December, 2025)),
      start_date: Some(calendar.Date(31, calendar.December, 2025)),
      start_amount: Some(money.Money(225, "EUR")),
      end_amount: Some(money.Money(-200, "EUR")),
    ),
  )
  should.equal(statement, [
    bank_transaction.BankTransaction(
      subject: "Transaction 1Detail",
      amount: money.Money(-25, "EUR"),
      booking_date: Some(calendar.Date(3, calendar.December, 2025)),
      execution_date: calendar.Date(3, calendar.December, 2025),
    ),
    bank_transaction.BankTransaction(
      subject: "Transaction 2DetailMore Details",
      amount: money.Money(-200, "EUR"),
      booking_date: Some(calendar.Date(5, calendar.December, 2025)),
      execution_date: calendar.Date(6, calendar.December, 2025),
    ),
    bank_transaction.BankTransaction(
      subject: "Transaction 3",
      amount: money.Money(1, "EUR"),
      booking_date: Some(calendar.Date(28, calendar.December, 2025)),
      execution_date: calendar.Date(31, calendar.December, 2025),
    ),
    bank_transaction.BankTransaction(
      subject: "Transaction 3",
      amount: money.Money(-201, "EUR"),
      booking_date: Some(calendar.Date(29, calendar.December, 2025)),
      execution_date: calendar.Date(31, calendar.December, 2025),
    ),
  ])
}
