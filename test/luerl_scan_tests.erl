%% Copyright (C) 2025 Robert Virding, Dave Lucia
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(luerl_scan_tests).

-include_lib("eunit/include/eunit.hrl").

syntax_error_test() ->
    State = luerl:init(),
    ?assertMatch({error, [{1,luerl_scan, {user,"syntax error near '\"'"}}], []}, luerl:do(<<"print(\"hi)">>, State)).

leveled_long_string_partial_close_test() ->
    ?assertMatch(
        {ok, [{'NAME', 1, <<"a">>}, {'=', 1}, {'LITERALSTRING', 1, <<"]=">>}], 2},
        luerl_scan:string("a = [==[]=]==]\n")
    ).

leveled_long_string_nested_equals_test() ->
    ?assertMatch(
        {ok,
         [{'NAME', 1, <<"a">>},
          {'=', 1},
          {'LITERALSTRING', 1, <<"[===[[=[]]=][====[]]===]===">>}],
         2},
        luerl_scan:string("a = [====[[===[[=[]]=][====[]]===]===]====]\n")
    ).

leveled_long_comment_test() ->
    ?assertMatch(
        {ok, [{'NAME', 7, <<"a">>}, {'=', 7}, {'NUMERAL', 7, 1}], 8},
        luerl_scan:string("--[===[\n"
                          "x y z [==[ blu foo\n"
                          "]==\n"
                          "]\n"
                          "]=]==]\n"
                          "error error]=]===]\n"
                          "a = 1\n")
    ).
