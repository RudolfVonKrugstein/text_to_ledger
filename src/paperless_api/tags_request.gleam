import gleam/list
import gleam/option.{None}
import gleam/result
import paperless_api/endpoint.{type PaperlessEndpoint}
import paperless_api/models/tag
import paperless_api/paged_request.{type Error, type PagedRequest}

pub fn new(endpoint: PaperlessEndpoint) -> Result(PagedRequest(tag.Tag), Error) {
  use req: PagedRequest(tag.Tag) <- result.try(paged_request.new(
    endpoint,
    "/api/tags/",
    None,
    tag.tag_decoder(),
  ))
  Ok(req)
}

pub fn get_tags_by_slugs(
  endpoint: PaperlessEndpoint,
  slugs: List(String),
) -> Result(List(tag.Tag), paged_request.Error) {
  use req <- result.try(new(endpoint))
  use tags <- result.try(paged_request.run_all(req))
  Ok(list.filter(tags, fn(t) { list.contains(slugs, t.slug) }))
}
