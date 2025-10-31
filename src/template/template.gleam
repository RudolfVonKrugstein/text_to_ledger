import gleam/list
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

/// Render the template into a string using variables from regex capture groups.
pub fn render(temp: Template, vars: List(#(String, List(String)))) {
  string.concat(
    list.map(temp.parts, fn(part) {
      case part {
        Literal(t) -> t
        Variable(name:, mods:) -> ""
      }
    }),
  )
}
