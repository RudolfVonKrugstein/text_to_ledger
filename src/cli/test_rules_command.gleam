//// The `test-rules` interactive subcommand.
////
//// Walks all input files and transactions and, whenever a transaction can not
//// be turned into a ledger entry because a required field is missing, opens
//// the user's `$EDITOR` so they can write one or more new rules. Accepted
//// rules are persisted to the `--rules` file and added to the active rule
//// set for all following transactions.

import cli/common
import cli/config/config
import cli/editor
import cli/error
import cli/log
import cli/suggester
import data/extracted_data.{type ExtractedData}
import data/ledger
import glaml
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import input_loader/input_file.{type InputFile}
import input_loader/input_loader
import rule/rule
import simplifile
import temporary
import yaml/yaml

const user_marker = "# ===== Add rules below this line ====="

type State {
  State(
    /// Raw text of the persisted extra rules file.
    text: String,
    /// Active rules: `config.rules ++ accumulated extra rules`.
    active_rules: List(rule.Rule),
  )
}

type Outcome {
  Continue(state: State)
  Stop
}

pub fn run(
  input_loaders: List(input_loader.InputLoader),
  config: config.Config,
  extra_rules_path: String,
) -> Result(Nil, error.Error) {
  log.info("loading extra rules", [#("path", extra_rules_path)])

  use #(text, extra_rules) <- result.try(load_extra_rules(extra_rules_path))

  log.info("loaded extra rules", [
    #("count", int.to_string(list.length(extra_rules))),
  ])

  let initial =
    State(text:, active_rules: list.append(config.rules, extra_rules))

  use outcome <- result.try(
    list.try_fold(input_loaders, Continue(initial), fn(outcome, loader) {
      case outcome {
        Stop -> Ok(Stop)
        Continue(state) ->
          process_loader(loader, config, extra_rules_path, state)
      }
    }),
  )

  case outcome {
    Stop -> log.info("editor session stopped by user", [])
    Continue(_) -> log.info("all transactions converted successfully", [])
  }
  Ok(Nil)
}

fn load_extra_rules(
  path: String,
) -> Result(#(String, List(rule.Rule)), error.Error) {
  case simplifile.read(path) {
    Error(simplifile.Enoent) -> Ok(#("", []))
    Error(e) ->
      Error(error.LoadExtraRulesError(path, "read error: " <> string.inspect(e)))
    Ok(text) ->
      case parse_rules(text) {
        Ok(rules) -> Ok(#(text, rules))
        Error(msg) -> Error(error.LoadExtraRulesError(path, msg))
      }
  }
}

fn rules_decoder() {
  decode.one_of(
    decode.list(rule.with_children_decoder()) |> decode.map(list.flatten),
    or: [rule.with_children_decoder()],
  )
}

/// Wrap a single-rule YAML document (top-level mapping) into a list item so it
/// can be appended to a rules file whose top level is a list. If the input
/// already starts with `-` it is returned unchanged.
fn wrap_as_list_item(text: String) -> String {
  let trimmed = string.trim(text)
  let lines = string.split(trimmed, "\n")
  let first_content =
    list.find(lines, fn(l) {
      let t = string.trim_start(l)
      t != "" && !string.starts_with(t, "#")
    })
  case first_content {
    Ok(line) ->
      case string.starts_with(string.trim_start(line), "-") {
        True -> trimmed
        False ->
          case lines {
            [] -> trimmed
            [first, ..rest] ->
              ["- " <> first, ..list.map(rest, fn(l) { "  " <> l })]
              |> string.join("\n")
          }
      }
    Error(_) -> trimmed
  }
}

/// Keep at most the last `n` top-level YAML list items from `text`. A new item
/// is detected as a line that starts with `- ` at column 0 (matching what
/// `wrap_as_list_item` produces). Any preamble before the first item is
/// dropped.
fn take_last_n_rules(text: String, n: Int) -> String {
  let lines = string.split(text, "\n")
  let rule_starts =
    list.index_fold(lines, [], fn(acc, l, i) {
      case string.starts_with(l, "- ") {
        True -> [i, ..acc]
        False -> acc
      }
    })
    |> list.reverse
  let to_drop = case list.length(rule_starts) - n {
    d if d > 0 -> d
    _ -> 0
  }
  let keep_from = case list.drop(rule_starts, to_drop) {
    [first, ..] -> first
    [] -> list.length(lines)
  }
  list.drop(lines, keep_from) |> string.join("\n")
}

fn parse_rules(text: String) -> Result(List(rule.Rule), String) {
  case yaml.parse_string(text, rules_decoder()) {
    Ok([]) -> Ok([])
    Ok([rules]) -> Ok(rules)
    Ok(_) -> Error("expected a single YAML document, got multiple")
    Error(e) -> Error(yaml_error_string(e))
  }
}

fn yaml_error_string(e: yaml.YamlDecodeError) -> String {
  case e {
    yaml.YamlError(glaml.ParsingError(msg:, loc:)) ->
      "YAML parse error at line "
      <> int.to_string(loc.line)
      <> " col "
      <> int.to_string(loc.column)
      <> ": "
      <> msg
    yaml.YamlError(glaml.UnexpectedParsingError) ->
      "unexpected YAML parse error"
    yaml.UnableToDecode(errs) ->
      "rule decode error:\n  "
      <> string.join(
        list.map(errs, fn(e) {
          let path = case e.path {
            [] -> "root"
            p -> string.join(p, ".")
          }
          "expected " <> e.expected <> ", found " <> e.found <> " at " <> path
        }),
        "\n  ",
      )
    yaml.ImportLoop(files) -> "import loop: " <> string.join(files, " -> ")
  }
}

fn process_loader(
  loader: input_loader.InputLoader,
  config: config.Config,
  extra_rules_path: String,
  state: State,
) -> Result(Outcome, error.Error) {
  case input_loader.next(loader) |> result.map_error(error.InputLoaderError) {
    Error(e) -> Error(e)
    Ok(None) -> Ok(Continue(state))
    Ok(Some(#(file, loader))) -> {
      use outcome <- result.try(process_file(
        file,
        config,
        extra_rules_path,
        state,
      ))
      case outcome {
        Stop -> Ok(Stop)
        Continue(state) ->
          process_loader(loader, config, extra_rules_path, state)
      }
    }
  }
}

fn process_file(
  file: InputFile,
  config: config.Config,
  extra_rules_path: String,
  state: State,
) -> Result(Outcome, error.Error) {
  log.info("loading", [#("file", file.name)])
  use #(_sheet, transactions) <- result.try(
    common.find_matching_extractor(file, config.extractors)
    |> result.map_error(fn(e) { error.ExtractFromFileError(file, e) }),
  )

  list.try_fold(transactions, Continue(state), fn(outcome, t) {
    case outcome {
      Stop -> Ok(Stop)
      Continue(state) ->
        process_transaction(t, file, extra_rules_path, state, config.suggester)
    }
  })
}

fn process_transaction(
  transaction: ExtractedData,
  file: InputFile,
  extra_rules_path: String,
  state: State,
  suggester: Option(suggester.Suggester),
) -> Result(Outcome, error.Error) {
  case apply_rules(transaction, state.active_rules) {
    Error(rule_err) ->
      Error(error.ExtractFromFileError(file, error.RuleError(rule_err)))
    Ok(applied) ->
      case ledger.from_extracted_data(applied) {
        Ok(_) -> Ok(Continue(state))
        Error(extracted_data.KeyNotFound(key)) -> {
          let missing = missing_ledger_keys(applied)
          log.info("transaction is missing a field, opening editor", [
            #("file", file.name),
            #("missing", string.join(missing, ", ")),
          ])
          let seed = initial_user_input(suggester, applied, missing, state.text)
          editor_loop(
            transaction,
            applied,
            file,
            extra_rules_path,
            state,
            seed,
            "missing key: " <> key,
          )
        }
        Error(other) ->
          Error(error.ExtractFromFileError(
            file,
            error.ExtractedDataError(applied, other),
          ))
      }
  }
}

fn initial_user_input(
  suggester: Option(suggester.Suggester),
  applied: ExtractedData,
  missing: List(String),
  examples: String,
) -> String {
  case suggester {
    None -> skeleton_rule(missing)
    Some(s) -> {
      log.info("asking suggester for a rule", [])
      let trimmed_examples = case s.example_count {
        None -> examples
        Some(n) -> take_last_n_rules(examples, n)
      }
      let values =
        dict.to_list(applied.values)
        |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
        |> list.map(fn(kv) { kv.0 <> ": " <> kv.1 })
        |> string.join("\n")
      let inputs = [
        #("T2L_EXAMPLES_FILE", trimmed_examples),
        #("T2L_CONTENT_FILE", applied.input.content),
        #("T2L_VALUES_FILE", values),
        #("T2L_MISSING_KEYS_FILE", string.join(missing, ", ")),
      ]
      case suggester.suggest(s, inputs) {
        Ok(raw) ->
          case string.trim(raw) {
            "" -> skeleton_rule(missing)
            _ -> raw
          }
        Error(msg) -> {
          log.error("suggester failed, falling back to skeleton", [
            #("error", msg),
          ])
          skeleton_rule(missing)
        }
      }
    }
  }
}

fn apply_rules(
  transaction: ExtractedData,
  rules: List(rule.Rule),
) -> Result(ExtractedData, rule.RuleError) {
  list.try_fold(rules, transaction, fn(t, r) {
    rule.try_apply(t, r)
    |> result.map(option.unwrap(_, t))
  })
}

const required_ledger_keys = [
  "date", "payee", "source_account", "target_account", "amount",
]

fn missing_ledger_keys(applied: ExtractedData) -> List(String) {
  list.filter(required_ledger_keys, fn(k) { !dict.has_key(applied.values, k) })
}

fn convert_error_string(err: error.ExtractFromFileError) -> String {
  case err {
    error.ExtractedDataError(data: _, err: extracted_data.KeyNotFound(key)) ->
      "missing key: " <> key
    error.ExtractedDataError(
      data: _,
      err: extracted_data.UnableToParse(key:, value:, msg:, value_type:),
    ) ->
      "unable to parse "
      <> value_type
      <> " for "
      <> key
      <> " (value="
      <> value
      <> "): "
      <> msg
    error.RuleError(err:) -> "rule failed: " <> rule.error_string(err)
    error.NoExtractorMatch(_) -> "no extractor matched (unexpected here)"
    error.ToManyExtractorMatched(num:) ->
      "multiple extractors matched: " <> int.to_string(num)
  }
}

fn editor_loop(
  transaction: ExtractedData,
  applied: ExtractedData,
  file: InputFile,
  extra_rules_path: String,
  state: State,
  user_input: String,
  error_msg: String,
) -> Result(Outcome, error.Error) {
  let seed =
    build_context(applied, file, error_msg)
    <> "\n"
    <> user_marker
    <> "\n"
    <> user_input

  use new_user_input <- result.try(launch_editor(seed))

  case string.trim(new_user_input) == "" {
    True -> Ok(Stop)
    False ->
      case parse_rules(new_user_input) {
        Error(msg) ->
          editor_loop(
            transaction,
            applied,
            file,
            extra_rules_path,
            state,
            new_user_input,
            "could not parse rules:\n" <> msg,
          )
        Ok([]) -> Ok(Stop)
        Ok(new_rules) -> {
          let combined = list.append(state.active_rules, new_rules)
          case apply_rules(transaction, combined) {
            Error(rule_err) ->
              editor_loop(
                transaction,
                applied,
                file,
                extra_rules_path,
                state,
                new_user_input,
                "rule application error:\n" <> rule.error_string(rule_err),
              )
            Ok(new_applied) ->
              case ledger.from_extracted_data(new_applied) {
                Ok(_) -> {
                  let to_append = wrap_as_list_item(new_user_input)
                  let new_text = case state.text {
                    "" -> to_append <> "\n"
                    t -> string.trim_end(t) <> "\n" <> to_append <> "\n"
                  }
                  use _ <- result.try(
                    simplifile.write(extra_rules_path, new_text)
                    |> result.map_error(error.SaveExtraRulesError(
                      extra_rules_path,
                      _,
                    )),
                  )
                  log.info("rule applied successfully, saved to file", [
                    #("file", extra_rules_path),
                    #("new_rules", int.to_string(list.length(new_rules))),
                  ])
                  Ok(Continue(State(text: new_text, active_rules: combined)))
                }
                Error(data_err) ->
                  editor_loop(
                    transaction,
                    new_applied,
                    file,
                    extra_rules_path,
                    state,
                    new_user_input,
                    "rule did not fix the transaction:\n"
                      <> convert_error_string(error.ExtractedDataError(
                      new_applied,
                      data_err,
                    )),
                  )
              }
          }
        }
      }
  }
}

fn build_context(
  applied: ExtractedData,
  file: InputFile,
  error_msg: String,
) -> String {
  let values_lines =
    dict.to_list(applied.values)
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(kv) { "#   " <> kv.0 <> ": " <> kv.1 })
    |> string.join("\n")

  let applied_rules = case applied.applied_rules {
    [] -> "(none)"
    rs -> string.join(rs, ", ")
  }

  let matched_extractor =
    applied.matched_extractor |> option.unwrap("(unnamed)")

  let content_lines =
    string.split(applied.input.content, "\n")
    |> list.map(fn(l) { "#   " <> l })
    |> string.join("\n")

  let err_lines =
    string.split(error_msg, "\n")
    |> list.map(fn(l) { "# " <> l })
    |> string.join("\n")

  "# ===== Context =====\n"
  <> "# file:    "
  <> file.name
  <> "\n"
  <> "# title:   "
  <> file.title
  <> "\n"
  <> "# loader:  "
  <> file.loader
  <> "\n"
  <> "# matched extractor: "
  <> matched_extractor
  <> "\n"
  <> "# applied rules:     "
  <> applied_rules
  <> "\n"
  <> "#\n"
  <> "# values:\n"
  <> values_lines
  <> "\n#\n"
  <> "# content:\n"
  <> content_lines
  <> "\n#\n"
  <> "# ===== Status =====\n"
  <> err_lines
}

fn launch_editor(seed: String) -> Result(String, error.Error) {
  let outer =
    temporary.create(
      temporary.file() |> temporary.with_suffix(".yaml"),
      fn(path) { write_edit_read(path, seed) },
    )
  case outer {
    Ok(inner) -> inner
    Error(e) ->
      Error(error.EditorError(
        "could not create temp file: " <> string.inspect(e),
      ))
  }
}

fn write_edit_read(path: String, seed: String) -> Result(String, error.Error) {
  use _ <- result.try(
    simplifile.write(path, seed)
    |> result.map_error(fn(e) {
      error.EditorError("write temp file: " <> string.inspect(e))
    }),
  )
  use _ <- result.try(editor.edit(path) |> result.map_error(error.EditorError))
  use new_content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(e) {
      error.EditorError("read temp file: " <> string.inspect(e))
    }),
  )
  Ok(extract_user_input(new_content))
}

fn skeleton_rule(missing: List(String)) -> String {
  let value_lines = case missing {
    [] -> "    field: VALUE"
    keys ->
      list.map(keys, fn(k) { "    " <> k <> ": VALUE" })
      |> string.join("\n")
  }
  "- name: new rule
  regexes:
    subject: PATTERN
  values:
" <> value_lines <> "\n"
}

fn extract_user_input(content: String) -> String {
  case string.split_once(content, user_marker) {
    Ok(#(_, after)) -> after
    Error(_) -> content
  }
}
