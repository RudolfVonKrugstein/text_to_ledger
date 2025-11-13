import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import regex/split_regex

pub type AreaRegex {
  AreaSplit(
    start: split_regex.SplitRegex,
    end: Option(split_regex.SplitRegex),
    subarea: AreaRegex,
  )
  FullArea
}

pub fn area_regex_decoder() -> decode.Decoder(AreaRegex) {
  use start <- decode.field("start", split_regex.split_regex_decoder())
  use end <- decode.optional_field(
    "end",
    None,
    decode.optional(split_regex.split_regex_decoder()),
  )

  use subarea <- decode.then(area_regex_optional_field_decoder("subarea"))

  decode.success(AreaSplit(start:, end:, subarea:))
}

pub fn area_regex_optional_field_decoder(field: String) {
  use subarea <- decode.optional_field(
    field,
    None,
    decode.optional(area_regex_decoder()),
  )
  case subarea {
    None -> decode.success(FullArea)
    Some(a) -> decode.success(a)
  }
}

pub fn split(area: AreaRegex, doc: String) {
  case area {
    FullArea -> [doc]
    AreaSplit(start, end, subarea) -> {
      let areas =
        split_regex.split_all(start, doc)
        |> list.drop(1)
        |> list.map(fn(begining) {
          case end |> option.then(split_regex.split(_, begining)) {
            None -> begining
            Some(#(begining, _)) -> begining
          }
        })

      areas |> list.map(split(subarea, _)) |> list.flatten
    }
  }
}
