export const idlFactory = ({ IDL }) => {
  const TokenId = IDL.Text;
  const Order = IDL.Record({
    'id' : IDL.Nat,
    'tokenId' : TokenId,
    'owner' : IDL.Principal,
    'isBuy' : IDL.Bool,
    'price' : IDL.Float64,
    'amount' : IDL.Float64,
  });
  return IDL.Service({
    'createToken' : IDL.Func([TokenId, IDL.Float64], [], []),
    'deposit' : IDL.Func([TokenId, IDL.Float64], [], []),
    'executeTrade' : IDL.Func([IDL.Nat, IDL.Nat], [], []),
    'getOrder' : IDL.Func([IDL.Nat], [IDL.Opt(Order)], ['query']),
    'getOrderBook' : IDL.Func([TokenId], [IDL.Vec(Order)], ['query']),
    'getTokenBalance' : IDL.Func([TokenId], [IDL.Opt(IDL.Float64)], ['query']),
    'getUserBalance' : IDL.Func(
        [IDL.Principal, TokenId],
        [IDL.Opt(IDL.Float64)],
        ['query'],
      ),
    'placeOrder' : IDL.Func(
        [TokenId, IDL.Bool, IDL.Float64, IDL.Float64],
        [IDL.Nat],
        [],
      ),
    'withdraw' : IDL.Func([TokenId, IDL.Float64], [], []),
  });
};
export const init = ({ IDL }) => { return []; };
