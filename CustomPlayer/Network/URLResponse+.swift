//
//  URLResponse+.swift
//  CustomPlayer
//
//  Created by USER on 20/05/2019.
//  Copyright © 2019 USER. All rights reserved.
//

import Foundation
extension URLResponse {
    
    var isSuccess: Bool {
        guard let response = self as? HTTPURLResponse else { return false }
        return (200...299).contains(response.statusCode)
    }
}
