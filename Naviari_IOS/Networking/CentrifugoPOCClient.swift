//
//  CentrifugoPOCClient.swift
//  Naviari_IOS
//
//  THROWAWAY Centrifugo proof of concept — not a product feature.
//  Subscribes anonymously to the Railway Centrifugo channel `poc_counter` and exposes the
//  latest `{ "value": <number> }` publication. Every failure is logged only; nothing is
//  surfaced in the UI. To remove the POC: delete this file, CentrifugoPOCLabel.swift, the
//  two POC lines in WelcomeScreen.swift, and the SwiftCentrifuge package.
//

import Foundation
import os
import SwiftCentrifuge

/// Holds the single POC connection and the latest value published on `poc_counter`.
@MainActor
final class CentrifugoPOCClient: ObservableObject {
    static let shared = CentrifugoPOCClient()

    // POC: hardcoded Railway endpoint and channel. Anonymous, no token.
    private static let endpoint = "wss://centrifugo-production-56aa.up.railway.app/connection/websocket"
    private static let channel = "poc_counter"

    /// `nil` until the first publication arrives after app start.
    @Published private(set) var latestValue: Double?

    private let logger = Logger(subsystem: "fi.mobiari.naviari-ios", category: "CentrifugoPOC")
    private var client: CentrifugeClient?
    private var listener: Listener?
    private var subscription: CentrifugeSubscription?

    private init() {}

    /// Connects and subscribes once per app launch; later calls are no-ops.
    func startIfNeeded() {
        guard client == nil else { return }

        let listener = Listener(logger: logger) { [weak self] value in
            Task { @MainActor in self?.latestValue = value }
        }
        let client = CentrifugeClient(
            endpoint: Self.endpoint,
            config: CentrifugeClientConfig(),
            delegate: listener
        )
        self.listener = listener
        self.client = client

        do {
            let subscription = try client.newSubscription(channel: Self.channel, delegate: listener)
            self.subscription = subscription
            subscription.subscribe()
            client.connect()
            logger.info("Connecting to \(Self.endpoint, privacy: .public), channel \(Self.channel, privacy: .public)")
        } catch {
            logger.error("Could not create subscription: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// SDK delegate. Callbacks arrive on SDK queues; only `onValue` crosses to the main actor.
private final class Listener: CentrifugeClientDelegate, CentrifugeSubscriptionDelegate {
    private struct Payload: Decodable {
        let value: Double
    }

    private let logger: Logger
    private let onValue: (Double) -> Void

    init(logger: Logger, onValue: @escaping (Double) -> Void) {
        self.logger = logger
        self.onValue = onValue
    }

    // MARK: Client

    func onConnected(_ client: CentrifugeClient, _ event: CentrifugeConnectedEvent) {
        logger.info("Connected, client id \(event.client, privacy: .public)")
    }

    func onDisconnected(_ client: CentrifugeClient, _ event: CentrifugeDisconnectedEvent) {
        logger.info("Disconnected: code \(event.code) \(event.reason, privacy: .public)")
    }

    func onConnecting(_ client: CentrifugeClient, _ event: CentrifugeConnectingEvent) {
        logger.info("Connecting: code \(event.code) \(event.reason, privacy: .public)")
    }

    func onError(_ client: CentrifugeClient, _ event: CentrifugeErrorEvent) {
        logger.error("Client error: \(String(describing: event.error), privacy: .public)")
    }

    // MARK: Subscription

    func onSubscribed(_ sub: CentrifugeSubscription, _ event: CentrifugeSubscribedEvent) {
        logger.info("Subscribed to \(sub.channel, privacy: .public)")
    }

    func onUnsubscribed(_ sub: CentrifugeSubscription, _ event: CentrifugeUnsubscribedEvent) {
        logger.info("Unsubscribed: code \(event.code) \(event.reason, privacy: .public)")
    }

    func onError(_ sub: CentrifugeSubscription, _ event: CentrifugeSubscriptionErrorEvent) {
        logger.error("Subscription error: \(String(describing: event.error), privacy: .public)")
    }

    func onPublication(_ sub: CentrifugeSubscription, _ event: CentrifugePublicationEvent) {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: event.data),
              payload.value.isFinite else {
            let raw = String(data: event.data, encoding: .utf8) ?? "<non-utf8>"
            logger.error("Ignoring malformed publication: \(raw, privacy: .public)")
            return
        }
        logger.info("Publication value \(payload.value)")
        onValue(payload.value)
    }
}
