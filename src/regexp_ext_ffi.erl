-module(regexp_ext_ffi).

-export([capture_names/2, split_before/2, split_after/2]).

names(Regex) ->
    {namelist, List} = re:inspect(Regex, namelist),
    List.

capture_names(Regex, Subject) ->
    Names = names(Regex),
    case re:run(Subject, Regex, [{capture, Names, list}, global]) of
        {match, Captured} ->
            lists:map(
                fun(X) ->
                    lists:map(
                        fun(S) ->
                            {Name, Value} = S,
                            {named_capture, Name, unicode:characters_to_binary(Value)}
                        end,
                        lists:zip(Names, X)
                    )
                end,
                Captured
            );
        match ->
            [[]];
        nomatch ->
            []
    end.

split_after(Regex, Subject) ->
  case re:run(Subject, Regex, [{capture, first, index}]) of
    {match, [{Start,Len}]} ->
      <<Before:(Start+Len)/binary, After/binary>> = Subject,
      {some, {unicode:characters_to_binary(Before), unicode:characters_to_binary(After)}};
    nomatch -> none
  end.

split_before(Regex, Subject) ->
  case re:run(Subject, Regex, [{capture, first, index}]) of
    {match, [{Start,_}]} ->
      <<Before:(Start)/binary, After/binary>> = Subject,
      {some, {unicode:characters_to_binary(Before), unicode:characters_to_binary(After)}};
    nomatch -> none
  end.
