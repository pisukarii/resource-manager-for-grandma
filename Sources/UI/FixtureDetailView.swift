import SwiftUI
import AppKit

/// Overview of a fixture type for the inspector pane: who/what it is, its
/// DMX modes, and its wheels with a thumbnail per GOBO slot. For a GDTF,
/// each gobo slot has a menu to swap (or set) its image.
struct FixtureDetailView: View {
    let info: FixtureInfo
    /// Slot image by `FixtureInfo.Slot.id`.
    let images: [String: NSImage]
    /// Slots whose image has been swapped in the (unsaved) draft.
    var stagedIDs: Set<String> = []
    let canEdit: Bool
    var onReplaceSlot: (FixtureInfo.Slot) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !info.modes.isEmpty { modesSection }
                ForEach(info.wheels) { wheel in
                    wheelSection(wheel)
                }
                if info.wheels.isEmpty {
                    Text("ホイール(色/GOBO)の定義はありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(info.name.isEmpty ? "(名前なし)" : info.name).font(.title3.bold())
                Text(info.format == .gdtf ? "GDTF" : "MA3 XML")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            Text([info.manufacturer, info.shortName.isEmpty ? nil : "略称: \(info.shortName)"]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ・  "))
                .foregroundStyle(.secondary)
            if !info.description.isEmpty {
                Text(info.description).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DMXモード (\(info.modes.count))").font(.headline)
            ForEach(info.modes) { mode in
                HStack {
                    Text(mode.name.isEmpty ? "(名前なし)" : mode.name)
                    Spacer()
                    Text("\(mode.channelCount) ch").foregroundStyle(.secondary).monospacedDigit()
                }
                .font(.callout)
                Divider()
            }
        }
    }

    private func wheelSection(_ wheel: FixtureInfo.Wheel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(wheel.name.isEmpty ? "ホイール" : wheel.name) (\(wheel.slots.count)スロット)").font(.headline)
            if isColorWheel(wheel) {
                HStack(alignment: .center, spacing: 14) {
                    ColorWheelDiagram(slots: wheel.slots).frame(width: 120, height: 120)
                    Text("色のホイール: スロットを上から時計回りに並べた見た目です。\n色は定義された色度から計算した表示用で、実機の見え方とは多少異なります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(wheel.slots) { slot in
                    slotCell(slot, in: wheel)
                }
            }
        }
    }

    @ViewBuilder
    private func slotCell(_ slot: FixtureInfo.Slot, in wheel: FixtureInfo.Wheel) -> some View {
        let editable = canEdit && wheel.isGobo && !isOpenSlot(slot)
        VStack(spacing: 4) {
            if editable {
                // One action, so a click goes straight to choosing the image.
                Button {
                    onReplaceSlot(slot)
                } label: {
                    thumbnail(for: slot, in: wheel, showsEditBadge: true)
                }
                .buttonStyle(.plain)
                .help(slot.mediaFileName == nil ? "クリックして画像を設定" : "クリックして画像を差し替え")
            } else {
                thumbnail(for: slot, in: wheel, showsEditBadge: false)
            }
            Text(slot.name.isEmpty ? "—" : slot.name)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
            // Say why a gobo slot has no picture instead of leaving a bare placeholder.
            if isPrismWheel(wheel), !slot.facets.isEmpty {
                Text("\(slot.facets.count)ファセット").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if !wheel.isGobo, !isPrismWheel(wheel), let t = slot.rgb?.transmission, t < 0.995, !isOpenSlot(slot) {
                Text("透過 \(Int((t * 100).rounded()))%").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if stagedIDs.contains(slot.id) {
                Text("変更あり(未保存)").font(.system(size: 9)).foregroundStyle(.orange)
            } else if wheel.isGobo, !isOpenSlot(slot), images[slot.id] == nil {
                Text(slot.mediaFileName == nil ? "画像なし" : "画像が見つかりません")
                    .font(.system(size: 9))
                    .foregroundStyle(slot.mediaFileName == nil ? Color.secondary : Color.orange)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func isOpenSlot(_ slot: FixtureInfo.Slot) -> Bool {
        slot.name.caseInsensitiveCompare("Open") == .orderedSame
    }

    /// A wheel of colour filters: not a gobo wheel, and the slots differ in colour
    /// (a prism wheel's slots all carry the same white, so there's nothing to draw).
    private func isColorWheel(_ wheel: FixtureInfo.Wheel) -> Bool {
        guard !wheel.isGobo, wheel.slots.count >= 2 else { return false }
        let colors = wheel.slots.compactMap(\.rgb)
        guard colors.count == wheel.slots.count, let first = colors.first else { return false }
        return colors.contains { $0 != first }
    }

    /// A wheel with at least one faceted slot (the others, e.g. Open, are plain).
    private func isPrismWheel(_ wheel: FixtureInfo.Wheel) -> Bool {
        !wheel.isGobo && wheel.slots.contains { !$0.facets.isEmpty }
    }

    private func thumbnail(for slot: FixtureInfo.Slot, in wheel: FixtureInfo.Wheel, showsEditBadge: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.14))
            if let image = images[slot.id] {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(4)
            } else if isPrismWheel(wheel) {
                // Prism slot: the beam copies the facets make (a plain circle for Open).
                PrismDiagram(facets: slot.facets)
                    .padding(6)
            } else if !wheel.isGobo, let c = slot.rgb {
                // Colour-wheel slot: show the filter's colour.
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: c.r, green: c.g, blue: c.b))
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .center) {
                        if isOpenSlot(slot) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .padding(6)
                        }
                    }
            } else {
                Image(systemName: slot.mediaFileName == nil ? "circle.dashed" : "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if showsEditBadge {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(3)
            }
        }
        .frame(width: 72, height: 72)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .strokeBorder(stagedIDs.contains(slot.id) ? Color.orange : Color.secondary.opacity(0.25),
                          lineWidth: stagedIDs.contains(slot.id) ? 2 : 1))
    }
}


