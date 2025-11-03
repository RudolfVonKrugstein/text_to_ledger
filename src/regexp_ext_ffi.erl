-module(regexp_ext_ffi).

-export([names/1, capture_names/3]).

names(Regex) ->
  {namelist, List} = re:inspect(Regex, namelist),
  List.

capture_names(Regex, Subject, Names) ->
  case re:run(Subject, Regex, [{capture,Names,list},global]) of
        {match, Captured} -> {some, lists:map(fun(X) -> lists:map(fun(S) -> unicode:characters_to_binary(S) end, X) end, Captured)};
        match -> {some, []};
        nomatch -> {none}
  end.
