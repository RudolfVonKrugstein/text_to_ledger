//// An `AreaRegex` allows extracting sub areas from a string using
//// recusive "start" and "end" regexes.
////
//// An `AreaRegex` can define a `subarea`, allowing recusivly splitting
//// the document to the desired list of sub areas.
////
//// # Examples
////
//// ```gleam
//// import regex/split_regex
//// import regex/area_regex
////
//// let string = "before begin stuff end begin stuff2 end after"
////
//// let assert Ok(start) = split_regex.compile_after("begin")
//// let assert Ok(end) = split_regex.compile_after("end")
////
//// let re = AreaSplit(start:, end:, subarea: FullArea)
////
//// let areas = area_regex.split(re, string)
//// echo areas
////// [" stuff ", " stuff2 "]
//// ```

import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import regex/split_regex

/// AreaRegex a regex to split areas out of a string.
pub type AreaRegex {
  // Recusivly split of areas.
  AreaSplit(
    // start of the area to split out.
    start: split_regex.SplitRegex,
    // end of the area to split out, if not given the area goes until the next start.
    end: Option(split_regex.SplitRegex),
    // subarea, to further split the split areas.
    subarea: AreaRegex,
  )
  // FullArea, as in just on split. Used to stop the recusion.
  FullArea
}

/// Decode from a dynamic, i.E. in `json.parse`
pub fn decoder() -> decode.Decoder(AreaRegex) {
  use start <- decode.field("start", split_regex.decoder())
  use end <- decode.optional_field(
    "end",
    None,
    decode.optional(split_regex.decoder()),
  )

  use subarea <- decode.optional_field(
    "subarea",
    FullArea,
    decode.optional(decoder()) |> decode.map(option.unwrap(_, FullArea)),
  )

  decode.success(AreaSplit(start:, end:, subarea:))
}

/// split the input `doc` using the are regex.
///
/// # Parameters
///
/// - area: The regex to use for splitting.
/// - doc: The document to split
///
/// # Result
///
/// List of strings, with the split out areas.
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
