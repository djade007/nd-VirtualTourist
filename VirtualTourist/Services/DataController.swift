//
//  DataController.swift
//  VirtualTourist
//
//  Created by Olajide Afeez on 03/08/2021.
//

import Foundation
import CoreData

class DataController {
    
    // MARK: Properties
    var appDelegate: AppDelegate!
    static var shared: DataController!
    
    
    var viewContext: NSManagedObjectContext {
        return appDelegate.persistentContainer.viewContext
    }
    
    lazy var backgroundContext:  NSManagedObjectContext = {
        let context = appDelegate.persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }()
    
    
    // MARK: Initialization
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        
        autoSaveViewContext()
    }
    
    
    
    // MARK: Helper Functions
    
    func saveContext() {
        appDelegate.saveContext()
    }
    
    private func autoSaveViewContext(interval: TimeInterval = 5) {
        guard interval > 0 else { return }
        
        saveContext()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            self.autoSaveViewContext(interval: interval)
        }
    }
    
}
