import Foundation
import NIO
import AsyncHTTPClient
import NIOHTTP1


public struct SendGridClient {
    
    public let http: HTTPClient
    public let eventLoop: EventLoop
    public var config: SendGridConfiguration?
    
    public init(http: HTTPClient, eventLoop: EventLoop, config: SendGridConfiguration){
        self.http = http
        self.eventLoop = eventLoop
        self.config = config
    }
    
    /// Encode/decode messages
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
         encoder.dateEncodingStrategy = .secondsSince1970
         return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
    
    public func delegating(to eventLoop: EventLoop) -> SendGridClient {
        SendGridClient(
            http: self.http,
            eventLoop: eventLoop,
            config: self.config!
        )
    }
    
    
    public func send(email: SendGridEmail)
        -> EventLoopFuture<Void> {
        
        do {
            
            let method: HTTPMethod = .POST
            var headers = HTTPHeaders()
            headers.add(name: "Authorization", value: "Bearer \(self.config!.apiKey)")
            headers.add(name: "Content-Type", value: "application/json")
            let url = self.config!.apiURL
            let body = try encoder.encode(email)
            let emailRequest = try HTTPClient.Request(
                url: url,
                method: method,
                headers: headers,
                body: .data(body)
            )
            
            return self.http.execute(
                request: emailRequest,
                eventLoop: .delegate(on: self.eventLoop)).flatMap { response in
                    switch response.status {
                    case .ok, .accepted:
                        return eventLoop.makeSucceededFuture(())
                    default:
                        // JSONDecoder will handle empty body by throwing decoding error
                        let byteBuffer = response.body ?? ByteBuffer(.init())
                        let responseData = Data(byteBuffer.readableBytesView)
                        
                        do {
                            let error = try self.decoder.decode(SendGridError.self, from: responseData)
                            return eventLoop.makeFailedFuture(error)
                        } catch  {
                            return eventLoop.makeFailedFuture(error)
                        }
                }
            }
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
    
    /// Send to endpoint
    public func mailRequest(email: SendGridEmail) -> EventLoopFuture<HTTPClient.Request> {
        do {
            let method: HTTPMethod = .POST
            var headers = HTTPHeaders()
            headers.add(name: "Authorization", value: "Bearer \(self.config!.apiKey)")
            headers.add(name: "Content-Type", value: "application/json")
            let url = self.config!.apiURL
            
            let body = try encoder.encode(email)
            
            return eventLoop.makeSucceededFuture(
                try HTTPClient.Request(url: url,
                               method: method,
                               headers: headers,
                               body: .data(body))
            )
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    private func execute(_ sendgrid: HTTPClient.Request)
    -> EventLoopFuture<HTTPClient.Response> {
        return self.http.execute(
            request: sendgrid,
            eventLoop: .delegate(on: self.eventLoop)
        ).map { $0 }
    }
}