/// A colour wheel drawn as a pie: one equal sector per slot, first slot at the
/// top, going clockwise.
struct ColorWheelDiagram: View {
    let slots: [FixtureInfo.Slot]

    var body: some View {
        Canvas { context, size in
            let n = slots.count
            guard n > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2
            let step = Angle.degrees(360 / Double(n))
            for (i, slot) in slots.enumerated() {
                let start = Angle.degrees(-90) + step * Double(i)
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: start + step, clockwise: false)
                path.closeSubpath()
                let c = slot.rgb
                context.fill(path, with: .color(c.map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? .gray))
                context.stroke(path, with: .color(Color(white: 0.1)), lineWidth: 1)
            }
            // hub
            let hub = Path(ellipseIn: CGRect(x: center.x - radius * 0.18, y: center.y - radius * 0.18,
                                             width: radius * 0.36, height: radius * 0.36))
            context.fill(hub, with: .color(Color(white: 0.12)))
        }
    }
}


/// What a prism does to the beam: one circle per facet, placed by the facet's
/// offset (so an 8-facet prism is a ring of 8 beams). No facets = a single
/// open beam.
struct PrismDiagram: View {
    let facets: [FixtureInfo.Facet]

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            if facets.isEmpty {
                let r = side * 0.34
                context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                             with: .color(Color(white: 0.92)))
                return
            }
            // Fit the farthest offset inside the box, beam radius a fixed share of it.
            let reach = max(facets.map { max(abs($0.x), abs($0.y)) }.max() ?? 0.5, 0.01)
            let scale = (side / 2 - side * 0.14) / reach
            let beam = side * (facets.count >= 4 ? 0.12 : 0.2)
            for facet in facets {
                // GDTF y points up; the screen's y points down.
                let p = CGPoint(x: center.x + facet.x * scale, y: center.y - facet.y * scale)
                let c = facet.color.map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? Color(white: 0.92)
                context.fill(Path(ellipseIn: CGRect(x: p.x - beam, y: p.y - beam, width: beam * 2, height: beam * 2)),
                             with: .color(c))
            }
        }
    }
}
