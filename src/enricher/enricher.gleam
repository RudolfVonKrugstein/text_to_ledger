//// An enricher adds or updates variables to `ExtractedData`
//// by applying regexes to existing variable or the file content
//// and rendering templates into new variables.

import data/extracted_data.{type ExtractedData, ExtractedData}
import extractor/extract_regex.{type ExtractRegex}
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import regex/regex
import regexp_ext
import template/parser/parser
import template/template

/// The enricher to add information/variables to `ExtractedData`
pub type Enricher {
  Enricher(
    /// Name of the enricher, just for tracing/debuging
    name: Option(String),
    /// The regexes with named capture groups
    regexes: List(ExtractRegex),
    /// The variables/values to render in case of sucessfull match of the regexes
    values: dict.Dict(String, template.Template),
  )
}

/// Decode an enricher, that may have children.
///
/// If it does not have children, than a list with just the enricher is returned.
/// Otherwise the outer enricherer is merged with the children and returned as a list.
pub fn with_children_decoder() -> decode.Decoder(List(Enricher)) {
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )

  use children <- decode.optional_field(
    "children",
    None,
    decode.optional(decode.list(with_children_decoder())),
  )

  case children {
    None -> {
      use res <- decode.then(decoder())
      decode.success([res])
    }
    Some(children) -> {
      use regexes <- decode.optional_field("regexes", [], regex_list_decoder())
      use values <- decode.optional_field(
        "values",
        dict.new(),
        decode.dict(decode.string, parser.decode_template()),
      )

      decode.success(
        list.map(list.flatten(children), fn(child) {
          Enricher(
            name: case name {
              None -> child.name
              Some(name) -> Some(name <> "/" <> child.name |> option.unwrap(""))
            },
            regexes: list.append(regexes, child.regexes),
            values: dict.merge(values, child.values),
          )
        }),
      )
    }
  }
}

/// Decode a single enricher.
/// 
/// Decode an enricher from `Dynamic`
pub fn decoder() -> decode.Decoder(Enricher) {
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )
  use regexes <- decode.field("regexes", regex_list_decoder())
  use values <- decode.field(
    "values",
    decode.dict(decode.string, parser.decode_template()),
  )
  decode.success(Enricher(name:, regexes:, values:))
}

/// Decode a single regex or a list into a list
fn regex_list_decoder() -> decode.Decoder(List(ExtractRegex)) {
  decode.one_of(decode.list(extract_regex.decoder("content")), [
    {
      use dict <- decode.then(decode.dict(
        decode.string,
        decode.one_of(
          {
            use regex <- decode.then(regex.regex_opt_decoder())
            decode.success([regex])
          },
          [
            decode.list(regex.regex_opt_decoder()),
          ],
        ),
      ))

      decode.success(
        dict.to_list(dict)
        |> list.map(fn(e) {
          let #(on, regexes) = e
          list.map(regexes, fn(regex) {
            extract_regex.ExtractRegex(regex:, on:)
          })
        })
        |> list.flatten,
      )
    },
  ])
}

/// The errors that can happen through extraction
pub type EnricherError {
  /// Regex did not match
  RegexMatchError(string: String, regex: String)
  /// Error during rendering of template
  TemplateRenderError(template: String, error: template.RenderError)
  /// Input variable was not found
  InputValueNotFound(name: String)
}

pub fn error_string(e: EnricherError) -> String {
  case e {
    RegexMatchError(string:, regex:) ->
      "Error matching regex:\n" <> regex <> "\non:\n" <> string
    TemplateRenderError(template:, error:) ->
      "Error rendering template:\n"
      <> template
      <> "error: "
      <> template.error_string(error)
    InputValueNotFound(name:) -> "Input value " <> name <> " was not found"
  }
}

/// Collect variables by applying regexes and getting all values for named captures groups.
fn collect_variables(
  regexes: List(ExtractRegex),
  data: ExtractedData,
) -> Result(dict.Dict(String, List(String)), EnricherError) {
  extend_variables(regexes, data, template.empty_vars())
}

/// Extend variables by applying regexes and getting all values for named captures groups.
fn extend_variables(
  regexes: List(ExtractRegex),
  data: ExtractedData,
  start: template.Vars,
) -> Result(dict.Dict(String, List(String)), EnricherError) {
  list.try_fold(regexes, start, fn(vars, regex) {
    use target <- result.try(case regex.on {
      "content" -> Ok(data.input.content)
      "file.name" -> Ok(data.input.name)
      "file.title" -> Ok(data.input.title)
      t ->
        dict.get(data.values, t)
        |> result.map_error(fn(_) { InputValueNotFound(t) })
    })
    let captures =
      regexp_ext.capture_names(with: regex.regex.regex, over: target)

    case captures {
      [] if regex.regex.optional == True -> Ok(vars)
      [] -> Error(RegexMatchError(target, regex.regex.original))
      captures ->
        Ok(
          list.fold(list.flatten(captures), vars, fn(vars, capture) {
            let regexp_ext.NamedCapture(name:, value:) = capture

            template.add_to_vars(vars, name, value)
          }),
        )
    }
  })
}

fn dict_fold_error(
  over dict: dict.Dict(k, v),
  from initial: acc,
  with fun: fn(acc, k, v) -> Result(acc, e),
) -> Result(acc, e) {
  dict.fold(dict, Ok(initial), fn(acc, k, v) {
    case acc {
      Error(_) -> acc
      Ok(acc) -> fun(acc, k, v)
    }
  })
}

fn dict_map_values_error(
  over dict: dict.Dict(k, v),
  with fun: fn(v) -> Result(res, e),
) {
  dict_fold_error(dict, dict.new(), fn(acc, k, v) {
    use v <- result.try(fun(v))
    Ok(dict.insert(acc, k, v))
  })
}

/// Apply an enricher to `ExtractedData`.
/// Gives back an error if it can not be applied.
pub fn apply(
  data: ExtractedData,
  enricher: Enricher,
) -> Result(ExtractedData, EnricherError) {
  use vars <- result.try(collect_variables(enricher.regexes, data))

  use new_values <- result.try(
    enricher.values
    |> dict_map_values_error(fn(template) {
      template.render(template, vars)
      |> result.map_error(fn(error) {
        TemplateRenderError(template: template.input, error:)
      })
    }),
  )

  Ok(
    ExtractedData(..data, values: dict.merge(data.values, new_values))
    |> extracted_data.with_option_enricher(enricher.name),
  )
}

/// Apply an enricher to `ExtractedData`, but dont give
/// back an error if the extractor cannot be applied
/// becaue a regex does not match or an input variable is not found.
/// Instead give back `None` in these cases.
pub fn try_apply(
  data: ExtractedData,
  enricher: Enricher,
) -> Result(Option(ExtractedData), EnricherError) {
  case apply(data, enricher) {
    Error(RegexMatchError(_, _)) -> Ok(None)
    Error(InputValueNotFound(_)) -> Ok(None)
    Error(e) -> Error(e)
    Ok(e) -> Ok(Some(e))
  }
}

/// Try apply (see `try_apply`) but give back the
/// original data instead of None if it cannot be applied.
pub fn try_maybe_apply(
  data: ExtractedData,
  enricher: Enricher,
) -> Result(ExtractedData, EnricherError) {
  try_apply(data, enricher) |> result.map(option.unwrap(_, data))
}
