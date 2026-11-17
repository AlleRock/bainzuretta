import SwiftUI
import BainzurettaCore

struct JournalView: View {
    @Environment(AppStore.self) private var store
    var isArchive: Bool
    var body: some View {
        @Bindable var store = store
        let grouping = isArchive ? store.archiveGrouping : store.diaryGrouping
        let groupBinding = Binding(get:{isArchive ? store.archiveGrouping : store.diaryGrouping},set:{if isArchive {store.archiveGrouping = $0} else {store.diaryGrouping = $0}})
        let year = isArchive ? store.selectedYear ?? store.years.first : store.today.year
        let items = year.map { Statistics.year(store.activities,$0,ytd:isArchive ? store.today.dayOfYear : nil) } ?? []
        List {
            Section {
                if isArchive {
                    if store.years.isEmpty { LabeledContent("Anno",value:"Nessun dato") }
                    else { Picker("Anno",selection:$store.selectedYear) { ForEach(store.years,id:\.self) { Text(String($0)).tag(Optional($0)) } } }
                }
                Picker("Vista",selection:groupBinding) { ForEach(Grouping.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            } header: { Text(isArchive ? "ARCHIVIO STORICO YTD" : "DIARIO \(String(store.today.year))") }
            if let year {
                Section { SummaryView(summary:Summary(items)) } header: { Text("\(String(year)) · al giorno \(store.today.dayOfYear)") }
                if isArchive { Section { Text("YTD: confronto fino allo stesso numero di giorno dell’anno, come nella versione web.").font(.caption).foregroundStyle(.secondary) } }
            }
            if items.isEmpty { EmptyState() }
            else if grouping == .activities { Section { ForEach(items) { ActivityRow(activity:$0,editable:!isArchive) } } }
            else {
                let groups = Statistics.groups(items,by:grouping)
                let top = groups.sorted { $0.summary.km > $1.summary.km }.prefix(3).map(\.id)
                Section {
                    ForEach(groups) { group in
                        NavigationLink { ActivityGroupView(group:group) } label: {
                            VStack(alignment:.leading,spacing:8) {
                                HStack { Text(group.label).font(.subheadline.bold()); Spacer(); if let place = top.firstIndex(of:group.id) { Text(["🥇","🥈","🥉"][place]) } }
                                Text(Display.number(group.summary.km)+" km").font(.title3.bold()).foregroundStyle(Brand.textOrange).monospacedDigit()
                                Text("\(group.summary.count) uscite · \(Display.number(group.speed)) km/h" + (group.summary.elevation > 0 ? " · \(Display.number(group.summary.elevation,0)) m" : "")).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical,5)
                        }
                    }
                }
            }
        }.listStyle(.insetGrouped)
    }
}
struct ChallengeView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        let weeks = Statistics.challenge(store.activities,today:store.today,target:store.target)
        List {
            Section {
                LabeledContent("Obiettivo",value:Display.number(store.target,0)+" km")
                LabeledContent("Quota settimanale",value:Display.number(store.target/Double(CivilDate.daysInYear(store.today.year))*7)+" km")
            } header: { Text("LA SFIDA \(String(store.today.year))") } footer: { Text("Settimane da lunedì a domenica. Quota proporzionale ai giorni compresi nell’anno.") }
            Section {
                ForEach(weeks) { week in
                    VStack(alignment:.leading,spacing:7) {
                        HStack { Text("#\(week.number)").bold().foregroundStyle(Brand.textOrange); Text(week.label); Spacer(); if week.current { Text("ORA").font(.caption2.bold()).foregroundStyle(Brand.textOrange) } }.font(.subheadline)
                        HStack {
                            Text("Quota \(Display.number(week.quota)) km").foregroundStyle(.secondary)
                            Spacer()
                            if week.current && week.km == 0 { Text("—") }
                            else { Text("\(Display.number(week.km)) km · \(week.delta >= 0 ? "+" : "")\(Display.number(week.delta))").bold().foregroundStyle(week.delta >= 0 ? Color.green : .red) }
                        }.font(.caption).monospacedDigit()
                    }.padding(.vertical,5).accessibilityElement(children:.combine)
                }
            }
        }
    }
}
struct RankingView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        let metric = store.rankingMetric
        let ranking = Statistics.ranking(store.activities,today:store.today,metric:metric)
        let max = ranking.map(\.value).max() ?? 0
        List {
            Section { Picker("Metrica",selection:$store.rankingMetric) { ForEach(RankingMetric.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu) } header: { Text("RANKING YTD · GIORNO \(store.today.dayOfYear)") }
            if ranking.isEmpty { EmptyState() }
            ForEach(Array(ranking.enumerated()),id:\.element.id) { i, entry in
                Button { if entry.year != store.today.year { store.openYear(entry.year) } } label: {
                    VStack(alignment:.leading,spacing:10) {
                        HStack {
                            Text("\(i+1). \(String(entry.year))").font(.headline).foregroundStyle(.primary)
                            if entry.year != store.today.year { Image(systemName:"arrow.up.right").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Text(Display.number(entry.value,metric == .elevation ? 0 : 2)+" "+metric.unit).font(.subheadline.bold()).foregroundStyle(Brand.textOrange)
                        }
                        ProgressView(value:max > 0 ? entry.value/max : 0).tint(Brand.textOrange)
                        if metric == .distance && entry.year != store.today.year { Text("Totale anno: \(Display.number(entry.total,0)) km").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical,4)
                }.buttonStyle(.plain)
            }
        }
    }
}
struct RecordsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        let category = store.archive.preferences.recordCategory
        let records = RecordEngine(store.activities,today:store.today).records(category)
        VStack(spacing:0) {
            VStack(alignment:.leading,spacing:8) {
                Text("RECORD STORICI").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("Categoria",selection:Binding(get:{category},set:store.setCategory)) {
                    ForEach(RecordCategory.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.menu).disabled(store.busy).accessibilityIdentifier("record-category")
                if !category.note.isEmpty { Text(category.note).font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,20).padding(.vertical,12).background(.bar)
            List {
                if records.isEmpty { EmptyState() }
                ForEach(records) { record in
                    if record.entries.isEmpty { RecordRow(record:record) }
                    else {
                        NavigationLink { RecordStandings(record:record) } label: { RecordRow(record:record) }
                            .accessibilityIdentifier("record-"+record.title)
                    }
                }
            }.id(category)
        }
    }
}
struct RecordRow: View {
    let record: CyclingRecord
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if typeSize.isAccessibilitySize {
                title
                value
            } else {
                HStack(alignment:.top,spacing:12) {
                    title
                    Spacer(minLength:2)
                    value.multilineTextAlignment(.trailing).layoutPriority(1)
                }
            }
            if !record.subtitle.isEmpty { Text(record.subtitle).font(.caption).foregroundStyle(.secondary) }
            else if record.override == nil, let best = record.entries.first { Text(best.title + (best.subtitle.isEmpty ? "" : " — " + best.subtitle)).font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical,5).accessibilityElement(children:.combine)
    }
    private var title: some View {
        HStack(alignment:.top,spacing:8) { Text(record.emoji); Text(record.title).font(.subheadline.weight(.semibold)).fixedSize(horizontal:false,vertical:true) }
    }
    private var value: some View {
        Text(record.value).font(.system(.headline,design:.rounded,weight:.bold)).foregroundStyle(Brand.textOrange).monospacedDigit().fixedSize(horizontal:false,vertical:true)
    }
}
struct RecordStandings: View {
    let record: CyclingRecord
    var body: some View {
        List {
            Section { Text(record.title).font(.headline) }
            ForEach(Array(record.entries.enumerated()),id:\.offset) { index, entry in
                VStack(alignment:.leading,spacing:8) {
                    HStack(alignment:.top) { Text(index < 3 ? ["🥇","🥈","🥉"][index] : "\(index+1)."); Text(entry.title).bold(); Spacer(); Text(entry.value).foregroundStyle(Brand.textOrange).bold().monospacedDigit() }.font(.subheadline)
                    if !entry.subtitle.isEmpty { Text(entry.subtitle).font(.caption).foregroundStyle(.secondary) }
                    if let sid = entry.activity?.stravaID { Button("STRAVA",systemImage:"arrow.up.right.square") { StravaLink.open(sid) }.font(.caption.bold()).buttonStyle(.bordered).tint(.orange) }
                }.padding(.vertical,6)
            }
        }.navigationTitle(record.all ? "Tutte le uscite (\(record.entries.count))" : "TOP 5").navigationBarTitleDisplayMode(.inline)
    }
}
