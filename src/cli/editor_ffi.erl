-module(editor_ffi).

-export([run_editor/2]).

%% Spawn the user's editor on a file and wait for it to exit.
%%
%% We use `open_port` with `nouse_stdio` rather than `os:cmd` so the spawned
%% shell inherits BEAM's fd 0/1/2 (typically the terminal where `gleam run`
%% was launched) instead of having them replaced by capture pipes. The editor
%% therefore drives the terminal directly.
run_editor(EditorBin, FileBin) ->
    Editor = unicode:characters_to_list(EditorBin),
    File = unicode:characters_to_list(FileBin),
    Cmd = Editor ++ " " ++ shell_escape(File),
    try
        Port = erlang:open_port({spawn, Cmd}, [nouse_stdio, exit_status]),
        wait_for_exit(Port)
    catch
        Class:Reason ->
            {error,
                unicode:characters_to_binary(
                    io_lib:format("editor failed: ~p:~p", [Class, Reason])
                )}
    end.

wait_for_exit(Port) ->
    receive
        {Port, {exit_status, 0}} ->
            {ok, nil};
        {Port, {exit_status, N}} ->
            {error,
                unicode:characters_to_binary(
                    io_lib:format("editor exited with status ~p", [N])
                )};
        {'EXIT', Port, Reason} ->
            {error,
                unicode:characters_to_binary(
                    io_lib:format("editor port crashed: ~p", [Reason])
                )}
    end.

shell_escape(S) ->
    "'" ++
        lists:flatmap(
            fun
                ($') -> "'\\''";
                (C) -> [C]
            end,
            S
        ) ++ "'".
