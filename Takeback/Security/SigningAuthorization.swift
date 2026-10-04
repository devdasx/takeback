import LocalAuthentication

@MainActor protocol CancellationAuthorizing {
    var symbol: String { get }
    func authorize(reason: String) async throws
}
/// Authentication is requested only by the explicit Cancel payment action.
@MainActor struct SigningAuthorization: CancellationAuthorizing {
    var symbol: String {
        let context = LAContext(); guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return "" }
        switch context.biometryType { case .touchID: return "touchid"; case .opticID: return "opticid"; case .faceID: return "faceid"; default: return "" }
    }
    func authorize(reason: String) async throws {
        let context = LAContext()
        defer { context.invalidate() }
        let granted = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        guard granted else { throw AuthorizationError.denied }
    }
    func authorize() async throws { try await authorize(reason: "Sign and broadcast your replacement transaction.") }
    enum AuthorizationError: Error { case denied }
    static func isCancellation(_ error: Error) -> Bool {
        guard let error = error as? LAError else { return error is CancellationError }
        return [.userCancel,.systemCancel,.appCancel].contains(error.code)
    }
}
