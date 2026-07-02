import SwiftUI
import MaohuobanDesignSystem

extension PetProfileEditScreen {
    func homePreviewContext(for profile: PetProfileEditProfile) -> PetProfileHomePreviewContext {
        PetProfileHomePreviewContext(
            profile: profile,
            name: displayName(for: profile),
            sexText: displaySexText(for: profile),
            birthDateText: displayBirthDateText(for: profile),
            arrivalDateText: displayArrivalDateText(for: profile),
            weightText: displayWeightText(for: profile),
            noteText: displayNoteText(for: profile)
        )
    }

    func showHomePreview(for profile: PetProfileEditProfile) {
        guard !isHomePreviewPreparing else {
            return
        }

        dismissSelectionMenus()

        let sessionID = UUID()
        let context = homePreviewContext(for: profile)
        let heroImageWidth = max(homePreviewHeroImageWidth, 1)
        let topSafeAreaInset = HomePreviewSafeAreaMetrics.currentWindowTopSafeAreaInset()
        homePreviewPreparationID = sessionID
        isHomePreviewPreparing = true

        Task { @MainActor in
            let themeStore = HomeDashboardThemeStore()
            let themeSize = CGSize(
                width: heroImageWidth,
                height: HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
            )

            await themeStore.update(
                selectedPet: context.pet,
                heroImageSize: themeSize
            )

            let snapshot = themeStore.snapshot

            guard homePreviewPreparationID == sessionID else {
                return
            }

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                homePreviewSession = PetProfileHomePreviewSession(
                    id: sessionID,
                    context: context,
                    initialThemeSnapshot: snapshot,
                    heroImageWidth: heroImageWidth,
                    topSafeAreaInset: topSafeAreaInset
                )
            }
            isHomePreviewPreparing = false
        }
    }

    func updateHomePreviewHeroImageWidth(_ width: CGFloat) {
        let normalizedWidth = max(width, 1)
        guard abs(homePreviewHeroImageWidth - normalizedWidth) > 0.5 else { return }

        homePreviewHeroImageWidth = normalizedWidth
    }
}
