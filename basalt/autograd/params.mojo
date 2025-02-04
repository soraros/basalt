from tensor import TensorShape
from collections.optional import Optional

from basalt import max_rank, dtype
from .symbol import Symbol
from .attributes import Attribute, AttributeVector


@value
struct Param(CollectionElement, Stringable):
    var data: Optional[DynamicVector[SIMD[dtype, 1]]]
    var initializer: Optional[Attribute]

    fn __init__(inout self):
        self.data = None
        self.initializer = None
    
    fn __init__(inout self, data: DynamicVector[SIMD[dtype, 1]]):
        self.data = data
        self.initializer = None

    fn __init__(inout self, a: SIMD[dtype, 1]):
        var data = DynamicVector[SIMD[dtype, 1]]()
        data.push_back(a)
        self.data = data
        self.initializer = None

    fn __init__(inout self, initializer: String, *args: SIMD[dtype, 1]):
        # Supported initializers:
        #   "random_uniform", lower_bound, upper_bound 
        #   "random_normal", mean, std
        #   #TODO: "kaiming_uniform", mode, nonlinearity
        #   #TODO: "kaiming_normal", mode, nonlinearity
        self.initializer = Attribute("initializer", initializer)
        var data = DynamicVector[SIMD[dtype, 1]]()
        for arg in args:
            data.push_back(arg)
        self.data = data

    fn __getitem__(self, i: Int) -> Optional[SIMD[dtype, 1]]:
        if self.data:
            return self.data.value()[i]
        else:
            return None

    fn __str__(self) -> String:
        var s: String = ""
        if self.data:
            var data = self.data.value()
            s += "["
            for i in range(len(data)):
                s += str(data[i])
                if i < len(data) - 1:
                    s += ", "
            s += "]"
        return s


@value
struct ParamDict(Sized):
    var symbols: DynamicVector[Symbol]
    var values: DynamicVector[Param]

    fn __init__(inout self):
        self.symbols = DynamicVector[Symbol]()
        self.values = DynamicVector[Param]()

    fn put(inout self, param_id: Symbol, value: Optional[Param] = None):
        self.symbols.push_back(param_id)
        if value:
            # Initialized parameter
            self.values.push_back(value.value())
        else:
            # Uninitialized parameter
            self.values.push_back(Param())

    fn get_tensor(self, idx: Int) -> Tensor[dtype]:
        # May only be called at runtime
        var t = Tensor[dtype](self.symbols[idx].shape())
        for i in range(t.num_elements()):
            t[i] = self.values[idx][i].value()
        return t ^

    fn __len__(self) -> Int:
        return len(self.symbols)