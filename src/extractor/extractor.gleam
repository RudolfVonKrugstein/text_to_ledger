import enricher/enricher
import data/extracted_data
import extractor/csv/csv_column
import gsv
import input_loader/input_file

pub type Extractor {
  Extractor(
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
