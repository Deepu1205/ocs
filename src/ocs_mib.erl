%%% ocs_mib.erl
%%% vim: ts=3
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @copyright 2018 SigScale Global Inc.
%%% @end
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc This library module implements the SNMP MIB for the
%%%     {@link //ocs. ocs} application.
%%%
-module(ocs_mib).
-copyright('Copyright (c) 2018 SigScale Global Inc.').

%% export the ocs_mib public API
-export([load/0, load/1, unload/0, unload/1]).

%% export the ocs_mib snmp agent callbacks
-export([client_table/3, dbp_local_config/2, dbp_local_stats/2]).

-include("ocs.hrl").

%%----------------------------------------------------------------------
%%  The ocs_mib public API
%%----------------------------------------------------------------------

-spec load() -> Result
	when
		Result :: ok | {error, Reason},
		Reason :: term().
%% @doc Loads the SigScale OCS MIB.
load() ->
	MibDir = code:priv_dir(ocs) ++ "/mibs",
	Mibs = [MibDir ++ "/SIGSCALE-OCS-MIB"],
	snmpa:load_mibs(Mibs).

-spec load(Agent) -> Result
	when
		Agent :: pid() | atom(),
		Result :: ok | {error, Reason},
		Reason :: term().
%% @doc Loads the SigScale OCS MIB.
load(Agent) ->
	MibDir = code:priv_dir(ocs) ++ "/mibs",
	Mibs = [MibDir ++ "/SIGSCALE-OCS-MIB",
				MibDir ++ "/SIGSCALE-DIAMETER-BASE-PROTOCOL-MIB",
				MibDir ++ "/SIGSCALE-DIAMETER-CC-APPLICATION-MIB"],
	snmpa:load_mibs(Agent, Mibs).

-spec unload() -> Result
	when
		Result :: ok | {error, Reason},
		Reason :: term().
%% @doc Unloads the SigScale OCS MIB.
unload() ->
	Mibs = ["SIGSCALE-OCS-MIB"],
	snmpa:unload_mibs(Mibs).

-spec unload(Agent) -> Result
	when
		Agent :: pid() | atom(),
		Result :: ok | {error, Reason},
		Reason :: term().
%% @doc Unloads the SigScale OCS MIB.
unload(Agent) ->
	Mibs = ["SIGSCALE-OCS-MIB"],
	snmpa:unload_mibs(Agent, Mibs).

%%----------------------------------------------------------------------
%% The ocs_mib snmp agent callbacks
%----------------------------------------------------------------------

-spec client_table(Operation, RowIndex, Columns) -> Result
	when
		Operation :: get | get_next,
		RowIndex :: ObjectId,
		ObjectId :: [integer()],
		Columns :: [Column],
		Column :: integer(),
		Result :: [Element] | {genErr, Column},
		Element :: {value, Value} | {ObjectId, Value},
		Value :: atom() | integer() | string() | [integer()].
%% @doc Handle SNMP requests for the client table.
%% @private
client_table(get, [1, 4] ++ Key = _RowIndex, Columns)
		when length(Key) == 4 ->
	case ocs:find_client(list_to_tuple(Key)) of
		{ok, #client{port = Port, identifier = Id, protocol = Proto}} ->
			F2 = fun(1, Acc) ->
						[{value, ipv4} | Acc];
					(2, Acc) ->
						[{value, Key} | Acc];
					(3, Acc) when Port == undefined ->
						[{value, 0} | Acc];
					(3, Acc) ->
						[{value, Port} | Acc];
					(4, Acc) ->
						[{value, binary_to_list(Id)} | Acc];
					(5, Acc) ->
						[{value, Proto} | Acc];
					(_, Acc) ->
						[{noValue, noSuchInstance} | Acc]
			end,
			lists:reverse(lists:foldl(F2, [], Columns));
		{error, not_found} ->
			{noValue, noSuchInstance};
		{error, _Reason} ->
			{genErr, 0}
	end;
client_table(get, _RowIndex, _Columns) ->
	{noValue, noSuchInstance};
client_table(get_next, [], Columns) ->
	F = fun() ->
			 mnesia:first(client)
	end,
	client_get_next(F, Columns, true);
client_table(get_next, [1, 4] ++ Key, Columns)
		when length(Key) == 4 ->
	F = fun() ->
			 mnesia:next(client, list_to_tuple(Key))
	end,
	client_get_next(F, Columns, true).
%% @hidden
client_get_next(F1, Columns, First) ->
	case mnesia:ets(F1) of
		IP when is_tuple(IP) ->
			case ocs:find_client(IP) of
				{ok, #client{port = Port, identifier = Id, protocol = Proto}} ->
					Key = tuple_to_list(IP),
					F2 = fun(0, Acc) ->
								[{[1, 1, 4 | Key], ipv4} | Acc];
							(1, Acc) ->
								[{[1, 1, 4 | Key], ipv4} | Acc];
							(2, Acc) ->
								[{[2, 1, 4 | Key], Key} | Acc];
							(3, Acc) when Port == undefined ->
								[{[3, 1, 4 | Key], 0} | Acc];
							(3, Acc) ->
								[{[3, 1, 4 | Key], Port} | Acc];
							(4, Acc) ->
								[{[4, 1, 4 | Key], binary_to_list(Id)} | Acc];
							(5, Acc) ->
								[{[5, 1, 4 | Key], Proto} | Acc];
							(_, Acc) ->
								[endOfTable | Acc]
					end,
					lists:reverse(lists:foldl(F2, [], Columns));
				{error, _Reason} ->
					{genErr, 0}
			end;
		'$end_of_table' when First == true ->
			F3 = fun(N) ->
					N + 1
			end,
			NextColumns = lists:map(F3, Columns),
			F4 = fun() ->
					mnesia:first(client)
			end,
			client_get_next(F4, NextColumns, false);
		'$end_of_table' ->
			[endOfTable || _ <- Columns]
	end.

-spec dbp_local_config(Operation, Items) -> Result
	when
		Operation :: get,
		Items :: 'Origin-Host' | 'Origin-Realm' | 'Product-Name',
		Result :: {value, Value} | genErr,
		Value :: atom() | integer() | string() | [integer()].
% @doc Get local DIAMETER configuration.
% @private
dbp_local_config(get, Item) ->
	case lists:keyfind(ocs_diameter_acct_service, 1, diameter:services()) of
		Service when is_tuple(Service) ->
			case diameter:service_info(Service, Item) of
				Info when is_binary(Info) ->
					{value, binary_to_list(Info)};
				Info when is_list(Info) ->
					{value, Info};
				_ ->
					genErr
			end;
		false ->
			{noValue, noSuchInstance}
	end.
 
-spec dbp_local_stats(Operation, Item) -> Result
	when
		Operation :: get,
		Item :: uptime,
		Result :: {value, Value} | {noValue, noSuchInstance} | genErr,
		Value :: atom() | integer() | string() | [integer()].
%% @doc Handle SNMP requests for `DIAMETER-BASE-PROTOCOL-MIB::dbpLocalStats'.
%% @private
dbp_local_stats(get, uptime) ->
	case catch diameter_stats:uptime() of
		{'EXIT', _Reason} ->
			genErr;
		{Hours, Mins, Secs, MicroSecs} ->
			{value, (Hours * 360000) + (Mins * 6000)
					+ (Secs * 100) + (MicroSecs div 10)}
	end;
dbp_local_stats(get, Item) ->
	case catch diameter:services() of
		[Service |  _] ->
			case catch diameter:service_info(Service, transport) of
				Info when is_list(Info) ->
					case total_packets(Info) of
						{ok, {PacketsIn, _}} when Item == in ->
							PacketsIn;
						{ok, {_, PacketsOut}} when Item == out ->
							PacketsOut;
						{error, _Reason} ->
							genErr
					end;
				_ ->
					genErr
			end;
		_ ->
			genErr
	end.

%%----------------------------------------------------------------------
%% internal functions
%----------------------------------------------------------------------
-spec total_packets(Info) -> Result
	when
		Info :: [tuple()],
		Result :: {ok, {PacketsIn, PacketsOut}} | {error, Reason},
		PacketsIn :: integer(),
		PacketsOut :: integer(),
		Reason :: term().
%% @doc Get packet counts from service info.

total_packets(Info) ->
	total_packets(Info, {0, 0}).
%% @hidden
total_packets([H | T], Acc) ->
	case lists:keyfind(accept, 1, H) of
		{_, L} ->
			case total_packets1(L, Acc) of
				{ok, Acc1} ->
					total_packets(T, Acc1);
				{error, _Reason} ->
					total_packets(T, Acc)
			end;
		false ->
			{error, not_found}
	end;
total_packets([], Acc) ->
	{ok, Acc}.
%% @hidden
total_packets1([H | T], Acc) ->
	case lists:keyfind(port, 1, H) of
		{_, L} ->
			case total_packets2(L, Acc) of
				{ok, Acc1} ->
					total_packets1(T, Acc1);
				{error, Reason} ->
					{error, Reason}
			end;
		false ->
			total_packets1(T, Acc)
	end;
total_packets1([], Acc) ->
	{ok, Acc}.
%% @hidden
total_packets2(L1, Acc) ->
	case lists:keyfind(statistics, 1, L1) of
		{_, L2} ->
			total_packets3(L2, Acc);
		false ->
			{error, not_found}
	end.
%% @hidden
total_packets3(L, {PacketsIn, PacketsOut}) ->
	case lists:keyfind(recv_cnt, 1, L) of
		{_, N} ->
			total_packets4(L, {PacketsIn + N, PacketsOut});
		false ->
			{error, not_found}
	end.
%% @hidden
total_packets4(L, {PacketsIn, PacketsOut}) ->
	case lists:keyfind(send_cnt, 1, L) of
		{_, N} ->
			{ok, {PacketsIn, PacketsOut + N}};
		false ->
			{error, not_found}
	end.

