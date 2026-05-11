import AppIntents
import CryptoKit
import Security
import SwiftUI
import WidgetKit

private let appGroupId = "group.cc.boring-lab.monodash"
private let keychainAccessGroup = "53R8Z6YBWK.cc.boring-lab.monodash.widget"
private let keychainService = "MonoDashServerWidget"
private let serversKey = "server_widget_servers"
private let snapshotsKey = "server_widget_snapshots"
private let errorsKey = "server_widget_errors"
private let settingsKey = "server_widget_settings"
private let revealedIPServerIdsKey = "server_widget_revealed_ip_server_ids"
private let skipNextFetchServerIdsKey = "server_widget_skip_next_fetch_server_ids"
private let simpleWidgetKind = "ServerStatusWidget"
private let horizontalMetricsWidgetKind = "ServerStatusWidgetHorizontalMetrics"
private let serverWidgetKinds = [simpleWidgetKind, horizontalMetricsWidgetKind]

private func reloadServerWidgetTimelines() {
  for kind in serverWidgetKinds {
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
  }
}

struct WidgetLocalizer {
  let code: String?

  func string(_ key: String) -> String {
    NSLocalizedString(key, bundle: bundle, comment: "")
  }

  func format(_ key: String, _ arguments: CVarArg...) -> String {
    format(key, arguments: arguments)
  }

  func format(_ key: String, arguments: [CVarArg]) -> String {
    String(format: string(key), locale: locale, arguments: arguments)
  }

  private var normalizedCode: String? {
    guard let code else { return nil }
    return code.lowercased().hasPrefix("en") ? "en" : "zh-Hans"
  }

  private var bundle: Bundle {
    guard
      let normalizedCode,
      let path = Bundle.main.path(forResource: normalizedCode, ofType: "lproj"),
      let bundle = Bundle(path: path)
    else { return .main }
    return bundle
  }

  private var locale: Locale {
    guard let normalizedCode else { return .current }
    return Locale(identifier: normalizedCode)
  }
}

private func l10n(_ key: String) -> String {
  WidgetLocalizer(code: WidgetStore.settings().appLocaleCode).string(key)
}

private func l10nFormat(_ key: String, _ arguments: CVarArg...) -> String {
  WidgetLocalizer(code: WidgetStore.settings().appLocaleCode).format(key, arguments: arguments)
}

extension View {
  @ViewBuilder
  func numericTextTransition() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.contentTransition(.numericText())
    } else {
      self
    }
  }
}

struct WidgetServer: Codable, Identifiable, Hashable {
  let id: Int
  let name: String?
  let displayName: String
  let host: String
  let port: Int
  let isHttps: Bool
  let allowInsecureConnections: Bool?
  let sortIndex: Int

  var title: String {
    if let name, !name.isEmpty { return name }
    return displayName
  }

  var baseURL: URL? {
    URL(string: "\(isHttps ? "https" : "http")://\(host):\(port)")
  }
}

struct WidgetSettings: Codable {
  let requestTimeoutSeconds: Int
  let customHeaders: [String: String]
  let userAgent: String?
  let appLocaleCode: String?

  static let fallback = WidgetSettings(
    requestTimeoutSeconds: 60,
    customHeaders: [:],
    userAgent: nil,
    appLocaleCode: nil
  )
}

struct ServerSnapshot: Codable, Identifiable {
  let id: Int
  let name: String?
  let displayName: String
  let host: String
  let port: Int
  let isHttps: Bool
  let allowInsecureConnections: Bool?
  let sortIndex: Int
  let title: String
  let subtitle: String
  let ipAddress: String?
  let osName: String
  let uptimeSeconds: Int?
  let cpuPercent: Double
  let memoryPercent: Double
  let diskPercent: Double?
  let websiteCount: Int
  let databaseCount: Int
  let appCount: Int
  let taskCount: Int
  let netBytesSent: Int64
  let netBytesRecv: Int64
  let uploadBytesPerSecond: Double
  let downloadBytesPerSecond: Double
  let totalTrafficBytes: Int64
  let latencyMs: Int
  let updatedAt: Date
}

struct WidgetStore {
  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  static func servers() -> [WidgetServer] {
    guard
      let string = defaults?.string(forKey: serversKey),
      let data = string.data(using: .utf8),
      let servers = try? JSONDecoder().decode([WidgetServer].self, from: data)
    else { return [] }
    return servers.sorted { $0.sortIndex < $1.sortIndex }
  }

  static func settings() -> WidgetSettings {
    guard
      let string = defaults?.string(forKey: settingsKey),
      let data = string.data(using: .utf8),
      let settings = try? JSONDecoder().decode(WidgetSettings.self, from: data)
    else { return .fallback }
    return settings
  }

  static func snapshots() -> [String: ServerSnapshot] {
    guard
      let string = defaults?.string(forKey: snapshotsKey),
      let data = string.data(using: .utf8),
      let snapshots = try? decoder.decode([String: ServerSnapshot].self, from: data)
    else { return [:] }
    return snapshots
  }

