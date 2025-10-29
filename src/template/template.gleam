pub type Template {
  Template(parts: List(TemplatePart))
}

pub type TemplatePart {
  Literal(String)
  Variable(name: String, mods: List(TemplateMod))
}

pub type TemplateMod {
  Mod(name: String, parameters: List(String))
}
