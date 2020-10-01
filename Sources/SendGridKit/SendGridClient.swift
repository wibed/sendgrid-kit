import Foundation
import NIO
import AsyncHTTPClient
import NIOHTTP1


public struct SendGridClient {
    
    let http: HTTPClient
    public let eventLoop: EventLoop
    var config: SendGridConfiguration?
    
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
    
    
    /// Send to endpoint
    public func send(emails: [SendGridEmail], on eventLoop: EventLoop) ->
    EventLoopFuture<Void> {
        
        let futures = emails.map { email
            -> EventLoopFuture<Void>  in
            
            do {
                var headers = HTTPHeaders()
                headers.add(name: "Authorization", value: "Bearer \(self.config!.apiKey)")
                headers.add(name: "Content-Type", value: "application/json")
                
                let bodyData = try encoder.encode(email)
                
                let bodyString = String(decoding: bodyData, as: UTF8.self)
                
                let request = try HTTPClient.Request(url: self.config!.apiURL,
                                                     method: .POST,
                                                     headers: headers,
                                                     body: .string(bodyString))
                
                return self._send(request).flatMap{ response in
                    
                    switch response.status {
                    case .ok, .accepted:
                        return eventLoop.makeSucceededFuture(())
                    default:
                        let byteBuffer = response.body ?? ByteBuffer(.init())
                        let responseData = Data(byteBuffer.readableBytesView)
                    
                        do {
                            let error = try self.decoder.decode(SendGridError.self,
                                                                from: responseData)
                            return eventLoop.makeFailedFuture(error)
                        } catch {
                            return eventLoop.makeFailedFuture(error)
                        }
                    }
                }
            } catch {
                return eventLoop.makeFailedFuture(error)
            }
        }
        
        return EventLoopFuture<Void>.andAllSucceed(futures, on: eventLoop)
    }
    
    
    
    private func _send(_ sendgrid: HTTPClient.Request)
    -> EventLoopFuture<HTTPClient.Response> {
        return self.http.execute(
            request: sendgrid,
            eventLoop: .delegate(on: self.eventLoop)
        ).map { response in
                response
        }
    }
}