  static func saveSnapshot(_ snapshot: ServerSnapshot) {
    var snapshots = snapshots()
    snapshots[String(snapshot.id)] = snapshot
    saveSnapshots(snapshots)
    clearError(serverId: snapshot.id)
  }

  static func selectedServer(id: String?) -> WidgetServer? {
    let servers = servers()
    return servers.first { String($0.id) == id } ?? servers.first
  }

  static func selectedSnapshot(id: String?) -> (WidgetServer?, ServerSnapshot?) {
    let server = selectedServer(id: id)
    let snapshot = server.flatMap { snapshots()[String($0.id)] }
    return (server, snapshot)
  }

  static func selectedError(id: String?) -> String? {
    guard let server = selectedServer(id: id) else { return nil }
    return errors()[String(server.id)]
  }

  static func saveError(_ message: String, serverId: Int) {
    var errors = errors()
    errors[String(serverId)] = message
    saveErrors(errors)
  }

  static func clearError(serverId: Int) {
    var errors = errors()
    errors.removeValue(forKey: String(serverId))
    saveErrors(errors)
  }

  static func isIPVisible(serverId: Int) -> Bool {
    let ids = defaults?.stringArray(forKey: revealedIPServerIdsKey) ?? []
    return ids.contains(String(serverId))
  }

  static func toggleIPVisibility(serverId: Int) {
    var ids = Set(defaults?.stringArray(forKey: revealedIPServerIdsKey) ?? [])
    let key = String(serverId)
    if ids.contains(key) {
      ids.remove(key)
    } else {
      ids.insert(key)
    }
    defaults?.set(Array(ids).sorted(), forKey: revealedIPServerIdsKey)
  }

  static func skipNextFetch(serverId: Int) {
    var ids = Set(defaults?.stringArray(forKey: skipNextFetchServerIdsKey) ?? [])
    ids.insert(String(serverId))
    defaults?.set(Array(ids).sorted(), forKey: skipNextFetchServerIdsKey)
  }

  static func consumeSkipNextFetch(serverId: Int) -> Bool {
    var ids = Set(defaults?.stringArray(forKey: skipNextFetchServerIdsKey) ?? [])
    let key = String(serverId)
    guard ids.contains(key) else { return false }
    ids.remove(key)
    defaults?.set(Array(ids).sorted(), forKey: skipNextFetchServerIdsKey)
    return true
  }

  static func apiKey(serverId: Int) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: "server_\(serverId)",
      kSecAttrAccessGroup as String: keychainAccessGroup,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  private static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static func saveSnapshots(_ snapshots: [String: ServerSnapshot]) {
    guard
      let data = try? encoder.encode(snapshots),
      let string = String(data: data, encoding: .utf8)
    else { return }
    defaults?.set(string, forKey: snapshotsKey)
  }

  private static func errors() -> [String: String] {
    guard
      let string = defaults?.string(forKey: errorsKey),
      let data = string.data(using: .utf8),
      let errors = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return errors
  }

  private static func saveErrors(_ errors: [String: String]) {
    guard
      let data = try? JSONEncoder().encode(errors),
      let string = String(data: data, encoding: .utf8)
    else { return }
    defaults?.set(string, forKey: errorsKey)
  }
}

final class DashboardFetcher: NSObject, URLSessionDelegate {
  private let allowInsecureConnections: Bool

  init(allowInsecureConnections: Bool) {
    self.allowInsecureConnections = allowInsecureConnections
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard
      allowInsecureConnections,
      challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let trust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    completionHandler(.useCredential, URLCredential(trust: trust))
  }
}

enum ServerWidgetFetcher {
  static func fetch(server: WidgetServer) async -> ServerSnapshot? {
    guard let baseURL = server.baseURL else {
      WidgetStore.saveError(l10n("widget.error.invalid_url"), serverId: server.id)
      return WidgetStore.selectedSnapshot(id: String(server.id)).1
    }
    guard let apiKey = WidgetStore.apiKey(serverId: server.id), !apiKey.isEmpty else {
      WidgetStore.saveError(l10n("widget.error.missing_api_key"), serverId: server.id)
      return WidgetStore.selectedSnapshot(id: String(server.id)).1
    }

    let previous = WidgetStore.selectedSnapshot(id: String(server.id)).1
    let settings = WidgetStore.settings()
    let start = Date()

    do {
      async let baseJson = request(
        baseURL: baseURL,
        path: "/api/v2/dashboard/base/all/all",
        apiKey: apiKey,
        server: server,
        settings: settings
      )
      async let currentJson = request(
        baseURL: baseURL,
        path: "/api/v2/dashboard/current/all/all",
        apiKey: apiKey,
        server: server,
        settings: settings
      )

      let base = try await baseJson
      let current = try await currentJson
      let latencyMs = max(0, Int(Date().timeIntervalSince(start) * 1000))
      let snapshot = makeSnapshot(
        server: server,
        base: base,
        current: current,
        previous: previous,
        latencyMs: latencyMs,
        updatedAt: Date()
      )
      WidgetStore.saveSnapshot(snapshot)
      return snapshot
    } catch {
      let message = errorMessage(error)
      if let base = try? await request(
        baseURL: baseURL,
        path: "/api/v2/dashboard/base/all/all",
        apiKey: apiKey,
        server: server,
        settings: settings
      ) {
        let current = dictionary(base["currentInfo"])
        let snapshot = makeSnapshot(
          server: server,
          base: base,
          current: current,
          previous: previous,
          latencyMs: max(0, Int(Date().timeIntervalSince(start) * 1000)),
          updatedAt: Date()
        )
        WidgetStore.saveSnapshot(snapshot)
        return snapshot
      }
      WidgetStore.saveError(message, serverId: server.id)
      return previous
    }
  }

