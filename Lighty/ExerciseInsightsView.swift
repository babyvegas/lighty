import SwiftUI

struct ExerciseInsightsView: View {
    enum Section: String, CaseIterable {
        case summary = "Summary"
        case history = "History"
        case indications = "Indications"
    }

    @Binding var exercise: ExerciseEntry
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: Section = .summary

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            sectionSelector
                .padding(.horizontal)
                .padding(.top, 10)

            Rectangle()
                .fill(Color(white: 0.9))
                .frame(height: 1)

            ScrollView {
                Group {
                    switch selectedSection {
                    case .summary:
                        summaryView
                    case .history:
                        historyTemplate
                    case .indications:
                        indicationsTemplate
                    }
                }
                .padding(.horizontal)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(Color.white)
        }
        .background(Color.white)
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
            }

            Spacer()

            Text(exercise.name)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Menu {
                Button("Share (coming soon)") {}
                Button("Add Note (coming soon)") {}
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var sectionSelector: some View {
        HStack(spacing: 0) {
            ForEach(Section.allCases, id: \.self) { item in
                Button {
                    selectedSection = item
                } label: {
                    VStack(spacing: 8) {
                        Text(item.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedSection == item ? .blue : .black)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedSection == item ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ExerciseMediaPanel(imageURL: exercise.imageURL)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Primary muscle: \(exercise.primaryMuscle)")
                    .foregroundStyle(.secondary)

                Text("Secondary muscles: \(secondaryMuscleLabel)")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Progress (Template)")
                    .font(.headline)

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.95))
                    .frame(height: 210)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("History chart placeholder")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private var historyTemplate: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History")
                .font(.headline)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.95))
                .frame(height: 260)
                .overlay(
                    Text("Template: session timeline and PR cards")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var indicationsTemplate: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Indications")
                .font(.headline)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.95))
                .frame(height: 260)
                .overlay(
                    Text("Template: coaching cues and safety indications")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                )
        }
    }

    private var secondaryMuscleLabel: String {
        let list = exercise.secondaryMuscles.filter { !$0.isEmpty }
        return list.isEmpty ? "Not available" : list.joined(separator: ", ")
    }
}

private struct ExerciseMediaPanel: View {
    let imageURL: URL?

    @State private var loadedImage: Image?

    private var mediaHeight: CGFloat {
        UIScreen.main.bounds.height * 0.30
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(white: 0.96))
            .frame(height: mediaHeight)
            .overlay {
                mediaContent
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .task(id: imageURL) {
                await loadImage()
            }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if let loadedImage {
            loadedImage
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .resizable()
                .scaledToFit()
                .padding(36)
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage() async {
        guard let imageURL else {
            loadedImage = nil
            return
        }

        do {
            var request = URLRequest(url: imageURL)
            if imageURL.host?.contains("rapidapi.com") == true {
                request.setValue(ExerciseDBConfig.apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
                request.setValue(ExerciseDBConfig.host, forHTTPHeaderField: "X-RapidAPI-Host")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode,
                  let uiImage = UIImage(data: data) else {
                loadedImage = nil
                return
            }

            loadedImage = Image(uiImage: uiImage)
        } catch {
            loadedImage = nil
        }
    }
}

#Preview {
    ExerciseInsightsView(
        exercise: .constant(
            ExerciseEntry(
                name: "Barbell Bench Press",
                imageURL: nil,
                mediaURL: nil,
                primaryMuscle: "Chest",
                secondaryMuscles: ["Shoulders", "Triceps"]
            )
        )
    )
}
