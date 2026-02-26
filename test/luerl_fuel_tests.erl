%% Copyright (c) 2026 Robert Virding
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

%% File    : luerl_fuel_tests.erl
%% Purpose : Tests for instruction fuel metering.

-module(luerl_fuel_tests).

-include_lib("eunit/include/eunit.hrl").

%% Default fuel is infinity.
default_fuel_test() ->
    St = luerl:init(),
    ?assertEqual(infinity, luerl:get_fuel(St)).

%% Setting and getting fuel.
set_get_fuel_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(1000, St0),
    ?assertEqual(1000, luerl:get_fuel(St1)),
    St2 = luerl:set_fuel(infinity, St1),
    ?assertEqual(infinity, luerl:get_fuel(St2)).

%% Zero fuel raises immediately.
zero_fuel_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(0, St0),
    ?assertMatch({lua_error, out_of_fuel, _}, luerl:do(<<"return 1">>, St1)).

%% Simple expression succeeds with sufficient fuel.
sufficient_fuel_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(1000, St0),
    ?assertMatch({ok, [42], _}, luerl:do(<<"return 42">>, St1)).

%% Fuel is consumed: remaining fuel is less than initial.
fuel_consumed_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(10000, St0),
    {ok, _, St2} = luerl:do(<<"return 1 + 2">>, St1),
    Remaining = luerl:get_fuel(St2),
    ?assert(Remaining < 10000),
    ?assert(Remaining > 0).

%% Infinite loop is stopped by fuel limit.
infinite_loop_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(10000, St0),
    ?assertMatch({lua_error, out_of_fuel, _},
		 luerl:do(<<"while true do end">>, St1)).

%% More iterations consume more fuel.
fuel_proportional_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(100000, St0),
    {ok, _, St2} = luerl:do(<<"local s = 0; for i=1,10 do s = s + i end; return s">>, St1),
    Fuel10 = luerl:get_fuel(St2),
    St3 = luerl:set_fuel(100000, St0),
    {ok, _, St4} = luerl:do(<<"local s = 0; for i=1,100 do s = s + i end; return s">>, St3),
    Fuel100 = luerl:get_fuel(St4),
    %% 100 iterations should consume more fuel than 10.
    ?assert(Fuel10 > Fuel100).

%% Fuel exhaustion mid-loop: loop starts but doesn't finish.
partial_loop_test() ->
    %% First, measure fuel needed for 10 iterations.
    St0 = luerl:init(),
    St1 = luerl:set_fuel(100000, St0),
    {ok, _, St2} = luerl:do(<<"local s = 0; for i=1,10 do s = s + i end; return s">>, St1),
    FuelFor10 = 100000 - luerl:get_fuel(St2),
    %% Now try 1000 iterations with only enough fuel for ~10.
    %% Should run out.
    St3 = luerl:set_fuel(FuelFor10, St0),
    ?assertMatch({lua_error, out_of_fuel, _},
		 luerl:do(<<"local s = 0; for i=1,1000 do s = s + i end; return s">>, St3)).

%% Fuel with pcall: out_of_fuel is NOT catchable by pcall.
%% This is important: fuel exhaustion is a hard limit, not a Lua error
%% that scripts can swallow. pcall re-raises it.
fuel_not_pcall_catchable_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(10000, St0),
    ?assertMatch({lua_error, out_of_fuel, _},
		 luerl:do(<<"return pcall(function() while true do end end)">>, St1)).

%% Nested pcall also cannot catch fuel exhaustion.
fuel_not_nested_pcall_catchable_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(10000, St0),
    ?assertMatch({lua_error, out_of_fuel, _},
		 luerl:do(<<"return pcall(function()\n"
			    "  return pcall(function()\n"
			    "    while true do end\n"
			    "  end)\n"
			    "end)">>, St1)).

%% Infinity fuel means no limit (standard behaviour).
infinity_no_limit_test() ->
    St0 = luerl:init(),
    St1 = luerl:set_fuel(infinity, St0),
    {ok, [5050], _St2} =
	luerl:do(<<"local s = 0; for i=1,100 do s = s + i end; return s">>, St1),
    ok.

%% set_fuel validates input.
set_fuel_validation_test() ->
    St = luerl:init(),
    ?assertException(error, function_clause, luerl:set_fuel(-1, St)),
    ?assertException(error, function_clause, luerl:set_fuel(foo, St)).
