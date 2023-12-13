from tensor import Tensor

from dainemo import GRAPH
from dainemo.autograd.node import Node
from dainemo.utils.tensorutils import dot, tsum, elwise_op, elwise_pow, elwise_transform, fill, batch_tensor_elwise_op

from math import add, sub, mul, div, log


'''
Implement forward and backward operations for basic tensor manipulations.
'''

# <------------ADD------------>
struct ADD:
    @staticmethod
    fn forward(n1: Node[dtype], n2: Node[dtype]) -> Node[dtype]:
        '''Forward operation of element wise addition.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype]
        if n1.tensor.shape() == n2.tensor.shape():
            res = elwise_op[dtype, nelts, add](n1.tensor, n2.tensor)
        else:
            res = batch_tensor_elwise_op[dtype, nelts, add](n1.tensor, n2.tensor)
        return GRAPH.create_graph_node[Self.backward](res, n1, n2)

    @staticmethod
    fn backward(ug: Tensor[dtype], tensors: VariadicListMem[Tensor[dtype]], tensor_id: Int) -> Tensor[dtype]:
        '''Backward operation of element wise addition.'''
        # d(x + y) / dx = d(x + y) / dy = 1
        return ug


# <------------SUB------------>
struct SUB:
    @staticmethod
    fn forward(n1: Node[dtype], n2: Node[dtype]) -> Node[dtype]:
        '''Forward operation of element wise subtraction.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype] 
        if n1.tensor.shape() == n2.tensor.shape():
            res = elwise_op[dtype, nelts, sub](n1.tensor, n2.tensor)
        else:
            res = batch_tensor_elwise_op[dtype, nelts, sub](n1.tensor, n2.tensor)
        return GRAPH.create_graph_node[Self.backward](res, n1, n2)

    @staticmethod
    fn backward(ug: Tensor[dtype], tensors: VariadicListMem[Tensor[dtype]], tensor_id: Int) -> Tensor[dtype]:
        '''Backward operation of element wise subtraction.'''
        if tensor_id == 0:
            # d(x - y) / dx = 1
            return ug
        else:
            # d(x - y) / dy = -1
            alias nelts = simdwidthof[dtype]()
            let factor: SIMD[dtype, 1] = -1.0
            return elwise_op[dtype, nelts, mul](factor, ug)


# <------------MUL------------>
struct MUL:
    @staticmethod
    fn forward(n1: Node[dtype], n2: Node[dtype]) -> Node[dtype]:
        '''Forward operation of element wise multiplication.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype]
        if n1.tensor.shape() == n2.tensor.shape():
            res = elwise_op[dtype, nelts, mul](n1.tensor, n2.tensor)
        else:
            res = batch_tensor_elwise_op[dtype, nelts, mul](n1.tensor, n2.tensor)
        return GRAPH.create_graph_node[Self.backward](res, n1, n2)

    @staticmethod
    fn forward(n1: Node[dtype], a: SIMD[dtype, 1]) -> Node[dtype]:
        '''Forward operation of tensor-scalar multiplication.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype] = elwise_op[dtype, nelts, mul](n1.tensor, a)
        var a_tensor: Tensor[dtype] = Tensor[dtype](1)
        a_tensor[0] = a
        return GRAPH.create_graph_node[Self.backward](res, n1, Node[dtype](a_tensor))

    @staticmethod
    fn backward(ug: Tensor[dtype], tensors: VariadicListMem[Tensor[dtype]], tensor_id: Int) -> Tensor[dtype]:
        '''Backward operation of element wise multiplication.'''
        # d(x*y) / dx = y
        # d(x*y) / dy = x 
        let other_id: Int = (tensor_id + 1) % 2
        alias nelts: Int = simdwidthof[dtype]()
        # return elwise_op[dtype, nelts, mul](nodes.get(other_id).tensor, ug)
        return Tensor[dtype](ug.shape()) # TODO: fix this


# <------------DIV------------>
# TODO


