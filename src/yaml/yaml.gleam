import glaml
import gleam/dynamic

@external(erlang, "yaml_dynamic_ffi", "parse_file_dynamic")
pub fn parse_file(p: String) -> Result(List(dynamic.Dynamic), glaml.YamlError)

@external(erlang, "yaml_dynamic_ffi", "parse_string_dynamic")
pub fn parse_string(s: String) -> Result(List(dynamic.Dynamic), glaml.YamlError)
