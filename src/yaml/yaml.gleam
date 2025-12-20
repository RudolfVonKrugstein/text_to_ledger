import filepath
import glaml
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

pub type YamlDecodeError {
  YamlError(glaml.YamlError)
  ImportLoop(files: List(String))
  UnableToDecode(List(decode.DecodeError))
}

pub fn decode_yaml(
  node: glaml.Node,
  visited_files: List(String),
) -> Result(dynamic.Dynamic, YamlDecodeError) {
  case node {
    glaml.NodeNil -> Ok(dynamic.nil())
    glaml.NodeStr(s) -> Ok(dynamic.string(s))
    glaml.NodeBool(b) -> Ok(dynamic.bool(b))
    glaml.NodeInt(i) -> Ok(dynamic.int(i))
    glaml.NodeFloat(f) -> Ok(dynamic.float(f))
    glaml.NodeSeq(l) ->
      list.try_map(l, decode_yaml(_, visited_files)) |> result.map(dynamic.list)
    glaml.NodeMap([#(glaml.NodeStr("import!"), glaml.NodeStr(file))]) -> {
      let resolved_file = case visited_files {
        [] -> file
        [current_file, ..] ->
          filepath.join(filepath.directory_name(current_file), file)
      }

      use _ <- result.try(case list.contains(visited_files, resolved_file) {
        False -> Ok(Nil)
        True -> Error(ImportLoop([resolved_file, ..visited_files]))
      })

      use nodes <- result.try(
        glaml.parse_file(resolved_file) |> result.map_error(YamlError),
      )
      case nodes {
        [] -> Ok(dynamic.nil())
        [glaml.Document(node)] ->
          decode_yaml(node, [resolved_file, ..visited_files])
        nodes ->
          decode_yaml(
            glaml.NodeSeq(
              nodes
              |> list.map(fn(d) { d.root }),
            ),
            [resolved_file, ..visited_files],
          )
      }
    }
    glaml.NodeMap(ml) -> {
      use dlist <- result.try(
        list.try_map(ml, fn(n) {
          let #(key, value) = n
          use key <- result.try(decode_yaml(key, visited_files))
          use value <- result.try(decode_yaml(value, visited_files))
          Ok(#(key, value))
        }),
      )
      Ok(dynamic.properties(dlist))
    }
  }
}

pub fn parse_file(
  f: String,
  decoder: decode.Decoder(a),
) -> Result(List(a), YamlDecodeError) {
  use documents <- result.try(
    glaml.parse_file(f) |> result.map_error(YamlError),
  )

  list.try_map(documents, fn(doc) {
    use d <- result.try(decode_yaml(doc.root, [f]))

    decode.run(d, decoder) |> result.map_error(UnableToDecode)
  })
}

pub fn parse_string(
  s: String,
  decoder: decode.Decoder(a),
) -> Result(List(a), YamlDecodeError) {
  use documents <- result.try(
    glaml.parse_string(s) |> result.map_error(YamlError),
  )

  list.try_map(documents, fn(doc) {
    use d <- result.try(decode_yaml(doc.root, []))

    decode.run(d, decoder) |> result.map_error(UnableToDecode)
  })
}
