import cli/log
import enricher/enricher
import extracted_data/extracted_data
import extractor/csv/csv_column
import extractor/extractor
import glaml
import gleam/dict
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import gsv
import input_loader/error as input_error
import input_loader/input_file
import paperless_api/error as api_error
import simplifile
import template/template

pub type ExtractFromFileError {
  ExtractorError(err: extractor.ExtractorError)
  NoExtractorMatch(errors: List(extractor.ExtractorError))
  ToManyExtractorMatched(num: Int)
  ExtractedDataError(
    data: extracted_data.ExtractedData,
    err: extracted_data.ExtractedDataError,
  )
  EnricherError(err: enricher.EnricherError)
}

pub type Error {
  ParseParameterError(msg: String)
  ReadConfigError(file: String, error: simplifile.FileError)
  DecodeConfigError(file: String, error: json.DecodeError)
  YamlParseError(file: String, error: glaml.YamlError)
  InputLoaderError(err: input_error.InputLoaderError)
  ExtractFromFileError(file: input_file.InputFile, err: ExtractFromFileError)
}

pub fn log(e: Error) {
  case e {
    DecodeConfigError(file:, error:) -> {
      log.error("unable to decode config file", [
        #("file", file),
        #("error", string.inspect(error)),
      ])
    }
    InputLoaderError(err:) -> print_input_loader_error(err)
    ParseParameterError(msg:) -> {
      log.error("unable to parse parameters", [#("message", msg)])
    }
    ReadConfigError(file:, error:) -> {
      log.error("unable to read config file", [
        #("error", string.inspect(error)),
        #("config_file", file),
      ])
    }
    ExtractFromFileError(file:, err:) ->
      print_extract_from_file_error(file, err)
    YamlParseError(file:, error:) ->
      case error {
        glaml.ParsingError(msg:, loc:) ->
          log.error("error parsing yaml", [
            #("config_file", file),
            #("message", msg),
            #("loc_line", int.to_string(loc.line)),
            #("loc_column", int.to_string(loc.line)),
          ])
        glaml.UnexpectedParsingError ->
          log.error("unexpected error when parsing yaml", [
            #("config_file", file),
          ])
      }
  }
}

fn print_enricher_error(
  err: enricher.EnricherError,
  file_vars: List(#(String, String)),
) {
  case err {
    enricher.RegexMatchError(string:, regex:) ->
      log.error("enricher failed to match required regular expresssion", [
        #("regex", regex),
        #("string", string),
        ..file_vars
      ])
    enricher.InputValueNotFound(name:) ->
      log.error("enricher failed to find input value", [
        #("value_name", name),
        ..file_vars
      ])
    enricher.TemplateRenderError(template:, error:) ->
      log.error("enricher failed to render template", [
        #("template", template),
        #("error", template.error_string(error)),
        ..file_vars
      ])
  }
}

fn print_extractor_error(
  err: extractor.ExtractorError,
  file_vars: List(#(String, String)),
) {
  case err {
    extractor.CsvColumnNotFound(csv_column.ByIndex(i)) ->
      log.error("unable to find coloumn by index in csv", [
        #("column_index", int.to_string(i)),
        ..file_vars
      ])
    extractor.CsvColumnNotFound(csv_column.ByName(n)) ->
      log.error("unable to find coloumn by name in csv", [
        #("column_name", n),
        ..file_vars
      ])
    extractor.CsvError(err) ->
      case err {
        gsv.MissingClosingQuote(starting_line:) ->
          log.error("missing closing quote in csv", [
            #("starting_line", int.to_string(starting_line)),
            ..file_vars
          ])
        gsv.UnescapedQuote(line:) ->
          log.error("unescaped quote in csv", [
            #("line", int.to_string(line)),
            ..file_vars
          ])
      }
    extractor.CsvFileInvalid -> log.error("csv file invalid", file_vars)
    extractor.EnricherError(err) -> print_enricher_error(err, file_vars)
  }
}

fn print_extracted_data_error(
  err: extracted_data.ExtractedDataError,
  data: extracted_data.ExtractedData,
  file_vars: List(#(String, String)),
) {
  case err {
    extracted_data.KeyNotFound(key:) -> {
      let extracted_data_vars =
        dict.to_list(data.values)
        |> list.map(fn(val) {
          let #(key, value) = val
          #("value_" <> key, value)
        })

      log.error("unable to find key in extracted data", [
        #("key", key),
        ..list.flatten([file_vars, extracted_data_vars])
      ])
    }
    extracted_data.UnableToParse(key:, value:, msg:, value_type:) ->
      log.error("unable to parse data when extracting", [
        #("key", key),
        #("value", value),
        #("type", value_type),
        #("msg", msg),
      ])
  }
}

fn print_extract_from_file_error(
  file: input_file.InputFile,
  err: ExtractFromFileError,
) {
  let file_vars = [
    #("file_name", file.name),
    #("file_title", file.title),
    #("input_loader", file.loader),
  ]

  case err {
    EnricherError(err:) -> print_enricher_error(err, file_vars)
    ExtractedDataError(data:, err:) ->
      print_extracted_data_error(err, data, file_vars)
    ExtractorError(err:) -> print_extractor_error(err, file_vars)
    NoExtractorMatch(errors: _) -> log.error("no extrator matched the file", [])
    ToManyExtractorMatched(num:) ->
      log.error("to many extrator matched the file", [
        #("num_matched_extractors", int.to_string(num)),
      ])
  }
}

fn print_input_loader_error(err: input_error.InputLoaderError) {
  case err {
    input_error.PaperlessApiError(err) -> {
      log.error("error with paperless API", [
        #("api_error", api_error.string(err)),
      ])
    }
    input_error.ReadDirectoryError(path:, error:) -> {
      log.error("error reading input directory", [
        #("path", path),
        #("api_error", string.inspect(error)),
      ])
    }
  }
}
