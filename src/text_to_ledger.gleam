import cli/main
import enricher/enricher
import extracted_data/extracted_data
import extractor/csv/csv_column
import extractor/extractor
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/string
import glight
import gsv
import input_loader/error
import input_loader/input_file
import paperless_api/error as api_error
import template/template

fn log_enricher_error(log: glight.LoggerContext, err: enricher.EnricherError) {
  case err {
    enricher.RegexMatchError(string:, regex:) ->
      log
      |> glight.with("regex", regex)
      |> glight.with("string", string)
      |> glight.error("enricher failed to match required regular expression")
    enricher.InputValueNotFound(name:) ->
      log
      |> glight.with("value_name", name)
      |> glight.error("enricher failed to find input value")
    enricher.TemplateRenderError(template:, error:) ->
      log
      |> glight.with("template", template)
      |> glight.with("error", template.error_string(error))
      |> glight.error("enricher failed to render template")
  }
}

fn log_extractor_error(log: glight.LoggerContext, err: extractor.ExtractorError) {
  case err {
    extractor.CsvColumnNotFound(csv_column.ByIndex(i)) ->
      log
      |> glight.with("column_index", int.to_string(i))
      |> glight.error("unable to find column by index in csv")
    extractor.CsvColumnNotFound(csv_column.ByName(n)) ->
      log
      |> glight.with("column_name", n)
      |> glight.error("unable to find column by index in csv")
    extractor.CsvError(err) ->
      case err {
        gsv.MissingClosingQuote(starting_line:) ->
          log
          |> glight.with("starting_line", int.to_string(starting_line))
          |> glight.error("missing closing quote in csv")
        gsv.UnescapedQuote(line:) ->
          log
          |> glight.with("line", int.to_string(line))
          |> glight.error("unescaped quote in csv")
      }
    extractor.CsvFileInvalid -> log |> glight.error("csv file invalid")
    extractor.EnricherError(err) -> log |> log_enricher_error(err)
  }
}

fn with_extracted_data_values(
  log: glight.LoggerContext,
  values: List(#(String, String)),
) {
  case values {
    [] -> log
    [#(key, value), ..vs] ->
      glight.with(log, "value_" <> key, value)
      |> with_extracted_data_values(vs)
  }
}

fn with_extracted_data(
  log: glight.LoggerContext,
  data: extracted_data.ExtractedData,
) {
  with_extracted_data_values(log, dict.to_list(data.values))
}

fn log_extracted_data_error(
  log: glight.LoggerContext,
  err: extracted_data.ExtractedDataError,
) {
  case err {
    extracted_data.KeyNotFound(data:, key:) ->
      log
      |> with_extracted_data(data)
      |> glight.with("key", key)
      |> glight.error("unable to find key in extracted data")
    extracted_data.UnableToParse(data: _, key:, value:, msg:, value_type:) ->
      log
      |> glight.with("key", key)
      |> glight.with("value", value)
      |> glight.with("type", value_type)
      |> glight.with("msg", msg)
      |> glight.error("unable to parse data when extracting")
  }
}

fn log_extract_from_file_error(
  log: glight.LoggerContext,
  file: input_file.InputFile,
  err: main.ExtractFromFileError,
) {
  let log =
    log
    |> glight.with("file_name", file.name)
    |> glight.with("file_title", file.title)
    |> glight.with("input_loader", file.loader)
  case err {
    main.EnricherError(err:) -> log |> log_enricher_error(err)
    main.ExtractedDataError(err) -> log |> log_extracted_data_error(err)
    main.ExtractorError(err:) -> log |> log_extractor_error(err)
    main.NoExtractorMatch(errors: _) ->
      log |> glight.error("no extrator matched the file")
    main.ToManyExtractorMatched(num:) ->
      log
      |> glight.with("num_matched_extractors", int.to_string(num))
      |> glight.error("to many extrator matched the file")
  }
}

fn log_input_loader_error(
  log: glight.LoggerContext,
  err: error.InputLoaderError,
) {
  case err {
    error.PaperlessApiError(err) ->
      log
      |> glight.with("api_error", api_error.string(err))
      |> glight.error("error with paperless api")
    error.ReadDirectoryError(path:, error:) ->
      log
      |> glight.with("path", path)
      |> glight.with("error", string.inspect(error))
      |> glight.error("error reading input directory")
  }
}

pub fn main() -> Nil {
  glight.configure([glight.Console, glight.File("server.log")])
  glight.set_log_level(glight.Debug)
  glight.set_is_color(True)

  let log = glight.logger()
  case main.cli() {
    Ok(_) -> glight.info(log, "done, exiting")
    Error(e) ->
      case e {
        main.DecodeConfigError(file:, error:) ->
          log
          |> glight.with("file", file)
          |> glight.with("error", string.inspect(error))
          |> glight.error("unable to decode config file")
        main.InputLoaderError(err:) -> log |> log_input_loader_error(err)
        main.ParseParameterError(msg:) ->
          log
          |> glight.with("message", msg)
          |> glight.error("unable to parse parameters")
        main.ReadConfigError(file:, error:) ->
          log
          |> glight.with("config_file", file)
          |> glight.with("error", string.inspect(error))
          |> glight.error("unable to read config file")
        main.ExtractFromFileError(file:, err:) ->
          log |> log_extract_from_file_error(file, err)
      }
  }
  // let the logger log all
  process.sleep(100)
}
