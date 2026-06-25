//// An extractor extracts the initial `ExtractedData` from
//// an `InputFile`. Running an extractor on an `InputFile` can
//// either fail (no match) or return a list of `ExtractedData`
//// for the transactions, as well as one `ExtractedData` for the sheet.
////
//// How the extractor creates this data depends on its type.
////
//// - The `TextExtractor` uses regexes to extract the data
////   from any text document.
//// - The `CsvExtractor` parses a CSV document and creates the
////   transactions from the lines.

import data/extracted_data
import extractor/csv/csv_column
import gleam/option.{type Option}
import gsv
import input_loader/input_file
import rule/rule

/// The Extractor, its just the `run` function doing the extraction.
pub type Extractor {
  Extractor(
    name: Option(String),
    run: fn(input_file.InputFile) ->
      Result(
        #(extracted_data.ExtractedData, List(extracted_data.ExtractedData)),
        ExtractRunError,
      ),
  )
}

/// Errors specific to an extractor's own work (parsing CSV, etc.).
pub type ExtractorError {
  CsvError(gsv.Error)
  CsvFileInvalid
  CsvColumnNotFound(column: csv_column.CsvColumn)
}

/// All the ways an `Extractor.run` call can fail.
///
/// An extractor runs a rule internally to populate sheet values,
/// so its failure is either a true extractor problem or a downstream
/// rule problem — kept as separate arms to preserve that origin.
pub type ExtractRunError {
  ExtractorFailure(extractor: ExtractorError)
  RuleFailure(data: extracted_data.ExtractedData, error: rule.RuleError)
}
