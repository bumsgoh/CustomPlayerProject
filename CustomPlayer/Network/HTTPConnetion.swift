//
//  Network.swift
//  CustomPlayer
//
//  Created by USER on 20/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class HTTPConnetion {
    public var session: URLSession
    
    public init() {
        self.session = URLSession.shared
    }
    
    public func request(url: URL?,
                        completion: @escaping (Result<Data, Error>, URLResponse?) -> ()) {
    
        guard let url = url else {
            completion(.failure(APIError.urlFailure), nil)
            return
        }
        
        let task = session.dataTask(with: url) { (data, response, error) in
            
            if let error = error {
                completion(.failure(error), response)
                return
            }
            guard response?.isSuccess ?? false else {
                completion(.failure(error ?? APIError.responseUnsuccessful), response)
                return
            }
            guard let data = data else {
                completion(.failure(APIError.invalidData), nil)
                return
            }
            completion(.success(data), response)
        }
        task.resume()
    }
}
