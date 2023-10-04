import Order "mo:base/Order";
import Result "mo:base/Result";
import Prelude "mo:base/Prelude";

module {
    type Order = Order.Order;
    public type FirstTupleItemCompare<A> = (a : (A, Any), b : (A, Any)) -> Order;
    public type SecondTupleItemCompare<B> = (a : (Any, B), b : (Any, B)) -> Order;

    public func cmp_first_tuple_item<A>(cmp : (A, A) -> Order) : FirstTupleItemCompare<A> {
        func(a : (A, Any), b : (A, Any)) : Order {
            cmp(a.0, b.0);
        };
    };

    public func cmp_second_tuple_item<B>(cmp : (B, B) -> Order) : SecondTupleItemCompare<B> {
        func(a : (Any, B), b : (Any, B)) : Order {
            cmp(a.1, b.1);
        };
    };

    type Result<A, B> = Result.Result<A, B>;
    
    public func send_error<OldOk, NewOk, Error>(res: Result<OldOk, Error>): Result<NewOk, Error>{
        switch (res) {
            case (#ok(_)) Prelude.unreachable();
            case (#err(errorMsg)) #err(errorMsg);
        };
    };
    

    public func div_ceil(n: Nat, d: Nat) : Nat {
       (n + (d - 1)) / d;
    };
};
