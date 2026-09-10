import SwiftUI

/// CREDITS — short zine panel over the alley. Cast lock one-liners, no legal wall.
struct CreditsPanel: View {
    var sfx: MenuSFX
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MenuPanelHeader(eyebrow: "CREDITS", title: "JJ NIGHT BRAWL", titleColor: MenuTheme.pink, cyanOffset: true)
            Text("a Junction City night.")
                .font(.system(size: 12, weight: .semibold).italic())
                .foregroundColor(MenuTheme.gold.opacity(0.9))
                .padding(.bottom, 12)

            cast("JJ", "pink / black hair punk. can + cig. doesn't sell the door.")
            cast("ANDREW", "red / black striped hoodie, freckles. hoodie + laptop. root access.")
            cast("HAN", "grey cat-ear beanie, blonde / orange tips. beanie + phone. night shift.")

            Text("Suits and scene-vultures bought the scene. JJ resists both.\nBootleg zine taped to a brick wall — not Settings.app.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            MenuRow(title: "BACK", hint: "Main menu", style: .back, sfx: sfx, action: onBack)
        }
    }

    private func cast(_ name: String, _ line: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(name)
                .font(MenuTheme.display(13))
                .tracking(1.1)
                .foregroundColor(.white)
                .frame(width: 66, alignment: .leading)
            Text(line)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
