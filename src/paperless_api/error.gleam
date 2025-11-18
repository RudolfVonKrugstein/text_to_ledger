import gleam/hackney
import gleam/http/response
import gleam/json
import gleam/string

pub type PaperlessApiError {
  UrlParseError(url: String)
  HttpError(hackney.Error)
  ResponseError(response.Response(String))
  DecodeError(json.DecodeError)
  Simple(String)
}

pub fn string(e: PaperlessApiError) {
  case e {
    UrlParseError(url:) -> "unable to parse url " <> url
    HttpError(err) -> "http error: " <> string.inspect(err)
    ResponseError(resp) -> "unexpected response: " <> string.inspect(resp)
    DecodeError(err) -> "decoding response error: " <> string.inspect(err)
    Simple(err) -> err
  }
}
