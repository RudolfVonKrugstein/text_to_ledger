import gleam/result
import gleam/uri

pub type PaperlessEndpoint {
  PaperlessEndpoint(base_url: uri.Uri, token: String)
}

pub fn parse(url: String, token: String) {
  use uri <- result.try(
    uri.parse(url) |> result.map_error(fn(_) { "unable to parse " <> url }),
  )
  Ok(PaperlessEndpoint(uri, token))
}

