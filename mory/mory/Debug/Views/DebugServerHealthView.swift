import SwiftUI
import SwiftData

struct DebugServerHealthView: View {
    @State private var probes: [DebugEndpointProbe] = []
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                DebugValueRow(title: String(localized: "debug.server.baseURL"), value: MoryAPIConfiguration.fromBundle().baseURL.absoluteString)
                Button {
                    Task { await runProbes() }
                } label: {
                    Label(isRunning ? String(localized: "debug.server.running") : String(localized: "debug.server.run"), systemImage: "network")
                }
                .disabled(isRunning)
                if isRunning {
                    DebugProgressRow(text: String(localized: "debug.server.running"))
                }
            } footer: {
                Text("debug.server.footer")
            }

            if !probes.isEmpty {
                Section("debug.server.results") {
                    ForEach(probes) { probe in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: probe.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(probe.isReachable ? .green : .orange)
                                Text(probe.name)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(verbatim: probe.latencyText)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(verbatim: probe.detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }
        }
        .navigationTitle("debug.capability.server")
    }

    @MainActor
    private func runProbes() async {
        isRunning = true
        probes = []
        errorMessage = nil
        defer { isRunning = false }

        let configuration = MoryAPIConfiguration.fromBundle()
        do {
            probes = await [
                probe(name: String(localized: "debug.server.probe.root"), request: URLRequest(url: configuration.baseURL)),
                probe(name: String(localized: "debug.server.probe.health"), request: URLRequest(url: configuration.url(for: "/healthz"))),
                probe(name: String(localized: "debug.server.probe.auth"), request: jsonPost(url: configuration.url(for: "/auth/apple"), body: ["identity_token": "debug-invalid-token"])),
                probe(name: String(localized: "debug.server.probe.analysis"), request: jsonPost(url: configuration.url(for: "/api/analyze"), body: [:]))
            ]
        }
    }

    private func jsonPost(url: URL, body: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    private func probe(name: String, request: URLRequest) async -> DebugEndpointProbe {
        let startedAt = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let latency = Date().timeIntervalSince(startedAt)
            guard let http = response as? HTTPURLResponse else {
                return DebugEndpointProbe(name: name, statusCode: nil, latency: latency, error: String(localized: "debug.server.nonHTTP"))
            }
            return DebugEndpointProbe(name: name, statusCode: http.statusCode, latency: latency, error: nil)
        } catch {
            return DebugEndpointProbe(name: name, statusCode: nil, latency: Date().timeIntervalSince(startedAt), error: error.localizedDescription)
        }
    }
}
