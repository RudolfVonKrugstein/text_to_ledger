-module(yaml_dynamic_ffi).

-include_lib("yamerl/include/yamerl_errors.hrl").

-export([parse_string_dynamic/1, parse_file_dynamic/1]).

parse_file_dynamic(Path) ->
    try
        Docs = map_yamerl_docs_dynamic(yamerl_constr:file(Path, [{detailed_constr, true}])),
        {ok, Docs}
    catch
        throw:#yamerl_exception{errors = [First | _]} ->
            {error, map_yamerl_error(First)};
        error:_ ->
            {error, {yaml_error, unexpected_parsing_error}}
    end.

parse_string_dynamic(String) ->
    try
        Docs = map_yamerl_docs_dynamic(yamerl_constr:string(String, [{detailed_constr, true}])),
        {ok, Docs}
    catch
        throw:#yamerl_exception{errors = [First | _]} ->
            {error, map_yamerl_error(First)};
        error:_ ->
            {error, {yaml_error, unexpected_parsing_error}}
    end.

map_yamerl_error(Error) ->
    case Error of
        #yamerl_parsing_error{text = undefined} ->
            {yaml_error, unexpected_parsing_error};

        #yamerl_parsing_error{text = Message, line = undefined, column = undefined} ->
           {yaml_error, unicode:characters_to_binary(Message), {0, 0}};

        #yamerl_parsing_error{text = Message, line = Line, column = Col} ->
            {yaml_error, unicode:characters_to_binary(Message), {Line, Col}};

        #yamerl_invalid_option{text = undefined} ->
            {yaml_error, unexpected_parsing_error};

        #yamerl_invalid_option{text = Message} ->
            {yaml_error, unicode:characters_to_binary(Message), {0, 0}}
    end.

map_yamerl_docs_dynamic(Documents) ->
    lists:map(fun map_yamerl_doc_dynamic/1, Documents).

map_yamerl_doc_dynamic(Document) ->
    {yamerl_doc, RootNode} = Document,
    map_yamerl_node_dynamic(RootNode).

map_yamerl_node_dynamic(Node) ->
    case Node of
        {yamerl_null, _, _Tag, _Loc} ->
            nil;

        {yamerl_str, _, _Tag, _Loc, String} ->
            unicode:characters_to_binary(String);

        {yamerl_bool, _, _Tag, _Loc, Bool} when is_boolean(Bool) ->
            Bool;

        {yamerl_int, _, _Tag, _Loc, Int} when is_integer(Int) ->
            Int;

        {yamerl_float, _, _Tag, _Loc, Float} when is_float(Float) ->
            Float;

        {yamerl_seq, _, _Tag, _Loc, Nodes, _Count} when is_list(Nodes) ->
            lists:map(fun map_yamerl_node_dynamic/1, Nodes);

        {yamerl_map, _, _Tag, _Loc, Pairs} when is_list(Pairs) ->
            maps:from_list(map_yamerl_map_dynamic(Pairs))
    end.

map_yamerl_map_dynamic(Pairs) ->
    F = fun({Key, Value}) ->
        {map_yamerl_node_dynamic(Key), map_yamerl_node_dynamic(Value)}
    end,
    lists:map(F, Pairs).
