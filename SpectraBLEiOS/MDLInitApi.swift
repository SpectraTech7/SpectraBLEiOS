//
//  MDLInitApi.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 24/02/22.
//

import Foundation

struct MDLInitApiRequest: Encodable {
    let key: String
}

struct MDLInitApiResponse: Decodable {
    let key: String?
    let isSuccess: Bool?
    let message: String?
}
