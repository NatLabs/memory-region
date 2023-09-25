import BTree "mo:stableheapbtreemap/BTree";
import Order "mo:base/Order";

module {

    type SearchResult = {
        #keyFound : Nat;
        #notFound : Nat;
    };

    type Node<K, V> = {
        #leaf : Leaf<K, V>;
        #internal : Internal<K, V>;
    };

    type Data<K, V> = {
        kvs : [var ?(K, V)];
        var count : Nat;
    };

    type Internal<K, V> = {
        data : Data<K, V>;
        children : [var ?Node<K, V>];
    };

    type Leaf<K, V> = {
        data : Data<K, V>;
    };

    type BTree<K, V> = {
        var root : Node<K, V>;
        var size : Nat;
        order : Nat;
    };

    type BinarySearchFn<K, V> = ([var ?(K, V)], (K, K) -> Order.Order, K, Nat) -> SearchResult;

    // helper fn
    func getFromLeaf<K, V>(leafNode : Leaf<K, V>, binarySearch : BinarySearchFn<K, V>, compare : (K, K) -> Order.Order, key : K) : ?(K, V) {
        switch (binarySearch(leafNode.data.kvs, compare, key, leafNode.data.count)) {
            case (#keyFound(index)) leafNode.data.kvs[index];
            case _ null;
        };
    };

    // helper fn
    func getFromInternal<K, V>(internalNode : Internal<K, V>, binarySearch : BinarySearchFn<K, V>, compare : (K, K) -> Order.Order, key : K) : ?(K, V) {
        switch (binarySearch(internalNode.data.kvs, compare, key, internalNode.data.count)) {
            case (#keyFound(index)) internalNode.data.kvs[index];
            case (#notFound(index)) {
                switch (internalNode.children[index]) {
                    case null { null };
                    case (? #leaf(leafNode)) {
                        getFromLeaf(leafNode, binarySearch, compare, key);
                    };
                    case (? #internal(internalNode)) {
                        getFromInternal(internalNode, binarySearch, compare, key);
                    };
                };
            };
        };
    };

    // Retrieves a key-value pair where the key is less than the given key
    public func getPrevious<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?(K, V) {
        func binarySearchPreviousNode(array : [var ?(K, V)], compare : (K, K) -> Order.Order, searchKey : K, maxIndex : Nat) : SearchResult {
            if (maxIndex == 0) {
                return #notFound(0);
            };

            var left : Nat = 0;
            var right = maxIndex;
            while (left < right) {
                let middle = (left + right) / 2;
                switch (array[middle]) {
                    case null { assert false };
                    case (?(key, _)) {
                        switch (compare(searchKey, key)) {
                            case (#equal) {
                                // Ensure that there is a previous node in the array
                                if (middle > 0) {
                                    return #keyFound(middle - 1);
                                } else {
                                    return #notFound(middle);
                                };
                            };
                            case (#greater) { left := middle + 1 };
                            case (#less) {
                                right := middle;
                            };
                        };
                    };
                };
            };

            if (left == 0) {
                return #notFound(0);
            };

            #keyFound(left - 1);
        };

        switch (tree.root) {
            case (#internal(internalNode)) {
                getFromInternal(internalNode, binarySearchPreviousNode, compare, key);
            };
            case (#leaf(leafNode)) {
                getFromLeaf(leafNode, binarySearchPreviousNode, compare, key);
            };
        };
    };

    public func getPreviousKey<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?K {
        switch (getPrevious<K, V>(tree, compare, key)) {
            case null { null };
            case (?ov) { ?ov.0 };
        };
    };

    /// Retrieves an entry where the key is greater than or equal to the given key
    public func getCeiling<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?(K, V) {

        let binarySearchCeilingNode : BinarySearchFn<K, V> = (
            func(array : [var ?(K, V)], compare : (K, K) -> Order.Order, searchKey : K, maxIndex : Nat) : SearchResult {
                // if all elements in the array are null (i.e. first element is null), return #notFound(0)
                if (maxIndex == 0) {
                    return #notFound(0);
                };

                // Initialize search from first to last index
                var left : Nat = 0;
                var right = maxIndex; // maxIndex does not necessarily mean array.size() - 1
                // Search the array
                while (left < right) {
                    let middle = (left + right) / 2;
                    switch (array[middle]) {
                        case null { assert false };
                        case (?(key, _)) {
                            switch (compare(searchKey, key)) {
                                // If the search key element is present at the middle itself
                                case (#equal) { return #keyFound(middle) };
                                // If search key element is greater than mid, it can only be present in right subarray
                                case (#greater) { left := middle + 1 };
                                // If search key element is smaller than mid, it can only be present in left subarray
                                case (#less) {
                                    right := middle;
                                };
                            };
                        };
                    };
                };

                if (left == array.size() or (array[left] : ?(Any, Any)) == null) {
                    return #notFound(left);
                };

                #keyFound(left);
            }
        );

        switch (tree.root) {
            case (#internal(internalNode)) {
                getFromInternal<K, V>(internalNode, binarySearchCeilingNode, compare, key);
            };
            case (#leaf(leafNode)) {
                getFromLeaf<K, V>(leafNode, binarySearchCeilingNode, compare, key);
            };
        };
    };

    public func getCeilingKey<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?K {
        switch (getCeiling<K, V>(tree, compare, key)) {
            case null { null };
            case (?ov) { ?ov.0 };
        };
    };

    public func getCeilingValue<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?V {
        switch (getCeiling<K, V>(tree, compare, key)) {
            case null { null };
            case (?ov) { ?ov.1 };
        };
    };

    // Retrieves a key-value pair where the key is greater than the given key
    public func getNext<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?(K, V) {
        func binarySearchNextNode(array : [var ?(K, V)], compare : (K, K) -> Order.Order, searchKey : K, maxIndex : Nat) : SearchResult {
            if (maxIndex == 0) {
                return #notFound(0);
            };

            var left : Nat = 0;
            var right = maxIndex;
            while (left < right) {
                let middle = (left + right) / 2;
                switch (array[middle]) {
                    case null { assert false };
                    case (?(key, _)) {
                        switch (compare(searchKey, key)) {
                            case (#equal) {
                                // Ensure that there is a next node in the array
                                if (middle + 1 < array.size() and (array[middle + 1] : ?(Any, Any)) != null) {
                                    return #keyFound(middle + 1);
                                } else {
                                    return #notFound(middle + 1);
                                };
                            };
                            case (#greater) { left := middle + 1 };
                            case (#less) {
                                right := middle;
                            };
                        };
                    };
                };
            };

            if (left == array.size() or (array[left] : ?(Any, Any)) == null) {
                return #notFound(left);
            };

            #keyFound(left);
        };

        switch (tree.root) {
            case (#internal(internalNode)) {
                getFromInternal(internalNode, binarySearchNextNode, compare, key);
            };
            case (#leaf(leafNode)) {
                getFromLeaf(leafNode, binarySearchNextNode, compare, key);
            };
        };
    };

    public func getNextKey<K, V>(tree : BTree.BTree<K, V>, compare : (K, K) -> Order.Order, key : K) : ?K {
        switch (getNext<K, V>(tree, compare, key)) {
            case null { null };
            case (?ov) { ?ov.0 };
        };
    };
};
