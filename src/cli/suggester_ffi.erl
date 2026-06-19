-module(suggester_ffi).

-export([run/2]).

%% Run an external "suggester" command.
%%
%% Each {EnvVar, Content} pair in Inputs becomes a temp file holding Content;
%% its path is exposed to the command via the env var EnvVar. We also create
%% one extra temp file for the suggestion output, exposed as
%% T2L_SUGGESTION_FILE.
%%
%% The command inherits the terminal's stdin/stdout/stderr so the user can
%% see progress and debug the script. We return the contents of
%% T2L_SUGGESTION_FILE on success.
run(ArgsList, Inputs) when is_list(ArgsList), is_list(Inputs) ->
    case [unicode:characters_to_list(A) || A <- ArgsList] of
        [] ->
            {error, <<"suggester command is empty">>};
        Args ->
            case make_input_files(Inputs) of
                {error, _} = E ->
                    E;
                {ok, InputFiles} ->
                    SuggestionFile = make_tmp_path("t2l_suggest_out_"),
                    file:write_file(SuggestionFile, <<>>),
                    Env =
                        [{K, P} || {K, P, _} <- InputFiles] ++
                            [{"T2L_SUGGESTION_FILE", SuggestionFile}],
                    print_env(Env),
                    try
                        CmdLine = string:join(
                            [shell_escape(A) || A <- Args], " "
                        ),
                        Port = erlang:open_port({spawn, CmdLine}, [
                            nouse_stdio,
                            exit_status,
                            {env, Env}
                        ]),
                        case wait_for_exit(Port) of
                            ok ->
                                case file:read_file(SuggestionFile) of
                                    {ok, Bin} ->
                                        {ok, Bin};
                                    {error, R} ->
                                        {error,
                                            unicode:characters_to_binary(
                                                io_lib:format(
                                                    "failed to read suggestion file ~ts: ~p",
                                                    [SuggestionFile, R]
                                                )
                                            )}
                                end;
                            {error, _} = Err ->
                                Err
                        end
                    catch
                        Class:Reason ->
                            {error,
                                unicode:characters_to_binary(
                                    io_lib:format("suggester failed: ~p:~p", [
                                        Class, Reason
                                    ])
                                )}
                    after
                        [file:delete(P) || {_, P, _} <- InputFiles],
                        file:delete(SuggestionFile)
                    end
            end
    end.

make_input_files(Inputs) ->
    make_input_files(Inputs, []).

make_input_files([], Acc) ->
    {ok, lists:reverse(Acc)};
make_input_files([{KeyBin, ContentBin} | Rest], Acc) ->
    Key = unicode:characters_to_list(KeyBin),
    Path = make_tmp_path("t2l_suggest_in_"),
    case file:write_file(Path, ContentBin) of
        ok ->
            make_input_files(Rest, [{Key, Path, ContentBin} | Acc]);
        {error, R} ->
            [file:delete(P) || {_, P, _} <- Acc],
            {error,
                unicode:characters_to_binary(
                    io_lib:format("failed to write input file ~ts: ~p", [
                        Path, R
                    ])
                )}
    end.

print_env(Env) ->
    io:format("suggester environment:~n"),
    lists:foreach(
        fun({K, V}) -> io:format("  ~s=~ts~n", [K, V]) end,
        Env
    ).

wait_for_exit(Port) ->
    receive
        {Port, {exit_status, 0}} ->
            ok;
        {Port, {exit_status, N}} ->
            {error,
                unicode:characters_to_binary(
                    io_lib:format("suggester exited with status ~p", [N])
                )};
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
