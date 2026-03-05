#if canImport(SwiftUI)
import SwiftUI
import NukeUI
import MetrolistCore

// MARK: - Reusable Components

/// Standard song row used across multiple screens.
public struct SongRowView: View {
    let song: any YTItem
    let onTap: () -> Void
    var onMore: (() -> Void)? = nil
    var showThumbnail: Bool = true

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if showThumbnail, let thumb = song.thumbnails.last {
                    LazyImage(url: URL(string: thumb.url)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if let subtitle = song.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let onMore {
                    Button(action: onMore) {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Compact item card for horizontal scrolling sections.
public struct ItemCardView: View {
    let title: String
    let subtitle: String?
    let thumbnailURL: String?
    let isRound: Bool
    let onTap: () -> Void

    public init(title: String, subtitle: String? = nil, thumbnailURL: String? = nil,
                isRound: Bool = false, onTap: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.isRound = isRound
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                if let urlString = thumbnailURL, let url = URL(string: urlString) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: isRound ? 999 : 8)
                                .fill(.quaternary)
                        }
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(isRound ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
                }

                Text(title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal section with a title and scrollable content.
public struct HorizontalSection<Content: View>: View {
    let title: String
    let moreAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    public init(_ title: String, moreAction: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.moreAction = moreAction
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                Spacer()
                if let moreAction {
                    Button("More", action: moreAction)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Squiggly slider for the player progress bar.
public struct ProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: ((Bool) -> Void)?
    let squiggly: Bool

    public init(value: Binding<Double>, in range: ClosedRange<Double> = 0...1,
                squiggly: Bool = true, onEditingChanged: ((Bool) -> Void)? = nil) {
        self._value = value
        self.range = range
        self.squiggly = squiggly
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)

                // Filled portion
                Capsule()
                    .fill(.tint)
                    .frame(width: progressWidth(geo.size.width), height: 4)

                // Thumb
                Circle()
                    .fill(.tint)
                    .frame(width: 16, height: 16)
                    .offset(x: progressWidth(geo.size.width) - 8)
            }
            .frame(height: 16)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged?(true)
                        let normalized = gesture.location.x / geo.size.width
                        let clamped = min(max(normalized, 0), 1)
                        value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 16)
    }

    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(min(max(normalized, 0), 1)) * totalWidth
    }
}

#endif
