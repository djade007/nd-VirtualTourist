//
//  Photo+Extensions.swift
//  VirtualTourist
//
//  Created by Olajide Afeez on 03/08/2021.
//

import Foundation

import CoreData

extension Photo {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.createdAt = Date()
    }
}