  private static func request(
    baseURL: URL,
    path: String,
    apiKey: String,
    server: WidgetServer,
    settings: WidgetSettings
  ) async throws -> [String: Any] {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path = path
    guard let url = components?.url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = TimeInterval(max(5, min(settings.requestTimeoutSeconds, 300)))
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let userAgent = settings.userAgent?.trimmingCharacters(in: .whitespacesAndNewlines)
    request.setValue(userAgent?.isEmpty == false ? userAgent! : "Mono-Dash-Widget/1.0", forHTTPHeaderField: "User-Agent")
    for (key, value) in settings.customHeaders where key.lowercased() != "user-agent" {
      request.setValue(value, forHTTPHeaderField: key)
    }

    let timestamp = String(Int(Date().timeIntervalSince1970))
    request.setValue(sign(apiKey: apiKey, timestamp: timestamp), forHTTPHeaderField: "1Panel-Token")
    request.setValue(timestamp, forHTTPHeaderField: "1Panel-Timestamp")

    let delegate = DashboardFetcher(
      allowInsecureConnections: server.allowInsecureConnections == true
    )
    let session = URLSession(
      configuration: .ephemeral,
      delegate: delegate,
      delegateQueue: nil
    )
    let (data, response) = try await session.data(for: request)
    session.finishTasksAndInvalidate()

    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw FetchError.httpStatus(http.statusCode)
    }
    guard
      let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let data = envelope["data"] as? [String: Any]
    else {
      if let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        throw FetchError.apiEnvelope(
          code: int(envelope["code"]),
          message: string(envelope["message"] ?? envelope["msg"])
        )
      }
      throw URLError(.cannotParseResponse)
    }
    if int(envelope["code"]) != 200 {
      throw FetchError.apiEnvelope(
        code: int(envelope["code"]),
        message: string(envelope["message"] ?? envelope["msg"])
      )
    }
    return data
  }

  private static func makeSnapshot(
    server: WidgetServer,
    base: [String: Any],
    current: [String: Any],
    previous: ServerSnapshot?,
    latencyMs: Int,
    updatedAt: Date
  ) -> ServerSnapshot {
    let hostname = string(base["hostname"])
    let prettyDistro = string(base["prettyDistro"])
    let ip = string(base["ipV4Addr"])
    let title = !(server.name ?? "").isEmpty ? server.name! : (hostname.isEmpty ? server.displayName : hostname)
    let subtitle = [prettyDistro, ip].filter { !$0.isEmpty }.joined(separator: "  |  ")
    let diskPercent = primaryDiskPercent(current["diskData"])
    let sent = int64(current["netBytesSent"])
    let recv = int64(current["netBytesRecv"])
    let elapsed = previous.map { updatedAt.timeIntervalSince($0.updatedAt) } ?? 0
    let uploadRate = rate(current: sent, previous: previous?.netBytesSent, elapsed: elapsed)
    let downloadRate = rate(current: recv, previous: previous?.netBytesRecv, elapsed: elapsed)

    return ServerSnapshot(
      id: server.id,
      name: server.name,
      displayName: server.displayName,
      host: server.host,
      port: server.port,
      isHttps: server.isHttps,
      allowInsecureConnections: server.allowInsecureConnections,
      sortIndex: server.sortIndex,
      title: title,
      subtitle: subtitle.isEmpty ? "\(server.host):\(server.port)" : subtitle,
      ipAddress: ip.isEmpty ? nil : ip,
      osName: osName(base),
      uptimeSeconds: int(current["uptime"]),
      cpuPercent: double(current["cpuUsedPercent"]),
      memoryPercent: double(current["memoryUsedPercent"]),
      diskPercent: diskPercent,
      websiteCount: int(base["websiteNumber"]),
      databaseCount: int(base["databaseNumber"]),
      appCount: int(base["appInstalledNumber"]),
      taskCount: int(base["cronjobNumber"]),
      netBytesSent: sent,
      netBytesRecv: recv,
      uploadBytesPerSecond: uploadRate,
      downloadBytesPerSecond: downloadRate,
      totalTrafficBytes: sent + recv,
      latencyMs: latencyMs,
      updatedAt: updatedAt
    )
  }

  private static func sign(apiKey: String, timestamp: String) -> String {
    let raw = Data("1panel\(apiKey)\(timestamp)".utf8)
    return Insecure.MD5.hash(data: raw).map { String(format: "%02x", $0) }.joined()
  }

  private static func primaryDiskPercent(_ value: Any?) -> Double? {
    guard let disks = value as? [[String: Any]], !disks.isEmpty else { return nil }
    let disk = disks.first { string($0["path"]) == "/" } ?? disks[0]
    return double(disk["usedPercent"])
  }

  private static func osName(_ base: [String: Any]) -> String {
    let source = [
      string(base["prettyDistro"]),
      string(base["platform"]),
      string(base["platformFamily"]),
      string(base["os"])
    ].joined(separator: " ").lowercased()
    if source.contains("ubuntu") { return "Ubuntu" }
    if source.contains("debian") { return "Debian" }
    if source.contains("centos") { return "CentOS" }
    if source.contains("fedora") { return "Fedora" }
    if source.contains("arch") { return "Arch" }
    if source.contains("suse") { return "openSUSE" }
    let platform = string(base["platform"])
    return platform.isEmpty ? "Linux" : platform
  }

  private static func rate(current: Int64, previous: Int64?, elapsed: TimeInterval) -> Double {
    guard let previous, elapsed > 0, current >= previous else { return 0 }
    return Double(current - previous) / elapsed
  }

  private static func dictionary(_ value: Any?) -> [String: Any] {
    value as? [String: Any] ?? [:]
  }

  private static func string(_ value: Any?) -> String {
    value.map { "\($0)" } ?? ""
  }

  private static func int(_ value: Any?) -> Int {
    if let value = value as? Int { return value }
    if let value = value as? NSNumber { return value.intValue }
    if let value = value as? String { return Int(value) ?? 0 }
    return 0
  }

  private static func int64(_ value: Any?) -> Int64 {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    if let value = value as? String { return Int64(value) ?? 0 }
    return 0
  }

  private static func double(_ value: Any?) -> Double {
    if let value = value as? Double { return value }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) ?? 0 }
    return 0
  }

  private static func errorMessage(_ error: Error) -> String {
    if let error = error as? FetchError {
      return error.message
    }
    if let error = error as? URLError {
      return error.localizedDescription
    }
    return "\(error)"
  }
}

