import gleam/dynamic/decode
import gleam/option

pub type Document {
  DocumentType(
    id: Int,
    correspondent: option.Option(Int),
    document_type: option.Option(Int),
    title: String,
    content: String,
    tags: List(Int),
  )
}

pub fn document_decoder() -> decode.Decoder(Document) {
  use id <- decode.field("id", decode.int)
  use correspondent <- decode.field(
    "correspondent",
    decode.optional(decode.int),
  )
  use document_type <- decode.field(
    "document_type",
    decode.optional(decode.int),
  )
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  use tags <- decode.field("tags", decode.list(decode.int))
  decode.success(DocumentType(
    id:,
    correspondent:,
    document_type:,
    title:,
    content:,
    tags:,
  ))
}
// pub type DocumentsResponse {
//   DocumentsResponse(documents: List(Document))
// }
//
// pub fn documents_response_decoder() -> decode.Decoder(DocumentsResponse) {
//   use documents <- decode.field("documents", decode.list(document_decoder()))
//   decode.success(DocumentsResponse(documents:))
// }
