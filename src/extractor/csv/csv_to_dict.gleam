import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import glearray
import gsv

// This is a copy of https://github.com/giacomocavalieri/gsv/blob/main/src/gsv.gleam#L318C1-L344C2
// We want to preserve missing/empty values as empty strings.

pub fn csv_to_dicts(
  input: String,
  separator field_separator: String,
) -> Result(List(Dict(String, String)), gsv.Error) {
  use rows <- result.map(gsv.to_lists(input, field_separator))
  case rows {
    [] -> []
    [headers, ..rows] -> {
      let headers = glearray.from_list(headers)

      use row <- list.map(rows)
      use row, field, index <- list.index_fold(row, dict.new())
      // We look for the header corresponding to this field's position.
      case glearray.get(headers, index) {
        Ok(header) -> dict.insert(row, header, field)
        // This could happen if the row has more fields than headers in the
        // header row, in this case the field is just discarded
        Error(_) -> row
      }
    }
  }
}
