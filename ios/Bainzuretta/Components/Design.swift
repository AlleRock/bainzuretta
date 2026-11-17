import SwiftUI
import BainzurettaCore

enum Brand {
    static let orange = Color(red:0.984,green:0.549,blue:0)
    static let background = Color(uiColor:.systemGroupedBackground)
}
struct Metric: View {
    var title: String, value: String, unit: String = ""
    var body: some View {
        VStack(alignment:.leading,spacing:5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            (Text(value).font(.system(.title3,design:.rounded,weight:.bold)) + Text(unit.isEmpty ? "" : " " + unit).font(.caption)).monospacedDigit()
        }.frame(maxWidth:.infinity,alignment:.leading).padding(12)
            .background(Brand.orange.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
            .accessibilityElement(children:.combine)
    }
}
struct SummaryView: View {
    let summary: Summary
    var body: some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:130),alignment:.leading)],spacing:8) {
            Metric(title:"Distanza",value:Display.number(summary.km),unit:"km")
            Metric(title:"Attività",value:String(summary.count))
            Metric(title:"Media ponderata",value:Display.number(summary.weightedSpeed,2),unit:"km/h")
            Metric(title:"Dislivello",value:Display.number(summary.elevation,0),unit:"m")
        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top:4,leading:0,bottom:4,trailing:0))
    }
}
struct EmptyState: View {
    var title: String = "Nessuna attività", description: String = "Aggiungi un’attività o importa un backup JSON dalla HOME."
    var body: some View { ContentUnavailableView(title,systemImage:"bicycle",description:Text(description)) }
}
struct ActivityRow: View {
    @Environment(AppStore.self) private var store
    var activity: Activity, editable = false
    @State private var confirmDelete = false
    var body: some View {
        NavigationLink { ActivityDetail(activity:activity,editable:editable) } label: {
            VStack(alignment:.leading,spacing:7) {
                HStack {
                    Text(activity.civil.display).font(.subheadline.weight(.semibold))
                    Spacer()
                    if activity.stravaID != nil { Text("STRAVA").font(.caption2.bold()).foregroundStyle(.orange) }
                }
                if !activity.name.isEmpty { Text(activity.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                HStack(spacing:12) {
                    Text(Display.number(activity.distance) + " km").foregroundStyle(Brand.orange).bold()
                    Text(Display.time(activity.hours))
                    Text(Display.number(activity.speed) + " km/h")
                }.font(.footnote).monospacedDigit().fixedSize(horizontal:false,vertical:true)
            }.padding(.vertical,4)
        }
        .accessibilityIdentifier("activity-"+activity.id)
        .contextMenu {
            if editable {
                if activity.stravaID == nil { Button("Modifica",systemImage:"pencil") { store.section = .home; store.editActivity = activity }.disabled(store.busy) }
                Button("Elimina",systemImage:"trash",role:.destructive) { confirmDelete = true }.disabled(store.busy)
            }
            if let sid = activity.stravaID { Button("Apri su Strava",systemImage:"arrow.up.right.square") { StravaLink.open(sid) } }
        }
        .swipeActions {
            if editable {
                Button("Elimina",role:.destructive) { confirmDelete = true }.disabled(store.busy)
                if activity.stravaID == nil { Button("Modifica") { store.section = .home; store.editActivity = activity }.tint(.blue).disabled(store.busy) }
            }
        }
        .confirmationDialog("Eliminare questa attività da Bainzuretta?",isPresented:$confirmDelete,titleVisibility:.visible) {
            Button("Elimina attività",role:.destructive) { do { try store.delete(activity) } catch { store.report(error) } }
        } message: { Text("L’attività su Strava rimane disponibile.") }
    }
}
struct ActivityDetail: View {
    @Environment(AppStore.self) private var store
    var activity: Activity, editable = false
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                if !activity.name.isEmpty { Text(activity.name).font(.title2.bold()) }
                LabeledContent("Data",value:activity.civil.display)
                LabeledContent("Distanza",value:Display.number(activity.distance) + " km")
                LabeledContent("Tempo",value:Display.time(activity.hours))
                LabeledContent("Velocità media",value:Display.number(activity.speed,2) + " km/h")
                if activity.elevation > 0 { LabeledContent("Dislivello",value:Display.number(activity.elevation,0) + " m") }
                if activity.cadence > 0 { LabeledContent("Cadenza",value:Display.number(activity.cadence,0) + " rpm") }
            }
            if let sid = activity.stravaID { Section { Button("Apri su Strava",systemImage:"arrow.up.right.square") { StravaLink.open(sid) } } }
            if editable {
                Section {
                    if activity.stravaID == nil { Button("Modifica attività",systemImage:"pencil") { dismiss(); store.section = .home; store.editActivity = activity }.disabled(store.busy) }
                    Button("Elimina attività",systemImage:"trash",role:.destructive) { deleting = true }.disabled(store.busy)
                }
            }
        }.navigationTitle("Attività").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Eliminare l’attività?",isPresented:$deleting,titleVisibility:.visible) {
                Button("Elimina",role:.destructive) { do { try store.delete(activity); dismiss() } catch { store.report(error) } }
            }
    }
}
enum StravaLink {
    @MainActor static func open(_ id: String) {
        guard id.allSatisfy(\.isNumber), let app = URL(string:"strava://activities/"+id), let web = URL(string:"https://www.strava.com/activities/"+id) else { return }
        UIApplication.shared.open(app,options:[:]) { opened in if !opened { Task { @MainActor in UIApplication.shared.open(web) } } }
    }
}
struct ActivityGroupView: View {
    let group: ActivityGroup
    var body: some View {
        List { SummaryView(summary:group.summary); ForEach(group.items.sorted { $0.civil > $1.civil }) { ActivityRow(activity:$0) } }
            .navigationTitle(group.label).navigationBarTitleDisplayMode(.inline)
    }
}
