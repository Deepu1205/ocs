%%% ocs_eap_codec.erl
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
%%% @doc This library module implements encoding and decoding (CODEC)
%%% 	functions for the Extensible Authentication Protocol (EAP) in the
%%% 	{@link //ocs. ocs} application.
%%%
%%% @reference <a href="http://tools.ietf.org/html/rfc3748">
%%% 	RFC3748 - Extensible Authentication Protocol (EAP)</a>
%%%
%%% @reference <a href="http://tools.ietf.org/html/rfc5931">
%%% 	RFC5931 - EAP Authentication Using Only a Password</a>
%%%
%%% @reference <a href="http://tools.ietf.org/html/rfc4187">
%%% 	RFC4187 - EAP Method for 3rd Generation
%%% 	Authentication and Key Agreement (EAP-AKA)</a>
%%%
%%% @reference <a href="http://tools.ietf.org/html/rfc5448">
%%% 	RFC5448 - Improved EAP Method for 3rd Generation
%%% 	Authentication and Key Agreement (EAP-AKA')</a>
%%%
-module(ocs_eap_codec).
-copyright('Copyright (c) 2016 - 2017 SigScale Global Inc.').

%% export the ocs public API
-export([eap_packet/1, eap_pwd/1, eap_pwd_id/1, eap_pwd_commit/1,
			eap_ttls/1, eap_aka/1, aka_attr/1]).

-include("ocs_eap_codec.hrl").

%%----------------------------------------------------------------------
%%  The ocs_eap_codec public API
%%----------------------------------------------------------------------

-spec eap_packet(Packet) -> Result 
	when
		Packet :: binary() | #eap_packet{},
		Result :: #eap_packet{} | binary().
%% @doc Encode or decode an EAP packet transported in the RADIUS `EAP-Message'
%% attribute.
eap_packet(<<?EapSuccess, Identifier, 4:16>> = _Packet) ->
	#eap_packet{code = success, identifier = Identifier};
eap_packet(<<?EapFailure, Identifier, 4:16>>) ->
	#eap_packet{code = failure, identifier = Identifier};
eap_packet(<<?EapRequest, Identifier, Length:16, Type, _/binary>> = Packet)
		when size(Packet) >= Length ->
	Data = binary:part(Packet, 5, Length - 5),
	#eap_packet{code = request, type = Type, identifier = Identifier, data = Data};
eap_packet(<<?EapResponse, Identifier, Length:16, Type, _/binary>> = Packet)
		when size(Packet) >= Length ->
	Data = binary:part(Packet, 5, Length - 5),
	#eap_packet{code = response, type = Type, identifier = Identifier, data = Data};
eap_packet(#eap_packet{code = success, identifier = Identifier}) ->
	<<?EapSuccess, Identifier, 4:16>>;
eap_packet(#eap_packet{code = failure, identifier = Identifier}) ->
	<<?EapFailure, Identifier, 4:16>>;
eap_packet(#eap_packet{code = request, type = Type,
		identifier = Identifier, data = Data})
		when is_integer(Type), is_integer(Identifier), is_binary(Data) ->
	Length = size(Data) + 5,
	<<?EapRequest, Identifier, Length:16, Type, Data/binary>>;
eap_packet(#eap_packet{code = response, type = Type,
		identifier = Identifier, data = Data})
		when is_integer(Type), is_integer(Identifier), is_binary(Data) ->
	Length = size(Data) + 5,
	<<?EapResponse, Identifier, Length:16, Type, Data/binary>>.

-spec eap_pwd(Packet) -> Result
	when
		Packet :: binary() | #eap_pwd{},
		Result :: #eap_pwd{} | binary().
%% @doc Encode or Decode an EAP-PWD-Header packet transported in the
%% RADIUS `EAP-Message' attribute.
%%
%% RFC-5931 3.1
eap_pwd(#eap_pwd{length = true, more = true, pwd_exch = id, data = D } = Packet) ->
	TLen = Packet#eap_pwd.tot_length,
	<<1:1, 1:1, 1:6, TLen:16, D/binary>>;
eap_pwd(#eap_pwd{length = true, more = true, pwd_exch = commit, data = D } = Packet) ->
	TLen = Packet#eap_pwd.tot_length,
	<<1:1, 1:1, 2:6, TLen:16, D/binary>>;
eap_pwd(#eap_pwd{length = true, more = true, pwd_exch = confirm, data = D } = Packet) ->
	TLen = Packet#eap_pwd.tot_length,
	<<1:1, 1:1, 3:6, TLen:16, D/binary>>;
eap_pwd(#eap_pwd{length = true, more = false, pwd_exch = id, data = D } = Packet) ->
	TLen = Packet#eap_pwd.tot_length,
	<<1:1, 0:1, 1:6, TLen:16, D/binary>>;
eap_pwd(#eap_pwd{length = true, more = false, pwd_exch = commit, data = D } = Packet) ->
	TLen = Packet#eap_pwd.tot_length,
	<<1:1, 0:1, 2:6, TLen:16, D/binary>>;
eap_pwd(#eap_pwd{length = true, more = false, pwd_exch = confirm, data = D } = Packet) ->
	TLen = Packet#eap_pwd.tot_length,
	<<1:1, 0:1, 3:6, TLen:16, D/binary>>;
eap_pwd(#eap_pwd{length = false, more = true, pwd_exch = id, data = D } = _Packet) ->
	<<0:1, 1:1, 1:6, D/binary>>;
eap_pwd(#eap_pwd{length = false, more = true, pwd_exch = commit, data = D } = _Packet) ->
	<<0:1, 1:1, 2:6, D/binary>>;
eap_pwd(#eap_pwd{length = false, more = true, pwd_exch = confirm, data = D } = _Packet) ->
	<<0:1, 1:1, 3:6, D/binary>>;
eap_pwd(#eap_pwd{length = false, more = false, pwd_exch = id, data = D } = _Packet) ->
	<<0:1, 0:1, 1:6, D/binary>>;
eap_pwd(#eap_pwd{length = false, more = false, pwd_exch = commit, data = D } = _Packet) ->
	<<0:1, 0:1, 2:6, D/binary>>;
eap_pwd(#eap_pwd{length = false, more = false, pwd_exch = confirm, data = D } = _Packet) ->
	<<0:1, 0:1, 3:6, D/binary>>;
eap_pwd(<<1:1, 1:1, 1:6, TotLength:16, Payload/binary>>) ->
	#eap_pwd{length = true, more = true, pwd_exch = id,
			tot_length = TotLength, data = Payload};
eap_pwd(<<1:1, 1:1, 2:6, TotLength:16, Payload/binary>>) ->
	#eap_pwd{length = true, more = true, pwd_exch = commit,
			tot_length = TotLength, data = Payload};
eap_pwd(<<1:1, 1:1, 3:6, TotLength:16, Payload/binary>>) ->
	#eap_pwd{length = true, more = true, pwd_exch = confirm,
			tot_length = TotLength, data = Payload};
eap_pwd(<<0:1, 1:1, 1:6, Payload/binary>>) ->
	#eap_pwd{length = false, more = true, pwd_exch = id,
			data = Payload};
eap_pwd(<<0:1, 1:1, 2:6, Payload/binary>>) ->
	#eap_pwd{length = false, more = true, pwd_exch = confirm,
			data = Payload};
eap_pwd(<<0:1, 1:1, 3:6, Payload/binary>>) ->
	#eap_pwd{length = false, more = true, pwd_exch = confirm,
			data = Payload};
eap_pwd(<<0:1, 0:1, 1:6, Payload/binary>>) ->
	#eap_pwd{length = false, more = false, pwd_exch = id,
			data = Payload};
eap_pwd(<<0:1, 0:1, 2:6, Payload/binary>>) ->
	#eap_pwd{length = false, more = false, pwd_exch = commit,
			data = Payload};
eap_pwd(<<0:1, 0:1, 3:6, Payload/binary>>) ->
	#eap_pwd{length = false, more = false, pwd_exch = confirm,
			data = Payload}.

-spec eap_pwd_id(Packet) -> Result
	when
		Packet :: binary() | #eap_pwd_id{},
		Result :: #eap_pwd_id{} | binary().
%% @doc Encode or Decode `EAP-pwd-ID'
%%
%% RFC-5931 3.2.1
%% Comprise the Ciphersuite included in the calculation of the
%% peer's and server's confirm messages
eap_pwd_id(<<GDesc:16, RanFun, PRF, Token:4/binary, 0, Identity/binary>>) ->
	#eap_pwd_id{group_desc = GDesc, random_fun = RanFun, prf = PRF,
		token = Token, pwd_prep = none, identity = Identity};
eap_pwd_id(<<GDesc:16, RanFun, PRF, Token:4/binary, 1, Identity/binary>>) ->
	#eap_pwd_id{group_desc = GDesc, random_fun = RanFun, prf = PRF,
		token = Token, pwd_prep = rfc2759, identity = Identity};
eap_pwd_id(<<GDesc:16, RanFun, PRF, Token:4/binary, 2, Identity/binary>>) ->
	#eap_pwd_id{group_desc = GDesc, random_fun = RanFun, prf = PRF,
		token = Token, pwd_prep = saslprep, identity = Identity};
eap_pwd_id(#eap_pwd_id{group_desc = GDesc, random_fun = RanFun, prf = PRF,
		token = Token, pwd_prep = none, identity = Identity})
		when size(Token) == 4, is_binary(Identity) ->
	<<GDesc:16, RanFun, PRF, Token/binary, 0, Identity/binary>>;
eap_pwd_id(#eap_pwd_id{group_desc = GDesc, random_fun = RanFun, prf = PRF,
		token = Token, pwd_prep = rfc2759, identity = Identity})
		when size(Token) == 4, is_binary(Identity) ->
	<<GDesc:16, RanFun, PRF, Token/binary, 1, Identity/binary>>;
eap_pwd_id(#eap_pwd_id{group_desc = GDesc, random_fun = RanFun, prf = PRF,
		token = Token, pwd_prep = saslprep, identity = Identity})
		when size(Token) == 4, is_binary(Identity) ->
	<<GDesc:16, RanFun, PRF, Token/binary, 2, Identity/binary>>.

-spec eap_pwd_commit(Packet) -> Result 
	when
		Packet :: binary() | #eap_pwd_commit{},
		Result :: #eap_pwd_commit{} | binary().
%% @doc Encode or Decode `EAP-pwd-commit'
%%
%%RFC-5931 3.2.2
%% Element, Scalar are generated by server (in EAP-PWD-Commit/Request) and
%% peer (in EAP-PWD-Commit/Response)
eap_pwd_commit(<<Element:64/binary, Scalar:32/binary>>) ->
	#eap_pwd_commit{element = Element, scalar = Scalar};
eap_pwd_commit(#eap_pwd_commit{element = Element, scalar = Scalar}) ->
	<<Element:64/binary, Scalar:32/binary>>.

-spec eap_ttls(Packet) -> Result
	when
		Packet :: binary() | #eap_ttls{},
		Result :: #eap_ttls{} | binary().
%% @doc Encode or Decode `EAP-TTLS' packet
%%
%% RFC-5281 9.1
eap_ttls(#eap_ttls{message_len = undefined, more = false, start = false,
		version = Version, data = Data}) when is_integer(Version) ->
	<<0:1, 0:1, 0:1, 0:2, Version:3, Data/binary>>;
eap_ttls(#eap_ttls{message_len = undefined, more = false, start = true,
		version = Version, data = Data}) when is_integer(Version) ->
	<<0:1, 0:1, 1:1, 0:2, Version:3, Data/binary>>;
eap_ttls(#eap_ttls{message_len = undefined, more = true, start = false,
		version = Version, data = Data}) when is_integer(Version) ->
	<<0:1, 1:1, 0:1, 0:2, Version:3, Data/binary>>;
eap_ttls(#eap_ttls{message_len = undefined, more = true, start = true,
		version = Version, data = Data}) when is_integer(Version) ->
	<<0:1, 1:1, 1:1, 0:2, Version:3, Data/binary>>;
eap_ttls(#eap_ttls{message_len = Length, more = true, start = false,
		version = Version, data = Data})
		when is_integer(Version), is_integer(Length) ->
	<<1:1, 1:1, 0:1, 0:2, Version:3, Length:32, Data/binary>>;
eap_ttls(#eap_ttls{message_len = Length, more = true, start = true,
		version = Version, data = Data})
		when is_integer(Version), is_integer(Length) ->
	<<1:1, 1:1, 1:1, 0:2, Version:3, Length:32, Data/binary>>;
eap_ttls(#eap_ttls{message_len = Length, more = false, start = false,
		version = Version, data = Data})
		when is_integer(Version), is_integer(Length) ->
	<<1:1, 0:1, 0:1, 0:2, Version:3, Length:32, Data/binary>>;
eap_ttls(<<0:1, 0:1, 0:1, _:2, Version:3, Data/binary>>) ->
	#eap_ttls{version = Version, data = Data};
eap_ttls(<<0:1, 0:1, 1:1, _:2, Version:3, Data/binary>>) ->
	#eap_ttls{start = true, version = Version, data = Data};
eap_ttls(<<0:1, 1:1, 0:1, _:2, Version:3, Data/binary>>) ->
	#eap_ttls{more = true, version = Version, data = Data};
eap_ttls(<<0:1, 1:1, 1:1, _:2, Version:3, Data/binary>>) ->
	#eap_ttls{more = true, start = true, version = Version, data = Data};
eap_ttls(<<1:1, 0:1, 0:1, _:2, Version:3, Length:32, Data/binary>>) ->
	#eap_ttls{version = Version, message_len = Length, data = Data};
eap_ttls(<<1:1, 1:1, 0:1, _:2, Version:3, Length:32, Data/binary>>) ->
	#eap_ttls{more = true, version = Version, message_len = Length, data = Data};
eap_ttls(<<1:1, 1:1, 1:1, _:2, Version:3, Length:32, Data/binary>>) ->
	#eap_ttls{more = true, start = true, version = Version,
			message_len = Length, data = Data}.

-spec eap_aka(Message) -> Message
	when
		Message :: binary()
				| #eap_aka_identity{}
				| #eap_aka_challenge{}
				| #eap_aka_reauthentication{}
				| #eap_aka_notification{}
				| #eap_aka_authentication_reject{}
				| #eap_aka_synchronization_failure{}
				| #eap_aka_client_error{}.
%% @doc Encode or decode an EAP-AKA message.
%%
%% RFC4187 section 8.1
%%
eap_aka(#eap_aka_challenge{} = _Message) ->
	<<1, 0:16, <<>>/binary>>;
eap_aka(#eap_aka_authentication_reject{}) ->
	<<2, 0:16, <<>>/binary>>;
eap_aka(#eap_aka_synchronization_failure{}) ->
	<<4, 0:16, <<>>/binary>>;
eap_aka(#eap_aka_identity{}) ->
	<<5, 0:16, <<>>/binary>>;
eap_aka(#eap_aka_notification{}) ->
	<<12, 0:16, <<>>/binary>>;
eap_aka(#eap_aka_reauthentication{}) ->
	<<13, 0:16, <<>>/binary>>;
eap_aka(#eap_aka_client_error{}) ->
	<<14, 0:16, <<>>/binary>>;
eap_aka(<<1, _:16, Attributes/binary>>) ->
	F = fun(?AT_RAND, Rand, Acc) ->
				Acc#eap_aka_challenge{rand = Rand};
			(?AT_AUTN, Autn, Acc) ->
				Acc#eap_aka_challenge{autn = Autn};
			(?AT_MAC, Mac, Acc) ->
				Acc#eap_aka_challenge{mac = Mac};
			(?AT_RESULT_IND, ResultInd, Acc) ->
				Acc#eap_aka_challenge{result_ind = ResultInd};
			(?AT_RES, Res, Acc) ->
				Acc#eap_aka_challenge{res = Res};
			(?AT_CHECKCODE, Code, Acc) ->
				Acc#eap_aka_challenge{checkcode = Code};
			(?AT_IV, Iv, Acc) ->
				Acc#eap_aka_challenge{iv = Iv};
			(?AT_ENCR_DATA, EncrData, Acc) ->
				Acc#eap_aka_challenge{encr_data = EncrData}
	end,
	maps:fold(F, #eap_aka_challenge{}, aka_attr(Attributes));
eap_aka(<<2, _:16, _Attributes/binary>>) ->
	#eap_aka_authentication_reject{};
eap_aka(<<4, _:16, Attributes/binary>>) ->
	F = fun(?AT_AUTS, Auts, Acc) ->
				Acc#eap_aka_synchronization_failure{auts = Auts}
	end,
	maps:fold(F, #eap_aka_synchronization_failure{}, aka_attr(Attributes));
eap_aka(<<5, _:16, Attributes/binary>>) ->
	F = fun(?AT_PERMANENT_ID_REQ, PermanentIdReq, Acc) ->
				Acc#eap_aka_identity{permanent_id_req = PermanentIdReq};
			(?AT_FULLAUTH_ID_REQ, FullAuthReq, Acc) ->
				Acc#eap_aka_identity{fullauth_id_req = FullAuthReq};
			(?AT_ANY_ID_REQ, AnyIdReq, Acc) ->
				Acc#eap_aka_identity{any_id_req = AnyIdReq};
			(?AT_IDENTITY, Identity, Acc) ->
				Acc#eap_aka_identity{identity = Identity}
	end,
	maps:fold(F, #eap_aka_identity{}, aka_attr(Attributes));
eap_aka(<<12, _:16, Attributes/binary>>) ->
	F = fun(?AT_NOTIFICATION, Notification, Acc) ->
				Acc#eap_aka_notification{notification = Notification};
			(?AT_MAC, Mac, Acc) ->
				Acc#eap_aka_notification{mac = Mac};
			(?AT_IV, Iv, Acc) ->
				Acc#eap_aka_notification{iv = Iv};
			(?AT_ENCR_DATA, EncrData, Acc) ->
				Acc#eap_aka_notification{encr_data = EncrData}
	end,
	maps:fold(F, #eap_aka_notification{}, aka_attr(Attributes));
eap_aka(<<13, _:16, Attributes/binary>>) ->
	F = fun(?AT_MAC, Mac, Acc) ->
				Acc#eap_aka_reauthentication{mac = Mac};
			(?AT_RESULT_IND, ResultInd, Acc) ->
				Acc#eap_aka_reauthentication{result_ind = ResultInd};
			(?AT_CHECKCODE, Code, Acc) ->
				Acc#eap_aka_reauthentication{checkcode = Code};
			(?AT_IV, Iv, Acc) ->
				Acc#eap_aka_reauthentication{iv = Iv};
			(?AT_ENCR_DATA, EncrData, Acc) ->
				Acc#eap_aka_reauthentication{encr_data = EncrData}
	end,
	maps:fold(F, #eap_aka_reauthentication{}, aka_attr(Attributes));
eap_aka(<<14, _:16, Attributes/binary>>) ->
	F = fun(?AT_AUTS, Auts, Acc) ->
				Acc#eap_aka_synchronization_failure{auts = Auts}
	end,
	maps:fold(F, #eap_aka_synchronization_failure{}, aka_attr(Attributes)).

%%----------------------------------------------------------------------
%%  internal functions
%%----------------------------------------------------------------------

-spec aka_attr(Attributes) -> Attributes
	when
		Attributes :: map() | binary().
%% @doc Encode or decode EAP-AKA attributes.
%% @hidden
aka_attr(Attributes) when is_binary(Attributes)->
	aka_attr(Attributes, #{});
aka_attr(Attributes) when is_tuple(Attributes)->
	aka_attr(Attributes, <<>>).
%% @hidden
aka_attr(<<?AT_RAND, 5, _:16, Rand:16/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_RAND => Rand});
aka_attr(<<?AT_AUTN, 5, _:16, Autn:16/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_AUTN => Autn});
aka_attr(<<?AT_RES, L1, _/bytes>> = B, Acc) ->
	L2 = (L1 * 4) - 4,
	<<_:16, L3:16, Data:L2/bytes, Rest/bytes>> = B,
	<<Res:L3/bits, _/bits>> = Data,
	aka_attr(Rest, Acc#{?AT_RES => Res});
aka_attr(<<?AT_AUTS, 4, Auts:14/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_AUTS => Auts});
aka_attr(<<?AT_PADDING, L1, _/bytes>> = B, Acc) ->
	L2 = (L1 * 4) - 2,
	<<_:16, _:L2/bytes, Rest/bytes>> = B,
	aka_attr(Rest, Acc);
aka_attr(<<?AT_PERMANENT_ID_REQ, 1, _:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_PERMANENT_ID_REQ => true});
aka_attr(<<?AT_MAC, 5, _:16, Mac:16/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_MAC => Mac});
aka_attr(<<?AT_NOTIFICATION, 1, Code:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_NOTIFICATION => Code});
aka_attr(<<?AT_ANY_ID_REQ, 1, _:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_ANY_ID_REQ => true});
aka_attr(<<?AT_IDENTITY, L1, _/bytes>> = B, Acc) ->
	L2 = (L1 * 4) - 4,
	<<_:16, L3:16, Data:L2/bytes, Rest/bytes>> = B,
	<<Identity:L3/bytes, _/bytes>> = Data,
	aka_attr(Rest, Acc#{?AT_IDENTITY => Identity});
aka_attr(<<?AT_FULLAUTH_ID_REQ, 1, _:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_FULLAUTH_ID_REQ => true});
aka_attr(<<?AT_COUNTER, 1, Counter:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_COUNTER => Counter});
aka_attr(<<?AT_COUNTER_TOO_SMALL, 1, _:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_COUNTER_TOO_SMALL => true});
aka_attr(<<?AT_NONCE_S, 5, _:16, Nonce:16/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_NONCE_S => Nonce});
aka_attr(<<?AT_CLIENT_ERROR_CODE, 1, Code:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_CLIENT_ERROR_CODE => Code});
aka_attr(<<?AT_IV, 5, _:16, Iv:16/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_IV => Iv});
aka_attr(<<?AT_ENCR_DATA, L1, _/bytes>> = B, Acc) ->
	L2 = (L1 * 4) - 4,
	<<_:32, EncrData:L2/bytes, Rest/bytes>> = B,
	aka_attr(Rest, Acc#{?AT_ENCR_DATA => EncrData});
aka_attr(<<?AT_NEXT_PSEUDONYM, L1, _/bytes>> = B, Acc) ->
	L2 = (L1 * 4) - 4,
	<<_:16, L3:16, Data:L2/bytes, Rest/bytes>> = B,
	<<NextPseudonym:L3/bytes, _/bytes>> = Data,
	aka_attr(Rest, Acc#{?AT_NEXT_PSEUDONYM => NextPseudonym});
aka_attr(<<?AT_NEXT_REAUTH_ID, L1, _/bytes>> = B, Acc) ->
	L2 = (L1 * 4) - 4,
	<<_:16, L3:16, Data:L2/bytes, Rest/bytes>> = B,
	<<NextReauthId:L3/bytes, _/bytes>> = Data,
	aka_attr(Rest, Acc#{?AT_NEXT_REAUTH_ID => NextReauthId});
aka_attr(<<?AT_CHECKCODE, 1, _:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_CHECKCODE => <<>>});
aka_attr(<<?AT_CHECKCODE, 6, _:16, CheckCode:20/bytes, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_CHECKCODE => CheckCode});
aka_attr(<<?AT_RESULT_IND, 1, _:16, Rest/bytes>>, Acc) ->
	aka_attr(Rest, Acc#{?AT_CHECKCODE => true});
aka_attr(<<Type, 1, _:16, Rest/bytes>>, Acc) when Type > 127 ->
	aka_attr(Rest, Acc);
aka_attr(<<>>, Acc) ->
	Acc.