enum FetchError: Error {
  case httpStatus(Int)
  case apiEnvelope(code: Int, message: String)

  var message: String {
    switch self {
    case .httpStatus(let code):
      return "HTTP \(code)"
    case .apiEnvelope(let code, let message):
      return message.isEmpty ? l10nFormat("widget.error.api_code", code) : message
    }
  }
}

struct ServerEntity: AppEntity, Identifiable {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("widget.intent.server.type")
  )
  static var defaultQuery = ServerEntityQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
  }
}

struct ServerEntityQuery: EntityStringQuery {
  func entities(for identifiers: [ServerEntity.ID]) async throws -> [ServerEntity] {
    WidgetStore.servers()
      .filter { identifiers.contains(String($0.id)) }
      .map { ServerEntity(id: String($0.id), name: $0.title) }
  }

  func entities(matching string: String) async throws -> [ServerEntity] {
    WidgetStore.servers()
      .filter { string.isEmpty || $0.title.localizedCaseInsensitiveContains(string) }
      .map { ServerEntity(id: String($0.id), name: $0.title) }
  }

  func suggestedEntities() async throws -> [ServerEntity] {
    WidgetStore.servers().map { ServerEntity(id: String($0.id), name: $0.title) }
  }
}

enum ServerWidgetCardStyle: String, AppEnum {
  case simple
  case horizontalMetrics

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("widget.card.style.type")
  )
  static var caseDisplayRepresentations: [ServerWidgetCardStyle: DisplayRepresentation] = [
    .simple: DisplayRepresentation(title: LocalizedStringResource("widget.card.style.simple")),
    .horizontalMetrics: DisplayRepresentation(title: LocalizedStringResource("widget.card.style.horizontal_metrics"))
  ]
}

enum ServerWidgetLanguage: String, AppEnum {
  case followApp
  case zh
  case en

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("widget.language.type")
  )
  static var caseDisplayRepresentations: [ServerWidgetLanguage: DisplayRepresentation] = [
    .followApp: DisplayRepresentation(title: LocalizedStringResource("widget.language.follow_app")),
    .zh: DisplayRepresentation(title: LocalizedStringResource("widget.language.zh")),
    .en: DisplayRepresentation(title: LocalizedStringResource("widget.language.en"))
  ]

  var resolvedCode: String? {
    switch self {
    case .followApp:
      return WidgetStore.settings().appLocaleCode
    case .zh:
      return "zh"
    case .en:
      return "en"
    }
  }
}

struct ServerSelectionIntent: WidgetConfigurationIntent {
  static var title = LocalizedStringResource("widget.intent.server.title")
  static var description = IntentDescription("widget.intent.server.description")

  @Parameter(title: "widget.intent.server.parameter")
  var server: ServerEntity?

  @Parameter(title: "widget.intent.language.parameter", default: .followApp)
  var language: ServerWidgetLanguage

  static var parameterSummary: some ParameterSummary {
    Summary("Show \(\.$server)")
  }
}

struct RefreshServerIntent: AppIntent {
  static var title = LocalizedStringResource("widget.intent.refresh.title")

  @Parameter(title: "widget.intent.refresh.server_id")
  var serverId: String

  init() {
    serverId = ""
  }

  init(serverId: String) {
    self.serverId = serverId
  }

