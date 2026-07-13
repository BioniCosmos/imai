import SwiftUI

/// A lightweight jacket-image view that uses URLCache for disk/memory caching
/// and loads images lazily. Avoids the eager-loading overhead of `AsyncImage`
/// when hundreds of cells are visible simultaneously.
struct CachedJacketView: View {
    let imageUrl: String

    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    private var url: URL? {
        guard !imageUrl.isEmpty else { return nil }
        return URL(string: Constants.imageBaseURL + imageUrl)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color(.systemGray5)
                    .onAppear { loadImage() }
                    .onDisappear { cancelLoad() }
            }
        }
    }

    private func loadImage() {
        guard let url else { return }
        loadTask = Task {
            // Check cache first
            let request = URLRequest(url: url)
            if let cached = URLCache.shared.cachedResponse(for: request),
               let img = UIImage(data: cached.data) {
                await MainActor.run { image = img }
                return
            }
            // Download
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }
                if let img = UIImage(data: data) {
                    let cached = CachedURLResponse(response: response, data: data)
                    URLCache.shared.storeCachedResponse(cached, for: request)
                    await MainActor.run { image = img }
                }
            } catch {
                // Silently fail — cell shows placeholder
            }
        }
    }

    private func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }
}
