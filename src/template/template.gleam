//// A template to create text (a `String`) using values extracted using
//// named capture groups in regexes.
////
//// Rendering a template allows inserting variables into a string.
//// Variable placeholders are defined using `{` and `}`:
////
//// ```gleam
//// import template/parser/parser
//// import template
//// import io
////
//// fn main() {
////   let template = parser.run("var: {var}")
////   let vars = dict.from_list([#("var", ["value"])])
////   let assert Ok(rendered) = template.render(template, vars)
////   
////   io.println(rendered)
////   // var: value
//// }
//// ```
////
//// The variables can be modified using modificators. This are
//// added behind a variable name using the pipe operator (`|`)
//// and have a name, and optional parameters in paranthese.
//// For examle the `replace` (or short `r`) modfier, replacing
//// a string with another:
////
//// ```gleam
//// import template/parser/parser
//// import template
//// import io
////
//// fn main() {
////   let template = parser.run("var: {var | r(v,V)}")
////   let vars = dict.from_list([#("var", ["value"])])
////   let assert Ok(rendered) = template.render(template, vars)
////   
////   io.println(rendered)
////   // var: Value
//// }
//// ```
////
//// Note, that the variables `vars` values are always lists of strings.
//// That is because they come from named capture groups, which can have
//// several matches when the regex is applied.
//// If you just use a variable, like in the first example above, the
//// value from the first match is used. But there are modifcators, that
//// use all values from the matches. For example the `cancat`, or short
//// `c` modifier:
////
//// ```gleam
//// import template/parser/parser
//// import template
//// import io
////
//// fn main() {
////   let template = parser.run("var: {var | c(-)}")
////   let vars = dict.from_list([#("var", ["1","2","3"])])
////   let assert Ok(rendered) = template.render(template, vars)
////   
////   io.println(rendered)
////   // var: 1-2-3
//// }
//// ```

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

/// Type for a template.
/// It saves the original string the template has been created form as
/// well as the parsed list of templated parts.
pub type Template {
  Template(input: String, parts: List(TemplatePart))
}

/// Parts of a template.
pub type TemplatePart {
  /// A string, which is added to the output as is.
  Literal(String)

  /// A variable filled by a capture group from a regex with optionaly modifications applied to it.
  Variable(name: String, mods: List(TemplateMod))
}

/// Modifcations, applied to variables inside a template.
pub type TemplateMod {
  Mod(
    /// The name of the modification.
    name: String,
    /// Parameters of the modifications.
    parameters: List(String),
  )
}

/// Type for variables inserted when rendering templates.
/// Since the Vars come from named capture groups in a regex
/// and a regex can have several matxhes, the values are
/// represented as a list, where every entry is from a match.
pub type Vars =
  dict.Dict(String, List(String))

pub type RenderError {
  ModParameterError(mod: String, parameters: List(String), msg: String)
  ModApplyError(mod: String, msg: String)
  UnkownModError(mod: String)
  VariableNotFound(var: String)
}

pub fn error_string(e: RenderError) {
  case e {
    ModApplyError(mod:, msg:) -> "could not apply mod " <> mod <> ": " <> msg
    ModParameterError(mod:, parameters:, msg:) ->
      "wrong number of parameters for mod "
      <> mod
      <> ". Applied "
      <> int.to_string(list.length(parameters))
      <> " parameters. "
      <> msg
    UnkownModError(mod:) -> "mod " <> mod <> " is not known"
    VariableNotFound(var:) -> "variable " <> var <> " not found"
  }
}

/// New, empty vars
pub fn empty_vars() {
  dict.new()
}

/// Add a variable value
pub fn add_to_vars(vars: Vars, key: String, value: String) {
  dict.upsert(vars, key, fn(values) {
    case values {
      None -> [value]
      Some(values) -> list.append(values, [value])
    }
  })
}

/// Find an input variable from a list.
fn find_var(name: String, vars: Vars) {
  dict.get(vars, name) |> option.from_result
}

/// Apply the "same" mod to a variable
fn apply_same_mod(
  values: List(String),
  parameters: List(String),
) -> Result(List(String), RenderError) {
  case parameters {
    [] ->
      case values {
        [] -> Ok([])
        [a] -> Ok([a])
        [a, b, ..cs] if a == b -> apply_same_mod([b, ..cs], parameters)
        [a, b, ..] ->
          Error(ModApplyError(
            mod: "same",
            msg: "same mod applied, but not all captures values are the same ("
              <> a
              <> " != "
              <> b
              <> ")",
          ))
      }
    _ ->
      Error(ModParameterError(
        mod: "same",
        parameters: parameters,
        msg: "same takes no parameters",
      ))
  }
}

/// Apply the "replace" mod to a variable
fn apply_replace_mod(
  values: List(String),
  parameters: List(String),
) -> Result(List(String), RenderError) {
  case parameters {
    [orig, replace] ->
      Ok(list.map(values, fn(v) { string.replace(v, orig, replace) }))
    _ ->
      Error(ModParameterError(
        mod: "concat",
        parameters: parameters,
        msg: "mod takes 2 parameter",
      ))
  }
}

/// Apply the "concat" mod to a variable
fn apply_concat_mod(
  values: List(String),
  parameters: List(String),
) -> Result(List(String), RenderError) {
  case parameters {
    [] -> apply_concat_mod(values, [""])
    [sep] -> Ok([string.join(values, sep)])
    _ ->
      Error(ModParameterError(
        mod: "concat",
        parameters: parameters,
        msg: "mod takes 1 parameter",
      ))
  }
}

/// Apply a mod to a variable
fn apply_mod(
  values: List(String),
  mod: String,
  parameters: List(String),
) -> Result(List(String), RenderError) {
  case mod {
    "same" -> apply_same_mod(values, parameters)
    "replace" | "r" -> apply_replace_mod(values, parameters)
    "concat" | "c" -> apply_concat_mod(values, parameters)
    _ -> Error(UnkownModError(mod))
  }
}

/// Apply list of mods to a variable
fn apply_mods(
  values: List(String),
  mods: List(TemplateMod),
) -> Result(List(String), RenderError) {
  case mods {
    [] -> Ok(values)
    [Mod(name, parameters), ..mods] -> {
      use values <- result.try(apply_mod(values, name, parameters))
      apply_mods(values, mods)
    }
  }
}

/// Render a variable into a string.
fn render_variable(
  name: String,
  mods: List(TemplateMod),
  vars: Vars,
) -> Result(String, RenderError) {
  let values = find_var(name, vars) |> option.unwrap([])

  use values <- result.try(apply_mods(values, mods))

  use value <- result.try(
    list.first(values)
    |> result.map_error(fn(_) { VariableNotFound(var: name) }),
  )

  Ok(value)
}

/// Render the template into a string using variables from regex capture groups.
pub fn render(temp: Template, vars: Vars) -> Result(String, RenderError) {
  use parts <- result.try(
    result.all(
      list.map(temp.parts, fn(part) {
        case part {
          Literal(t) -> Ok(t)
          Variable(name, mods) -> render_variable(name, mods, vars)
        }
      }),
    ),
  )

  Ok(string.concat(parts))
}
