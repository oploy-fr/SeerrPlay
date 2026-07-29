import SwiftUI

struct MediaDetailView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.openURL) private var openURL
    let item: MediaItem

    @State private var details: MediaDetails?
    @State private var errorMessage: String?
    @State private var preparingPlayback = false
    @State private var playbackSource: PlaybackSource?
    @State private var requestMessage: String?
    @State private var showMore = false

    var body: some View {
        ZStack {
            PageBackground()
            if let details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 38) {
                        hero(details)
                        overview(details)
                        cast(details)
                        if showMore {
                            moreInformation(details)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        Button(showMore ? "Show less" : "Learn more") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showMore.toggle()
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                ProgressView("Loading details…").controlSize(.large)
            }
        }
        .navigationTitle(item.title)
        .task { await load() }
        .fullScreenCover(item: $playbackSource) { source in
            NativePlayerView(source: source)
                .environmentObject(app)
                .ignoresSafeArea()
        }
    }

    private func hero(_ details: MediaDetails) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: details.backdropURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LinearGradient(
                    colors: [SeerrPlayTheme.violet.opacity(0.45), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(height: 650)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, SeerrPlayTheme.background.opacity(0.98)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }

            HStack(alignment: .bottom, spacing: 38) {
                PosterImage(url: details.posterURL, ratio: 2 / 3)
                    .frame(width: 290, height: 435)
                    .shadow(radius: 25)

                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        if let availability = details.mediaInfo?.availability {
                            AvailabilityBadge(availability: availability)
                        }
                        if let certification = details.certification, !certification.isEmpty {
                            Text(ageLabel(certification))
                                .font(.caption.bold())
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Text(details.title)
                        .font(.system(size: 58, weight: .bold))
                        .lineLimit(2)
                    if let tagline = details.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.title3.italic())
                            .foregroundStyle(.secondary)
                    }
                    metadata(details)
                    actionButtons(details)
                    if let requestMessage {
                        Text(requestMessage)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(SeerrPlayTheme.cyan)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 70)
            .padding(.bottom, 30)
        }
    }

    private func metadata(_ details: MediaDetails) -> some View {
        HStack(spacing: 18) {
            if let date = details.releaseDate {
                Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            }
            if let runtime = details.runtimeMinutes {
                Label("\(runtime) min", systemImage: "clock")
            }
            if details.rating > 0 {
                Label(String(format: "%.1f", details.rating), systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
            ForEach(details.genres.prefix(3), id: \.self) {
                Text($0)
            }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func actionButtons(_ details: MediaDetails) -> some View {
        HStack(spacing: 18) {
            if canPlay(details) {
                Button {
                    Task { await play() }
                } label: {
                    if preparingPlayback {
                        ProgressView()
                    } else {
                        Label("Play", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(preparingPlayback)
            } else {
                Button {
                    Task { await request() }
                } label: {
                    Label("Request", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(SeerrPlayTheme.violet)
            }

            if let trailer = details.videos.first(where: {
                $0.type?.localizedCaseInsensitiveContains("trailer") == true
            }) ?? details.videos.first,
            let url = trailer.url
            {
                Button {
                    openURL(url)
                } label: {
                    Label("Watch trailer", systemImage: "play.rectangle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func overview(_ details: MediaDetails) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Synopsis").font(.title2.bold())
            Text(details.overview.isEmpty ? "No synopsis is available." : details.overview)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineSpacing(7)
                .frame(maxWidth: 1300, alignment: .leading)
        }
        .padding(.horizontal, 70)
    }

    @ViewBuilder
    private func cast(_ details: MediaDetails) -> some View {
        if !details.cast.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("Cast").font(.title2.bold())
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 25) {
                        ForEach(details.cast) { person in
                            NavigationLink {
                                PersonDetailView(personID: person.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    PosterImage(url: person.imageURL, ratio: 2 / 3)
                                        .frame(width: 180, height: 270)
                                    Text(person.name)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Text(person.character ?? "Cast member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 180, alignment: .leading)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
            .padding(.horizontal, 70)
        }
    }

    private func moreInformation(_ details: MediaDetails) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Technical and production details")
                .font(.title2.bold())
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 22
            ) {
                InfoValue(title: "Original title", value: details.originalTitle)
                InfoValue(title: "Studios", value: details.studios.joined(separator: ", "))
                InfoValue(title: "Budget", value: currency(details.budget))
                InfoValue(title: "Revenue", value: currency(details.revenue))
                InfoValue(title: "Votes", value: details.voteCount > 0 ? "\(details.voteCount)" : nil)
                InfoValue(title: "Type", value: details.kind == .movie ? "Movie" : "Series")
            }
        }
        .padding(34)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 70)
    }

    private func load() async {
        errorMessage = nil
        do {
            details = try await app.mediaDetails(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func play() async {
        preparingPlayback = true
        defer { preparingPlayback = false }
        do {
            playbackSource = try await app.playback(for: item)
        } catch {
            requestMessage = error.localizedDescription
        }
    }

    private func request() async {
        do {
            try await app.createRequest(item)
            requestMessage = "Request sent to Seerr."
            await load()
        } catch {
            requestMessage = error.localizedDescription
        }
    }

    private func canPlay(_ details: MediaDetails) -> Bool {
        let availability = details.mediaInfo?.availability
        return availability == .available
            || availability == .partiallyAvailable
            || details.mediaInfo?.jellyfinID != nil
            || details.mediaInfo?.jellyfin4KID != nil
    }

    private func ageLabel(_ value: String) -> String {
        value.rangeOfCharacter(from: .letters) == nil ? "Age \(value)+" : value
    }

    private func currency(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

private struct InfoValue: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text(LocalizedStringKey(title))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(value).font(.body)
            }
        }
    }
}

struct MediaServerDetailView: View {
    @EnvironmentObject private var app: AppModel
    let item: MediaServerItem
    @State private var details: MediaServerItem?
    @State private var backdropURL: URL?
    @State private var posterURL: URL?
    @State private var playbackSource: PlaybackSource?
    @State private var loadingPlayback = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PageBackground()
            if let details {
                ScrollView {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: backdropURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            SeerrPlayTheme.brandGradient.opacity(0.2)
                        }
                        .frame(height: 620)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, SeerrPlayTheme.background],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        }

                        HStack(alignment: .bottom, spacing: 38) {
                            PosterImage(url: posterURL, ratio: 2 / 3)
                                .frame(width: 290, height: 435)
                            VStack(alignment: .leading, spacing: 20) {
                                AvailabilityBadge(availability: .available)
                                Text(details.displayTitle)
                                    .font(.system(size: 56, weight: .bold))
                                HStack(spacing: 18) {
                                    if let year = details.productionYear {
                                        Text(String(year))
                                    }
                                    if let rating = details.officialRating {
                                        Text(rating)
                                    }
                                }
                                .foregroundStyle(.secondary)
                                Button {
                                    Task { await play(details) }
                                } label: {
                                    if loadingPlayback {
                                        ProgressView()
                                    } else {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.white)
                                .foregroundStyle(.black)
                                .disabled(loadingPlayback)
                                if let errorMessage {
                                    Text(errorMessage).foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.horizontal, 70)
                    }
                    Text(details.overview.isEmpty ? "No synopsis is available." : details.overview)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineSpacing(7)
                        .frame(maxWidth: 1300, alignment: .leading)
                        .padding(70)
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .navigationTitle(item.displayTitle)
        .task {
            do {
                async let loaded = app.mediaServerDetails(item)
                async let poster = app.mediaServerImage(item)
                async let backdrop = app.mediaServerImage(item, backdrop: true)
                details = try await loaded
                posterURL = await poster
                backdropURL = await backdrop
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .fullScreenCover(item: $playbackSource) { source in
            NativePlayerView(source: source)
                .environmentObject(app)
                .ignoresSafeArea()
        }
    }

    private func play(_ item: MediaServerItem) async {
        loadingPlayback = true
        defer { loadingPlayback = false }
        do {
            playbackSource = try await app.playback(for: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
