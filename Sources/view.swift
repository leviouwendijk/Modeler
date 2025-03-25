import SwiftUI
import Foundation
import plate

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    var content: String
}

func apiURLString(_ domain: String,_ endpoint: APIEndpoint) -> String {
    let apiConfig: plate.APIConfiguration = APIConfiguration(
        domain: domain,
        apiName: "modeler",
        version: APIVersion(version: 1),
        endpoints: [
            APIEndpoint(route: "ollama", endpoint: "chat", details: "basic chat"),
            APIEndpoint(route: "ollama", endpoint: "models", details: "models"),
            APIEndpoint(route: "precontext", endpoint: "chat", details: "chat with precontext intialized"),
        ]
    )
    return apiConfig.endpoint(endpoint.route, endpoint.endpoint)
}

enum Precontext: String, CaseIterable {
    case clientResponder
    case clientResponder2
    case development
    case hondenmeesters
}

struct ChatView: View {
    @State private var inputText = ""
    @State private var chatHistory: [ChatMessage] = []
    @State private var isLoading = false
    @State private var alertMessage = ""

    @State private var domain = ""
    @State private var apiURL = ""
    @State private var apikey = ""
    @State private var debug = ""

    @State private var pendingBotMessage: ChatMessage? = nil
    @State private var autoScroll: Bool = false
    @State private var parseMarkdown: Bool = true

    @FocusState private var inputIsFocused: Bool

    @State private var activeStream: NetworkRequestStream?
    
    @State private var precontext: Precontext = Precontext.clientResponder

