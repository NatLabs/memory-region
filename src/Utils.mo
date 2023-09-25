import Order "mo:base/Order";

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

    public func div_ceil(n: Nat, d: Nat) : Nat {
       n + (d - 1) / d;
    };
};
