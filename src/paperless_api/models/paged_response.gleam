import gleam/dynamic/decode
import gleam/option.{type Option, None}

pub type PageResponse(a) {
  PageResponse(
    count: Int,
    next: Option(String),
    previous: Option(String),
    all: List(Int),
    results: List(a),
  )
}

pub fn page_response_decoder(
  content_decoder: decode.Decoder(a),
) -> decode.Decoder(PageResponse(a)) {
  use count <- decode.field("count", decode.int)
  use next <- decode.optional_field(
    "next",
    None,
    decode.optional(decode.string),
  )
  use previous <- decode.optional_field(
    "previous",
    None,
    decode.optional(decode.string),
  )
  use all <- decode.field("all", decode.list(decode.int))
  use results <- decode.field("results", decode.list(content_decoder))
  decode.success(PageResponse(count:, next:, previous:, all:, results:))
}