    var body: some View {
        VStack {

            // ScrollViewReader { proxy in
                ScrollView {
                    ForEach(chatHistory) { message in
                        HStack {
                            if message.role == "user" {
                                Spacer()
                                Text(message.content)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                                    .textSelection(.enabled)
                                Button(action: {
                                    copyToClipboard(message.content)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .imageScale(.medium)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                VStack {
                                    if parseMarkdown {
                                        let options = AttributedString.MarkdownParsingOptions(
                                            allowsExtendedAttributes: false,
                                            interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                            failurePolicy: .returnPartiallyParsedIfPossible,
                                            languageCode: nil
                                        )
                                        
                                        if let attributed = try? AttributedString(markdown: message.content, options: options) {
                                            Text(attributed)
                                                .padding()
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(10)
                                        } else {
                                            // Fallback if markdown parsing fails:
                                            Text(message.content)
                                                .padding()
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(10)
                                        }
                                    } else {
                                        Text(message.content)
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                    // right click menu
                                    // .contextMenu {
                                    //     Button(action: {
                                    //         copyToClipboard(message.content)
                                    //     }) {
                                    //         Text("Copy")
                                    //         Image(systemName: "doc.on.doc")
                                    //     }
                                    // }
                                    // quick-copy
                                    Button(action: {
                                        copyToClipboard(message.content)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .imageScale(.medium)
                                            .padding(8)
                                            .background(Color.gray.opacity(0.2))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
                // .onChange(of: chatHistory) { _ in
                //     if autoScroll, let last = chatHistory.last {
                //         withAnimation {
                //             proxy.scrollTo(last.id, anchor: .bottom)
                //         }
                //     }
                // }
            // }

            Divider()

            VStack {
                HStack {
                    ZStack(alignment: .topLeading) {
                        PromptTextEditor(text: $inputText)
                            .focused($inputIsFocused)
                            .frame(minHeight: 40, maxHeight: 120)
                            .padding(8)
                            // .background(Color(.black))
                            .cornerRadius(8)

                        if inputText.isEmpty {
                            Text("Type your message...")
                                .foregroundColor(.gray)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                        }

                    }
                    // .background(Color(NSColor.windowBackgroundColor))
                    // .overlay(
                    //     RoundedRectangle(cornerRadius: 8)
                    //     .stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1)
                    // )
                    .padding(.horizontal) // controls layout around the whole block

                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()

                HStack {
                    Picker("precontext", selection: $precontext) {
                        ForEach(Precontext.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .frame(width: 250)
                    .pickerStyle(MenuPickerStyle())
                    .padding()

                    Toggle("Auto-Scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)

                    Toggle("Parse Markdown", isOn: $parseMarkdown)
                    .toggleStyle(.switch)
                }
                .padding()
            }

            Divider()

            HStack {
                Text("apikey: \(debug)")
                Button("Test") {
                    test()
                }
            }
            .padding()
        }
        .onAppear {
            let home = Home.string()
            let varsFile = home + "/dotfiles/.vars.zsh"

            do {
                try DotEnv(path: varsFile).load()
            } catch {
                print("Failed to load environment file:", error)
            }

            apikey = processEnvironment("MODELER_API_KEY")
            debug = obscure(apikey)
            domain = processEnvironment("MODELER_DOMAIN")

            let basicChat = APIEndpoint(route: "ollama", endpoint: "chat")
            let precontextChat = APIEndpoint(route: "precontext", endpoint: "chat")

            apiURL = apiURLString(domain, precontextChat)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if inputIsFocused && event.modifierFlags.contains(.command) && event.keyCode == 36 { // 36 = Return key
                    sendMessage()
                    return nil
                }
                return event
            }
        }
    }

    func test() {
        apikey = plate.processEnvironment("MODELER_API_KEY")
        debug = apikey
    }

    // func sendMessage() {
    //     let userMessage = ChatMessage(role: "user", content: inputText)
    //     chatHistory.append(userMessage)
    //     inputText = ""
    //     isLoading = true

    //     Task {
    //         let model = "gemma3:1b"
    //         let stream = true
    //         let url = URL(string: apiURL)!

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

    //         let request = NetworkRequest(
    //             url: url,
    //             method: .post,
    //             auth: .apikey(value: apikey),
    //             headers: ["Content-Type": "application/json"],
    //             body: body,
    //             log: true
    //         )

    //         request.execute { success, data, error in
    //             DispatchQueue.main.async {
    //                 isLoading = false

    //                 if let data = data, let rawText = String(data: data, encoding: .utf8) {
    //                     let lines = rawText.split(separator: "\n")

    //                     DispatchQueue.main.async {
    //                         pendingBotMessage = ChatMessage(role: "assistant", content: "")
    //                         chatHistory.append(pendingBotMessage!)
    //                     }

    //                     for line in lines {
    //                         if let lineData = line.data(using: .utf8),
    //                            let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
    //                            let message = json["message"] as? [String: Any],
    //                            let chunk = message["content"] as? String {

    //                             DispatchQueue.main.async {
    //                                 if let idx = chatHistory.firstIndex(where: { $0.id == pendingBotMessage?.id }) {
    //                                     withAnimation(.linear(duration: 0.05)) {
    //                                         chatHistory[idx].content += chunk
    //                                     }
    //                                 }
    //                             }
    //                         }
    //                     }

    //                     DispatchQueue.main.async {
    //                         pendingBotMessage = nil
    //                         isLoading = false
    //                     }
    //                 } else {

    //                     let statusCode = (error as NSError?)?.code ?? -1
    //                     let errorDescription = error?.localizedDescription ?? "Unknown error"

    //                     var rawBody = "No response body"
    //                     if let data = data, let string = String(data: data, encoding: .utf8) {
    //                         rawBody = string
    //                     }

    //                     let fullError = """
    //                     Error \(statusCode)
    //                     Description: \(errorDescription)
    //                     Raw Response:
    //                     \(rawBody)
    //                     """
    //                     chatHistory.append(ChatMessage(role: "assistant", content: "\(fullError)"))
    //                 }
    //             }
    //         }
    //     }
    // }

    func sendMessage() {
        // Append user's message.
        let userMessage = ChatMessage(role: "user", content: inputText)
        chatHistory.append(userMessage)
        inputText = ""
        isLoading = true

        // Create and append a pending assistant message.
        let pendingMessage = ChatMessage(role: "assistant", content: "")
        pendingBotMessage = pendingMessage
        chatHistory.append(pendingMessage)
        
        // Capture the pending message's id.
        let pendingMessageID = pendingMessage.id

        // Prepare request body.
        let model = "gemma3:1b"
        let stream = true
        guard let url = URL(string: apiURL) else {
            print("Invalid URL")
            return
        }
        let messagesPayload = chatHistory.map { ["role": $0.role, "content": $0.content] }
        let bodyDict: [String: Any] = [
            "model": model,
            "precontext": precontext.rawValue,
            "messages": messagesPayload,
            "stream": stream
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) else {
            print("Error encoding body")
            return
        }
        
        // Create the streaming request.
        let streamRequest = NetworkRequestStream(
            url: url,
            method: .post,
            auth: .apikey(value: apikey),
            headers: ["Content-Type": "application/json"],
            body: body,
            onChunk: { chunk in
                // Log the raw chunk.
                print("Received chunk: \(chunk)")
                let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    print("Empty chunk received, skipping")
                    return
                }
                do {
                    let data = Data(trimmed.utf8)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let messageDict = json["message"] as? [String: Any],
                       let content = messageDict["content"] as? String {
                        // Update the pending message on the main thread without animation.
                        DispatchQueue.main.async {
                            if let index = chatHistory.firstIndex(where: { $0.id == pendingMessageID }) {
                                chatHistory[index].content += content
                            } else {
                                print("Pending message not found")
                            }
                        }
                    } else {
                        print("JSON structure invalid for chunk: \(trimmed)")
                    }
                } catch {
                    print("JSON parsing error: \(error.localizedDescription) for chunk: \(trimmed)")
                }
            },
            onComplete: { error in
                DispatchQueue.main.async {
                    isLoading = false
                    pendingBotMessage = nil
                    activeStream = nil // release the stream object
                    if let error = error {
                        print("Stream completed with error: \(error)")
                    } else {
                        print("Stream completed successfully")
                    }
                }
            }
        )
        
        // Retain and start the stream.
        activeStream = streamRequest
        streamRequest.start()
    }
}

struct ContentView: View {
    var body: some View {
        ChatView()
    }
}
