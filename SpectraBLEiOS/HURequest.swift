//
//  HURequest.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 24/02/22.
//

import Foundation

protocol Request {
    var url: URL { get set }
    var method: HUHttpMethods { get set }
}


public struct HURequest: Request {
    
    var url: URL
    var method: HUHttpMethods
    var requestBody: Data? = nil
    
    init(withUrl url: URL, forHttpMethod method: HUHttpMethods, requestBody: Data? = nil) {
        self.url = url
        self.method = method
        self.requestBody = requestBody
    }
}
