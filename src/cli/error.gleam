import cli/log
import data/extracted_data
import extractor/csv/csv_column
import extractor/extractor
import glaml
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gsv
import input_loader/error as input_error
import input_loader/input_file
import paperless_api/error as api_error
import rule/rule
import simplifile
import template/template
import yaml/yaml

pub type ExtractFromFileError {
  NoExtractorMatch(errors: List(extractor.ExtractRunError))
  ToManyExtractorMatched(num: Int)
  ExtractedDataError(
    data: extracted_data.ExtractedData,
    err: extracted_data.ExtractedDataError,
  )
  RuleError(
    rule: rule.Rule,
    data: extracted_data.ExtractedData,
    err: rule.RuleError,
  )
}

pub type Error {
  ParseParameterError(msg: String)
  ReadConfigError(file: String, error: simplifile.FileError)
  YamlParseError(file: String, error: yaml.YamlDecodeError)
  InputLoaderError(err: input_error.InputLoaderError)
  ExtractFromFileError(file: input_file.InputFile, err: ExtractFromFileError)
  LoadExtraRulesError(file: String, message: String)
  SaveExtraRulesError(file: String, error: simplifile.FileError)
  EditorError(message: String)
}

pub fn log(e: Error) {
  case e {
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
    LoadExtraRulesError(file:, message:) -> {
      log.error("unable to load extra rules file", [
        #("file", file),
        #("message", message),
      ])
    }
    SaveExtraRulesError(file:, error:) -> {
      log.error("unable to save extra rules file", [
        #("file", file),
        #("error", string.inspect(error)),
      ])
    }
    EditorError(message:) -> {
      log.error("unable to launch editor", [#("message", message)])
    }
    YamlParseError(file:, error:) ->
      case error {
        yaml.YamlError(glaml.ParsingError(msg:, loc:)) ->
          log.error("error parsing yaml", [
            #("config_file", file),
            #("message", msg),
            #("loc_line", int.to_string(loc.line)),
            #("loc_column", int.to_string(loc.line)),
          ])
        yaml.YamlError(glaml.UnexpectedParsingError) ->
          log.error("unexpected error when parsing yaml", [
            #("config_file", file),
          ])
        yaml.UnableToDecode(error) -> {
          log.error("unable to decode config file", [
            #("file", file),
            #("error", string.inspect(error)),
          ])
        }
        yaml.ImportLoop(files) -> {
          log.error("import loop when loading yaml config file", [
            #("config_file", file),
            #("loop", string.join(files, ", ")),
          ])
        }
      }
  }
}

fn print_rule_error(
  rule: option.Option(rule.Rule),
  data: extracted_data.ExtractedData,
  err: rule.RuleError,
  file_vars: List(#(String, String)),
) {
  let rule_name =
    option.then(rule, fn(r) { r.name }) |> option.unwrap("no name")
  case err {
    rule.RegexMatchError(string:, regex:) ->
      log.error("rule failed to match required regular expresssion", [
        #("rule", rule_name),
        #("regex", regex),
        #("string", string),
        ..file_vars
      ])
    rule.InputValueNotFound(name:) ->
      log.error("rule failed to find input value", [
        #("rule", rule_name),
        #("value_name", name),
        ..file_vars
      ])
    rule.TemplateRenderError(template:, error:) ->
      log.error("rule failed to render template", [
        #("rule", rule_name),
        #("template", template),
        #("error", template.error_string(error)),
        ..file_vars
      ])
    rule.KeyOverwriteError(keys:) ->
      log.error("rule overwrites existing keys", [
        #("rule", rule_name),
        #("keys", string.join(keys, ", ")),
        #("applied_rules", string.join(data.applied_rules, ", ")),
        ..list.flatten([
          dict.to_list(data.values)
            |> list.map(fn(val) {
              let #(key, value) = val
              #("value_" <> key, value)
            }),
          file_vars,
        ])
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
  }
}

fn print_extract_run_error(
  err: extractor.ExtractRunError,
  file_vars: List(#(String, String)),
) {
  case err {
    extractor.ExtractorFailure(extractor:) ->
      print_extractor_error(extractor, file_vars)
    extractor.RuleFailure(data:, error:) ->
      print_rule_error(option.None, data, error, file_vars)
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
        list.flatten([
          [
            #("content", data.input.content),
            #(
              "matched_extractor",
              data.matched_extractor |> option.unwrap("null"),
            ),
          ],
          list.index_map(data.applied_rules, fn(name, index) {
            #("applied_rule#" <> int.to_string(index), name)
          }),
          dict.to_list(data.values)
            |> list.map(fn(val) {
              let #(key, value) = val
              #("value_" <> key, value)
            }),
        ])

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
    RuleError(rule:, data:, err:) ->
      print_rule_error(option.Some(rule), data, err, file_vars)
    ExtractedDataError(data:, err:) ->
      print_extracted_data_error(err, data, file_vars)
    NoExtractorMatch(errors:) -> {
      log.error("no extrator matched the file", file_vars)
      list.each(errors, fn(e) { print_extract_run_error(e, file_vars) })
    }
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
