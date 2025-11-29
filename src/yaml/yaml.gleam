import glaml
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

pub type YamlDecodeError {
  YamlError(glaml.YamlError)
  UnableToDecode(List(decode.DecodeError))
}

@external(erlang, "yaml_dynamic_ffi", "parse_file_dynamic")
fn yaml_parse_file(p: String) -> Result(List(dynamic.Dynamic), glaml.YamlError)

@external(erlang, "yaml_dynamic_ffi", "parse_string_dynamic")
fn yaml_parse_string(
  s: String,
) -> Result(List(dynamic.Dynamic), glaml.YamlError)

pub fn parse_file(
  f: String,
  decoder: decode.Decoder(a),
) -> Result(List(a), YamlDecodeError) {
  use dynamic_values <- result.try(
    yaml_parse_file(f) |> result.map_error(YamlError),
  )

  dynamic_values
  |> list.try_map(decode.run(_, decoder))
  |> result.map_error(UnableToDecode)
}

pub fn parse_string(
  s: String,
  decoder: decode.Decoder(a),
) -> Result(List(a), YamlDecodeError) {
  use dynamic_values <- result.try(
    yaml_parse_string(s) |> result.map_error(YamlError),
  )

  dynamic_values
  |> list.try_map(decode.run(_, decoder))
  |> result.map_error(UnableToDecode)
}
