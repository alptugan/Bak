//
//  PreviewProvider.swift
//  Gor
//
//  Created by alp tugan on 20.02.2026.
//

import Cocoa
import Quartz

class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        
        let contentType = UTType.plainText // replace with your data type
        
        let reply = QLPreviewReply.init(dataOfContentType: contentType, contentSize: CGSize.init(width: 800, height: 800)) { (replyToUpdate : QLPreviewReply) in

            let data = Data("Hello world".utf8)
            
            replyToUpdate.stringEncoding = .utf8
            
            //initialize your data here
            
            return data
        }
                
        return reply
    }
}
