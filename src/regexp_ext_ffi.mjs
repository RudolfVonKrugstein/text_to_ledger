import { List } from "./gleam.mjs";
import {Some, None} from "../gleam_stdlib/gleam/option.mjs";
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

export function split_after(regex, string) {
  regex.lastIndex = 0;
  const match = regex.exec(string);
  if (match) {
    const matchEnd = match.index + match[0].length;
    const before = string.slice(0, matchEnd);
    const after = string.slice(matchEnd);
    return new Some([before, after])
  }
  return new None()
}

export function split_before(regex, string) {
  regex.lastIndex = 0;
  const match = regex.exec(string);
  if (match) {
    const matchBegin = match.index;
    const before = string.slice(0, matchBegin);
    const after = string.slice(matchBegin);
    return new Some([before, after])
  }
  return new None()
}
