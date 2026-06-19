-module(suggester_ffi).

-export([run/2]).

%% Run an external command with `Input` written to its stdin and capture
%% stdout (plus stderr). The command is provided as a non-empty list of
%% binaries (program followed by its arguments).
%%
%% We materialise the input as a temp file and redirect stdin through the
%% shell instead of trying to half-close the Erlang port's stdin pipe.
run(ArgsList, Input) when is_list(ArgsList), is_binary(Input) ->
    case [unicode:characters_to_list(A) || A <- ArgsList] of
        [] ->
            {error, <<"suggester command is empty">>};
        [Cmd | Rest] ->
            TmpFile = make_tmp_path("t2l_suggest_in_"),
            case file:write_file(TmpFile, Input) of
                {error, Reason} ->
                    {error,
                        unicode:characters_to_binary(
                            io_lib:format("failed to write tmp file ~ts: ~p", [
                                TmpFile, Reason
                            ])
                        )};
                ok ->
                    try
                        CmdLine =
                            shell_escape(Cmd) ++
                                " " ++ string:join(
                                    [shell_escape(A) || A <- Rest], " "
                                ) ++
                                " < " ++ shell_escape(TmpFile),
                        %% Let stderr pass through to the user's terminal so
                        %% they see Ollama's progress spinner / errors live,
                        %% while we capture only stdout (the model output).
                        %% TERM=dumb discourages CLIs that still draw escape
                        %% sequences to stdout from doing so.
                        Port = erlang:open_port({spawn, CmdLine}, [
                            binary,
                            use_stdio,
                            exit_status,
                            hide,
                            {env, [{"TERM", "dumb"}]}
                        ]),
                        collect(Port, <<>>)
                    catch
                        Class:Reason ->
                            {error,
                                unicode:characters_to_binary(
                                    io_lib:format("suggester failed: ~p:~p", [
                                        Class, Reason
                                    ])
                                )}
                    after
                        file:delete(TmpFile)
                    end
            end
    end.

collect(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            {ok, Acc};
        {Port, {exit_status, N}} ->
            Header = unicode:characters_to_binary(
                io_lib:format("suggester exited with status ~p:\n", [N])
            ),
            {error, <<Header/binary, Acc/binary>>};
        {'EXIT', Port, Reason} ->
            {error,
                unicode:characters_to_binary(
                    io_lib:format("suggester port crashed: ~p", [Reason])
                )}
    end.

make_tmp_path(Prefix) ->
    TmpDir =
        case os:getenv("TMPDIR") of
            false -> "/tmp";
            T -> T
        end,
    Stamp = integer_to_list(erlang:phash2({make_ref(), erlang:monotonic_time()})),
    filename:join(TmpDir, Prefix ++ Stamp).

shell_escape(S) when is_list(S) ->
    "'" ++
        lists:flatmap(
            fun
                ($') -> "'\\''";
                (C) -> [C]
            end,
            S
        ) ++ "'".
