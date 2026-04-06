%% Copyright (c) 2013-2020 Robert Virding
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

%% File    : luerl_lib_utf8.erl
%% Author  : Robert Virding
%% Purpose : The utf8 library for Luerl.

-module(luerl_lib_utf8).

-include("luerl.hrl").

?MODULEDOC(false).

-export([install/1,utf8_char/3,codes/3,codepoint/3,utf8_len/3,offset/3]).

-import(luerl_lib, [lua_error/2,badarg_error/3]). %Shorten these

install(St) ->
    luerl_heap:alloc_table(table(), St).

table() ->
    [{<<"char">>,#erl_mfa{m=?MODULE,f=utf8_char}},
     {<<"charpattern">>,<<"[\0-\x7F\xC2-\xF4][\x80-\xBF]*">>},
     {<<"codes">>,#erl_mfa{m=?MODULE,f=codes}},
     {<<"codepoint">>,#erl_mfa{m=?MODULE,f=codepoint}},
     {<<"len">>,#erl_mfa{m=?MODULE,f=utf8_len}},
     {<<"offset">>,#erl_mfa{m=?MODULE,f=offset}}
    ].

%% char(...) -> String.
%%  Receives zero or more integers, converts each one to its
%%  corresponding UTF-8 byte sequence and returns a string with the
%%  concatenation of all these sequences.

utf8_char(_, As, St) ->
    case luerl_lib:args_to_integers(As) of
	Is when is_list(Is) ->
	    case encode_codepoints(Is) of
		{ok,Ss} -> {[Ss],St};
		error -> lua_error(<<"value out of range">>, St)
	    end;
	error -> badarg_error(char, As, St)
    end.

encode_codepoints(Is) ->
    try
	{ok,<< <<I/utf8>> || I <- Is >>}
    catch
	error:badarg -> error
    end.

%% len(...) -> Integer.
%%  Returns the number of UTF-8 characters in string s that start
%%  between positions i and j (both inclusive). The default for i is 1
%%  and for j is -1. If it finds any invalid byte sequence, returns a
%%  false value plus the position of the first invalid byte.

utf8_len(_, [S|_], St) when is_binary(S), byte_size(S) =:= 0 ->
    {[0],St};
utf8_len(_, As, St) ->
    {Str,I,J} = string_args(As, len, St),
    StrLen = byte_size(Str),
    Ret = if I > J -> [0];			%Do the same as Lua
	     true ->
		  Bin = binary_part(Str, I - 1, StrLen - I + 1),
		  case bin_len(Bin, StrLen - J, 0) of
		      {ok,Size} -> [Size];
		      {error,Rest} -> [nil,StrLen - byte_size(Rest) + 1]
		  end
	  end,
    {Ret,St}.

bin_len(Bin, Last, N) when byte_size(Bin) =< Last -> {ok,N};
bin_len(Bin0, Last, N) ->
    try
	<<_/utf8,Bin1/binary>> = Bin0,
	bin_len(Bin1, Last, N+1)
    catch
	_:_ -> {error,Bin0}
    end.

%% codepoint(...) -> [Integer].
%%  Returns the codepoints (as integers) from all characters in s that
%%  start between byte position i and j (both included). The default
%%  for i is 1 and for j is i. It raises an error if it meets any
%%  invalid byte sequence.

codepoint(_, As, St) ->
    {Str,I,J} = string_args(As, codepoint, St),
    StrLen = byte_size(Str),
    Ret = if I > J -> [];			%Do the same as Lua
	     true ->
		  Bin = binary_part(Str, I - 1, StrLen - I + 1),
		  case bin_codepoint(Bin, StrLen - J, []) of
		      {ok,Cps} -> Cps;
		      {error,_} -> badarg_error(codepoint, As, St)
		  end
	  end,
    {Ret,St}.

bin_codepoint(Bin, Last, Cps) when byte_size(Bin) =< Last ->
    {ok,lists:reverse(Cps)};
bin_codepoint(Bin0, Last, Cps) ->
    try
	<<C/utf8,Bin1/binary>> = Bin0,
	bin_codepoint(Bin1, Last, [C|Cps])
    catch
	_:_ -> {error,Bin0}
    end.

%% codes(String) -> [Fun,String,P].

codes(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string]) of
	error -> badarg_error(codes, As, St);
	[Str|_] -> {[#erl_func{code=fun codes_next/2},Str,0],St}
    end.

codes_next([A], St) -> codes_next([A,0], St);
codes_next([Str,P|_], St) when byte_size(Str) =< P -> {[nil],St};
codes_next([Str,P|_], St) when is_binary(Str) ->
    case Str of
	<<_:P/binary,C/utf8,Rest/binary>> ->
	    P1 = byte_size(Str) - byte_size(Rest),
	    {[P1,C],St};
	_ ->
	    lua_error(<<"invalid UTF-8 code">>, St)
    end.

%% offset(String, N [, I]) -> Integer | nil.
%%  Returns the byte position where the encoding of the N-th character
%%  of S starts, counting from position I. A negative N gets characters
%%  before position I.
%%
%%  Default I: 1 when N >= 0, byte_size(S) + 1 when N < 0.
%%
%%  When N == 0: returns the start of the character containing byte I
%%  (walks backward over continuation bytes).

offset(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_integer,lua_integer]) of
	[S,N,I0|_] ->
	    do_offset(S, N, I0, St);
	[S,N] ->
	    I0 = if N >= 0 -> 1; true -> byte_size(S) + 1 end,
	    do_offset(S, N, I0, St);
	_ ->
	    badarg_error(offset, As, St)
    end.

do_offset(S, N, I0, St) ->
    Len = byte_size(S),
    %% Resolve negative positions.
    Posi0 = if I0 >= 0 -> I0;
	       true -> Len + I0 + 1
	    end,
    %% Validate: 1 <= Posi0 <= Len + 1.
    if Posi0 < 1; Posi0 > Len + 1 ->
	    lua_error(<<"position out of range">>, St);
       true -> ok
    end,
    %% Convert to 0-indexed.
    Posi = Posi0 - 1,
    if N =:= 0 ->
	    %% Find beginning of current byte sequence.
	    P1 = cont_back(S, Posi),
	    {[P1 + 1],St};
       true ->
	    %% N /= 0: starting position must not be a continuation byte.
	    case Posi < Len andalso is_cont(S, Posi) of
		true ->
		    lua_error(<<"initial position is a continuation byte">>, St);
		false ->
		    case offset_n(S, Len, Posi, N) of
			nil -> {[nil],St};
			P1 -> {[P1 + 1],St}
		    end
	    end
    end.

%% Walk backward over continuation bytes (0-indexed).
cont_back(_S, 0) -> 0;
cont_back(S, P) ->
    case is_cont(S, P) of
	true -> cont_back(S, P - 1);
	false -> P
    end.

%% Check if byte at 0-indexed position is a continuation byte (10xxxxxx).
is_cont(S, P) ->
    <<_:P/binary,B,_/binary>> = S,
    B band 16#C0 =:= 16#80.

%% offset_n: move N characters from position P (0-indexed).
offset_n(S, Len, P, N) when N > 0 ->
    %% N - 1: do not count character at P.
    offset_fwd(S, Len, P, N - 1);
offset_n(S, _Len, P, N) when N < 0 ->
    offset_back(S, P, N).

%% Move forward N characters.
offset_fwd(_S, _Len, P, 0) -> P;
offset_fwd(_S, Len, P, _N) when P >= Len -> nil;
offset_fwd(S, Len, P, N) ->
    P1 = skip_cont_fwd(S, Len, P + 1),
    offset_fwd(S, Len, P1, N - 1).

skip_cont_fwd(_S, Len, P) when P >= Len -> P;
skip_cont_fwd(S, Len, P) ->
    case is_cont(S, P) of
	true -> skip_cont_fwd(S, Len, P + 1);
	false -> P
    end.

%% Move backward |N| characters.
offset_back(_S, P, 0) -> P;
offset_back(_S, P, _N) when P =< 0 -> nil;
offset_back(S, P, N) ->
    P1 = skip_cont_back(S, P - 1),
    offset_back(S, P1, N + 1).

skip_cont_back(_S, 0) -> 0;
skip_cont_back(S, P) when P > 0 ->
    case is_cont(S, P) of
	true -> skip_cont_back(S, P - 1);
	false -> P
    end;
skip_cont_back(_S, P) -> P.

%% string_args(Args, Op, St) -> {String,I,J}.
%%  Return the string, i and j values from the arguments. Generate a
%%  badarg error on bad values.

string_args(As, Op, St) ->
    %% Get the args.
    Args = luerl_lib:conv_list(As, [lua_string,lua_integer,lua_integer]),
    case Args of			%Cunning here, export A1,A2,A3
	[A1,A2,A3|_] -> ok;
	[A1,A2] -> A3 = byte_size(A1);
	[A1] -> A2 = 1, A3 = byte_size(A1);
	error -> A1 = A2 = A3 = ok, badarg_error(Op, As, St)
    end,
    StrLen = byte_size(A1),
    %% Check args and return Str, I, J.
    Str = A1,
    I = if A2 > 0, A2 =< StrLen -> A2;
	   A2 < 0, A2 >= -StrLen -> StrLen + A2 + 1;
	   true -> badarg_error(Op, As, St)
	end,
    J = if A3 > 0, A3 =< StrLen -> A3;
	   A3 < 0, A3 >= -StrLen -> StrLen + A3 + 1;
	   true -> badarg_error(Op, As, St)
	end,
    {Str,I,J}.
