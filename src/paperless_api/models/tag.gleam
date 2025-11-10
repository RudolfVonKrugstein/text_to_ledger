import gleam/dynamic/decode
import gleam/list
import gleam/option

pub type Tag {
  Tag(name: String, slug: String, id: Int)
}

pub fn tag_decoder() -> decode.Decoder(Tag) {
  use name <- decode.field("name", decode.string)
  use slug <- decode.field("slug", decode.string)
  use id <- decode.field("id", decode.int)
  decode.success(Tag(name:, slug:, id:))
}

pub type TagsResponse {
  TagsResponse(tags: List(Tag))
}

pub fn tags_response_decoder() -> decode.Decoder(TagsResponse) {
  use tags <- decode.field("tags", decode.list(tag_decoder()))
  decode.success(TagsResponse(tags:))
}

pub fn get_tag_by_name(l: List(Tag), name: String) {
  list.first(list.filter(l, fn(t) { t.name == name }))
}

pub fn get_tag_by_slug(l: List(Tag), slug: String) {
  list.first(list.filter(l, fn(t) { t.slug == slug }))
  |> option.from_result
}
