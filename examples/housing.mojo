from dainemo.utils.datasets import BostonHousing
from dainemo.utils.dataloader import DataLoader

import dainemo.nn as nn
from dainemo.autograd.graph import Graph
from dainemo.autograd.node import Node

from tensor import Tensor, TensorShape
from utils.index import Index



struct LinearRegression[dtype: DType]:
    var graph: Graph[dtype]
    var layer1: nn.Linear[dtype]

    fn __init__(inout self, input_dim: Int):
        self.graph = Graph[dtype]()
        self.layer1 = nn.Linear[dtype](self.graph, input_dim, 1)
        
    fn forward(inout self, x: Tensor[dtype]) -> Node[dtype]:
        return self.layer1(self.graph, Node[dtype](x))



fn main():
    alias dtype = DType.float32
    
    let train_data: BostonHousing[dtype]
    try:
        train_data = BostonHousing[dtype](file_path='./examples/data/housing.csv')
    except:
        print("Could not load data")
    
    alias num_epochs = 500
    alias batch_size = 64
    var training_loader = DataLoader[dtype](
                            data=train_data.data,
                            labels=train_data.labels,
                            batch_size=batch_size
                        )
    
    var model = LinearRegression[dtype](train_data.data.dim(1))
    var loss_func = nn.MSELoss[dtype]()
    var optim = nn.optim.Adam[dtype](lr=0.01)

    let batch_start: Int
    let batch_end: Int
    let batch_data: Tensor[dtype]
    let batch_labels: Tensor[dtype]
    for epoch in range(num_epochs):
        var epoch_loss: SIMD[dtype, 1] = 0.0
        var num_batches: Int = 0
        for batch_indeces in training_loader:
            
            batch_start = batch_indeces.get[0, Int]()
            batch_end = batch_indeces.get[1, Int]()
            batch_data = create_data_batch[dtype](batch_start, batch_end, training_loader.data)
            batch_labels = create_label_batch[dtype](batch_start, batch_end, training_loader.labels)
            
            optim.zero_grad(model.graph)
            let output = model.forward(batch_data)            
            var loss = loss_func(model.graph, output, batch_labels)

            loss.backward(model.graph)
            optim.step(model.graph)

            epoch_loss += loss.tensor[0]
            num_batches += 1
        
        print("Epoch: [", epoch+1, "/", num_epochs, "] \t Avg loss per epoch:", epoch_loss / num_batches)


#TODO: See DataLoader
fn create_data_batch[dtype: DType](start: Int, end: Int, data: Tensor[dtype]) ->  Tensor[dtype]:
    var batch = Tensor[dtype](TensorShape(end - start, 13))
    for n in range(end - start):
        for i in range(13):
            batch[Index(n, i)] = data[Index(start + n, i)]
    return batch

fn create_label_batch[dtype: DType](start: Int, end: Int, labels: Tensor[dtype]) ->  Tensor[dtype]:
    var batch = Tensor[dtype](TensorShape(end - start, 1))    
    for i in range(end - start):
        batch[i] = labels[start + i]
    return batch
