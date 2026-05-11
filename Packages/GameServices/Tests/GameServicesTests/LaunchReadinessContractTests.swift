import Foundation
import Testing

@Suite("Launch Readiness Contracts")
struct LaunchReadinessContractTests {
    @Test("Firestore rules copies are synchronized and cover launch collections")
    func firestoreRulesCoverage() throws {
        let rootRules = try String(contentsOf: repositoryFileURL("firestore.rules"), encoding: .utf8)
        let deployRules = try String(contentsOf: repositoryFileURL("firebase/firestore.rules"), encoding: .utf8)

        #expect(rootRules == deployRules)
        #expect(rootRules.contains("match /players/{uid}"))
        #expect(rootRules.contains("allow create, update: if isOwner(uid)"))
        #expect(rootRules.contains("match /progress/{document=**}"))
        #expect(rootRules.contains("allow read, write: if isOwner(uid)"))
        #expect(rootRules.contains("match /leaderboards/{board=**}"))
        #expect(rootRules.contains("match /reports/{id}"))
        #expect(rootRules.contains("request.resource.data.reporterId == request.auth.uid"))
        #expect(rootRules.contains("match /leaderboards/{boardId}"))
        #expect(rootRules.contains("match /scores/{uid}"))
        #expect(rootRules.contains("match /socialFeed/{postId}"))
        #expect(rootRules.contains("match /comments/{commentId}"))
        #expect(rootRules.contains("match /familyInvites/{inviteId}"))
        #expect(rootRules.contains("validReaction(request.resource.data)"))
        #expect(rootRules.contains("validPostReactionCountTransition(postId)"))
        #expect(rootRules.contains("validPostCommentCountTransition(postId)"))
        #expect(rootRules.contains("validCommentLikeCountTransition(postId, commentId)"))
        #expect(rootRules.contains("resource.data.participantIds.hasAny([request.auth.uid])"))
        #expect(rootRules.contains("allow write: if false"))
    }

    @Test("App Store release metadata is present")
    func appStoreReleaseMetadata() throws {
        let project = try String(
            contentsOf: repositoryFileURL("2244/game2244.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.ideabloomlabs.game2244;"))
        #expect(project.contains("IPHONEOS_DEPLOYMENT_TARGET = 26.0;"))
        #expect(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = game2244.entitlements;"))

        let info = try readPlist("2244/game2244/Info.plist")
        #expect((info["CFBundleDisplayName"] as? String)?.isEmpty == false)
        #expect((info["NSUserTrackingUsageDescription"] as? String)?.isEmpty == false)
        #expect((info["GADApplicationIdentifier"] as? String) == "$(ADMOB_APP_ID)")
        #expect((info["SKAdNetworkItems"] as? [[String: Any]])?.isEmpty == false)

        let buildEntitlements = try readPlist("2244/game2244.entitlements")
        let nestedEntitlements = try readPlist("2244/game2244/game2244.entitlements")
        #expect(buildEntitlements["com.apple.developer.game-center"] as? Bool == true)
        #expect(nestedEntitlements["com.apple.developer.game-center"] as? Bool == true)
        #expect(NSDictionary(dictionary: buildEntitlements).isEqual(to: nestedEntitlements))
    }

    @Test("App privacy manifest declares app-owned UserDefaults usage")
    func privacyManifestDeclaresUserDefaults() throws {
        let manifest = try readPlist("2244/game2244/PrivacyInfo.xcprivacy")
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)

        let accessed = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaultsEntry = accessed.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        let reasons = try #require(userDefaultsEntry?["NSPrivacyAccessedAPITypeReasons"] as? [String])
        #expect(reasons.contains("CA92.1"))
    }

    @Test("Firebase credential file is ignored and untracked")
    func googleServiceInfoIsIgnored() throws {
        let gitignore = try String(contentsOf: repositoryFileURL(".gitignore"), encoding: .utf8)
        #expect(gitignore.contains("GoogleService-Info.plist"))

        let tracked = try gitOutput(["ls-files", "--", "2244/game2244/GoogleService-Info.plist"])
        #expect(tracked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private func repositoryFileURL(_ relativePath: String) throws -> URL {
    var cursor = URL(fileURLWithPath: #filePath)
    while cursor.path != "/" {
        let candidate = relativePath
            .split(separator: "/")
            .reduce(cursor) { url, component in
                url.appendingPathComponent(String(component))
            }
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        cursor.deleteLastPathComponent()
    }

    throw CocoaError(.fileNoSuchFile)
}

private func readPlist(_ relativePath: String) throws -> [String: Any] {
    let data = try Data(contentsOf: repositoryFileURL(relativePath))
    let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return try #require(object as? [String: Any])
}

private func gitOutput(_ arguments: [String]) throws -> String {
    let root = try repositoryFileURL(".gitignore").deletingLastPathComponent()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = root

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}
