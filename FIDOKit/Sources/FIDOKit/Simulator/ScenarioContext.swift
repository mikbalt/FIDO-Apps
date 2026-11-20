/// What a scenario body can use while the card session is open.
struct ScenarioContext: Sendable {
    let channel: ISO7816Channel
    let client: CTAPClient
    let clientPIN: ClientPIN
    let progress: @Sendable (ScenarioStep) -> Void

    /// Reports `executing(label)`, then runs the command.
    func execute<T: Sendable>(_ label: String, _ command: () async throws -> T) async throws -> T {
        progress(.executing(label))
        return try await command()
    }

    /// `SELECT_FIDO`. A non-9000 SW or an unknown version ends the session as `selectFailed`.
    func selectFIDO() async throws {
        do {
            _ = try await execute("SELECT_FIDO") { try await channel.selectFIDO() }
        } catch let error as ChannelError {
            throw ScenarioFailure(reason: .selectFailed, underlying: error)
        }
    }

    /// `GET_INFO`. `6D00` ends the session as `ctap1Only`; another failure as `getInfoFailed`.
    func getInfo() async throws -> AuthenticatorInfo {
        do {
            return try await execute("GET_INFO") { try await client.getInfo() }
        } catch let error as ChannelError {
            let reason: SessionEndReason = error == .unexpectedStatus(.insNotSupported) ? .ctap1Only : .getInfoFailed
            throw ScenarioFailure(reason: reason, underlying: error)
        } catch let error as CTAPError {
            throw ScenarioFailure(reason: .getInfoFailed, underlying: error)
        } catch let error as GetInfoError {
            throw ScenarioFailure(reason: .getInfoFailed, underlying: error)
        } catch let error as CTAPClientError {
            throw ScenarioFailure(reason: .getInfoFailed, underlying: error)
        }
    }
}
