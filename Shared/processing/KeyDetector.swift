//
//  KeyDetector.swift
//  Nika
//
//  Created by Ruben Zilibowitz on 30/8/18.
//  Copyright © 2018 Ruben Zilibowitz. All rights reserved.
//

import Foundation

class KeyDetector {
    func majorKey(centre: Int) -> [Double] {
        let majorTemplate: [Double] = [2,0,1,0,1,1,0,2,0,1,0,1]
        var noteTable: [Double] = [0,0,0,0,0,0,0,0,0,0,0,0]
        for i in 0 ..< 12 {
            noteTable[(i + centre) % 12] = majorTemplate[i]
        }
        return noteTable
    }
    
    func minorKey(centre: Int) -> [Double] {
        let minorTemplate: [Double] = [2,0,1,1,0,1,0,2,1,0,1,0]
        var noteTable: [Double] = [0,0,0,0,0,0,0,0,0,0,0,0]
        for i in 0 ..< 12 {
            noteTable[(i + centre) % 12] = minorTemplate[i]
        }
        return noteTable
    }
    
    func process(notes: [(Int,Double)]) -> [(root: Int, major: Bool, score: Double)] {
        var keys: [(root: Int, major: Bool, score: Double)] = []
        
        for i in 0 ..< 12 {
            let keyTable = majorKey(centre: i)
            let score = fitKeyForNotes(key: keyTable, notes: notes)
            keys.append((root: i, major: true, score: score))
        }
        
        for i in 0 ..< 12 {
            let keyTable = minorKey(centre: i)
            let score = fitKeyForNotes(key: keyTable, notes: notes)
            keys.append((root: i, major: false, score: score))
        }
        
        keys.sort(by: {return $0.score > $1.score})
        
        return keys
    }
    
    private func fitKeyForNotes(key: [Double], notes: [(Int,Double)]) -> Double {
        var noteTable: [Double] = [0,0,0,0,0,0,0,0,0,0,0,0]
        for nt in notes {
            noteTable[nt.0 % 12] += nt.1
        }
        
        return pearsonCorrelation(xs: key, ys: noteTable)
    }
    
    private func pearsonCorrelation(xs: [Double], ys: [Double]) -> Double {
        let xbar = xs.reduce(0, (+)) / Double(xs.count)
        let ybar = ys.reduce(0, (+)) / Double(ys.count)
        let top = zip(xs, ys).reduce(0, {$0 + ($1.0 - xbar) * ($1.1 - ybar)})
        let bot = sqrt(xs.reduce(0, {$0 + sqr($1 - xbar)}) * ys.reduce(0, {$0 + sqr($1 - ybar)}))
        return top / bot
    }
}
