import SwiftUI

struct PersonDetailView: View {
    @EnvironmentObject private var app: AppModel
    let personID: Int
    @State private var person: PersonDetails?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PageBackground()
            if let person {
                ScrollView {
                    VStack(alignment: .leading, spacing: 45) {
                        HStack(alignment: .top, spacing: 45) {
                            PosterImage(url: person.imageURL, ratio: 2 / 3)
                                .frame(width: 320, height: 480)
                            VStack(alignment: .leading, spacing: 18) {
                                Text(person.name)
                                    .font(.system(size: 58, weight: .bold))
                                if !person.department.isEmpty {
                                    Text(person.department)
                                        .font(.title2)
                                        .foregroundStyle(SeerrPlayTheme.cyan)
                                }
                                if let birthday = person.birthday {
                                    Label(
                                        birthday.formatted(date: .long, time: .omitted),
                                        systemImage: "birthday.cake"
                                    )
                                }
                                if let place = person.placeOfBirth {
                                    Label(place, systemImage: "mappin.and.ellipse")
                                }
                                Text(person.biography.isEmpty ? "No biography is available." : person.biography)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(12)
                                    .lineSpacing(6)
                            }
                        }
                        MediaRail(title: "Movies and series", items: person.credits)
                    }
                    .padding(70)
                }
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            person = try await app.personDetails(personID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
