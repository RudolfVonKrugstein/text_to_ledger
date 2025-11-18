import gleam/http/request
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import paperless_api/endpoint.{type PaperlessEndpoint}
import paperless_api/error
import paperless_api/models/document
import paperless_api/models/document_type
import paperless_api/models/tag
import paperless_api/paged_request.{type PagedRequest, PagedRequest}

pub fn new(
  ep: PaperlessEndpoint,
) -> Result(PagedRequest(document.Document), error.PaperlessApiError) {
  paged_request.new(ep, "/api/documents/", None, document.document_decoder())
}

pub fn set_tag_filter(
  req: PagedRequest(document.Document),
  tags: List(tag.Tag),
) -> PagedRequest(document.Document) {
  let new_para =
    "tags__id__all="
    <> string.join(list.map(tags, fn(tag) { int.to_string(tag.id) }), ",")
  let new_query = case req.req.query {
    None -> new_para
    Some(q) -> q <> "&" <> new_para
  }
  PagedRequest(..req, req: request.Request(..req.req, query: Some(new_query)))
}

pub fn set_not_tag_filter(
  req: PagedRequest(document.Document),
  tags: List(tag.Tag),
) -> PagedRequest(document.Document) {
  let new_para =
    "tags__id__none="
    <> string.join(list.map(tags, fn(tag) { int.to_string(tag.id) }), ",")
  let new_query = case req.req.query {
    None -> new_para
    Some(q) -> q <> "&" <> new_para
  }
  PagedRequest(..req, req: request.Request(..req.req, query: Some(new_query)))
}

pub fn set_document_type_filter(
  req: PagedRequest(document.Document),
  ts: List(document_type.DocumentType),
) -> PagedRequest(document.Document) {
  let new_para =
    "document_type__id__in="
    <> string.join(list.map(ts, fn(t) { int.to_string(t.id) }), ",")
  let new_query = case req.req.query {
    None -> new_para
    Some(q) -> q <> "&" <> new_para
  }
  PagedRequest(..req, req: request.Request(..req.req, query: Some(new_query)))
}
