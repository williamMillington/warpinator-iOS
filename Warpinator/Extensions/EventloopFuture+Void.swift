//
//  EventloopFuture+Void.swift
//  Warpinator
//
//  Created by William Millington on 2022-07-26.
//

import Foundation
import NIO
import CoreMIDI




// quick function to turn EventLoopFuture<VoidType> from the API into
// EventLoopFuture<Void>, which grpc-swift seems to prefer
//extension ExtensionManager where Base == EventLoopFuture<VoidType> {
//    func void() -> EventLoopFuture<Void> {
//        return base.flatMap { voidType in
//            return base.eventLoop.makeSucceededVoidFuture()
//        }
//    }
//}




extension EventLoopFuture where Value == VoidType {
    func convertVoidTypeToVoid() -> EventLoopFuture<Void> {
        return map { voidType in
            return
        }
        
    }
    
    
//    func nilCheck<T>() -> EventLoopFuture<T> {
//        
//        if let unwrapped = self.
//        
//        
//    }
////    func nilCheck() -> EventLoopFuture<Result> {
////        return eventLoop.makeSucceededFuture()
////    }
}
