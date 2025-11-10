import gleam/dynamic/decode
import gleam/hackney
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import paperless_api/endpoint.{type PaperlessEndpoint}
import paperless_api/models/paged_response

pub type PagedRequest(a) {
  PagedRequest(
    ep: PaperlessEndpoint,
    req: request.Request(String),
    decode: decode.Decoder(a),
  )
}

pub type Error {
  HttpError(hackney.Error)
  ResponseError(response.Response(String))
  DecodeError(json.DecodeError)
  Simple(String)
}

pub fn error_string(e: Error) {
  case e {
    HttpError(err) -> "http error: " <> string.inspect(err)
    ResponseError(resp) -> "unexpected response: " <> string.inspect(resp)
    DecodeError(err) -> "decoding response error: " <> string.inspect(err)
    Simple(err) -> err
  }
}

pub fn new(
  ep: PaperlessEndpoint,
  path: String,
  query: Option(String),
  decode: decode.Decoder(a),
) -> Result(PagedRequest(a), Error) {
  let uri = uri.Uri(..ep.base_url, path: ep.base_url.path <> path, query: query)
  // Prepare a HTTP request record
  use req <- result.try(
    result.map_error(request.from_uri(uri), fn(_) {
      Simple("unable to parse request url: " <> path)
    }),
  )

  Ok(PagedRequest(
    ep: ep,
    req: req |> request.set_header("Authorization", "Token " <> ep.token),
    decode: decode,
  ))
}

pub fn run_request(
  req: PagedRequest(a),
) -> Result(#(List(a), Option(PagedRequest(a))), Error) {
  use resp <- result.try(hackney.send(req.req) |> result.map_error(HttpError))
  use _ <-
    fn(next) {
      case resp.status {
        200 -> next(Nil)
        _ -> Error(ResponseError(resp))
      }
    }
  use dec_resp <- result.try(
    json.parse(resp.body, paged_response.page_response_decoder(req.decode))
    |> result.map_error(DecodeError),
  )
  use next <- result.try(get_next(req, dec_resp))
  Ok(#(dec_resp.results, next))
}

fn remove_prefix(orig: String, prefix: String) {
  case string.starts_with(orig, prefix) {
    False -> orig
    True -> string.drop_start(orig, string.length(prefix))
  }
}

fn next_decoder() -> decode.Decoder(Option(String)) {
  use next <- decode.optional_field(
    "next",
    None,
    decode.optional(decode.string),
  )
  case next {
    Some("") | None -> decode.success(None)
    Some(url) -> decode.success(Some(url))
  }
}

fn get_next(
  last_req: PagedRequest(a),
  resp: paged_response.PageResponse(a),
) -> Result(option.Option(PagedRequest(a)), Error) {
  case resp.next {
    None -> Ok(None)
    Some(url) -> {
      use url <- result.try(
        uri.parse(url)
        |> result.map_error(fn(_nil) {
          Simple("unable to parse next url: " <> url)
        }),
      )
      use new_req <- result.try(new(
        last_req.ep,
        remove_prefix(url.path, last_req.ep.base_url.path),
        url.query,
        last_req.decode,
      ))
      Ok(Some(new_req))
    }
  }
}

pub fn run_all(req: PagedRequest(a)) -> Result(List(a), Error) {
  use #(page, next) <- result.try(run_request(req))
  case next {
    None -> Ok(page)
    Some(next) -> {
      use rest <- result.try(run_all(next))
      Ok(list.flatten([page, rest]))
    }
  }
}
