import SwiftUI

struct PersonDestination: Hashable {
    let id: Int
    let name: String
}

struct PersonDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PersonViewModel()

    let person: PersonDestination

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    loadPerson()
                }
            } else {
                contentView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .task {
            loadPerson()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                headerSection
                    .padding(.horizontal, 60)

                ForEach(viewModel.creditSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .padding(.horizontal, 60)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 30) {
                                ForEach(section.items) { item in
                                    NavigationLink(value: item) {
                                        MediaCard(item: item)
                                    }
                                    .buttonStyle(.focusableCard)
                                }
                            }
                            .padding(.horizontal, 60)
                        }
                        .focusSection()
                    }
                }
            }
            .padding(.vertical, 40)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 30) {
            profileImage
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.personDetails?.name ?? person.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let department = viewModel.personDetails?.knownForDepartment, !department.isEmpty {
                    Text(department)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let biography = viewModel.personDetails?.biography, !biography.isEmpty {
                    Text(biography)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .focusable()
                }
            }
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let url = ImageService.posterURL(viewModel.personDetails?.profilePath, size: .w185) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Circle().fill(.quaternary)
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(Circle())
        } else {
            Circle().fill(.quaternary)
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
        }
    }

    private func loadPerson() {
        guard let client = appState.overseerrClient else { return }
        Task {
            await viewModel.loadPerson(personId: person.id, using: client)
        }
    }
}
