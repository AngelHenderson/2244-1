import Foundation

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds
#endif

#if canImport(UserMessagingPlatform)
@preconcurrency import UserMessagingPlatform
#endif

@MainActor
public final class AdConsentManager {
    public static let shared = AdConsentManager()

    public private(set) var canRequestAds: Bool = true
    public private(set) var isPrivacyOptionsRequired: Bool = false
    public private(set) var lastErrorMessage: String?

    private var didStartMobileAds = false
    private var isGatheringConsent = false

    private init() {}

    @discardableResult
    public func prepareForAdRequests() async -> Bool {
        #if canImport(UserMessagingPlatform)
        guard isGatheringConsent == false else { return canRequestAds }
        isGatheringConsent = true
        defer { isGatheringConsent = false }

        let parameters = RequestParameters()

        do {
            try await requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            refreshConsentState()
        } catch {
            lastErrorMessage = error.localizedDescription
            refreshConsentState()
        }

        return canRequestAds
        #else
        canRequestAds = true
        isPrivacyOptionsRequired = false
        return true
        #endif
    }

    @discardableResult
    public func prepareAndStartMobileAds() async -> Bool {
        guard await prepareForAdRequests() else { return false }

        #if canImport(GoogleMobileAds)
        guard didStartMobileAds == false else { return true }
        didStartMobileAds = true
        await requestTrackingAuthorizationIfNeeded()
        await MobileAds.shared.start()
        #endif

        return true
    }

    @discardableResult
    public func presentPrivacyOptions() async -> Bool {
        #if canImport(UserMessagingPlatform)
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            refreshConsentState()
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            refreshConsentState()
            return false
        }
        #else
        return false
        #endif
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        guard #available(iOS 14.0, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in cont.resume() }
        }
        #endif
    }

    #if canImport(UserMessagingPlatform)
    private func requestConsentInfoUpdate(with parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }

    private func refreshConsentState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    #endif
}
