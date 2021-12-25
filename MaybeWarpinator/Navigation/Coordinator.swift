//
//  Coordinator.swift
//  MaybeWarpinator
//
//  Created by William Millington on 2021-11-17.
//

import UIKit


// MARK: - Coordinator
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navController: UINavigationController { get set }
    
    func start()
    func coordinatorDidFinish(_ child: Coordinator)
}

extension Coordinator {
    func coordinatorDidFinish(_ child: Coordinator){
        for (i, coordinator) in childCoordinators.enumerated() {
            if coordinator === child {
                childCoordinators.remove(at: i)
                break
            }
        }
    }
}


//MARK: SubCoordinator
protocol SubCoordinator {
    var parent: Coordinator { get }
    func back()
}
