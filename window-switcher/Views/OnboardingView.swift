import SwiftUI

struct OnboardingView: View {
    let permissionManager: PermissionManager
    let onDismiss: () -> Void
    let onRelaunch: () -> Void

    @State private var screenRecordingWasGranted = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.bottom, 24)

            VStack(spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    description: "Required to list and switch between open windows.",
                    status: permissionManager.accessibilityStatus,
                    pendingStatusText: "Required",
                    pendingStatusColor: .red,
                    onRequest: { permissionManager.requestAccessibility() }
                )

                permissionRow(
                    title: "Screen Recording",
                    description: "Optional for window preview thumbnails.",
                    status: permissionManager.screenRecordingStatus,
                    pendingStatusText: "Optional",
                    pendingStatusColor: .secondary,
                    onRequest: { permissionManager.requestScreenRecording() }
                )
            }

            if screenRecordingWasGranted {
                VStack(spacing: 6) {
                    Text("You may need to relaunch for Screen Recording to take effect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Relaunch") {
                        onRelaunch()
                    }
                    .controlSize(.small)
                }
                .padding(.top, 8)
            }

            Spacer()

            continueButton
        }
        .padding(32)
        .frame(width: 480, height: 360)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            guard !permissionManager.allGranted else { return }
            let wasDenied = permissionManager.screenRecordingStatus != .granted
            permissionManager.refreshAll()
            if wasDenied && permissionManager.screenRecordingStatus == .granted {
                screenRecordingWasGranted = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Window Switcher")
                .font(.title2.bold())

            Text("Grant accessibility to get started. Screen recording enables previews.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func permissionRow(
        title: String,
        description: String,
        status: PermissionStatus,
        pendingStatusText: String,
        pendingStatusColor: Color,
        onRequest: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: status == .granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(status == .granted ? .green : .yellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if status != .granted {
                Button("Grant Access") {
                    onRequest()
                }

                Text(pendingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(pendingStatusColor)
            } else {
                Text("Granted")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var continueButton: some View {
        Button {
            permissionManager.completeOnboarding()
            onDismiss()
        } label: {
            Text("Continue")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .disabled(!permissionManager.requiredPermissionsGranted)
    }
}
