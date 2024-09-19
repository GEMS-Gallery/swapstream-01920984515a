import Bool "mo:base/Bool";
import Order "mo:base/Order";

import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";

actor DEX {
    // Types
    type TokenId = Text;
    type Order = {
        id: Nat;
        owner: Principal;
        tokenId: TokenId;
        isBuy: Bool;
        amount: Float;
        price: Float;
    };

    // State variables
    stable var nextOrderId: Nat = 0;
    stable var tokenEntries: [(TokenId, Float)] = [];
    stable var balanceEntries: [(Principal, [(TokenId, Float)])] = [];
    stable var orderEntries: [(Nat, Order)] = [];

    var tokens = HashMap.HashMap<TokenId, Float>(10, Text.equal, Text.hash);
    var balances = HashMap.HashMap<Principal, HashMap.HashMap<TokenId, Float>>(10, Principal.equal, Principal.hash);
    var orders = HashMap.HashMap<Nat, Order>(10, Nat.equal, Hash.hash);

    // Helper function to convert HashMap entries to arrays
    func hashMapToArray<K, V>(hm: HashMap.HashMap<K, V>): [(K, V)] {
        Iter.toArray(hm.entries())
    };

    // Initialize state from stable variables
    system func preupgrade() {
        tokenEntries := hashMapToArray(tokens);
        balanceEntries := Array.map<(Principal, HashMap.HashMap<TokenId, Float>), (Principal, [(TokenId, Float)])>(
            Iter.toArray(balances.entries()),
            func((principal, balanceMap): (Principal, HashMap.HashMap<TokenId, Float>)): (Principal, [(TokenId, Float)]) {
                (principal, hashMapToArray(balanceMap))
            }
        );
        orderEntries := hashMapToArray(orders);
    };

    system func postupgrade() {
        tokens := HashMap.fromIter<TokenId, Float>(tokenEntries.vals(), 10, Text.equal, Text.hash);
        balances := HashMap.HashMap<Principal, HashMap.HashMap<TokenId, Float>>(10, Principal.equal, Principal.hash);
        for ((principal, balanceArray) in balanceEntries.vals()) {
            let balanceMap = HashMap.HashMap<TokenId, Float>(10, Text.equal, Text.hash);
            for ((tokenId, balance) in balanceArray.vals()) {
                balanceMap.put(tokenId, balance);
            };
            balances.put(principal, balanceMap);
        };
        orders := HashMap.fromIter<Nat, Order>(orderEntries.vals(), 10, Nat.equal, Hash.hash);
    };

    // Token management
    public func createToken(tokenId: TokenId, initialSupply: Float) : async () {
        tokens.put(tokenId, initialSupply);
    };

    public query func getTokenBalance(tokenId: TokenId) : async ?Float {
        tokens.get(tokenId)
    };

    // User account management
    public shared(msg) func deposit(tokenId: TokenId, amount: Float) : async () {
        let caller = msg.caller;
        switch (balances.get(caller)) {
            case (null) {
                let newBalance = HashMap.HashMap<TokenId, Float>(10, Text.equal, Text.hash);
                newBalance.put(tokenId, amount);
                balances.put(caller, newBalance);
            };
            case (?userBalance) {
                let currentBalance: Float = Option.get(userBalance.get(tokenId), 0.0);
                userBalance.put(tokenId, currentBalance + amount);
            };
        };
    };

    public shared(msg) func withdraw(tokenId: TokenId, amount: Float) : async () {
        let caller = msg.caller;
        switch (balances.get(caller)) {
            case (null) {
                Debug.trap("No balance found for user");
            };
            case (?userBalance) {
                switch (userBalance.get(tokenId)) {
                    case (null) {
                        Debug.trap("No balance found for token");
                    };
                    case (?balance) {
                        if (balance < amount) {
                            Debug.trap("Insufficient balance");
                        };
                        userBalance.put(tokenId, balance - amount);
                    };
                };
            };
        };
    };

    public query func getUserBalance(user: Principal, tokenId: TokenId) : async ?Float {
        switch (balances.get(user)) {
            case (null) { null };
            case (?userBalance) { userBalance.get(tokenId) };
        }
    };

    // Order book
    public shared(msg) func placeOrder(tokenId: TokenId, isBuy: Bool, amount: Float, price: Float) : async Nat {
        let orderId = nextOrderId;
        nextOrderId += 1;

        let order: Order = {
            id = orderId;
            owner = msg.caller;
            tokenId = tokenId;
            isBuy = isBuy;
            amount = amount;
            price = price;
        };

        orders.put(orderId, order);
        orderId
    };

    public query func getOrder(orderId: Nat) : async ?Order {
        orders.get(orderId)
    };

    public query func getOrderBook(tokenId: TokenId) : async [Order] {
        Iter.toArray(Iter.filter(orders.vals(), func (order: Order) : Bool { order.tokenId == tokenId }))
    };

    // Trade execution
    public shared(msg) func executeTrade(buyOrderId: Nat, sellOrderId: Nat) : async () {
        let buyOrder = Option.get(orders.get(buyOrderId), Debug.trap("Buy order not found"));
        let sellOrder = Option.get(orders.get(sellOrderId), Debug.trap("Sell order not found"));

        assert(buyOrder.tokenId == sellOrder.tokenId);
        assert(buyOrder.isBuy and not sellOrder.isBuy);
        assert(buyOrder.price >= sellOrder.price);

        let tradeAmount = Float.min(buyOrder.amount, sellOrder.amount);
        let tradePrice = sellOrder.price;

        // Update balances
        updateBalance(buyOrder.owner, buyOrder.tokenId, tradeAmount);
        updateBalance(sellOrder.owner, buyOrder.tokenId, -tradeAmount);
        updateBalance(buyOrder.owner, "ICP", -tradeAmount * tradePrice);
        updateBalance(sellOrder.owner, "ICP", tradeAmount * tradePrice);

        // Update orders
        if (buyOrder.amount > tradeAmount) {
            orders.put(buyOrderId, {
                id = buyOrder.id;
                owner = buyOrder.owner;
                tokenId = buyOrder.tokenId;
                isBuy = buyOrder.isBuy;
                amount = buyOrder.amount - tradeAmount;
                price = buyOrder.price;
            });
        } else {
            orders.delete(buyOrderId);
        };

        if (sellOrder.amount > tradeAmount) {
            orders.put(sellOrderId, {
                id = sellOrder.id;
                owner = sellOrder.owner;
                tokenId = sellOrder.tokenId;
                isBuy = sellOrder.isBuy;
                amount = sellOrder.amount - tradeAmount;
                price = sellOrder.price;
            });
        } else {
            orders.delete(sellOrderId);
        };
    };

    // Helper function to update user balance
    private func updateBalance(user: Principal, tokenId: TokenId, amount: Float) {
        switch (balances.get(user)) {
            case (null) {
                let newBalance = HashMap.HashMap<TokenId, Float>(10, Text.equal, Text.hash);
                newBalance.put(tokenId, amount);
                balances.put(user, newBalance);
            };
            case (?userBalance) {
                let currentBalance: Float = Option.get(userBalance.get(tokenId), 0.0);
                userBalance.put(tokenId, currentBalance + amount);
            };
        };
    };
};
