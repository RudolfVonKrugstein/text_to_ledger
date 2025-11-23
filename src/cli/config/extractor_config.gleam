import extracted_data/extracted_data
import extractor/csv/csv_extractor
import extractor/csv/csv_extractor_config
import extractor/extractor
import extractor/text/text_extractor
import extractor/text/text_extractor_config
import gleam/dict
import gleam/dynamic/decode
import gleam/option
import input_loader/input_file

pub fn decoder() -> decode.Decoder(extractor.Extractor) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "text" -> {
      use config <- decode.then(text_extractor_config.decoder())
      decode.success(text_extractor.new(config))
    }
    "csv" -> {
      use config <- decode.then(csv_extractor_config.decoder())
      decode.success(csv_extractor.new(config))
    }
    _ ->
      decode.failure(
        extractor.Extractor(fn(_) {
          Ok(
            #(
              extracted_data.ExtractedData(
                input_file.InputFile("", "", "", "", 0, option.None),
                dict.new(),
              ),
              [],
            ),
          )
        }),
        "extractor type '" <> variant <> "' is not known",
      )
  }
}