  func perform() async throws -> some IntentResult {
    if let server = WidgetStore.selectedServer(id: serverId) {
      _ = await ServerWidgetFetcher.fetch(server: server)
      reloadServerWidgetTimelines()
    }
    return .result()
  }
}

struct ToggleServerIPVisibilityIntent: AppIntent {
  static var title = LocalizedStringResource("widget.intent.toggle_ip.title")

  @Parameter(title: "widget.intent.refresh.server_id")
  var serverId: String

  init() {
    serverId = ""
  }

  init(serverId: String) {
    self.serverId = serverId
  }

  func perform() async throws -> some IntentResult {
    if let id = Int(serverId) {
      WidgetStore.toggleIPVisibility(serverId: id)
      WidgetStore.skipNextFetch(serverId: id)
      reloadServerWidgetTimelines()
    }
    return .result()
  }
}

struct ServerEntry: TimelineEntry {
  let date: Date
  let server: WidgetServer?
  let snapshot: ServerSnapshot?
  let errorMessage: String?
  let cardStyle: ServerWidgetCardStyle
  let languageCode: String?
}

struct ServerStatusProvider: AppIntentTimelineProvider {
  let cardStyle: ServerWidgetCardStyle

  init(cardStyle: ServerWidgetCardStyle) {
    self.cardStyle = cardStyle
  }

  func placeholder(in context: Context) -> ServerEntry {
    ServerEntry(
      date: Date(),
      server: WidgetServer(
        id: 1,
        name: "Mono Dash",
        displayName: "Mono Dash",
        host: "127.0.0.1",
        port: 10086,
        isHttps: true,
        allowInsecureConnections: false,
        sortIndex: 0
      ),
      snapshot: ServerSnapshot(
        id: 1,
        name: "Mono Dash",
        displayName: "Mono Dash",
        host: "127.0.0.1",
        port: 10086,
        isHttps: true,
        allowInsecureConnections: false,
        sortIndex: 0,
        title: "Mono Dash",
        subtitle: "Ubuntu  |  10.0.0.2",
        ipAddress: "10.0.0.2",
        osName: "Ubuntu",
        uptimeSeconds: 183_600,
        cpuPercent: 24,
        memoryPercent: 58,
        diskPercent: 43,
        websiteCount: 4,
        databaseCount: 2,
        appCount: 8,
        taskCount: 3,
        netBytesSent: 1_200_000_000,
        netBytesRecv: 8_600_000_000,
        uploadBytesPerSecond: 52_000,
        downloadBytesPerSecond: 380_000,
        totalTrafficBytes: 9_800_000_000,
        latencyMs: 86,
        updatedAt: Date()
      ),
      errorMessage: nil,
      cardStyle: cardStyle,
      languageCode: WidgetStore.settings().appLocaleCode
    )
  }

  func snapshot(
    for configuration: ServerSelectionIntent,
    in context: Context
  ) async -> ServerEntry {
    guard let server = WidgetStore.selectedServer(id: configuration.server?.id) else {
      return ServerEntry(
        date: Date(),
        server: nil,
        snapshot: nil,
        errorMessage: nil,
        cardStyle: cardStyle,
        languageCode: configuration.language.resolvedCode
      )
    }
    let snapshot = context.isPreview
      ? WidgetStore.selectedSnapshot(id: String(server.id)).1
      : await ServerWidgetFetcher.fetch(server: server)
    return ServerEntry(
      date: Date(),
      server: server,
      snapshot: snapshot,
      errorMessage: WidgetStore.selectedError(id: String(server.id)),
      cardStyle: cardStyle,
      languageCode: configuration.language.resolvedCode
    )
  }

  func timeline(
    for configuration: ServerSelectionIntent,
    in context: Context
  ) async -> Timeline<ServerEntry> {
    guard let server = WidgetStore.selectedServer(id: configuration.server?.id) else {
      return Timeline(
        entries: [
          ServerEntry(
            date: Date(),
            server: nil,
            snapshot: nil,
            errorMessage: nil,
            cardStyle: cardStyle,
            languageCode: configuration.language.resolvedCode
          )
        ],
        policy: .after(Date().addingTimeInterval(900))
      )
    }

    let cachedSnapshot = WidgetStore.selectedSnapshot(id: String(server.id)).1
    let snapshot = WidgetStore.consumeSkipNextFetch(serverId: server.id)
      ? cachedSnapshot
      : await ServerWidgetFetcher.fetch(server: server)
    let entry = ServerEntry(
      date: Date(),
      server: server,
      snapshot: snapshot,
      errorMessage: WidgetStore.selectedError(id: String(server.id)),
      cardStyle: cardStyle,
      languageCode: configuration.language.resolvedCode
    )
    return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
  }
}

