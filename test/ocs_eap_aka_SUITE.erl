%%% ocs_eap_aka_SUITE.erl
%%% vim: ts=3
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @copyright 2016 - 2017 SigScale Global Inc.
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%  @doc Test suite for authentication using Extensible Authentication
%%% 	Protocol (EAP) using only a password (EAP-AKA)
%%% 	of the {@link //ocs. ocs} application.
%%%
-module(ocs_eap_aka_SUITE).
-copyright('Copyright (c) 2016 - 2017 SigScale Global Inc.').

%% common_test required callbacks
-export([suite/0, sequences/0, all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([init_per_testcase/2, end_per_testcase/2]).

%% Note: This directive should only be used in test suites.
-compile(export_all).

-include("ocs_eap_codec.hrl").
-include("ocs.hrl").
-include_lib("radius/include/radius.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter/include/diameter_gen_base_rfc6733.hrl").
-include_lib("../include/diameter_gen_eap_application_rfc4072.hrl").
-include_lib("kernel/include/inet.hrl").

-define(BASE_APPLICATION_ID, 0).
-define(EAP_APPLICATION_ID, 5).
-define(IANA_PEN_3GPP, 10415).
-define(IANA_PEN_SigScale, 50386).

%% support deprecated_time_unit()
-define(MILLISECOND, milli_seconds).
%-define(MILLISECOND, millisecond).

%%---------------------------------------------------------------------
%%  Test server callback functions
%%---------------------------------------------------------------------

-spec suite() -> DefaultData :: [tuple()].
%% Require variables and set default values for the suite.
%%
suite() ->
	[{userdata, [{doc, "Test suite for authentication with EAP-AKA in OCS"}]},
	{timetrap, {seconds, 8}},
	{require, mcc}, {default_config, mcc, "001"},
	{require, mnc}, {default_config, mnc, "001"},
	{require, radius_shared_secret},{default_config, radius_shared_secret, "xyzzy5461"}].

-spec init_per_suite(Config :: [tuple()]) -> Config :: [tuple()].
%% Initialization before the whole suite.
%%
init_per_suite(Config) ->
	ok = ocs_test_lib:initialize_db(),
	RadiusPort = rand:uniform(64511) + 1024,
	Options = [{eap_method_prefer, aka}, {eap_method_order, [aka]}],
	RadiusAppVar = [{auth, [{{127,0,0,1}, RadiusPort, Options}]}],
	ok = application:set_env(ocs, radius, RadiusAppVar, [{persistent, true}]),
	DiameterPort = rand:uniform(64511) + 1024,
	DiameterAppVar = [{auth, [{{127,0,0,1}, DiameterPort, Options}]}],
	ok = application:set_env(ocs, diameter, DiameterAppVar, [{persistent, true}]),
	ok = ocs_test_lib:start(),
	{ok, ProdID} = ocs_test_lib:add_offer(),
	{ok, DiameterConfig} = application:get_env(ocs, diameter),
	{auth, [{Address, Port, _} | _]} = lists:keyfind(auth, 1, DiameterConfig),
	Host = atom_to_list(?MODULE),
	Realm = "wlan.mnc" ++ ct:get_config(mnc) ++ ".mcc"
			++ ct:get_config(mcc) ++ ".3gppnetwork.org",
	Config1 = [{host, Host}, {realm, Realm}, {product_id, ProdID},
		{diameter_client, Address} | Config],
	ok = diameter:start_service(?MODULE, client_service_opts(Config1)),
	true = diameter:subscribe(?MODULE),
	{ok, _Ref} = connect(?MODULE, Address, Port, diameter_tcp),
	receive
		#diameter_event{service = ?MODULE, info = Info}
				when element(1, Info) == up ->
			Config1;
		_Other ->
			{skip, diameter_client_service_not_started}
	end.

-spec end_per_suite(Config :: [tuple()]) -> any().
%% Cleanup after the whole suite.
%%
end_per_suite(Config) ->
	ok = application:unset_env(ocs, radius, [{persistent, true}]),
	ok = application:unset_env(ocs, diameter, [{persistent, true}]),
	ok = diameter:stop_service(?MODULE),
	ok = ocs_test_lib:stop(),
	Config.

-spec init_per_testcase(TestCase :: atom(), Config :: [tuple()]) -> Config :: [tuple()].
%% Initialization before each test case.
%%
init_per_testcase(aka_prf, Config) ->
	Config.

-spec end_per_testcase(TestCase :: atom(), Config :: [tuple()]) -> any().
%% Cleanup after each test case.
%%
end_per_testcase(aka_prf, Config) ->
	Config.

-spec sequences() -> Sequences :: [{SeqName :: atom(), Testcases :: [atom()]}].
%% Group test cases into a test sequence.
%%
sequences() ->
	[].

-spec all() -> TestCases :: [Case :: atom()].
%% Returns a list of all test cases in this test suite.
%%
all() ->
	[aka_prf].

%%---------------------------------------------------------------------
%%  Test cases
%%---------------------------------------------------------------------

aka_prf() ->
   [{userdata, [{doc, "Psuedo-Random Number Function (PRF) (RFC4187 Appendix A)"}]}].

aka_prf(_Config) ->
	Identity = <<"0001001000000001@wlan.mnc001.mcc001.3gppnetwork.org">>,
	IK = <<151,68,135,26,211,43,249,187,209,221,92,229,78,62,46,90>>,
	CK = <<83,73,251,224,152,100,159,148,143,93,46,151,58,129,192,15>>,
	Kencr = <<148,91,8,16,161,208,23,165,64,169,134,69,67,227,0,133>>,
	Kaut = <<87,96,126,37,22,113,111,207,109,211,155,62,214,86,159,97>>,
	MSK = <<217,187,67,94,211,52,132,255,234,40,196,63,79,207,34,84,171,
			250,178,244,145,168,248,131,227,111,91,87,47,47,47,141,150,226,
			109,195,79,38,25,151,172,239,221,28,30,61,96,155,141,114,17,144,
			81,226,225,131,225,71,143,0,217,133,111,196>>,
	EMSK = <<160,209,144,223,251,129,233,55,81,60,175,138,195,210,165,45,
			7,201,181,3,118,57,115,64,33,209,210,205,179,197,91,41,227,157,
			150,91,143,235,198,126,109,163,130,110,165,180,216,175,57,135,
			249,221,157,140,125,189,158,4,81,175,147,246,89,192>>,
	MK = crypto:hash(sha, [Identity, IK, CK]),
			<<Kencr:16/binary, Kaut:16/binary, MSK:64/binary,
			EMSK:64/binary>> = ocs_eap_aka:prf(MK).

%%---------------------------------------------------------------------
%%  Internal functions
%%---------------------------------------------------------------------

