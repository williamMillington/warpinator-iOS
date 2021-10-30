#!/bin/bash

protoc MaybeWarpinator/gRPC/warp.proto \
 --proto_path=MaybeWarpinator/gRPC  \
 --plugin=./protoc-gen-swift \
 --swift_opt=Visibility=Public \
 --swift_out=MaybeWarpinator/gRPC \
 --plugin=./protoc-gen-grpc-swift \
 --grpc-swift_opt=Visibility=Public \
 --grpc-swift_out=MaybeWarpinator/gRPC 
