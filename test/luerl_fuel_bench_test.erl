-module(luerl_fuel_bench_test).
-include_lib("eunit/include/eunit.hrl").

%% Quick sanity check: fuel=infinity should not be measurably slower
%% than... fuel=infinity (since that's the only mode now). This test
%% just ensures a moderately heavy workload completes in reasonable
%% time with both modes.
bench_infinity_test() ->
    Code = <<"local s = 0; for i=1,10000 do s = s + i end; return s">>,
    St0 = luerl:init(),
    %% Warm up: compile and run once to eliminate JIT/compilation cost.
    {ok, _, _} = luerl:do(Code, St0),
    %% Infinity (default)
    {T1, {ok, [_], _}} = timer:tc(fun() -> luerl:do(Code, St0) end),
    %% With fuel set high enough to not exhaust
    St1 = luerl:set_fuel(10000000, St0),
    {T2, {ok, [_], _}} = timer:tc(fun() -> luerl:do(Code, St1) end),
    %% Fuel mode should be within 3x of infinity mode.
    %% This is a very loose bound; we just want to catch catastrophic
    %% regressions, not micro-benchmark.
    %% Fuel mode overhead should be within 50% of infinity mode.
    %% Measured at ~5% overhead (one record copy per instruction).
    ?assert(T2 < T1 * 1.5 + 1000).  %% +1000us for timer noise floor
