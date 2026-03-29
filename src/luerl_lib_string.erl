%% Copyright (c) 2013-2025 Robert Virding
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

%% File    : luerl_lib_string.erl
%% Author  : Robert Virding
%% Purpose : The string library for Luerl.

-module(luerl_lib_string).

-include("luerl.hrl").

?MODULEDOC(false).

%% The basic entry point to set up the function table.
-export([install/1,byte/3,char/3,dump/3,find/3,format/3,gmatch/3,gsub/3,len/3,lower/3,
         match/3,pack/3,packsize/3,rep/3,reverse/3,sub/3,unpack/3,upper/3]).

%% Export some test functions.
-export([test_gsub/3,test_match_pat/3,test_pat/1,
	 test_byte/3,test_do_find/4,test_sub/2,test_sub/3]).

-import(luerl_lib, [lua_error/2,badarg_error/3]).	%Shorten this

%%-compile([bin_opt_info]).			%For when we are optimising

install(St0) ->
    {T,St1} = luerl_heap:alloc_table(table(), St0),
    {M,St2} = luerl_heap:alloc_table(metatable(T), St1),
    Meta0 = St2#luerl.meta,
    Meta1 = Meta0#meta{string=M},
    {T,St2#luerl{meta=Meta1}}.

%% metatable(Table) -> [{TableName,Table}].
%% table() -> [{FuncName,Function}].

metatable(T) ->					%String type metatable
    [{<<"__index">>,T}].

table() ->					%String table
    [{<<"byte">>,#erl_mfa{m=?MODULE,f=byte}},
     {<<"char">>,#erl_mfa{m=?MODULE,f=char}},
     {<<"dump">>,#erl_mfa{m=?MODULE,f=dump}},
     {<<"find">>,#erl_mfa{m=?MODULE,f=find}},
     {<<"format">>,#erl_mfa{m=?MODULE,f=format}},
     {<<"gmatch">>,#erl_mfa{m=?MODULE,f=gmatch}},
     {<<"gsub">>,#erl_mfa{m=?MODULE,f=gsub}},
     {<<"len">>,#erl_mfa{m=?MODULE,f=len}},
     {<<"lower">>,#erl_mfa{m=?MODULE,f=lower}},
     {<<"pack">>,#erl_mfa{m=?MODULE,f=pack}},
     {<<"packsize">>,#erl_mfa{m=?MODULE,f=packsize}},
     {<<"match">>,#erl_mfa{m=?MODULE,f=match}},
     {<<"rep">>,#erl_mfa{m=?MODULE,f=rep}},
     {<<"reverse">>,#erl_mfa{m=?MODULE,f=reverse}},
     {<<"sub">>,#erl_mfa{m=?MODULE,f=sub}},
     {<<"unpack">>,#erl_mfa{m=?MODULE,f=unpack}},
     {<<"upper">>,#erl_mfa{m=?MODULE,f=upper}}
    ].

%% byte(String [, I [, J]] ) -> [Code]
%%  Return numerical codes of string between I and J.

byte(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_integer,lua_integer]) of
	[S|Is] ->
	    Bs = do_byte(S, byte_size(S), Is),
	    {Bs,St};
	_ -> badarg_error(byte, As, St)		%nil or []
    end.

test_byte(S, I, J) ->
    do_byte(S, byte_size(S), I, J).

do_byte(_, 0, _) -> [nil];
do_byte(S, Len, []) -> do_byte(S, Len, 1, 1);
do_byte(S, Len, [I]) -> do_byte(S, Len, I, I);
do_byte(S, Len, [I,J]) -> do_byte(S, Len, I, J).

do_byte(S, Len, I0, J0) ->			%The same as for sub
    I1 = do_sub_m(Len, I0),
    J1 = do_sub_m(Len, J0),
    do_byte_ij(S, Len, I1, J1).

do_byte_ij(S, Len, I, J) when I < 1 -> do_byte_ij(S, Len, 1, J);
do_byte_ij(S, Len, I, J) when J > Len -> do_byte_ij(S, Len, I, Len);
do_byte_ij(_, _, I, J) when I > J -> [nil];
do_byte_ij(S, _, I, J) ->
    [ N || N <- binary_to_list(S, I, J) ].

%% char(...) -> String
%%  Return string of the numerical arguments.

char(_, [nil], St) -> {[<<>>],St};
char(_, As, St) ->
    case luerl_lib:args_to_integers(As) of
	error -> badarg_error(char, As, St);
	Bs ->
            %% Errors here also become lua_error.
            try
                String = list_to_binary(Bs),
                {[String],St}
            catch
                _:_ ->
                    badarg_error(char, As, St)
            end
    end.

%% dump(Function) -> String.
%%  Return a string with binary representation of Function.

-spec dump(_, [_], _) -> no_return().

dump(_, As, St) -> badarg_error(dump, As, St).

%% find(String, Pattern [, Init [, Plain]]) -> [Indice].
%%  Return first occurrence of Pattern in String.

find(_, As, St0) ->
    try
	do_find(As, St0)
    catch
	throw:{error,E,St1} -> lua_error(E, St1);
	throw:{error,E} -> lua_error(E, St0)
    end.

do_find([A1,A2], St) -> do_find([A1,A2,1.0], St);
do_find([A1,A2,A3], St) -> do_find([A1,A2,A3,nil], St);
do_find(As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_string,lua_integer,lua_bool]) of
	[S,P,I,Pl] -> {do_find(S, byte_size(S), P, I, Pl),St};
	_ -> throw({error,{badarg,find,As},St})	%nil, [_] or []
    end.

test_do_find(S, Pat, I, Pl) -> do_find(S, byte_size(S), Pat, I, Pl).

%% do_find(String, Length, Pattern, Start, Plain) -> [Return].
%% Adjust the starting index and find the string.

do_find(_, L, _, I, _) when I > L+1 -> [nil];
do_find(S, L, Pat, I, Pl) when I < -L -> do_find(S, L, Pat, 1, Pl);
do_find(S, L, Pat, I, Pl) when I < 0 -> do_find(S, L, Pat, L+I+1, Pl);
do_find(S, L, Pat, 0, Pl) ->  do_find(S, L, Pat, 1, Pl);
do_find(S, L, Pat, I, true) ->			%Plain text search string
    case binary:match(S, Pat, [{scope,{I-1,L-I+1}}]) of
	{Fs,Fl} -> [Fs+1,Fs+Fl];
	nomatch -> [nil]
    end;
do_find(S, L, Pat0, I, false) ->		%Pattern search string
    case pat(binary_to_list(Pat0)) of
	{ok,{Pat1,_},_} ->
	    L1 = L - I + 1,			%Length of substring
	    S1 = binary_part(S, I-1, L1),	%Start searching from I
	    case match_loop(S1, L1, Pat1, 1, {S, I-1}) of
		[{_,P,Len}|Cas] ->		%Matches
		    P1 = P + I - 1,		%Position in original string
		    [P1,P1+Len-1|match_caps(Cas, S, I)];
		[] -> [nil]			%No match
	    end;
	{error,E} -> throw({error,E})
    end.

%% format([Format|Args], State) -> {[String],State}.
%%  Format a string. All errors are badarg errors.
%%  Do all the work in luerl_string_format but generate errors here.

format(_, [F|As], St0) ->
    try
	%% io:format("format ~w\n", [element(1,luerl_lib_string_format:format(F, As, St0))]),
	luerl_lib_string_format:format(F, As, St0)
    catch
	%% If we have no specific error, default is badarg.
	throw:{error,E,St1} -> lua_error(E, St1);
	throw:{error,E} -> lua_error(E, St0);
	_:_ -> badarg_error(format, [F|As], St0)
        %% ?CATCH(C, E, Stack)
        %%     error({C,E,Stack})
    end;
format(_, As, St) -> badarg_error(format, As, St).

%% gmatch(String, Pattern) -> [Function].
%%  Returns an iterator function that, each time it is called, returns
%%  the next captures from pattern over string s. If pattern has no
%%  captures, the whole match is returned.
%%
%%  Implementation: pre-compute all matches using gsub_match_loop/6,
%%  store the match list in the luerl private state under a unique
%%  ref, and return an erl_func iterator that pops matches on each
%%  call.

gmatch(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_string]) of
	[S,P] ->
	    do_gmatch(S, P, St);
	_ -> badarg_error(gmatch, As, St)
    end.

do_gmatch(S, P, St0) ->
    case pat(binary_to_list(P)) of
	{ok,{Pat,_},_} ->
	    L = byte_size(S),
	    Matches = gsub_match_loop(S, L, Pat, 1, 1, all, {S, 0}),
	    %% Store the match state in private data.
	    Ref = make_ref(),
	    St1 = luerl:put_private(Ref, {Matches, S}, St0),
	    %% Build the iterator function.
	    Iter = #erl_func{code=fun(_, St2) ->
		case luerl:get_private(Ref, St2) of
		    {[], _} ->
			St3 = luerl:delete_private(Ref, St2),
			{[nil], St3};
		    {[Cas|Rest], S1} ->
			St3 = luerl:put_private(Ref, {Rest, S1}, St2),
			Vals = gmatch_vals(Cas, S1),
			{Vals, St3}
		end
	    end},
	    {[Iter], St1};
	{error,E} -> lua_error(E, St0)
    end.

%% gmatch_vals(Captures, String) -> [Values].
%%  Extract the match values from a capture list.
%%  If there are explicit captures (length > 1), return only the
%%  sub-captures (skip the whole-match entry at the head).
%%  If no explicit captures, return the whole match.

gmatch_vals([Ca], S) ->
    [match_cap(Ca, S)];
gmatch_vals([_Ca|Cas], S) ->
    match_caps(Cas, S).

%% gsub(String, Pattern, Repl [, N]) -> [String]

gsub(_, As, St0) ->
    try
	do_gsub(As, St0)
    catch
	throw:{error,E,St1} -> lua_error(E, St1);
	throw:{error,E} -> lua_error(E, St0)
    end.

do_gsub(As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_string,lua_any,lua_integer]) of
	[S,P,R,N] when N > 0 ->
	    do_gsub(S, byte_size(S), P, R, N, St);
	[S,P,R] ->				%'all' bigger than any number
	    do_gsub(S, byte_size(S), P, R, all, St);
	_ -> throw({error,{badarg,gsub,As},St})
    end.

test_gsub(S, P, N) ->
    {ok,{Pat,_},_} = pat(binary_to_list(P)),
    gsub_match_loop(S, byte_size(S), Pat, 1, 1, N, {S, 0}).

do_gsub(S, L, Pat0, R, N, St0) ->
    case pat(binary_to_list(Pat0)) of
	{ok,{Pat1,_},_} ->
	    Fs = gsub_match_loop(S, L, Pat1, 1, 1, N, {S, 0}),
	    {Ps,St1} = gsub_repl_loop(Fs, S, 1, L, R, St0),
	    {[iolist_to_binary(Ps),length(Fs)],St1};
	{error,E} -> throw({error,E})
    end.

%% gsub_match_loop(S, L, Pat, I, C, N, Orig) -> [Cas].
%%  Return the list of Cas's for each match.
%%  Implements Lua 5.3.3 empty match semantics: after a match ending
%%  at position E, a subsequent match at the same position E is
%%  rejected (the character is skipped without matching).

gsub_match_loop(S, L, Pat, I, C, N, Orig) ->
    gsub_match_loop(S, L, Pat, I, C, N, Orig, none).

gsub_match_loop(_, _, _, _, C, N, _Orig, _LastMatch) when C > N -> [];
gsub_match_loop(<<>>, _, Pat, I, _, _, Orig, LastMatch) ->
    case match_pat(<<>>, Pat, I, Orig) of
	{match,_Cas,_,I} when I =:= LastMatch -> [];  %Reject: same as last
	{match,Cas,_,_} -> [Cas];
	nomatch -> []
    end;
gsub_match_loop(S0, L, Pat, I0, C, N, Orig, LastMatch) ->
    case match_pat(S0, Pat, I0, Orig) of
	{match,_Cas,_,I0} when I0 =:= LastMatch ->
	    %% Match at same position as last match end: reject, skip char.
	    S1 = binary_part(S0, 1, L-I0),
	    gsub_match_loop(S1, L, Pat, I0+1, C, N, Orig, LastMatch);
	{match,Cas,_,I0} ->			%Zero length match
	    S1 = binary_part(S0, 1, L-I0),
	    [Cas|gsub_match_loop(S1, L, Pat, I0+1, C+1, N, Orig, I0)];
	{match,Cas,S1,I1} ->
	    [Cas|gsub_match_loop(S1, L, Pat, I1, C+1, N, Orig, I1)];
	nomatch ->
	    S1 = binary_part(S0, 1, L-I0),
	    gsub_match_loop(S1, L, Pat, I0+1, C, N, Orig, LastMatch)
    end.

%% gsub_repl_loop([Cas], String, Index, Length, Reply, State) ->
%%     {iolist,State}.
%%  Build the return string as an iolist processing each match and
%%  filling in with the original string.

gsub_repl_loop([[{_,F,Len}|_]=Cas|Fs], S, I, L, R, St0) ->
    %% io:fwrite("grl: ~p\n", [{Cas,S,R}]),
    {Rep,St1} = gsub_repl(Cas, S, R, St0),
    %% io:fwrite("grl->~p\n", [{Rep}]),
    {Ps,St2} = gsub_repl_loop(Fs, S, F+Len, L, R, St1),
    {[binary_part(S, I-1, F-I),Rep|Ps],St2};
gsub_repl_loop([], S, I, L, _, St) ->
    {[binary_part(S, I-1, L-I+1)],St}.

gsub_repl(Cas, S, #tref{}=T, St0) ->
    case Cas of					%Export both Ca and Key
	[Ca] -> Key = match_cap(Ca, S);
	[Ca,Ca1|_] -> Key = match_cap(Ca1, S)
    end,
    {R,St1} = luerl_emul:get_table_key(T, Key, St0),
    {[gsub_repl_val(S, R, Ca)],St1};
gsub_repl(Cas0, S, Repl, St0) when ?IS_FUNCTION(Repl) ->
    case Cas0 of				%Export both Ca and Args
	[Ca] -> Args = [match_cap(Ca, S)];
	[Ca|Cas] -> Args = match_caps(Cas, S)
    end,
    {Rs,St1} = luerl_emul:functioncall(Repl, Args, St0),
    {[gsub_repl_val(S, luerl_lib:first_value(Rs), Ca)],St1};
gsub_repl(Cas, S, Repl, St) ->			%Replace string
    case luerl_lib:arg_to_list(Repl) of
	error -> {[],St};
	R -> {gsub_repl_str(Cas, S, R),St}
    end.

gsub_repl_str(Cas, S, [$%,$%|R]) ->
    [$%|gsub_repl_str(Cas, S, R)];
gsub_repl_str(Cas, S, [$%,$0|R]) ->
    Cstr = luerl_lib:arg_to_string(match_cap(hd(Cas), S)), %Force to string!
    [Cstr|gsub_repl_str(Cas, S, R)];
gsub_repl_str(Cas, S, [$%,C|R]) when C >= $1, C =< $9 ->
    case lists:keysearch(C-$0, 1, Cas) of
	{value,Ca} ->
	    Cstr = luerl_lib:arg_to_string(match_cap(Ca, S)), %Force to string!
	    [Cstr|gsub_repl_str(Cas, S, R)];
	false ->
	    %% Lua 5.3: when pattern has no explicit captures,
	    %% %1 refers to the whole match (implicit capture).
	    %% Only %1 gets this treatment; %2+ is always invalid.
	    case {C - $0, Cas} of
		{1, [{0,_,_}=Ca]} ->
		    Cstr = luerl_lib:arg_to_string(match_cap(Ca, S)),
		    [Cstr|gsub_repl_str(Cas, S, R)];
		_ -> throw({error,{invalid_capture_index,C-$0}})
	    end
    end;
gsub_repl_str(_Cas, _S, [$%,C|_R]) ->
    %% Lua 5.3: only %%, %0-%9 are valid in replacement strings.
    throw({error,{invalid_percent_in_repl,C}});
gsub_repl_str(Cas, S, [C|R]) ->
    [C|gsub_repl_str(Cas, S, R)];
gsub_repl_str(_, _, []) -> [].

%% Return string or original match.

gsub_repl_val(S, nil, Ca) -> match_cap(Ca, S);
gsub_repl_val(S, false, Ca) -> match_cap(Ca, S);
gsub_repl_val(_S, Val, _Ca) ->
    case luerl_lib:arg_to_string(Val) of
	error ->
	    %% Lua 5.3: non-string/number/boolean replacement is an error.
	    throw({error,{invalid_repl_value,luerl_lib_basic:type(Val)}});
	Str -> Str
    end.

%% len(String) -> Length.

len(_, [A|_], St) when is_binary(A) -> {[byte_size(A)],St};
len(_, [A|_], St) when is_number(A) ->
    {[length(luerl_lib:number_to_list(A))],St};
len(_, As, St) -> badarg_error(len, As, St).

%% lower(String) -> String.

lower(_, As, St) ->
    case luerl_lib:conv_list(As, [erl_list]) of
	[S] -> {[list_to_binary(string:to_lower(S))],St};
	_ -> badarg_error(lower, As, St)	%nil or []
    end.

%% match(String, Pattern [, Init]) -> [Match].

match(_, As, St0) ->
    try
	do_match(As, St0)
    catch
	throw:{error,E,St1} -> lua_error(E, St1);
	throw:{error,E} -> lua_error(E, St0)
    end.

do_match([A1,A2], St) -> do_match([A1,A2,1.0], St);
do_match(As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_string,lua_integer]) of
	[S,P,I] -> {do_match(S, byte_size(S), P, I),St};
	_ -> throw({error,{badarg,match,As},St})
    end.

%% do_match(String, Length, Pattern, Start) -> [Return].
%% Adjust the starting index and find the match.

do_match(_, L, _, I) when I > L -> [nil];		%Shuffle values
do_match(S, L, Pat, I) when I < -L -> do_match(S, L, Pat, 1);
do_match(S, L, Pat, I) when I < 0 -> do_match(S, L, Pat, L+I+1);
do_match(S, L, Pat, 0) -> do_match(S, L, Pat, 1);
do_match(S, L, Pat0, I) ->
    case pat(binary_to_list(Pat0)) of		%"Compile" the pattern
	{ok,{Pat1,_},_} ->
	    L1 = L - I + 1,			%Length of substring
	    S1 = binary_part(S, I-1, L1),	%Start searching from I
	    case match_loop(S1, L1, Pat1, 1, {S, I-1}) of
		[{_,P,Len}] ->			%Only top level match
		    P1 = P + I - 1,		%Position in original string
		    [binary_part(S, P1-1, Len)];
		[_|Cas] ->			%Have sub matches
		    match_caps(Cas, S1);
		[] -> [nil]			%No match
	    end;
	{error,E} -> throw({error,E})
    end.

%% match_loop(String, Length, Pattern, Index) -> Cas | [].
%% Step down the string trying to find a match.

match_loop(S, L, Pat, I, Orig) when I > L ->	%It can still match at end!
    case match_pat(S, Pat, I, Orig) of
	{match,Cas,_,_} -> Cas;
	nomatch -> []				%Now we haven't found it
    end;
match_loop(S0, L, Pat, I, Orig) ->
    case match_pat(S0, Pat, I, Orig) of
	{match,Cas,_,_} -> Cas;
	nomatch ->
	    S1 = binary_part(S0, 1, L-I),
	    match_loop(S1, L, Pat, I+1, Orig)
    end.

%% match_cap(Capture, String [, Init]) -> Capture.
%% match_caps(Captures, String [, Init]) -> Captures.
%%  Get the captures. The string is the whole string not just from
%%  Init.

match_cap(Ca, S) -> match_cap(Ca, S, 1).

match_cap({_,P,Len}, _, I) when Len < 0 ->	%Capture position
    P+I-1;
match_cap({_,P,Len}, S, I) ->			%Capture
    binary_part(S, P+I-2, Len).			%Binaries count from 0

match_caps(Cas, S) -> match_caps(Cas, S, 1).

match_caps(Cas, S, I) -> [ match_cap(Ca, S, I) || Ca <- Cas ].

%% rep(String, N [, Separator]) -> [String].

rep(_, [A1,A2], St) -> rep(nil, [A1,A2,<<>>], St);
rep(_, [_,_,_|_]=As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_integer,lua_string]) of
        [S,I,Sep] ->
            %% Check total size before allocating. Lua limits string size
            %% to ~2^31 bytes; we use the same limit to avoid hanging on
            %% enormous repetitions like string.rep("a", maxinteger).
            MaxSize = 16#7FFFFFFE,              %2^31 - 2
            TotalSize = I * (byte_size(S) + byte_size(Sep)),
            Part = [Sep,S],
            if TotalSize > MaxSize ->
                    badarg_error(rep, As, St);
               I > 100 ->
                    %% For many repetitions.
                    I1 = (I-1) div 100,
                    I2 = (I-1) rem 100,
                    D100 = iolist_to_binary(lists:duplicate(100, Part)),
                    {[iolist_to_binary([S,
                                        lists:duplicate(I1, D100),
                                        lists:duplicate(I2, Part)])],
                     St};
               I > 0 ->
                    {[iolist_to_binary([S|lists:duplicate(I-1, Part)])],St};
               true -> {[<<>>],St}
            end;
        error ->                                %Error or bad values
            badarg_error(rep, As, St)
    end;
rep(_, As, St) -> badarg_error(rep, As, St).

%% reverse([String], State) -> {[Res],St}.

reverse(_, [A|_], St) when is_binary(A) ; is_number(A) ->
    S = luerl_lib:arg_to_list(A),
    {[list_to_binary(lists:reverse(S))],St};
reverse(_, As, St) -> badarg_error(reverse, As, St).

%% sub([String, I [, J]], State) -> {[Res],State}.

sub(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string,lua_integer,lua_integer]) of
	[S,I|Js] ->
	    Len = byte_size(S),
	    Sub = do_sub(S, Len, I, Js),	%Just I, or both I and J
	    {[Sub],St};
	_ -> badarg_error(sub, As, St)		%nil, [_] or []
    end.

test_sub(S, I) -> do_sub(S, byte_size(S), I, []).
test_sub(S, I, J) -> do_sub(S, byte_size(S), I, [J]).

do_sub(S, _, 0, []) -> S;			%Special case this
do_sub(S, Len, I, []) -> do_sub_1(S, Len, I, Len);
do_sub(S, Len, I, [J]) -> do_sub_1(S, Len, I, J).

do_sub_1(S, Len, I0, J0) ->
    I1 = do_sub_m(Len, I0),
    J1 = do_sub_m(Len, J0),
    do_sub_ij(S, Len, I1, J1).

do_sub_m(Len, I) when I < 0 -> Len+I+1;		%Negative count from end
do_sub_m(_, I) -> I.

do_sub_ij(S, Len, I, J) when I < 1 -> do_sub_ij(S, Len, 1, J);
do_sub_ij(S, Len, I, J) when J > Len -> do_sub_ij(S, Len, I, Len);
do_sub_ij(_, _, I, J) when I > J -> <<>>;
do_sub_ij(S, _, I, J) ->
    binary:part(S, I-1, J-I+1).			%Zero-based, yuch!

upper(_, [A|_], St) when is_binary(A) ; is_number(A) ->
    S = luerl_lib:arg_to_list(A),
    {[list_to_binary(string:to_upper(S))],St};
upper(_, As, St) -> badarg_error(upper, As, St).

%% This is the pattern grammar used. It may actually be overkill to
%% first parse the pattern as the pattern is relativey simple and we
%% should be able to do it in one pass.
%%
%% pat -> seq : '$1'.
%% seq -> single seq : ['$1'|'$2'].
%% seq -> single : '$1'.
%% single -> "(" seq ")" .
%% single -> "[" class "]" : {char_class,char_class('$2')}
%% single -> "[" "^" class "]" : {comp_class,char_class('$3')}
%% single -> char "*" .
%% single -> char "+" .
%% single -> char "-" .
%% single -> char "?" .
%% single -> char .
%% char -> "%" class .
%% char -> "." .
%% char -> char .
%%  The actual parser is a recursive descent implementation of the
%%  grammar. We leave ^ $ as normal characters and handle them
%%  specially in matching.

pat(Cs0) ->
    case catch seq(Cs0, 0, 1, []) of
	{error,E} -> {error,E};
	{P,0,Sn} -> {ok,{P,0},Sn};
	{_,_,_} -> {error,invalid_capture}
    end.

test_pat(P) -> pat(P).

seq([$^|Cs], Sd, Sn, P) -> single(Cs, Sd, Sn, ['^'|P]);
seq([_|_]=Cs, Sd, Sn, P) -> single(Cs, Sd, Sn, P);
seq([], Sd, Sn, P) -> {lists:reverse(P),Sd,Sn}.

single([$(|Cs], Sd, Sn, P) -> single(Cs, Sd+1, Sn+1, [{'(',Sn}|P]);
single([$)|_], 0, _, _) -> throw({error,invalid_capture});
single([$)|Cs], Sd, Sn, P) -> single(Cs, Sd-1, Sn, [')'|P]);
single([$[|Cs], Sd, Sn, P) -> char_set(Cs, Sd, Sn, P);
single([$.|Cs], Sd, Sn, P) -> singlep(Cs, Sd, Sn, ['.'|P]);
single([$%|Cs], Sd, Sn, P) -> char_class(Cs, Sd, Sn, P);
single([$$], Sd, Sn, P) -> {lists:reverse(P, ['\$']),Sd,Sn};
single([C|Cs], Sd, Sn, P) -> singlep(Cs, Sd, Sn, [C|P]);
single([], 0, Sn, P) -> {lists:reverse(P),0,Sn};
single([], _Sd, _Sn, _P) -> throw({error,unfinished_capture}).

singlep([$*|Cs], Sd, Sn, [Char|P]) -> single(Cs, Sd, Sn, [{kclosure,Char}|P]);
singlep([$+|Cs], Sd, Sn, [Char|P]) -> single(Cs, Sd, Sn, [{pclosure,Char}|P]);
singlep([$-|Cs], Sd, Sn, [Char|P]) -> single(Cs, Sd, Sn, [{mclosure,Char}|P]);
singlep([$?|Cs], Sd, Sn, [Char|P]) -> single(Cs, Sd, Sn, [{optional,Char}|P]);
singlep(Cs, Sd, Sn, P) -> single(Cs, Sd, Sn, P).

char_set([$^|Cs], Sd, Sn, P) -> char_set(Cs, Sd, Sn, P, comp_set);
char_set(Cs, Sd, Sn, P) -> char_set(Cs, Sd, Sn, P, char_set).

char_set(Cs0, Sd, Sn, P, Tag) ->
    case char_set(Cs0) of
	{Set,[$]|Cs1]} -> singlep(Cs1, Sd, Sn, [{Tag,Set}|P]);
	{_,_} -> throw({error,invalid_char_set})
    end.

char_set([$]|Cs]) -> char_set(Cs, [$]]);	%Must special case this
char_set(Cs) -> char_set(Cs, []).

char_set([$]|_]=Cs, Set) -> {Set,Cs};		%We are at the end
char_set([$%,C|Cs], Set) ->
    char_set(Cs, [char_class(C)|Set]);
char_set([C1,$-,C2|Cs], Set) when C2 =/= $] ->
    char_set(Cs, [{C1,C2}|Set]);
char_set([C|Cs], Set) ->
    char_set(Cs, [C|Set]);
char_set([], Set) -> {Set,[]}.			%We are at the end

char_class([$f,$[|Cs0], Sd, Sn, P) ->		%Frontier pattern
    {SetType, Cs1} = case Cs0 of
        [$^|Rest] -> {comp_set, Rest};
        Rest -> {char_set, Rest}
    end,
    case char_set(Cs1) of
        {Set, [$]|Cs2]} -> single(Cs2, Sd, Sn, [{frontier,SetType,Set}|P]);
        _ -> throw({error,invalid_char_set})
    end;
char_class([$f|_], _, _, _) -> throw({error,missing_frontier_set});
char_class([$b,L,R|Cs], Sd, Sn, P) -> singlep(Cs, Sd, Sn, [{balance,L,R}|P]);
char_class([$0|_Cs], _Sd, _Sn, _P) ->          %Capture ref %0 invalid in patterns
    throw({error,{invalid_capture_index,0}});
char_class([C|Cs], Sd, Sn, P) when C >= $1, C =< $9 ->  %Backreference
    singlep(Cs, Sd, Sn, [{capture_ref,C - $0}|P]);
char_class([C|Cs], Sd, Sn, P) -> singlep(Cs, Sd, Sn, [char_class(C)|P]);
char_class([], _, _, _) -> throw({error,invalid_pattern}).

char_class($a) -> 'a';
char_class($A) -> 'A';
char_class($c) -> 'c';
char_class($C) -> 'C';
char_class($d) -> 'd';
char_class($D) -> 'D';
char_class($g) -> 'g';
char_class($G) -> 'G';
char_class($l) -> 'l';
char_class($L) -> 'L';
char_class($p) -> 'p';
char_class($P) -> 'P';
char_class($s) -> 's';
char_class($S) -> 'S';
char_class($u) -> 'u';
char_class($U) -> 'U';
char_class($w) -> 'w';
char_class($W) -> 'W';
char_class($x) -> 'x';
char_class($X) -> 'X';
char_class($z) -> 'z';				%Deprecated
char_class($Z) -> 'Z';
char_class(C) ->				%Only non-alphanum allowed
    case is_w_char(C) of
	true -> throw({error,{invalid_char_class,C}});
	false -> C
    end.

test_match_pat(S, P, I) ->
    {ok,{Pat,_},_} = pat(P),
    io:fwrite("tdm: ~p\n", [{Pat}]),
    match_pat(S, Pat, I, {S, 0}).

%% match_pat(String, Pattern, Index) -> {match,[Capture],Rest,Index} | nomatch.
%%  Try and match the pattern with the string *at the current
%%  position*. No searching.

%% Maximum pattern match recursion depth before aborting.
%%
%% C Lua uses MAXCCALLS=200 (C stack frames). Our Erlang implementation
%% has the same recursive structure: each pattern element (closure,
%% optional, char match) generates one recursive match_pat call. Depth
%% is bounded by pattern_length × string_length for backtracking, or
%% just pattern_length for greedy forward matching.
%%
%% Typical agent patterns: 5-50 elements × strings up to 10KB = depth
%% well under 10,000. The conformance test requires f(80) to pass and
%% f(200000) to fail, where f(N) = match(rep("a",N), rep(".?",N)).
%% rep(".?",N) creates N optionals; greedy matching gives depth ≈ N.
%%
%% 200,000 is generous enough for any real-world pattern (even complex
%% patterns on large strings won't exceed 100K depth) while catching
%% the pathological rep(".?", 200000) case. C Lua's limit of 200 is
%% for C stack frames (~100 bytes each); Erlang heap frames are cheap,
%% so we can afford a much higher limit without memory risk.
-define(MAX_MATCH_DEPTH, 100000).

match_pat(S0, P0, I0, Orig) ->
    case match_pat(P0, S0, I0, [{0,I0}], [], Orig, 0) of
	{match,S1,I1,_,Cas} ->{match,Cas,S1,I1};
	{nomatch,_,_,_,_,_} -> nomatch
    end.

%% Depth limit guard: abort when match complexity is too high.
match_pat(_Ps, _Cs, _I, _Ca, _Cas, _Orig, Depth)
  when Depth > ?MAX_MATCH_DEPTH ->
    throw({error,pattern_too_complex});
match_pat(['\$']=Ps, Cs, I, Ca, Cas, Orig, Steps) -> %Match only end of string
    case Cs of
	<<>> -> match_pat([], <<>>, I, Ca, Cas, Orig, Steps+1);
	_ -> {nomatch,Ps,Cs,I,Ca,Cas}
    end;
match_pat(['^'|Ps]=Ps0, Cs, I, Ca, Cas, Orig, Steps) -> %Match beginning of string
    if I =:= 1 -> match_pat(Ps, Cs, 1, Ca, Cas, Orig, Steps+1);
       true -> {nomatch,Ps0,Cs,I,Cs,Cas}
    end;
match_pat([{'(',Sn},')'|P], Cs, I, Ca, Cas, Orig, Steps) ->
    match_pat(P, Cs, I, Ca, save_cap(Sn, I, -1, Cas), Orig, Steps+1);
match_pat([{'(',Sn}|P], Cs, I, Ca, Cas, Orig, Steps) ->
    match_pat(P, Cs, I, [{Sn,I}|Ca], Cas, Orig, Steps+1);
match_pat([')'|P], Cs, I, [{Sn,S}|Ca], Cas, Orig, Steps) ->
    match_pat(P, Cs, I, Ca, save_cap(Sn, S, I-S, Cas), Orig, Steps+1);
match_pat([{kclosure,P}=K|Ps], Cs, I, Ca, Cas, Orig, Steps) ->
    %%io:fwrite("dm: ~p\n", [{[P,K|Ps],Cs,I,Ca,Cas}]),
    case match_pat([P,K|Ps], Cs, I, Ca, Cas, Orig, Steps+1) of %First try with it
	{match,_,_,_,_}=M -> M;
	{nomatch,_,_,_,_,_} ->			%Else try without it
	    match_pat(Ps, Cs, I, Ca, Cas, Orig, Steps+1)
    end;
match_pat([{pclosure,P}|Ps], Cs, I, Ca, Cas, Orig, Steps) -> %The easy way
    match_pat([P,{kclosure,P}|Ps], Cs, I, Ca, Cas, Orig, Steps+1);
match_pat([{mclosure,P}=K|Ps], Cs, I, Ca, Cas, Orig, Steps) ->
    case match_pat(Ps, Cs, I, Ca, Cas, Orig, Steps+1) of %First try without it
	{match,_,_,_,_}=M -> M;
	{nomatch,_,_,_,_,_} ->			%Else try with it
	    match_pat([P,K|Ps], Cs, I, Ca, Cas, Orig, Steps+1)
    end;
match_pat([{optional,P}|Ps], Cs, I, Ca, Cas, Orig, Steps) ->
    case match_pat([P|Ps], Cs, I, Ca, Cas, Orig, Steps+1) of %First try with it
	{match,_,_,_,_}=M -> M;
	{nomatch,_,_,_,_,_} ->			%Else try without it
	    match_pat(Ps, Cs, I, Ca, Cas, Orig, Steps+1)
    end;
match_pat([{capture_ref,N}|Ps]=Ps0, Cs, I, Ca, Cas, Orig, Steps) ->
    case lists:keyfind(N, 1, Cas) of
	{N, P, Len} when Len >= 0 ->
	    {OrigBin, BaseOff} = Orig,
	    CapText = binary_part(OrigBin, P - 1 + BaseOff, Len),
	    case Cs of
		<<Prefix:Len/binary, Rest/binary>> when Prefix =:= CapText ->
		    match_pat(Ps, Rest, I+Len, Ca, Cas, Orig, Steps+1);
		_ ->
		    {nomatch,Ps0,Cs,I,Ca,Cas}
	    end;
	_ ->
	    %% Capture N not found or incomplete.
	    %% Lua 5.3: error if capture is open/unfinished.
	    throw({error,{invalid_capture_index,N}})
    end;
match_pat([{frontier,SetType,Set}|Ps]=Ps0, Cs, I, Ca, Cas, Orig, Steps) ->
    {OrigBin, BaseOff} = Orig,
    AbsI = I + BaseOff,
    PrevChar = if AbsI =:= 1 -> 0;		%NUL before start of string
		  true -> binary:at(OrigBin, AbsI - 2)
	       end,
    CurrChar = case Cs of
	<<C, _/binary>> -> C;
	<<>> -> 0				%NUL after end of string
    end,
    PrevMatch = frontier_set_test(SetType, Set, PrevChar),
    CurrMatch = frontier_set_test(SetType, Set, CurrChar),
    case (not PrevMatch) andalso CurrMatch of
	true -> match_pat(Ps, Cs, I, Ca, Cas, Orig, Steps+1); %Zero-width assertion
	false -> {nomatch,Ps0,Cs,I,Ca,Cas}
    end;
match_pat([{char_set,Set}|Ps]=Ps0, <<C,Cs/binary>>=Cs0, I, Ca, Cas, Orig, Steps) ->
    case match_char_set(Set, C) of
	true -> match_pat(Ps, Cs, I+1, Ca, Cas, Orig, Steps+1);
	false -> {nomatch,Ps0,Cs0,I,Ca,Cas}
    end;
match_pat([{comp_set,Set}|Ps]=Ps0, <<C,Cs/binary>>=Cs0, I, Ca, Cas, Orig, Steps) ->
    case match_char_set(Set, C) of
	true -> {nomatch,Ps0,Cs0,I,Ca,Cas};
	false -> match_pat(Ps, Cs, I+1, Ca, Cas, Orig, Steps+1)
    end;
match_pat([{balance,L,R}|Ps]=Ps0, <<L,Cs1/binary>>=Cs0, I0, Ca, Cas, Orig, Steps) ->
    case balance(Cs1, I0+1, L, R, 1) of
	{ok,Cs2,I1} -> match_pat(Ps, Cs2, I1, Ca, Cas, Orig, Steps+1);
	error -> {nomatch,Ps0,Cs0,I0,Ca,Cas}
    end;
match_pat(['.'|Ps], <<_,Cs/binary>>, I, Ca, Cas, Orig, Steps) -> %Matches anything
    match_pat(Ps, Cs, I+1, Ca, Cas, Orig, Steps+1);
match_pat([A|Ps]=Ps0, <<C,Cs/binary>>=Cs0, I, Ca, Cas, Orig, Steps) when is_atom(A) ->
    case match_class(A, C) of
	true -> match_pat(Ps, Cs, I+1, Ca, Cas, Orig, Steps+1);
	false -> {nomatch,Ps0,Cs0,I,Ca,Cas}
    end;
match_pat([C|Ps], <<C,Cs/binary>>, I, Ca, Cas, Orig, Steps) ->
    match_pat(Ps, Cs, I+1, Ca, Cas, Orig, Steps+1);
match_pat([], Cs, I, [{Sn,S}|Ca], Cas, _Orig, _Steps) ->
    {match,Cs,I,Ca,[{Sn,S,I-S}|Cas]};
match_pat(Ps, Cs, I, Ca, Cas, _Orig, _Steps) ->
    {nomatch,Ps,Cs,I,Ca,Cas}.

%% save_cap(N, Position, Length, Captures) -> Captures.
%%  Add a new capture to the list in the right place, ordered.

save_cap(N, P, L, [{N1,_,_}=Ca|Cas]) when N > N1 ->
    [Ca|save_cap(N, P, L, Cas)];
save_cap(N, P, L, Cas) -> [{N,P,L}|Cas].

%% MUST first check for right char, this in case of L == R!
balance(<<R,Cs/binary>>, I, L, R, D) ->
    if D =:= 1 -> {ok,Cs,I+1};
       true -> balance(Cs, I+1, L, R, D-1)
    end;
balance(<<L,Cs/binary>>, I, L, R, D) -> balance(Cs, I+1, L, R, D+1);
balance(<<_,Cs/binary>>, I, L, R, D) -> balance(Cs, I+1, L, R, D);
balance(<<>>, _, _, _, _) -> error.

match_class('a', C) -> is_a_char(C);
match_class('A', C) -> not is_a_char(C);
match_class('c', C) -> is_c_char(C);
match_class('C', C) -> not is_c_char(C);
match_class('d', C) -> is_d_char(C);
match_class('D', C) -> not is_d_char(C);
match_class('g', C) -> is_g_char(C);
match_class('G', C) -> not is_g_char(C);
match_class('l', C) -> is_l_char(C);
match_class('L', C) -> not is_l_char(C);
match_class('p', C) -> is_p_char(C);
match_class('P', C) -> not is_p_char(C);
match_class('s', C) -> is_s_char(C);
match_class('S', C) -> not is_s_char(C);
match_class('u', C) -> is_u_char(C);
match_class('U', C) -> not is_u_char(C);
match_class('w', C) -> is_w_char(C);
match_class('W', C) -> not is_w_char(C);
match_class('x', C) -> is_x_char(C);
match_class('X', C) -> not is_x_char(C);
match_class('z', C) -> is_z_char(C);		%Deprecated
match_class('Z', C) -> not is_z_char(C).

frontier_set_test(char_set, Set, C) -> match_char_set(Set, C);
frontier_set_test(comp_set, Set, C) -> not match_char_set(Set, C).

match_char_set([{C1,C2}|_], C) when C >= C1, C=< C2 -> true;
match_char_set([A|Set], C) when is_atom(A) ->
    match_class(A, C) orelse match_char_set(Set, C);
match_char_set([C|_], C) -> true;
match_char_set([_|Set], C) -> match_char_set(Set, C);
match_char_set([], _) -> false.

%% Test for various character types.

is_a_char(C) ->					%All letters
    is_l_char(C) orelse is_u_char(C).

is_c_char(C) when C >= 0, C =< 31 -> true;	%All control characters
is_c_char(C) when C >= 128, C =< 159 -> true;
is_c_char(_) -> false.

is_d_char(C) -> (C >= $0) and (C =< $9).	%All digits

is_g_char(C) when C >= 33, C =< 126 -> true;	%All printable characters
is_g_char(C) when C >= 161, C =< 255 -> true;
is_g_char(_) -> false.

is_l_char(C) when C >= $a, C =< $z -> true;	%All lowercase letters
is_l_char(C) when C >= 224, C =< 246 -> true;
is_l_char(C) when C >= 248, C =< 255 -> true;
is_l_char(_) -> false.

is_p_char(C) when C >= 33, C =< 47 -> true;	%All punctutation characters
is_p_char(C) when C >= 58, C =< 63 -> true;
is_p_char(C) when C >= 91, C =< 96 -> true;
is_p_char(126) -> true;
is_p_char(C) when C >= 161, C =< 191 -> true;
is_p_char(215) -> true;
is_p_char(247) -> true;
is_p_char(_) -> false.

is_s_char(C) when C >= 9, C =< 13 -> true;	%Space characters
is_s_char(32) -> true;
is_s_char(160) -> true;
is_s_char(_) -> false.

is_u_char(C) when C >= $A, C =< $Z -> true;	%All uppercase letters
is_u_char(C) when C >= 192, C =< 214 -> true;
is_u_char(C) when C >= 216, C =< 223 -> true;
is_u_char(_) -> false.

is_w_char(C) ->					%All alphanumeric characters
    is_a_char(C) orelse is_d_char(C).

is_x_char(C) when C >= $a, C =< $f -> true;	%All hexadecimal characters
is_x_char(C) when C >= $A, C =< $F -> true;
is_x_char(C) -> is_d_char(C).

is_z_char(C) -> C =:= 0.			%The zero character, deprecated

%% match_class('a', C) -> (char_table(C) band ?_A) =/= 0;
%% match_class('A', C) ->  (char_table(C) band ?_A) =:= 0.

%% char_table(C) when C >= 0, C =< 31 -> ?_C;
%% char_table(C) when C >= 65, C =< 91 -> ?_U bor ?_A;
%% char_table(C) when C >= 97, C =< 123 -> ?_L;

%% ===================================================================
%% string.pack, string.unpack, string.packsize
%% ===================================================================

-define(PACK_NB, 16).
-define(SIZEOF_SHORT, 2).
-define(SIZEOF_INT, 4).
-define(SIZEOF_LONG, 8).
-define(SIZEOF_SIZE_T, 8).
-define(SIZEOF_LUA_INTEGER, 8).
-define(SIZEOF_LUA_NUMBER, 8).
-define(SIZEOF_FLOAT, 4).
-define(SIZEOF_DOUBLE, 8).
-define(NATIVE_ENDIAN, little).

%% Pack state record
-record(pst, {endian = ?NATIVE_ENDIAN, max_align = 1}).

%% --- string.pack ---

pack(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string]) of
        [Fmt|_] ->
            try
                Vals = tl(As),
                {Bin, _Vals2} = pack_loop(binary_to_list(Fmt), Vals, #pst{}, 0, []),
                {[iolist_to_binary(Bin)], St}
            catch
                throw:{error, E} -> lua_error(E, St)
            end;
        _ -> badarg_error(pack, As, St)
    end.

pack_loop([], _Vals, _Pst, _Pos, Acc) ->
    {lists:reverse(Acc), []};
pack_loop(Fmt, Vals, Pst, Pos, Acc) ->
    {Item, Fmt2, Vals2, Pst2, Pos2} = pack_one(Fmt, Vals, Pst, Pos),
    pack_loop(Fmt2, Vals2, Pst2, Pos2, [Item|Acc]).

pack_one([$b|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, 1, signed, Fmt, Vals, Pst, Pos);
pack_one([$B|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, 1, unsigned, Fmt, Vals, Pst, Pos);
pack_one([$h|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_SHORT, signed, Fmt, Vals, Pst, Pos);
pack_one([$H|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_SHORT, unsigned, Fmt, Vals, Pst, Pos);
pack_one([$l|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_LONG, signed, Fmt, Vals, Pst, Pos);
pack_one([$L|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_LONG, unsigned, Fmt, Vals, Pst, Pos);
pack_one([$j|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_LUA_INTEGER, signed, Fmt, Vals, Pst, Pos);
pack_one([$J|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_LUA_INTEGER, unsigned, Fmt, Vals, Pst, Pos);
pack_one([$T|Fmt], [V|Vals], Pst, Pos) ->
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, ?SIZEOF_SIZE_T, unsigned, Fmt, Vals, Pst, Pos);
pack_one([$i|Fmt], [V|Vals], Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, N, signed, Fmt2, Vals, Pst, Pos);
pack_one([$I|Fmt], [V|Vals], Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    Int = luerl_lib:arg_to_integer(V),
    pack_int(Int, N, unsigned, Fmt2, Vals, Pst, Pos);
pack_one([$f|Fmt], [V|Vals], Pst, Pos) ->
    Num = to_float(V),
    pack_float(Num, ?SIZEOF_FLOAT, Fmt, Vals, Pst, Pos);
pack_one([$d|Fmt], [V|Vals], Pst, Pos) ->
    Num = to_float(V),
    pack_float(Num, ?SIZEOF_DOUBLE, Fmt, Vals, Pst, Pos);
pack_one([$n|Fmt], [V|Vals], Pst, Pos) ->
    Num = to_float(V),
    pack_float(Num, ?SIZEOF_DOUBLE, Fmt, Vals, Pst, Pos);
pack_one([$c|Fmt], [V|Vals], Pst, Pos) ->
    {N, Fmt2} = parse_number(Fmt),
    S = luerl_lib:arg_to_list(V),
    Bin = iolist_to_binary(S),
    Len = byte_size(Bin),
    if Len > N -> throw({error, {pack_string_longer, N}});
       true ->
            Pad = N - Len,
            {[Bin, <<0:(Pad*8)>>], Fmt2, Vals, Pst, Pos + N}
    end;
pack_one([$s|Fmt], [V|Vals], Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_SIZE_T),
    S = luerl_lib:arg_to_list(V),
    Bin = iolist_to_binary(S),
    Len = byte_size(Bin),
    MaxVal = (1 bsl (N * 8)) - 1,
    if Len > MaxVal -> throw({error, {pack_does_not_fit, N}});
       true ->
            Align = pack_align(N, Pst),
            PadBits = align_padding(Pos, Align) * 8,
            Pos2 = Pos + align_padding(Pos, Align),
            LenBin = encode_int(Len, N, unsigned, Pst#pst.endian),
            {[<<0:PadBits>>, LenBin, Bin], Fmt2, Vals, Pst, Pos2 + N + Len}
    end;
pack_one([$z|Fmt], [V|Vals], Pst, Pos) ->
    S = luerl_lib:arg_to_list(V),
    Bin = iolist_to_binary(S),
    case binary:match(Bin, <<0>>) of
        nomatch ->
            {[Bin, <<0>>], Fmt, Vals, Pst, Pos + byte_size(Bin) + 1};
        _ ->
            throw({error, {pack_string_contains_zeros, z}})
    end;
pack_one([$x|Fmt], Vals, Pst, Pos) ->
    {<<0>>, Fmt, Vals, Pst, Pos + 1};
pack_one([$X|Fmt], Vals, Pst, Pos) ->
    {_Size, NatAlign, Fmt2} = parse_x_option(Fmt),
    Align = min(NatAlign, Pst#pst.max_align),
    Pad = align_padding(Pos, Align),
    {<<0:(Pad*8)>>, Fmt2, Vals, Pst, Pos + Pad};
pack_one([$ |Fmt], Vals, Pst, Pos) ->
    {<<>>, Fmt, Vals, Pst, Pos};
pack_one([$<|Fmt], Vals, Pst, Pos) ->
    {<<>>, Fmt, Vals, Pst#pst{endian=little}, Pos};
pack_one([$>|Fmt], Vals, Pst, Pos) ->
    {<<>>, Fmt, Vals, Pst#pst{endian=big}, Pos};
pack_one([$=|Fmt], Vals, Pst, Pos) ->
    {<<>>, Fmt, Vals, Pst#pst{endian=?NATIVE_ENDIAN}, Pos};
pack_one([$!|Fmt], Vals, Pst, Pos) ->
    {N, Fmt2} = parse_align_size(Fmt),
    {<<>>, Fmt2, Vals, Pst#pst{max_align=N}, Pos};
pack_one([C|_], _Vals, _Pst, _Pos) ->
    throw({error, {pack_invalid_format, C}}).

pack_int(Int, Size, Sign, Fmt, Vals, Pst, Pos) ->
    check_int_overflow(Int, Size, Sign),
    Align = pack_align(Size, Pst),
    PadBits = align_padding(Pos, Align) * 8,
    Pos2 = Pos + align_padding(Pos, Align),
    Bin = encode_int(Int, Size, Sign, Pst#pst.endian),
    {[<<0:PadBits>>, Bin], Fmt, Vals, Pst, Pos2 + Size}.

pack_float(Num, Size, Fmt, Vals, Pst, Pos) ->
    Align = pack_align(Size, Pst),
    PadBits = align_padding(Pos, Align) * 8,
    Pos2 = Pos + align_padding(Pos, Align),
    Bin = encode_float(Num, Size, Pst#pst.endian),
    {[<<0:PadBits>>, Bin], Fmt, Vals, Pst, Pos2 + Size}.

pack_align(Size, #pst{max_align=MaxAlign}) ->
    min(Size, MaxAlign).

%% --- string.unpack ---

unpack(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string, lua_string, lua_integer]) of
        [Fmt, S | Rest] ->
            try
                InitPos = case Rest of
                              [P] -> resolve_pos(P, byte_size(S));
                              _ -> 0
                          end,
                if InitPos < 0; InitPos > byte_size(S) ->
                        throw({error, {pack_out_of_string, InitPos + 1}});
                   true -> ok
                end,
                {Results, FinalPos} = unpack_loop(binary_to_list(Fmt), S, #pst{}, InitPos, []),
                {lists:reverse(Results) ++ [FinalPos + 1], St}
            catch
                throw:{error, E} -> lua_error(E, St)
            end;
        _ -> badarg_error(unpack, As, St)
    end.

resolve_pos(P, Len) when P < 0 -> max(0, Len + P);
resolve_pos(P, _Len) -> P - 1.

unpack_loop([], _S, _Pst, Pos, Acc) ->
    {Acc, Pos};
unpack_loop(Fmt, S, Pst, Pos, Acc) ->
    {Val, Fmt2, Pst2, Pos2} = unpack_one(Fmt, S, Pst, Pos),
    case Val of
        none -> unpack_loop(Fmt2, S, Pst2, Pos2, Acc);
        _ -> unpack_loop(Fmt2, S, Pst2, Pos2, [Val|Acc])
    end.

unpack_one([$b|Fmt], S, Pst, Pos) ->
    unpack_int(1, signed, Fmt, S, Pst, Pos);
unpack_one([$B|Fmt], S, Pst, Pos) ->
    unpack_int(1, unsigned, Fmt, S, Pst, Pos);
unpack_one([$h|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_SHORT, signed, Fmt, S, Pst, Pos);
unpack_one([$H|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_SHORT, unsigned, Fmt, S, Pst, Pos);
unpack_one([$l|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_LONG, signed, Fmt, S, Pst, Pos);
unpack_one([$L|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_LONG, unsigned, Fmt, S, Pst, Pos);
unpack_one([$j|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_LUA_INTEGER, signed, Fmt, S, Pst, Pos);
unpack_one([$J|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_LUA_INTEGER, unsigned, Fmt, S, Pst, Pos);
unpack_one([$T|Fmt], S, Pst, Pos) ->
    unpack_int(?SIZEOF_SIZE_T, unsigned, Fmt, S, Pst, Pos);
unpack_one([$i|Fmt], S, Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    unpack_int(N, signed, Fmt2, S, Pst, Pos);
unpack_one([$I|Fmt], S, Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    unpack_int(N, unsigned, Fmt2, S, Pst, Pos);
unpack_one([$f|Fmt], S, Pst, Pos) ->
    unpack_float(?SIZEOF_FLOAT, Fmt, S, Pst, Pos);
unpack_one([$d|Fmt], S, Pst, Pos) ->
    unpack_float(?SIZEOF_DOUBLE, Fmt, S, Pst, Pos);
unpack_one([$n|Fmt], S, Pst, Pos) ->
    unpack_float(?SIZEOF_DOUBLE, Fmt, S, Pst, Pos);
unpack_one([$c|Fmt], S, Pst, Pos) ->
    {N, Fmt2} = parse_number(Fmt),
    check_str_avail(S, Pos, N),
    Bin = binary:part(S, Pos, N),
    {Bin, Fmt2, Pst, Pos + N};
unpack_one([$s|Fmt], S, Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_SIZE_T),
    Align = pack_align(N, Pst),
    Pos2 = Pos + align_padding(Pos, Align),
    check_str_avail(S, Pos2, N),
    LenBin = binary:part(S, Pos2, N),
    Len = decode_int(LenBin, N, unsigned, Pst#pst.endian),
    Pos3 = Pos2 + N,
    check_str_avail(S, Pos3, Len),
    Str = binary:part(S, Pos3, Len),
    {Str, Fmt2, Pst, Pos3 + Len};
unpack_one([$z|Fmt], S, Pst, Pos) ->
    case binary:match(S, <<0>>, [{scope, {Pos, byte_size(S) - Pos}}]) of
        {ZPos, 1} ->
            Str = binary:part(S, Pos, ZPos - Pos),
            {Str, Fmt, Pst, ZPos + 1};
        nomatch ->
            throw({error, {pack_too_short, z}})
    end;
unpack_one([$x|Fmt], S, Pst, Pos) ->
    check_str_avail(S, Pos, 1),
    {none, Fmt, Pst, Pos + 1};
unpack_one([$X|Fmt], _S, Pst, Pos) ->
    {_Size, NatAlign, Fmt2} = parse_x_option(Fmt),
    Align = min(NatAlign, Pst#pst.max_align),
    Pos2 = Pos + align_padding(Pos, Align),
    {none, Fmt2, Pst, Pos2};
unpack_one([$ |Fmt], _S, Pst, Pos) ->
    {none, Fmt, Pst, Pos};
unpack_one([$<|Fmt], _S, Pst, Pos) ->
    {none, Fmt, Pst#pst{endian=little}, Pos};
unpack_one([$>|Fmt], _S, Pst, Pos) ->
    {none, Fmt, Pst#pst{endian=big}, Pos};
unpack_one([$=|Fmt], _S, Pst, Pos) ->
    {none, Fmt, Pst#pst{endian=?NATIVE_ENDIAN}, Pos};
unpack_one([$!|Fmt], _S, Pst, Pos) ->
    {N, Fmt2} = parse_align_size(Fmt),
    {none, Fmt2, Pst#pst{max_align=N}, Pos};
unpack_one([C|_], _S, _Pst, _Pos) ->
    throw({error, {pack_invalid_format, C}}).

unpack_int(Size, Sign, Fmt, S, Pst, Pos) ->
    Align = pack_align(Size, Pst),
    Pos2 = Pos + align_padding(Pos, Align),
    check_str_avail(S, Pos2, Size),
    Bin = binary:part(S, Pos2, Size),
    Val = decode_int(Bin, Size, Sign, Pst#pst.endian),
    %% Check if fits in lua integer for large unsigned
    if Sign =:= unsigned, Size > ?SIZEOF_LUA_INTEGER ->
            %% Check sign bit of the decoded value
            check_unsigned_fits(Val, Size);
       Sign =:= signed, Size > ?SIZEOF_LUA_INTEGER ->
            check_signed_fits(Val, Size);
       true -> ok
    end,
    {Val, Fmt, Pst, Pos2 + Size}.

unpack_float(Size, Fmt, S, Pst, Pos) ->
    Align = pack_align(Size, Pst),
    Pos2 = Pos + align_padding(Pos, Align),
    check_str_avail(S, Pos2, Size),
    Bin = binary:part(S, Pos2, Size),
    Val = decode_float(Bin, Size, Pst#pst.endian),
    {Val, Fmt, Pst, Pos2 + Size}.

%% --- string.packsize ---

packsize(_, As, St) ->
    case luerl_lib:conv_list(As, [lua_string]) of
        [Fmt] ->
            try
                Size = packsize_loop(binary_to_list(Fmt), #pst{}, 0),
                {[Size], St}
            catch
                throw:{error, E} -> lua_error(E, St)
            end;
        _ -> badarg_error(packsize, As, St)
    end.

packsize_loop([], _Pst, Size) -> Size;
packsize_loop(Fmt, Pst, Size) ->
    {ItemSize, Fmt2, Pst2} = packsize_one(Fmt, Pst, Size),
    packsize_loop(Fmt2, Pst2, ItemSize).

packsize_one([$b|Fmt], Pst, Pos) -> {Pos + 1, Fmt, Pst};
packsize_one([$B|Fmt], Pst, Pos) -> {Pos + 1, Fmt, Pst};
packsize_one([$h|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_SHORT, Fmt, Pst, Pos);
packsize_one([$H|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_SHORT, Fmt, Pst, Pos);
packsize_one([$l|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_LONG, Fmt, Pst, Pos);
packsize_one([$L|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_LONG, Fmt, Pst, Pos);
packsize_one([$j|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_LUA_INTEGER, Fmt, Pst, Pos);
packsize_one([$J|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_LUA_INTEGER, Fmt, Pst, Pos);
packsize_one([$T|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_SIZE_T, Fmt, Pst, Pos);
packsize_one([$i|Fmt], Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    packsize_aligned(N, Fmt2, Pst, Pos);
packsize_one([$I|Fmt], Pst, Pos) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    packsize_aligned(N, Fmt2, Pst, Pos);
packsize_one([$f|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_FLOAT, Fmt, Pst, Pos);
packsize_one([$d|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_DOUBLE, Fmt, Pst, Pos);
packsize_one([$n|Fmt], Pst, Pos) -> packsize_aligned(?SIZEOF_DOUBLE, Fmt, Pst, Pos);
packsize_one([$c|Fmt], Pst, Pos) ->
    {N, Fmt2} = parse_number(Fmt),
    check_packsize_overflow(Pos, N),
    {Pos + N, Fmt2, Pst};
packsize_one([$s|_Fmt], _Pst, _Pos) ->
    throw({error, pack_variable_length});
packsize_one([$z|_Fmt], _Pst, _Pos) ->
    throw({error, pack_variable_length});
packsize_one([$x|Fmt], Pst, Pos) -> {Pos + 1, Fmt, Pst};
packsize_one([$X|Fmt], Pst, Pos) ->
    {_Size, NatAlign, Fmt2} = parse_x_option(Fmt),
    Align = min(NatAlign, Pst#pst.max_align),
    Pad = align_padding(Pos, Align),
    {Pos + Pad, Fmt2, Pst};
packsize_one([$ |Fmt], Pst, Pos) -> {Pos, Fmt, Pst};
packsize_one([$<|Fmt], Pst, Pos) -> {Pos, Fmt, Pst#pst{endian=little}};
packsize_one([$>|Fmt], Pst, Pos) -> {Pos, Fmt, Pst#pst{endian=big}};
packsize_one([$=|Fmt], Pst, Pos) -> {Pos, Fmt, Pst#pst{endian=?NATIVE_ENDIAN}};
packsize_one([$!|Fmt], Pst, Pos) ->
    {N, Fmt2} = parse_align_size(Fmt),
    {Pos, Fmt2, Pst#pst{max_align=N}};
packsize_one([C|_], _Pst, _Pos) ->
    throw({error, {pack_invalid_format, C}}).

packsize_aligned(Size, Fmt, Pst, Pos) ->
    Align = pack_align(Size, Pst),
    Pos2 = Pos + align_padding(Pos, Align),
    check_packsize_overflow(Pos2, Size),
    {Pos2 + Size, Fmt, Pst}.

check_packsize_overflow(Pos, Size) ->
    Max = 16#7fffffff,
    if Pos + Size > Max -> throw({error, {pack_too_large, Pos + Size}});
       true -> ok
    end.

%% --- Helpers ---

to_float(V) ->
    case luerl_lib:arg_to_number(V) of
        N when is_integer(N) -> float(N);
        N when is_float(N) -> N;
        _ -> throw({error, {badarg, pack, [V]}})
    end.

parse_int_size(Fmt, Default) ->
    case parse_optional_number(Fmt) of
        {none, Fmt2} -> {Default, Fmt2};
        {N, Fmt2} ->
            if N < 1; N > ?PACK_NB ->
                    throw({error, {pack_out_of_limits, N}});
               true -> {N, Fmt2}
            end
    end.

parse_align_size(Fmt) ->
    case parse_optional_number(Fmt) of
        {none, Fmt2} -> {1, Fmt2};
        {N, Fmt2} ->
            if N > ?PACK_NB ->
                    throw({error, {pack_out_of_limits, N}});
               (N band (N - 1)) =/= 0 ->
                    throw({error, {pack_not_power_of_2, N}});
               true -> {N, Fmt2}
            end
    end.

parse_number(Fmt) ->
    case parse_optional_number(Fmt) of
        {none, _} -> throw({error, pack_missing_size});
        {N, Fmt2} -> {N, Fmt2}
    end.

parse_optional_number([D|Fmt]) when D >= $0, D =< $9 ->
    parse_digits(Fmt, D - $0, 1);
parse_optional_number(Fmt) ->
    {none, Fmt}.

parse_digits([D|Fmt], Acc, Count) when D >= $0, D =< $9 ->
    NewAcc = Acc * 10 + (D - $0),
    if Count >= 10 ->
            throw({error, {pack_invalid_format_string, overflow}});
       true ->
            parse_digits(Fmt, NewAcc, Count + 1)
    end;
parse_digits(Fmt, Acc, _Count) ->
    {Acc, Fmt}.

align_padding(_Pos, 1) -> 0;
align_padding(Pos, Align) ->
    case Pos rem Align of
        0 -> 0;
        R -> Align - R
    end.

natural_align($b) -> 1;
natural_align($B) -> 1;
natural_align($h) -> ?SIZEOF_SHORT;
natural_align($H) -> ?SIZEOF_SHORT;
natural_align($l) -> ?SIZEOF_LONG;
natural_align($L) -> ?SIZEOF_LONG;
natural_align($j) -> ?SIZEOF_LUA_INTEGER;
natural_align($J) -> ?SIZEOF_LUA_INTEGER;
natural_align($T) -> ?SIZEOF_SIZE_T;
natural_align($f) -> ?SIZEOF_FLOAT;
natural_align($d) -> ?SIZEOF_DOUBLE;
natural_align($n) -> ?SIZEOF_DOUBLE;
natural_align($x) -> 1;
natural_align($i) -> ?SIZEOF_INT;
natural_align($I) -> ?SIZEOF_INT;
natural_align(_) -> throw({error, pack_invalid_next_option}).

option_size($i, Fmt) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    {N, N, Fmt2};
option_size($I, Fmt) ->
    {N, Fmt2} = parse_int_size(Fmt, ?SIZEOF_INT),
    {N, N, Fmt2};
option_size(C, Fmt) ->
    A = natural_align(C),
    {A, A, Fmt}.

parse_x_option([]) ->
    throw({error, pack_invalid_next_option});
parse_x_option([C|_Fmt]) when C =:= $ ; C =:= $X; C =:= $c ->
    throw({error, pack_invalid_next_option});
parse_x_option([C|Fmt]) ->
    {_Size, NatAlign, Fmt2} = option_size(C, Fmt),
    {0, NatAlign, Fmt2}.

encode_int(Int, Size, _Sign, little) ->
    <<Int:(Size*8)/little-signed-integer>>;
encode_int(Int, Size, _Sign, big) ->
    <<Int:(Size*8)/big-signed-integer>>.

decode_int(Bin, Size, signed, little) ->
    <<Val:(Size*8)/little-signed-integer>> = Bin, Val;
decode_int(Bin, Size, unsigned, little) ->
    <<Val:(Size*8)/little-unsigned-integer>> = Bin, Val;
decode_int(Bin, Size, signed, big) ->
    <<Val:(Size*8)/big-signed-integer>> = Bin, Val;
decode_int(Bin, Size, unsigned, big) ->
    <<Val:(Size*8)/big-unsigned-integer>> = Bin, Val.

encode_float(Num, 4, little) -> <<Num:32/little-float>>;
encode_float(Num, 4, big) -> <<Num:32/big-float>>;
encode_float(Num, 8, little) -> <<Num:64/little-float>>;
encode_float(Num, 8, big) -> <<Num:64/big-float>>.

decode_float(Bin, 4, little) -> <<V:32/little-float>> = Bin, V;
decode_float(Bin, 4, big) -> <<V:32/big-float>> = Bin, V;
decode_float(Bin, 8, little) -> <<V:64/little-float>> = Bin, V;
decode_float(Bin, 8, big) -> <<V:64/big-float>> = Bin, V.

check_int_overflow(Int, _Size, unsigned) when Int < 0 ->
    throw({error, {pack_overflow, Int}});
check_int_overflow(Int, Size, unsigned) ->
    Max = (1 bsl (Size * 8)) - 1,
    if Int > Max -> throw({error, {pack_overflow, Int}});
       true -> ok
    end;
check_int_overflow(Int, Size, signed) ->
    Max = (1 bsl (Size * 8 - 1)) - 1,
    Min = -(1 bsl (Size * 8 - 1)),
    if Int > Max; Int < Min -> throw({error, {pack_overflow, Int}});
       true -> ok
    end.

check_unsigned_fits(Val, Size) ->
    MaxLuaInt = (1 bsl (?SIZEOF_LUA_INTEGER * 8)) - 1,
    if Val > MaxLuaInt ->
            throw({error, {pack_does_not_fit, Size}});
       true -> ok
    end.

check_signed_fits(Val, Size) ->
    MaxLuaInt = (1 bsl (?SIZEOF_LUA_INTEGER * 8 - 1)) - 1,
    MinLuaInt = -(1 bsl (?SIZEOF_LUA_INTEGER * 8 - 1)),
    if Val > MaxLuaInt; Val < MinLuaInt ->
            throw({error, {pack_integer_overflow, Size}});
       true -> ok
    end.

check_str_avail(S, Pos, Need) ->
    if Pos + Need > byte_size(S) ->
            throw({error, {pack_too_short, Need}});
       true -> ok
    end.
