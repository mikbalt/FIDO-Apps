/// What `AppContainer` should build for a run.
enum TransportSelection {
    case nfc
    case mock(MockFixture, realtime: Bool)
}
