import AstroCore
import SwiftUI

struct AskView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var deepAnalysisStore = AskDeepAnalysisStore.shared
    @State var mode: HoraryQuestionMode?
    @State var question = ""
    @State var primaryHouse: Int?
    @State var relatedHouses: Set<Int> = []
    @State var options = [AskOptionDraft(), AskOptionDraft()]
    @State var sharedSamePrimary: Bool?
    @State var sharedPrimaryHouse: Int?
    @State var sharedRelatedHouses: Set<Int> = []
    @State var chartDate = Date()
    @State var bestTimeWindow: BestTimeSearchWindow = .thirtyDays
    @State var location: LocationSelection?
    @State var showsLocationPicker = false
    @State var session: HorarySession?
    @State var isCalculating = false
    @State var progress = 0.0
    @State var errorMessage: String?
    @State var calculationTask: Task<Void, Never>?
    @State var askHistory: [AskHistoryEntry] = []
    @State var showAskHistory = false
    @State var showLifeAreasHelp = false
    @FocusState var focusedInputID: String?
    let askHistoryStore = AskHistoryStore()

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    modeSelection
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsLocationPicker) {
                LocationSearchView(language: model.language) {
                    location = $0
                }
            }
            .sheet(isPresented: $showLifeAreasHelp) {
                ABCLifeAreasHelpView(language: model.language)
            }
            .onAppear {
                if location == nil {
                    location = profileLocation
                }
                askHistory = askHistoryStore.load()
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { mode != nil },
                    set: { isPresented in
                        if !isPresented {
                            resetToModes()
                        }
                    }
                )
            ) {
                if let mode {
                    askFlow(mode)
                }
            }
            .navigationDestination(isPresented: $showAskHistory) {
                AskHistoryView(
                    entries: $askHistory,
                    language: model.language,
                    onOpen: { entry in
                        openHistoryEntry(entry)
                    },
                    onDelete: { entry in
                        askHistoryStore.remove(id: entry.id)
                    }
                )
            }
        }
        .onDisappear {
            calculationTask?.cancel()
        }
    }

    func askFlow(_ mode: HoraryQuestionMode) -> some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if let session {
                        resultView(session)
                    } else {
                        configurationView(mode)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(session == nil
            ? modeTitle(mode)
            : localized("ask.your-answer", language: model.language))
        .navigationBarTitleDisplayMode(.inline)
    }

}
