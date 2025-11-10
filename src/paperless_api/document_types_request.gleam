import gleam/list
import gleam/option.{None}
import gleam/result
import paperless_api/endpoint.{type PaperlessEndpoint}
import paperless_api/models/document_type
import paperless_api/paged_request.{type Error, type PagedRequest}

pub fn new(
  endpoint: PaperlessEndpoint,
) -> Result(PagedRequest(document_type.DocumentType), Error) {
  paged_request.new(
    endpoint,
    "/api/document_types/",
    None,
    document_type.document_type_decoder(),
  )
}

pub fn get_document_types_by_slugs(
  endpoint: PaperlessEndpoint,
  slugs: List(String),
) {
  use req <- result.try(new(endpoint))
  use types <- result.try(paged_request.run_all(req))
  Ok(list.filter(types, fn(t) { list.contains(slugs, t.slug) }))
}
