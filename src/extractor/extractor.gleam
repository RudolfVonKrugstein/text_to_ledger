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
import enricher/enricher
import extractor/csv/csv_column
import gleam/option.{type Option}
import gsv
import input_loader/input_file

/// The Extractor, its just the `run` function doing the extraction.
pub type Extractor {
  Extractor(
    name: Option(String),
    run: fn(input_file.InputFile) ->
      Result(
        #(extracted_data.ExtractedData, List(extracted_data.ExtractedData)),
        ExtractorError,
      ),
  )
}

pub type ExtractorError {
  EnricherError(enricher.EnricherError)
  CsvError(gsv.Error)
  CsvFileInvalid
  CsvColumnNotFound(column: csv_column.CsvColumn)
}
