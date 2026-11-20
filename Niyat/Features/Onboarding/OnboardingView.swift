import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    let onFinish: () -> Void

    @State private var step = 0
    @State private var spin = false
    @State private var quranGoal = 10
    @State private var quranReminder = true

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 24) {
                Spacer()
                Group {
                    switch step {
                    case 0: welcome
                    case 1: locationStep
                    case 2: notificationStep
                    default: quranGoalStep
                    }
                }
                .transition(.blurReplace)
                Spacer()
            }
            .padding(24)
            .animation(.smooth, value: step)
        }
        .foregroundStyle(.white)
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                .font(.quran(size: 30))
                .fitText()
                .foregroundStyle(Palette.highlight)
            ZStack {
                Rosette(color: Palette.highlight.opacity(0.18), lineWidth: 1)
                    .frame(width: 250, height: 250)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 90).repeatForever(autoreverses: false), value: spin)
                DialMark()
                    .frame(width: 175, height: 175)
            }
            .onAppear { spin = true }
            VStack(spacing: 10) {
                Text("Isfar").font(.display(52, weight: .heavy))
                // The Arabic name between two hairlines, like a title on a mushaf page.
                HStack(spacing: 14) {
                    hairline(leading: true)
                    Text("إسفار")
                        .font(.calligraphy(size: 34))
                        .foregroundStyle(Palette.highlight)
                        .fixedSize()
                    hairline(leading: false)
                }
                .frame(maxWidth: 260)
                Text("THE FIRST LIGHT OF DAWN")
                    .font(.caption.weight(.semibold))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text("Prayer times, Qur'an, Qibla and more. Free forever. No ads, no accounts, no tracking.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 12)
            primaryButton("Get started") { step = 1 }
                .haptic(.impact(weight: .medium), trigger: step)
        }
    }

    private var locationStep: some View {
        VStack(spacing: 20) {
            stepIcon("location.fill")
            Text("Where are you?").font(.display(32))
            Text("Prayer times depend on where you are. Your location never leaves your device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
            LocationPickerView(locateTitle: "Continue") { location, mode in
                model.setLocation(location, mode: mode)
                step = 2
            }
        }
    }

    private var notificationStep: some View {
        VStack(spacing: 20) {
            stepIcon("bell.badge.fill")
            Text("Never miss a prayer").font(.display(32))
            if let location = model.location {
                Text("Times for \(location.name) use the \(model.prayerSettings.method.title) method. You can change this any time in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text("Isfar can notify you at each adhan. You choose which prayers and when in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
            // Neutral wording before the permission request (App Review 5.1.1).
            primaryButton("Continue") {
                Task {
                    await NotificationScheduler.requestAuthorization()
                    model.refresh()
                    step = 3
                }
            }
        }
    }

    private var quranGoalStep: some View {
        VStack(spacing: 20) {
            stepIcon("book.fill")
            Text("A daily Qur'an goal").font(.display(32))
            Text("How many ayat would you like to read each day? Small and steady is beloved. You can change this any time.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
            GoalPicker(selection: $quranGoal)
                .padding(16)
                .surface(cornerRadius: 20)
            Toggle("Remind me each day", isOn: $quranReminder)
                .padding(16)
                .surface(cornerRadius: 20)
            primaryButton("Start") {
                QuranGoalModel.shared.setGoal(quranGoal)
                model.quranReminders.isEnabled = quranReminder
                model.settingsChanged()
                onFinish()
            }
            Button("Skip for now", action: onFinish)
                .buttonStyle(.glass)
        }
    }

    private func hairline(leading: Bool) -> some View {
        LinearGradient(colors: [Palette.highlight.opacity(0), Palette.highlight.opacity(0.6)],
                       startPoint: leading ? .leading : .trailing, endPoint: leading ? .trailing : .leading)
            .frame(height: 1)
    }

    private func stepIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(Palette.highlight)
            .frame(width: 96, height: 96)
            .glassEffect(.regular.tint(Palette.glow.opacity(0.5)), in: .circle)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.highlight)
        .controlSize(.extraLarge)
    }
}
