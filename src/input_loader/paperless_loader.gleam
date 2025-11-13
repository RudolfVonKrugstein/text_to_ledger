import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import input_loader/input_file.{type InputFile}
import input_loader/input_loader.{type InputLoader, InputLoader}
import paperless_api/document_types_request
import paperless_api/documents_request
import paperless_api/endpoint
import paperless_api/models/document
import paperless_api/paged_request
import paperless_api/tags_request

fn next_impl(
  loader_name: String,
  page: List(document.Document),
  next_req: Option(paged_request.PagedRequest(document.Document)),
) -> Result(Option(#(InputFile, InputLoader)), String) {
  case page, next_req {
    [], None -> {
      Ok(None)
    }
    [], Some(next_req) -> {
      use #(page, next_req) <- result.try(
        paged_request.run_request(next_req)
        |> result.map_error(paged_request.error_string),
      )
      next_impl(loader_name, page, next_req)
    }
    [a, ..rest], _ -> {
      Ok(
        Some(#(
          input_file.InputFile(
            loader_name,
            int.to_string(a.id),
            a.title,
            a.content,
          ),
          InputLoader(fn() { next_impl(loader_name, rest, next_req) }),
        )),
      )
    }
  }
}

pub fn new(
  name: String,
  url: String,
  token: String,
  allowed_tags: List(String),
  forbidden_tags: List(String),
  document_types: List(String),
) -> Result(InputLoader, String) {
  use endpoint <- result.try(endpoint.parse(url, token))

  use allowed_tags <- result.try(
    tags_request.get_tags_by_slugs(endpoint, allowed_tags)
    |> result.map_error(paged_request.error_string),
  )
  use forbidden_tags <- result.try(
    tags_request.get_tags_by_slugs(endpoint, forbidden_tags)
    |> result.map_error(paged_request.error_string),
  )
  use doc_types <- result.try(
    document_types_request.get_document_types_by_slugs(endpoint, document_types)
    |> result.map_error(paged_request.error_string),
  )

  use doc_req <- result.try(
    documents_request.new(endpoint)
    |> result.map_error(paged_request.error_string),
  )

  let doc_req =
    doc_req
    |> documents_request.set_document_type_filter(doc_types)
    |> documents_request.set_tag_filter(allowed_tags)
    |> documents_request.set_not_tag_filter(forbidden_tags)

  Ok(InputLoader(fn() { next_impl(name, [], Some(doc_req)) }))
}
