-module(regexp_ext_ffi).

-export([capture_names/2]).

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
