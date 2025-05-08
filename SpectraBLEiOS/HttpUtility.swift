//
//  HttpUtility.swift
//  MyFirstFrameworkApp
//
//  Created by sft_mac on 24/02/22.
//

import Foundation

public class HttpUtility {
    
    public static let shared = HttpUtility()
    public var authenticationToken : String? = nil
    public var customJsonDecoder : JSONDecoder? = nil
    
    private init() {}
    
    public func reqeuest<T: Decodable>(huRequest: HURequest,
                                       resultType: T.Type,
                                       completionHandler: @escaping(Result<T?, HUNetworkError>) -> Void) {
        
        switch huRequest.method {
            
        case .post:
            
            self.postData(request: huRequest,
                     resultType: resultType) { result in
                
                completionHandler(result)
            }
            
        default:
            _ = ""
            
        }
        
    }
}


extension HttpUtility {
    
    /// Post API
    private func postData<T:Decodable>(request: HURequest,
                                       resultType: T.Type,
                                       completionHandler:@escaping(Result<T?, HUNetworkError>) -> Void) {
        
        var urlRequest = self.createUrlRequest(requestUrl: request.url)
        urlRequest.httpMethod = HUHttpMethods.post.rawValue
        urlRequest.httpBody = request.requestBody
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")

        performOperation(requestUrl: urlRequest, responseType: T.self) { (result) in
            completionHandler(result)
        }
    }
    
    // MARK: - Perform data task
    private func performOperation<T: Decodable>(requestUrl: URLRequest,
                                                responseType: T.Type,
                                                completionHandler: @escaping(Result<T?, HUNetworkError>) -> Void) {
        
        URLSession.shared.dataTask(with: requestUrl) { (data, httpUrlResponse, error) in

            let statusCode = (httpUrlResponse as? HTTPURLResponse)?.statusCode
            
            if(error == nil && data != nil && data?.count != 0) {
                
                let response = self.decodeJsonResponse(data: data!, responseType: responseType)
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] {
                        // try to read out a dictionary
                        print("Json reponse is: \(json)")
                    }
                } catch let error {
                    
                    print("error: \(error.localizedDescription)")
                }
                
                if response != nil {
                    
                    completionHandler(.success(response))
                    
                } else {
                    
                    let networkError = HUNetworkError(withServerResponse: data,
                                                       forRequestUrl: requestUrl.url!,
                                                       withHttpBody: requestUrl.httpBody,
                                                       errorMessage: error.debugDescription,
                                                       forStatusCode: statusCode)
                                       
                    completionHandler(.failure(networkError))
                }
                
            } else {
                
                let networkError = HUNetworkError(withServerResponse: data,
                                                  forRequestUrl: requestUrl.url!,
                                                  withHttpBody: requestUrl.httpBody,
                                                  errorMessage: error.debugDescription,
                                                  forStatusCode: statusCode)
                
                completionHandler(.failure(networkError))
            }

        }.resume()
    }
    
}


// MARK: -
// MARK: - Private functions
extension HttpUtility {
    
    private func createJsonDecoder() -> JSONDecoder
    {
        let decoder =  customJsonDecoder != nil ? customJsonDecoder! : JSONDecoder()
        if(customJsonDecoder == nil) {
            decoder.dateDecodingStrategy = .iso8601
        }
        return decoder
    }
    
    private func createUrlRequest(requestUrl: URL) -> URLRequest
    {
        var urlRequest = URLRequest(url: requestUrl)
        if(authenticationToken != nil) {
            urlRequest.setValue(authenticationToken!, forHTTPHeaderField: "authorization")
        }
        
        return urlRequest
    }
    
    private func decodeJsonResponse<T: Decodable>(data: Data, responseType: T.Type) -> T?
    {
        let decoder = createJsonDecoder()
        do {
            return try decoder.decode(responseType, from: data)
        }catch let error {
            debugPrint("deocding error =>\(error.localizedDescription)")
        }
        return nil
    }
    
}
