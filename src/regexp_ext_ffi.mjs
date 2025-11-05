import { List } from "./gleam.mjs";
import { NamedCapture as RegexNamedCapture } from "./regexp_ext/regexp_ext.mjs";

export function capture_names(regex, string, names) {
  regex.lastIndex = 0;
  const matches = Array.from(string.matchAll(regex)).map((match) => {
    if (match.groups !== undefined) {
      return List.fromArray(
        Object.entries(match.groups).map(([key, value]) => {
          return new RegexNamedCapture(key, value);
        }),
      );
    } else {
      return List.fromArray([]);
    }
  });
  return List.fromArray(matches);
}
