import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Order {
  'id' : bigint,
  'tokenId' : TokenId,
  'owner' : Principal,
  'isBuy' : boolean,
  'price' : number,
  'amount' : number,
}
export type TokenId = string;
export interface _SERVICE {
  'createToken' : ActorMethod<[TokenId, number], undefined>,
  'deposit' : ActorMethod<[TokenId, number], undefined>,
  'executeTrade' : ActorMethod<[bigint, bigint], undefined>,
  'getOrder' : ActorMethod<[bigint], [] | [Order]>,
  'getOrderBook' : ActorMethod<[TokenId], Array<Order>>,
  'getTokenBalance' : ActorMethod<[TokenId], [] | [number]>,
  'getUserBalance' : ActorMethod<[Principal, TokenId], [] | [number]>,
  'placeOrder' : ActorMethod<[TokenId, boolean, number, number], bigint>,
  'withdraw' : ActorMethod<[TokenId, number], undefined>,
}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
