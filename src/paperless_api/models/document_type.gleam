import gleam/dynamic/decode
import gleam/list

pub type DocumentType {
  DocumentType(name: String, slug: String, id: Int)
}

pub fn document_type_decoder() -> decode.Decoder(DocumentType) {
  use name <- decode.field("name", decode.string)
  use slug <- decode.field("slug", decode.string)
  use id <- decode.field("id", decode.int)
  decode.success(DocumentType(name:, slug:, id:))
}

pub type DocumentTypesResponse {
  DocumentTypesResponse(document_types: List(DocumentType))
}

pub fn document_types_response_decoder() -> decode.Decoder(
  DocumentTypesResponse,
) {
  use document_types <- decode.field(
    "document_types",
    decode.list(document_type_decoder()),
  )
  decode.success(DocumentTypesResponse(document_types:))
}

pub fn get_document_type_by_slug(l: List(DocumentType), slug: String) {
  list.first(list.filter(l, fn(t) { t.slug == slug }))
}
