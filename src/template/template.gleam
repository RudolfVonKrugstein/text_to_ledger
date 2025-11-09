import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

/// A template is rendered using variables extracted using regexes into a string.
///
/// Normaly one would get a template by parsing a template string.
///
/// TODO: Explain how template strings work.
pub type Template {
  Template(parts: List(TemplatePart))
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

pub type Vars =
  dict.Dict(String, List(String))

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
fn apply_same_mod(values: List(String), parameters: List(String)) {
  case parameters {
    [] ->
      case values {
        [] -> Ok([])
        [a] -> Ok([a])
        [a, b, ..cs] if a == b -> apply_same_mod([b, ..cs], parameters)
        [a, b, ..] ->
          Error(
            "same mod applied, but not all captures values are the same: "
            <> a
            <> " != "
            <> b,
          )
      }
    _ -> Error("same mod takes no parameters")
  }
}

/// Apply the "replace" mod to a variable
fn apply_replace_mod(values: List(String), parameters: List(String)) {
  case parameters {
    [orig, replace] ->
      Ok(list.map(values, fn(v) { string.replace(v, orig, replace) }))
    _ -> Error("replace mod takes 2 parameters")
  }
}

/// Apply the "concat" mod to a variable
fn apply_concat_mod(values: List(String), parameters: List(String)) {
  case parameters {
    [] -> apply_concat_mod(values, [""])
    [sep] -> Ok([string.join(values, sep)])
    _ -> Error("concat mod takes 1 parameter")
  }
}

/// Apply a mod to a variable
fn apply_mod(values: List(String), mod: String, parameters: List(String)) {
  case mod {
    "same" -> apply_same_mod(values, parameters)
    "replace" | "r" -> apply_replace_mod(values, parameters)
    "concat" | "c" -> apply_concat_mod(values, parameters)
    _ -> Error("unkown mod: " <> mod)
  }
}

/// Apply list of mods to a variable
fn apply_mods(values: List(String), mods: List(TemplateMod)) {
  case mods {
    [] -> Ok(values)
    [Mod(name, parameters), ..mods] -> {
      use values <- result.try(apply_mod(values, name, parameters))
      apply_mods(values, mods)
    }
  }
}

/// Render a variable into a string.
fn render_variable(name: String, mods: List(TemplateMod), vars: Vars) {
  let values = find_var(name, vars) |> option.unwrap([])

  use values <- result.try(apply_mods(values, mods))

  use value <- result.try(
    list.first(values)
    |> result.map_error(fn(_) {
      "variable" <> name <> " has no matches or does not exist"
    }),
  )

  Ok(value)
}

/// Render the template into a string using variables from regex capture groups.
pub fn render(temp: Template, vars: Vars) {
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
