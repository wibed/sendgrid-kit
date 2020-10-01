import Foundation
import NIO
import AsyncHTTPClient
import NIOHTTP1


public struct SendGridConfiguration {
    public var apiURL: String
    public var apiKey: String
    
    public init(
        apiURL: String = ProcessInfo.processInfo.environment["SENDGRID_URL"] ??
            "https://api.sendgrid.com/v3/mail/send",
        apiKey: String? = ProcessInfo.processInfo.environment["SENDGRID_KEY"]
    ){
        guard let apiKey = apiKey else {
            fatalError("APIKey not found.")
        }
        
        self.apiKey = apiKey
        self.apiURL = apiURL
    }
}
