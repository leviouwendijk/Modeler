import SwiftUI
import Foundation
import plate

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String // "user" or "assistant"
    var content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
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
    case communications
    case genericMessageHelper
    case hondenmeesters
    case accountingLibrary
}

enum Model: String, RawRepresentable {
    case gemma3_1b = "gemma3:1b"
    case qwen2_5_7b = "qwen2.5:7b"
}

struct ChatView: View {
    @State private var inputText = ""
    @State private var chatHistory: [ChatMessage] = []
    @State private var isLoading = false
    @State private var alertMessage = ""

    @State private var model = Model.gemma3_1b
    @State private var domain = ""
    @State private var apiURL = ""
    @State private var apikey = ""
    @State private var debug = ""
    @State private var chatFile = ""

    @State private var pendingBotMessage: ChatMessage? = nil
    @State private var autoScroll: Bool = true
    @State private var parseMarkdown: Bool = true

    @FocusState private var inputIsFocused: Bool

    @State private var activeStream: NetworkRequestStream?
    
    @State private var precontext: Precontext = Precontext.hondenmeesters

    @State private var scrollToBottomTrigger = UUID()

    @State private var showClearConfirmation = false
    @State private var showOverwriteConfirmation = false
    @State private var showLoadConfirmation = false

    var body: some View {
        VStack {

            ScrollViewReader { proxy in
                ScrollView {
                    ForEach(chatHistory) { message in
                        HStack {
                            if message.role == "user" {
                                Spacer()

                                Text(message.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)

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
                                    Text(message.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.gray)

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
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: scrollToBottomTrigger) { oldValue, newValue in
                    if autoScroll {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                if !autoScroll && !chatHistory.isEmpty {
                    Button(action: {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.primary)

                            Text("Scroll to Bottom")
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 8)
                }
            }

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
                                .padding(.top, 6)
                                .padding(.leading, 8)
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

                HStack(spacing: 12) {
                    Toggle("Auto-Scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)

                    Toggle("Parse Markdown", isOn: $parseMarkdown)
                    .toggleStyle(.switch)
                }
                .padding(.top, 4)

                HStack(spacing: 12) {
                    Picker("precontext", selection: $precontext) {
                        ForEach(Precontext.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .frame(width: 250)
                    .pickerStyle(MenuPickerStyle())
                    .padding()

                    Button("precontext list") {
                        fetchPrecontextList()
                    }

                    Button("precontext current") {
                        fetchPrecontextByKey()
                    }
                }
                .padding(.top, 4)

                HStack(spacing: 12) {
                    TextField("chat-title.json", text: $chatFile)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)

                    Button {
                        confirmBeforeOverwritingOrSave()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        confirmBeforeClearingAndLoad()
                    } label: {
                        Label("Load", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        confirmBeforeClear()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }

            Divider()

            HStack {
                Text("apikey:")
                    .foregroundStyle(.gray)
                Text("\(debug)")
                // Button("Test") {
                //     test()
                // }
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

            // let basicChat = APIEndpoint(route: "ollama", endpoint: "chat")
            let precontextChat = APIEndpoint(route: "precontext", endpoint: "chat")

            apiURL = apiURLString(domain, precontextChat)

            precontext = defaultPrecontext()
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
        .alert("Clear current chat?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                chatHistory.removeAll()
            }
        }

        .alert("Overwrite existing file?", isPresented: $showOverwriteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Overwrite", role: .destructive) {
                saveChatHistory(chatFile)
            }
        }

        .alert("Replace current chat with saved one?", isPresented: $showLoadConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Load", role: .destructive) {
                loadChatHistory(chatFile)
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

        let model = model.rawValue
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
                                scrollToBottomTrigger = UUID()
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

    func defaultPrecontext() -> Precontext {
        let envPrecontext = processEnvironment("MODELER_DEFAULT_PRECONTEXT")
        let precontext = Precontext(rawValue: envPrecontext) ?? Precontext.hondenmeesters
        return precontext
    }


    func fetchPrecontextList() {
        guard let url = URL(string: apiURLString(domain, APIEndpoint(route: "precontext", endpoint: "list"))) else {
            print("Invalid /list URL")
            return
        }

        let request = NetworkRequest(
            url: url,
            method: .get,
            auth: .apikey(value: apikey),
            headers: ["Content-Type": "application/json"],
            log: true
        )

        request.execute { success, data, error in
            if let error = error {
                print("Error fetching precontext list:", error.localizedDescription)
                return
            }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let contexts = json["contexts"] as? [[String: String]] {
                var output = ""
                output.append("Precontext list:\n\n")
                for context in contexts {
                    output.append("- \(context["name"] ?? "unknown"): \(context["preview"] ?? "...")")
                    output.append("\n")
                }

                DispatchQueue.main.async {
                    chatHistory.append(ChatMessage(role: "assistant", content: output))
                }
            } else {
                print("Failed to parse precontext list.")
            }
        }
    }

    func fetchPrecontextByKey() {
        let key = precontext.rawValue
        guard let url = URL(string: apiURLString(domain, APIEndpoint(route: "precontext", endpoint: key))) else {
            print("Invalid /:key URL")
            return
        }

        let request = NetworkRequest(
            url: url,
            method: .get,
            auth: .apikey(value: apikey),
            headers: ["Content-Type": "application/json"],
            log: true
        )

        request.execute { success, data, error in
            if let error = error {
                print("Error fetching context for \(key):", error.localizedDescription)
                return
            }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? String {

                print("Context for \(key):\n\(content)")

                DispatchQueue.main.async {
                    chatHistory.append(ChatMessage(role: "assistant", content: content))
                }

            } else {
                print("Failed to parse context for \(key).")
            }
        }
    }

    func saveChatHistory(_ filename: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(chatHistory)
            let url = getChatHistoryURL(filename)
            try data.write(to: url)
            print("Chat saved to: \(url.path)")
        } catch {
            print("Failed to save chat history: \(error)")
        }
    }

    func loadChatHistory(_ filename: String) {
        let url = getChatHistoryURL(filename)
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([ChatMessage].self, from: data)
            chatHistory = messages
            scrollToBottomTrigger = UUID()
            print("Loaded chat with \(messages.count) messages.")
        } catch {
            print("Failed to load chat history: \(error.localizedDescription)")
        }
    }

    func getChatHistoryURL(_ filename: String) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Modeler")

        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create directory: \(error.localizedDescription)")
            }
        }
        return directory.appendingPathComponent(filename)
    }

    private func confirmBeforeClear() {
        if !chatHistory.isEmpty {
            showClearConfirmation = true
        }
    }

    private func confirmBeforeOverwritingOrSave() {
        let fileExists = FileManager.default.fileExists(atPath: getChatHistoryURL(chatFile).path)
        if fileExists {
            showOverwriteConfirmation = true
        } else {
            saveChatHistory(chatFile)
        }
    }

    private func confirmBeforeClearingAndLoad() {
        if !chatHistory.isEmpty {
            showLoadConfirmation = true
        } else {
            loadChatHistory(chatFile)
        }
    }
}

struct ContentView: View {
    var body: some View {
        ChatView()
    }
}
