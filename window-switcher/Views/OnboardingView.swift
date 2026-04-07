import SwiftUI

struct OnboardingView: View {
    let permissionStore: PermissionStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.bottom, 24)

            VStack(spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    description: "Required to list and switch between open windows.",
                    status: permissionStore.accessibilityStatus,
                    pendingStatusText: "Required",
                    pendingStatusColor: .red,
                    onRequest: { permissionStore.requestAccessibility() }
                )

                permissionRow(
                    title: "Screen Recording",
                    description: "Optional for window preview thumbnails.",
                    status: permissionStore.screenRecordingStatus,
                    pendingStatusText: "Optional",
                    pendingStatusColor: .secondary,
                    onRequest: { permissionStore.requestScreenRecording() }
                )
            }

            Spacer()

            continueButton
        }
        .padding(32)
        .frame(width: 480, height: 360)
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
            onDismiss()
        } label: {
            Text("Continue")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .disabled(!permissionStore.requiredPermissionsGranted)
    }
}
