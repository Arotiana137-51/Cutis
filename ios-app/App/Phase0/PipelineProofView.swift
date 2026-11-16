import AppCore
import SwiftUI
import UIKit

/// The single Phase 0 screen: app version, device model and whether ARKit
/// supports scene depth and mesh reconstruction (in other words, LiDAR).
struct PipelineProofView: View {

    let snapshot: DiagnosticsSnapshot

    @State private var copied: Bool = false

    init(snapshot: DiagnosticsSnapshot) {
        self.snapshot = snapshot
    }

    var body: some View {
        ZStack {
            Theme.Palette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    lidarCard
                    section(title: "App", rows: snapshot.appRows)
                    section(title: "Device", rows: snapshot.deviceRows)
                    section(title: "ARKit", rows: snapshot.capabilityRows)
                    copyButton
                }
                .padding(20)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phase 0 · Pipeline proof")
                .font(Theme.Typography.mono(12, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)

            Text(snapshot.appName)
                .font(Theme.Typography.display(40))
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var lidarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.lidarHeadline)
                .font(Theme.Typography.mono(34, weight: .bold))
                .foregroundStyle(lidarColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(snapshot.lidarExplanation)
                .font(Theme.Typography.ui(15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(lidarColor, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var lidarColor: Color {
        switch snapshot.lidarStatus {
        case .available:
            return Theme.Palette.accent
        case .unavailable, .partial:
            return Theme.Palette.warning
        }
    }

    private func section(title: String, rows: [DiagnosticsSnapshot.Row]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Theme.Typography.ui(13, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.bottom, 10)

            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.Palette.border)
                        .frame(height: 1)
                }
                rowView(rows[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Palette.border, lineWidth: 1)
        }
    }

    private func rowView(_ row: DiagnosticsSnapshot.Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.label)
                .font(Theme.Typography.ui(15))
                .foregroundStyle(Theme.Palette.text)
            Spacer(minLength: 12)
            Text(row.value)
                .font(Theme.Typography.mono(15))
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var copyButtonTitle: String {
        copied ? "Copied" : "Copy diagnostics"
    }

    private var copyButton: some View {
        Button {
            copyDiagnostics()
        } label: {
            Text(copyButtonTitle)
                .font(Theme.Typography.ui(17, weight: .semibold))
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Theme.Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Actions

    /// Puts the diagnostics text on the clipboard so it can be pasted into a message.
    private func copyDiagnostics() {
        UIPasteboard.general.string = snapshot.report
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }
}
