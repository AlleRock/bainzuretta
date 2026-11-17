import SwiftUI
import BainzurettaCore

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo:.caption2) private var scaledNavigationWidth: CGFloat = 88
    private var navigationItemWidth: CGFloat { typeSize.isAccessibilitySize ? max(176,scaledNavigationWidth) : 58 }
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                switch store.section {
                case .home: HomeView()
                case .diary: JournalView(isArchive:false)
                case .challenge: ChallengeView()
                case .archive: JournalView(isArchive:true)
                case .ranking: RankingView()
                case .records: RecordsView()
                }
            }
            .toolbar {
                ToolbarItem(placement:.principal) {
                    Text("Bainzuretta").font(.system(.title2,design:.serif,weight:.bold).italic()).foregroundStyle(Brand.textOrange).accessibilityAddTraits(.isHeader)
                }
                if store.busy { ToolbarItem(placement:.topBarTrailing) { ProgressView().accessibilityLabel("Operazione in corso") } }
            }
            .navigationBarTitleDisplayMode(.inline)
        }.id(store.section)
            .safeAreaInset(edge:.bottom,spacing:0) {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:0) {
                        ForEach(AppSection.allCases) { section in
                            Button {
                                withAnimation(.easeInOut(duration:0.15)) { store.section = section }
                            } label: {
                                VStack(spacing:5) {
                                    Image(systemName:section.icon).font(.system(size:19,weight:.semibold)).frame(height:22)
                                    Text(section.rawValue).font(.system(.caption2,design:.rounded,weight:.bold)).fixedSize(horizontal:true,vertical:false)
                                }.foregroundStyle(store.section == section ? Brand.orange : .secondary)
                                    .frame(minWidth:navigationItemWidth,minHeight:52)
                                    .frame(maxWidth:.infinity)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("tab-"+section.rawValue)
                                .accessibilityAddTraits(store.section == section ? .isSelected : [])
                        }
                    }.padding(.horizontal,6).containerRelativeFrame(.horizontal) { width, _ in max(width, typeSize.isAccessibilitySize ? navigationItemWidth * 6 + 12 : 0) }
                }.accessibilityIdentifier("main-navigation").background(.bar).overlay(alignment:.top) { Divider() }
            }
            .alert("Bainzuretta",isPresented:Binding(get:{store.notice != nil},set:{if !$0 {store.notice = nil}}),presenting:store.notice) { _ in Button("OK",role:.cancel) {} } message: { Text($0.text) }
            .sheet(item:$store.editActivity) { activity in ManualActivityView(existing:activity).environment(store) }
            .sheet(isPresented:Binding(get:{store.pendingRemoval != nil},set:{if !$0 {store.pendingRemoval = nil}})) {
                NavigationStack {
                    List {
                        Section { Text("Queste attività non risultano più su Strava. Vuoi rimuoverle anche da Bainzuretta?") }
                        ForEach(store.pendingRemoval?.missing ?? []) { a in VStack(alignment:.leading) { Text(a.civil.display).bold(); Text(a.name); Text(Display.number(a.distance)+" km") } }
                        Button("Rimuovi attività elencate",role:.destructive) { do { try store.confirmRemoval() } catch { store.report(error) } }
                    }.navigationTitle("Attività mancanti").toolbar { ToolbarItem(placement:.cancellationAction) { Button("Conserva") { store.pendingRemoval = nil } } }
                }.presentationDetents([.medium,.large])
            }
    }
}
