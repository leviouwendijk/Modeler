// import SwiftUI
// import Combine
// import plate

// final class ChatViewModel: ObservableObject {
//     @Published var chatHistory: [ChatMessage] = []
//     @Published var isLoading = false
//     @Published var debug = ""
    
//     var activeStream: NetworkRequestStream? = nil
//     var pendingMessageID: UUID?
    
//     func sendMessage(input: String, apikey: String) {
//         let userMessage = ChatMessage(role: "user", content: input)
//         chatHistory.append(userMessage)
        
//         isLoading = true
        
//         let pendingMessage = ChatMessage(role: "assistant", content: "")
//         pendingMessageID = pendingMessage.id
//         chatHistory.append(pendingMessage)
        
//         let model = "gemma3:1b"
//         let stream = true
//         guard let url = URL(string: "https://api2.hondenmeesters.nl/modeler/v1/ollama/chat") else {
//             print("Invalid URL")
//             return
//         }
//         let messagesPayload = chatHistory.map { ["role": $0.role, "content": $0.content] }
//         let bodyDict: [String: Any] = [
//             "model": model,
//             "messages": messagesPayload,
//             "stream": stream
//         ]
//         guard let body = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) else {
//             print("Error encoding body")
//             return
//         }
        
//         let streamRequest = NetworkRequestStream(
//             url: url,
//             method: .post,
//             auth: .apikey(value: apikey),
//             headers: ["Content-Type": "application/json"],
//             body: body,
//             onChunk: { [weak self] chunk in
//                 guard let self = self else { return }
//                 print("Received chunk: \(chunk)")
//                 let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
//                 guard !trimmed.isEmpty else {
//                     print("Empty chunk received, skipping")
//                     return
//                 }
//                 do {
//                     let data = Data(trimmed.utf8)
//                     if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//                        let messageDict = json["message"] as? [String: Any],
//                        let content = messageDict["content"] as? String {
//                         DispatchQueue.main.async {
//                             if let id = self.pendingMessageID,
//                                let index = self.chatHistory.firstIndex(where: { $0.id == id }) {
//                                 // Update without animation for stability
//                                 self.chatHistory[index].content += content
//                             } else {
//                                 print("Pending message not found")
//                             }
//                         }
//                     } else {
//                         print("JSON structure invalid for chunk: \(trimmed)")
//                     }
//                 } catch {
//                     print("JSON parsing error: \(error.localizedDescription) for chunk: \(trimmed)")
//                 }
//             },
//             onComplete: { [weak self] error in
//                 DispatchQueue.main.async {
//                     self?.isLoading = false
//                     self?.pendingMessageID = nil
//                     self?.activeStream = nil
//                     if let error = error {
//                         print("Stream completed with error: \(error)")
//                     } else {
//                         print("Stream completed successfully")
//                     }
//                 }
//             }
//         )
//         activeStream = streamRequest
//         streamRequest.start()
//     }
// }
