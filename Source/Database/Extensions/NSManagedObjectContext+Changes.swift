//
//  NSManagedObjectContext+Changes.swift
//  Slate
//
//  Created by John Coates on 6/12/17.
//  Copyright © 2017 John Coates. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    
    func insertObject<ObjectType: NSManagedObject>() -> ObjectType where ObjectType: Managed {
        guard let object = NSEntityDescription.insertNewObject(forEntityName: ObjectType.entityName,
                                                               into: self) as? ObjectType else {
                                                                fatalError("Insertion failed")
        }
        return object
    }
    
    @discardableResult
    func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch let error {
            print("Rolling back after save failed with error: \(error)")
            rollback()
            return false
        }
    }
    
    func performChanges(block: @escaping () -> Void) {
        perform {
            block()
            self.saveOrRollback()
        }
    }
    
}
