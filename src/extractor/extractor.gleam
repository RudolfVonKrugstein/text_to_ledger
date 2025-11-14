import extractor/extracted_data
import input_loader/input_file

pub type Extractor {
  Extractor(
    run: fn(input_file.InputFile) ->
      Result(
        #(extracted_data.ExtractedData, List(extracted_data.ExtractedData)),
        String,
      ),
  )
}
