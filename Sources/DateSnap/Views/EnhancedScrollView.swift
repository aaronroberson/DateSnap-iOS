import SwiftUI

// MARK: - Enhanced ScrollView Utilities (iOS 18+)

/// ScrollView performance and measurement utilities for iOS 18+
@available(iOS 18.0, *)
public struct ScrollViewMetrics {
    public let contentSize: CGSize
    public let visibleRect: CGRect
    public let isScrolling: Bool
    public let velocity: CGPoint
    
    public init(contentSize: CGSize, visibleRect: CGRect, isScrolling: Bool, velocity: CGPoint) {
        self.contentSize = contentSize
        self.visibleRect = visibleRect
        self.isScrolling = isScrolling
        self.velocity = velocity
    }
}

/// Enhanced ScrollView with iOS 18+ performance features
public struct EnhancedScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let content: Content
    private let onScrollChange: ((ScrollViewMetrics) -> Void)?
    
    @State private var scrollPosition: CGPoint = .zero
    @State private var contentSize: CGSize = .zero
    @State private var isScrolling: Bool = false
    
    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        onScrollChange: ((ScrollViewMetrics) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.onScrollChange = onScrollChange
        self.content = content()
    }
    
    public var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                iOS18ScrollView
            } else {
                iOS17ScrollView
            }
        }
    }
    
    @available(iOS 18.0, *)
    private var iOS18ScrollView: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content
                .scrollTargetLayout()
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollContentSizeKey.self, value: geometry.size)
                    }
                )
        }
        .scrollPosition($scrollPosition)
        .scrollTargetBehavior(.paging)
        .onScrollPhaseChange { oldPhase, newPhase in
            isScrolling = newPhase.isScrolling
            notifyScrollChange()
        }
        .onPreferenceChange(ScrollContentSizeKey.self) { newSize in
            contentSize = newSize
            notifyScrollChange()
        }
    }
    
    private var iOS17ScrollView: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollContentSizeKey.self, value: geometry.size)
                    }
                )
        }
        .onPreferenceChange(ScrollContentSizeKey.self) { newSize in
            contentSize = newSize
            notifyScrollChange()
        }
    }
    
    private func notifyScrollChange() {
        guard let onScrollChange = onScrollChange else { return }
        
        let metrics = ScrollViewMetrics(
            contentSize: contentSize,
            visibleRect: CGRect(origin: scrollPosition, size: .zero), // Simplified for iOS 17
            isScrolling: isScrolling,
            velocity: .zero
        )
        
        onScrollChange(metrics)
    }
}

// MARK: - Scroll Position Management

/// Enhanced scroll position management for event history
public struct ScrollPositionManager {
    private var positions: [String: CGPoint] = [:]
    
    public init() {}
    
    public mutating func savePosition(for key: String, position: CGPoint) {
        positions[key] = position
    }
    
    public func position(for key: String) -> CGPoint {
        positions[key] ?? .zero
    }
    
    public mutating func clearPosition(for key: String) {
        positions.removeValue(forKey: key)
    }
}

// MARK: - Performance Optimized Event List

/// Performance-optimized event list view with iOS 18+ enhancements
public struct OptimizedEventList<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let estimatedRowHeight: CGFloat
    private let content: (Item) -> Content
    private let onScrollChange: ((ScrollViewMetrics) -> Void)?
    
    public init(
        items: [Item],
        estimatedRowHeight: CGFloat = 80,
        onScrollChange: ((ScrollViewMetrics) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.estimatedRowHeight = estimatedRowHeight
        self.onScrollChange = onScrollChange
        self.content = content
    }
    
    public var body: some View {
        EnhancedScrollView(.vertical, showsIndicators: true, onScrollChange: onScrollChange) {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    content(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply performance optimizations for scroll views
    @ViewBuilder
    public func scrollPerformanceOptimized() -> some View {
        if #available(iOS 18.0, *) {
            self
                .scrollTargetBehavior(.viewAligned)
                .scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
    
    /// Add scroll position tracking
    @ViewBuilder
    public func trackScrollPosition(_ position: Binding<CGPoint>) -> some View {
        if #available(iOS 18.0, *) {
            self.scrollPosition(position)
        } else {
            self
        }
    }
}

// MARK: - Preference Keys

private struct ScrollContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Scroll Phase Extension (iOS 18+)

@available(iOS 18.0, *)
extension ScrollPhase {
    var isScrolling: Bool {
        switch self {
        case .idle:
            return false
        case .interacting, .animating:
            return true
        @unknown default:
            return false
        }
    }
}