# <------------DOT------------>
struct DOT:
    @staticmethod
    fn forward(n1: Node[dtype], n2: Node[dtype]) -> Node[dtype]:
        '''Forward operation of dot product.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype] = dot[dtype, nelts](n1.tensor, n2.tensor)
        return GRAPH.create_graph_node[Self.backward](res, n1, n2)

    @staticmethod
    fn backward(ug: Tensor[dtype], tensors: VariadicListMem[Tensor[dtype]], tensor_id: Int) -> Tensor[dtype]:
        '''Backward operation of dot product.'''
        # Only 2D input tensors are supported yet !! 
        # from testing import assert_equal
        from dainemo.utils.tensorutils import transpose_2D
        alias nelts: Int = simdwidthof[dtype]()
        if tensor_id == 0:
            # _ = assert_equal(nodes.get(1).tensor.rank(), 2)
            # return dot[dtype, nelts](ug, transpose_2D[dtype, nelts](nodes.get(1).tensor))           # dot(ug, n2.T)
            return Tensor[dtype](ug.shape()) # TODO: fix this
        else:
            # _ = assert_equal(nodes.get(0).tensor.rank(), 2)
            # return dot[dtype, nelts](transpose_2D[dtype, nelts](nodes.get(0).tensor), ug)           # dot(n1.T, ug)
            return Tensor[dtype](ug.shape()) # TODO: fix this



# <------------EXP------------>
# TODO


# <------------LOG------------>
# TODO


# <------------POW------------>
struct POW:
    @staticmethod
    fn forward(n1: Node[dtype], a: Int) -> Node[dtype]:
        '''Forward operation of element wise pow.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype] = elwise_pow[dtype, nelts](n1.tensor, a)
        var a_tensor: Tensor[dtype] = Tensor[dtype](1)
        a_tensor[0] = a
        return GRAPH.create_graph_node[Self.backward](res, n1, Node[dtype](a_tensor))

    @staticmethod
    fn backward(ug: Tensor[dtype], tensors: VariadicListMem[Tensor[dtype]], tensor_id: Int) -> Tensor[dtype]:
        '''Backward operation of element wise pow.'''
        # By design: tensor has id = 0 and scalar has id 1
        alias nelts: Int = simdwidthof[dtype]()
        # let a: SIMD[dtype, 1] = nodes.get(1).tensor[0]

        # if tensor_id == 0:
        #     # d(x^y) / dx = y * x^(y-1)
        #     let res = elwise_op[dtype, nelts, mul](a, elwise_pow[dtype, nelts](nodes.get(0).tensor, a.to_int() - 1))    # a * t^(a-1)
        #     return elwise_op[dtype, nelts, mul](res, ug)                                                                # a * t^(a-1) * ug
        # else:
        #     # d(x^y) / dy = x^y * log(x)
        #     let t_a = elwise_pow[dtype, nelts](nodes.get(0).tensor, a.to_int())             # t^a
        #     let log_t = elwise_transform[dtype, nelts, log](nodes.get(0).tensor)            # log(t)
        #     let res = elwise_op[dtype, nelts, mul](t_a, log_t)                              # t^a * log(t)
        #     return elwise_op[dtype, nelts, mul](res, ug)                                    # t^a * log(t) * ug
        return Tensor[dtype](ug.shape()) # TODO: fix this


# <------------SUM------------>
struct SUM:
    @staticmethod
    fn forward[axis: Int](n: Node[dtype]) -> Node[dtype]:
        '''Forward pass of sum operation: along axis.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: Tensor[dtype] = tsum[dtype, nelts](n.tensor, axis=axis)
        return GRAPH.create_graph_node[Self.backward[axis=axis]](res, n)

    @staticmethod
    fn forward(n: Node[dtype]) -> Node[dtype]:
        '''Forward pass of sum operation: all elements.'''
        alias nelts: Int = simdwidthof[dtype]()
        let res: SIMD[dtype, 1] = tsum[dtype, nelts](n.tensor)
        var res_tensor = Tensor[dtype](1)
        res_tensor[0] = res
        return GRAPH.create_graph_node[Self.backward[axis=-1]](res_tensor, n)

    @staticmethod
    fn backward[axis: Int = -1](ug: Tensor[dtype], tensors: VariadicListMem[Tensor[dtype]], tensor_id: Int) -> Tensor[dtype]:
        '''Backward pass of sum operation.'''
        # By design only one node in the collection
        # Output tensor has always the same shape as node input tensor
        alias nelts: Int = simdwidthof[dtype]()
        # let tensor = nodes.get(0).tensor
        # var res = Tensor[dtype](tensor.shape())
        # fill[dtype, nelts](res, 1.0)
        
        # if axis == -1:
        #     # Upper gradient will be a Tensor of shape: 1 scalar as it was constructed by summing all elements of node.tensor
        #     return elwise_op[dtype, nelts, mul](res, ug[0])

        # elif axis == 0:
        #     # Upper gradient will be a Tensor of shape: sum of node.tensor along axis 0
        #     return batch_tensor_elwise_op[dtype, nelts, mul](res, ug)

        # elif axis == 1:
        #     # Upper gradient will be a Tensor of shape: sum of node.tensor along axis 1
        #     print("NotImplemented: batch_tensor_elwise_op only support axis 0.")
        #     return res

        # else:
        #     print("NotImplemented: Tensor Sum only support up to rank 2.")
        #     return res
        return Tensor[dtype](ug.shape()) # TODO: fix this


# <---------TRANSPOSE--------->
# TODO


# <----------FLATTEN---------->
# TODO


# <----------RESHAPE---------->
# TODO

