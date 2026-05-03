/*
  Authentication controller.
  - Biometrics handling with passcode fallback
*/
import LocalAuthentication

enum AuthError: Error {
  case failed
  case canceled
  case unavailable
}

func authenticateUser(completion: @escaping (Result<Void, AuthError>) -> Void) {
  let context = LAContext()
  var error: NSError?

  context.localizedCancelTitle = "Cancel"
  context.localizedFallbackTitle = ""

  let policy: LAPolicy = .deviceOwnerAuthentication
  let reason = "Unlock to access your courses"

  guard context.canEvaluatePolicy(policy, error: &error) else {
    DispatchQueue.main.async {
      completion(.failure(.unavailable))
    }
    return
  }

  context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
    DispatchQueue.main.async {
      if success {
        completion(.success(()))
        return
      }

      let laError = evalError as? LAError

      switch laError?.code {
      case .userCancel, .systemCancel, .appCancel:
        completion(.failure(.canceled))
      case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
        completion(.failure(.unavailable))
      default:
        completion(.failure(.failed))
      }
    }
  }
}
