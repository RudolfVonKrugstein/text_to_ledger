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

/// Find an input variable from a list.
fn find_var(name: String, vars: List(#(String, List(String)))) {
  case vars {
    [#(fname, flist), ..] if fname == name -> Some(flist)
    [_, ..r] -> find_var(name, r)
    _ -> None
  }
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

/// Apply a mod to a variable
fn apply_mod(values: List(String), mod: String, parameters: List(String)) {
  case mod {
    "same" -> {
      apply_same_mod(values, parameters)
    }
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
fn render_variable(
  name: String,
  mods: List(TemplateMod),
  vars: List(#(String, List(String))),
) {
  use values <- result.try(
    find_var(name, vars) |> option.to_result("unable to find variable " <> name),
  )

  use values <- result.try(apply_mods(values, mods))

  use value <- result.try(
    list.first(values) |> result.map_error(fn(_) { name <> " has not matches" }),
  )

  Ok(value)
}

/// Render the template into a string using variables from regex capture groups.
pub fn render(temp: Template, vars: List(#(String, List(String)))) {
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