struct ServerStatusWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: ServerEntry

  var strings: WidgetLocalizer {
    WidgetLocalizer(code: entry.languageCode)
  }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot {
        switch entry.cardStyle {
        case .simple:
          simpleServerCard(snapshot)
        case .horizontalMetrics:
          horizontalMetricsServerCard(snapshot)
        }
      } else if let server = entry.server {
        fallbackCard(server, errorMessage: entry.errorMessage)
      } else {
        emptyCard
      }
    }
    .containerBackground(.background, for: .widget)
  }

  func smallHeader(_ snapshot: ServerSnapshot) -> some View {
    let uptime = formatUptime(snapshot.uptimeSeconds ?? 0)

    return HStack(spacing: 5) {
      osIcon(snapshot.osName, size: 20)

      VStack(alignment: .leading, spacing: 1) {
        Text(snapshot.title)
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .lineLimit(1)

        Text(uptime.isEmpty ? "--" : uptime)
          .font(.system(size: 10.5, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
          .numericTextTransition()
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      Button(intent: RefreshServerIntent(serverId: String(snapshot.id))) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 20, height: 20)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
    }
  }

  private func fallbackCard(_ server: WidgetServer, errorMessage: String?) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      header(
        title: server.title,
        subtitle: strings.string("widget.fallback.waiting"),
        osName: "Linux",
        latencyMs: nil
      )
      Text(errorMessage ?? (WidgetStore.apiKey(serverId: server.id) == nil ? strings.string("widget.fallback.open_app") : strings.string("widget.fallback.tap_refresh")))
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(3)
      Spacer(minLength: 0)
      Button(intent: RefreshServerIntent(serverId: String(server.id))) {
        Label(strings.string("widget.action.refresh"), systemImage: "arrow.clockwise")
          .font(.caption.weight(.semibold))
      }
      .buttonStyle(.bordered)
    }
    .padding(16)
  }

  private var emptyCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: "server.rack")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(strings.string("widget.empty.title"))
        .font(.headline)
      Text(strings.string("widget.empty.subtitle"))
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
    .padding(16)
  }

  @ViewBuilder
  func simpleHeader(_ snapshot: ServerSnapshot) -> some View {
    if family == .systemMedium {
      mediumHeader(snapshot)
    } else {
      header(
        title: snapshot.title,
        subtitle: simpleSubtitle(snapshot),
        osName: snapshot.osName,
        latencyMs: snapshot.latencyMs,
        serverId: snapshot.id
      )
    }
  }

  private func mediumHeader(_ snapshot: ServerSnapshot) -> some View {
    let ip = displayIPAddress(snapshot)
    let isIPVisible = WidgetStore.isIPVisible(serverId: snapshot.id)

    return HStack(spacing: 10) {
      osIcon(snapshot.osName)

      VStack(alignment: .leading, spacing: 3) {
        Text(snapshot.title)
          .font(.headline.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.9)

        HStack(spacing: 5) {
          ipAddressText(ip: ip, isVisible: isIPVisible)

          Button(intent: ToggleServerIPVisibilityIntent(serverId: String(snapshot.id))) {
            Image(systemName: isIPVisible ? "eye.slash" : "eye")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.secondary)
              .frame(width: 18, height: 18)
          }
          .buttonStyle(.plain)
        }
      }

      Spacer(minLength: 0)

      mediumActions(snapshot)
    }
  }

  private func mediumActions(_ snapshot: ServerSnapshot) -> some View {
    HStack(spacing: 6) {
      HStack(spacing: 3) {
        Image(systemName: "timer")
          .font(.caption2.weight(.bold))
        Text("\(snapshot.latencyMs)ms")
          .font(.caption2.weight(.bold))
          .numericTextTransition()
      }
      .foregroundStyle(snapshot.latencyMs > 500 ? .orange : .green)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background((snapshot.latencyMs > 500 ? Color.orange : Color.green).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

      Button(intent: RefreshServerIntent(serverId: String(snapshot.id))) {
        Image(systemName: "arrow.clockwise")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .frame(width: 24, height: 24)
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
    }
  }

  private func ipAddressText(ip: String, isVisible: Bool) -> some View {
    Text(ip)
      .font(.caption2.monospacedDigit().weight(.medium))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.82)
      .blur(radius: isVisible ? 0 : 3.2, opaque: false)
      .opacity(isVisible ? 1 : 0.62)
      .saturation(isVisible ? 1 : 0.25)
      .animation(.easeInOut(duration: 0.18), value: isVisible)
  }

  private func header(
    title: String,
    subtitle: String,
    osName: String,
    latencyMs: Int?,
    serverId: Int? = nil
  ) -> some View {
    let isSmall = family == .systemSmall
    let resolvedSubtitle = isSmall && latencyMs != nil
      ? "\(subtitle.isEmpty ? "--" : subtitle) · \(latencyMs!)ms"
      : subtitle

    return HStack(spacing: 10) {
      osIcon(osName)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(isSmall ? 0.72 : 0.9)
        Text(resolvedSubtitle.isEmpty ? "--" : resolvedSubtitle)
          .font(.caption2.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(isSmall ? 0.72 : 0.9)
      }

      Spacer(minLength: 0)

      if let latencyMs, !isSmall {
        Text("\(latencyMs)ms")
          .font(.caption2.weight(.bold))
          .foregroundStyle(latencyMs > 500 ? .orange : .green)
          .numericTextTransition()
          .padding(.horizontal, 7)
          .padding(.vertical, 4)
          .background((latencyMs > 500 ? Color.orange : Color.green).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
      }

      if let serverId {
        Button(intent: RefreshServerIntent(serverId: String(serverId))) {
          Image(systemName: "arrow.clockwise")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
    }
  }

  func metricRows(_ snapshot: ServerSnapshot) -> some View {
    VStack(spacing: family == .systemSmall ? 4 : 8) {
      metric(label: "CPU", value: snapshot.cpuPercent, tint: usageColor(snapshot.cpuPercent))
      metric(label: strings.string("widget.metric.memory"), value: snapshot.memoryPercent, tint: usageColor(snapshot.memoryPercent))
      if let diskPercent = snapshot.diskPercent {
        metric(label: strings.string("widget.metric.disk"), value: diskPercent, tint: usageColor(diskPercent))
      }
    }
  }

  private func compactMetricRow(_ snapshot: ServerSnapshot) -> some View {
    HStack(spacing: 5) {
      compactMetric("CPU", snapshot.cpuPercent, tint: usageColor(snapshot.cpuPercent))
      compactMetric(strings.string("widget.metric.memory"), snapshot.memoryPercent, tint: usageColor(snapshot.memoryPercent))
      if let diskPercent = snapshot.diskPercent {
        compactMetric(strings.string("widget.metric.disk"), diskPercent, tint: usageColor(diskPercent))
      }
    }
  }

  private func compactMetric(_ label: String, _ value: Double, tint: Color) -> some View {
    HStack(spacing: 3) {
      Circle()
        .fill(tint)
        .frame(width: 5, height: 5)
      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      Text(percent(value))
        .font(.caption2.monospacedDigit().weight(.semibold))
        .numericTextTransition()
    }
    .lineLimit(1)
    .minimumScaleFactor(0.68)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  func smallMetricRows(_ snapshot: ServerSnapshot) -> some View {
    VStack(spacing: 6) {
      smallMetric(label: "CPU", value: snapshot.cpuPercent, tint: usageColor(snapshot.cpuPercent))
      smallMetric(label: strings.string("widget.metric.memory"), value: snapshot.memoryPercent, tint: usageColor(snapshot.memoryPercent))
      if let diskPercent = snapshot.diskPercent {
        smallMetric(label: strings.string("widget.metric.disk"), value: diskPercent, tint: usageColor(diskPercent))
      }
    }
  }

  private func smallMetric(label: String, value: Double, tint: Color) -> some View {
    HStack(spacing: 6) {
      Text(label)
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary)
        .frame(width: 28, alignment: .leading)

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(.secondary.opacity(0.14))
          Capsule()
            .fill(tint)
            .frame(width: proxy.size.width * min(max(value, 0), 100) / 100)
        }
      }
      .frame(height: 5)

      Text(percent(value))
        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
        .numericTextTransition()
        .frame(width: 34, alignment: .trailing)
    }
    .frame(height: 11)
  }

  private func metric(label: String, value: Double, tint: Color) -> some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .frame(width: 30, alignment: .leading)
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(.secondary.opacity(0.14))
          Capsule()
            .fill(tint)
            .frame(width: proxy.size.width * min(max(value, 0), 100) / 100)
        }
      }
      .frame(height: 6)
      Text(percent(value))
        .font(.caption2.monospacedDigit().weight(.semibold))
        .numericTextTransition()
        .frame(width: 36, alignment: .trailing)
    }
  }

  func trafficTotalsRow(_ snapshot: ServerSnapshot) -> some View {
    HStack(spacing: 10) {
      trafficTotal(strings.string("widget.traffic.up"), snapshot.netBytesSent, systemImage: "arrow.up", tint: .green)
      trafficTotal(strings.string("widget.traffic.down"), snapshot.netBytesRecv, systemImage: "arrow.down", tint: .blue)
      uptimeTotal(snapshot)
    }
    .lineLimit(1)
    .minimumScaleFactor(0.82)
  }

  private func compactTrafficRows(_ snapshot: ServerSnapshot) -> some View {
    HStack(spacing: 6) {
      smallTrafficTotal(snapshot.netBytesSent, systemImage: "arrow.up", tint: .green, accessibilityLabel: strings.string("widget.traffic.up"))
      smallTrafficTotal(snapshot.netBytesRecv, systemImage: "arrow.down", tint: .blue, accessibilityLabel: strings.string("widget.traffic.down"))
    }
    .lineLimit(1)
  }

  func smallTrafficRows(_ snapshot: ServerSnapshot) -> some View {
    HStack(spacing: 10) {
      smallTrafficBlock(
        label: strings.string("widget.traffic.up"),
        value: snapshot.netBytesSent,
        systemImage: "arrow.up.circle.fill",
        tint: .green
      )
      smallTrafficBlock(
        label: strings.string("widget.traffic.down"),
        value: snapshot.netBytesRecv,
        systemImage: "arrow.down.circle.fill",
        tint: .blue
      )
    }
    .frame(maxWidth: .infinity)
  }

  private func smallTrafficBlock(
    label: String,
    value: Int64,
    systemImage: String,
    tint: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)

      HStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.caption)
          .foregroundStyle(tint)
        Text(bytes(value))
          .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
          .numericTextTransition()
          .lineLimit(1)
          .minimumScaleFactor(0.78)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func smallTrafficTotal(
    _ value: Int64,
    systemImage: String,
    tint: Color,
    accessibilityLabel: String
  ) -> some View {
    HStack(spacing: 3) {
      Image(systemName: systemImage)
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
      Text(bytes(value))
        .font(.caption2.monospacedDigit().weight(.bold))
        .numericTextTransition()
    }
    .accessibilityLabel("\(accessibilityLabel) \(bytes(value))")
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private func trafficTotal(
    _ label: String,
    _ value: Int64,
    systemImage: String,
    tint: Color
  ) -> some View {
    HStack(spacing: 3) {
      Image(systemName: systemImage)
        .font(.caption.weight(.bold))
        .foregroundStyle(tint)
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(bytes(value))
        .font(.caption.monospacedDigit().weight(.bold))
        .numericTextTransition()
    }
  }

  private func uptimeTotal(_ snapshot: ServerSnapshot) -> some View {
    let uptime = formatUptime(snapshot.uptimeSeconds ?? 0)

    return HStack(spacing: 3) {
      Image(systemName: "clock")
        .font(.caption.weight(.bold))
        .foregroundStyle(.indigo)
      Text(strings.string("widget.uptime.label"))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(uptime.isEmpty ? "--" : uptime)
        .font(.caption.monospacedDigit().weight(.bold))
        .numericTextTransition()
    }
  }

  private var separatorDot: some View {
    Text("·")
      .font(.caption.weight(.bold))
      .foregroundStyle(.tertiary)
  }

  private func simpleSubtitle(_ snapshot: ServerSnapshot) -> String {
    let uptime = formatUptime(snapshot.uptimeSeconds ?? 0)
    if !snapshot.osName.isEmpty {
      return uptime.isEmpty ? snapshot.osName : "\(snapshot.osName) · \(uptime)"
    }
    let pieces = snapshot.subtitle.components(separatedBy: "  |  ")
    let os = pieces.first?.isEmpty == false ? pieces[0] : "--"
    return uptime.isEmpty ? os : "\(os) · \(uptime)"
  }

  private func displayIPAddress(_ snapshot: ServerSnapshot) -> String {
    if let ipAddress = snapshot.ipAddress, !ipAddress.isEmpty {
      return ipAddress
    }
    let pieces = snapshot.subtitle.components(separatedBy: "  |  ")
    if pieces.count > 1, !pieces[1].isEmpty {
      return pieces[1]
    }
    return snapshot.host.isEmpty ? "--" : snapshot.host
  }

  func usageColor(_ value: Double) -> Color {
    if value >= 85 { return .red }
    if value >= 60 { return .orange }
    return .green
  }

  private func osIcon(_ value: String, size: CGFloat = 34) -> some View {
    Image(osAssetName(value))
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
  }

  private func osAssetName(_ value: String) -> String {
    let source = value.lowercased()
    if source.contains("ubuntu") { return "Ubuntu" }
    if source.contains("debian") { return "Debian" }
    if source.contains("centos") { return "CentOS" }
    if source.contains("fedora") { return "Fedora" }
    if source.contains("arch") { return "Arch Linux" }
    if source.contains("suse") { return "openSUSE" }
    return "Linux"
  }

  func percent(_ value: Double) -> String {
    let clamped = min(max(value, 0), 100)
    return clamped >= 10
      ? "\(Int(clamped.rounded()))%"
      : String(format: "%.1f%%", clamped)
  }

  func bytes(_ value: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var amount = Double(max(value, 0))
    var index = 0
    while amount >= 1024, index < units.count - 1 {
      amount /= 1024
      index += 1
    }
    return amount >= 10 || index == 0
      ? "\(Int(amount.rounded()))\(units[index])"
      : String(format: "%.1f%@", amount, units[index])
  }

  private func formatUptime(_ seconds: Int) -> String {
    guard seconds > 0 else { return "" }
    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60
    if days > 0 { return strings.format("widget.uptime.days_hours", days, hours) }
    if hours > 0 { return strings.format("widget.uptime.hours_minutes", hours, minutes) }
    return strings.format("widget.uptime.minutes", minutes)
  }
}

struct ServerStatusWidget: Widget {
  let kind = simpleWidgetKind

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: ServerSelectionIntent.self,
      provider: ServerStatusProvider(cardStyle: .simple)
    ) { entry in
      ServerStatusWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("widget.display.name.simple")
    .description("widget.display.description.simple")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}

struct ServerStatusHorizontalMetricsWidget: Widget {
  let kind = horizontalMetricsWidgetKind

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: ServerSelectionIntent.self,
      provider: ServerStatusProvider(cardStyle: .horizontalMetrics)
    ) { entry in
      ServerStatusWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("widget.display.name.horizontal_metrics")
    .description("widget.display.description.horizontal_metrics")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}

@main
struct ServerStatusWidgetBundle: WidgetBundle {
  var body: some Widget {
    ServerStatusWidget()
    ServerStatusHorizontalMetricsWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      FileTransferActivityWidget()
    }
  }
}
