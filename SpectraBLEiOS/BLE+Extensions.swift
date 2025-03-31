//
//  BLE+Extensions.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 24/02/22.
//

import Foundation

extension String {
  
  var isValidURL: Bool {
    
    let regEx = "((https|http)://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
    let predicate = NSPredicate(format:"SELF MATCHES %@", argumentArray:[regEx])
    return predicate.evaluate(with: self)
  }
  
  var isNumeric : Bool {
      let digitsCharacters = CharacterSet(charactersIn: "0123456789")
      return CharacterSet(charactersIn: self).isSubset(of: digitsCharacters)
  }
  
  func index(from: Int) -> Index {
    return self.index(startIndex, offsetBy: from)
  }
  
  func substring(from: Int) -> String {
    let fromIndex = index(from: from)
    return String(self[fromIndex...])
  }
  
  func substring(to: Int) -> String {
    let toIndex = index(from: to)
    return String(self[..<toIndex])
  }
  
  func substring(with r: Range<Int>) -> String {
    let startIndex = index(from: r.lowerBound)
    let endIndex = index(from: r.upperBound)
    return String(self[startIndex..<endIndex])
  }

}
