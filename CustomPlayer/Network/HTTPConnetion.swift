//
//  Network.swift
//  CustomPlayer
//
//  Created by USER on 20/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation

class HTTPConnetion: NSObject {
    public var session: URLSession?
    public var networkChecker: NetworkChecker
    
    public override init() {
        
        self.networkChecker = NetworkChecker.shared
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 3
        super.init()
        self.session = URLSession(configuration: configuration)
        
    }
    
    public func request(url: URL?,
                        completion: @escaping (Result<Data, Error>, URLResponse?) -> ()) {
        networkChecker.setStartTime()
        guard let url = url else {
            completion(.failure(APIError.urlFailure), nil)
            return
        }
        print(url)
        session?.dataTask(with: url) { [weak self] (data, response, error) in
            
            if response?.expectedContentLength ?? 0 > 0 {
                self?.networkChecker.stopTimeTracking()
                self?.networkChecker.getDataLength(size: Int(response!.expectedContentLength))
                self?.networkChecker.calculateNetworkSpeed()
            }
            
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
        }.resume()
    }
}


