import gleam/result
import gleam/uri
import paperless_api/error

pub type PaperlessEndpoint {
  PaperlessEndpoint(base_url: uri.Uri, token: String)
}

pub fn parse(url: String, token: String) {
  use uri <- result.try(
    uri.parse(url) |> result.map_error(fn(_) { error.UrlParseError(url) }),
  )
  Ok(PaperlessEndpoint(uri, token))
}
