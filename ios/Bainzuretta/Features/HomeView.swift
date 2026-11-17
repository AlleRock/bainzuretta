import SwiftUI
import BainzurettaCore

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var manual = false
    @State private var goal = false
    @State private var configuration = false
    @State private var importing = false
    @State private var pasting = false
    @State private var exporting = false
    @State private var reset = false
    @State private var restoring = false
    @State private var disconnecting = false
    @State private var candidate: Archive?
    @State private var confirmImport = false
    @State private var pastedData: Data?
    @State private var document: JSONDocument?
    @State private var filename = "bainzuretta"
    @State private var shared: SharedFile?
    var body: some View {
        let best = Statistics.bestSpeedYear(store.activities)
        List {
            Section {
                GoalCard(goal:Statistics.goal(store.activities,today:store.today,target:store.target),year:store.today.year) { goal = true }
            }.listRowBackground(Color.clear).listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
            Section {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:130))],spacing:8) {
                    Metric(title:"Totale km storici",value:Display.number(Summary(store.activities).km,2),unit:"km")
                    Metric(title:"Giri del mondo",value:Display.fixed(Summary(store.activities).km/40075,2))
                    Metric(title:"Top media anno",value:Display.fixed(best.1,2),unit:"km/h")
                    Metric(title:"Anno migliore",value:best.0.map(String.init) ?? "—")
                }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if !store.readable { Section { Label("Archivio non leggibile. Importa una copia valida o ripristina la precedente.",systemImage:"exclamationmark.triangle").foregroundStyle(.red) } }
            Section {
                Button("Aggiungi attività manuale",systemImage:"plus.circle.fill") { manual = true }.disabled(!store.readable || store.busy).accessibilityIdentifier("add-manual")
            }
            Section {
                if store.strava.connected {
                    Label("Connesso a Strava" + (store.strava.name.isEmpty ? "" : " come " + store.strava.name),systemImage:"checkmark.circle.fill").font(.subheadline).foregroundStyle(.orange)
                    Button("Sincronizza Strava",systemImage:"arrow.triangle.2.circlepath") { Task { await store.sync() } }.disabled(store.busy || !store.readable)
                    Button("Risincronizza ultimi 60 giorni",systemImage:"clock.arrow.circlepath") { Task { await store.sync(resync:true) } }.disabled(store.busy || !store.readable)
                    Button("Disconnetti",role:.destructive) { disconnecting = true }.disabled(store.busy)
                } else {
                    Text("Strava non collegato").font(.subheadline).foregroundStyle(.secondary)
                    Button("Connetti con Strava",systemImage:"link") {
                        if store.strava.configured { Task { await store.connect() } } else { configuration = true }
                    }.disabled(store.busy)
                    Button("Configura collegamento sicuro",systemImage:"gearshape") { configuration = true }.font(.footnote).disabled(store.busy)
                }
                if store.busy { ProgressView("Operazione in corso…") }
                if !store.syncMessage.isEmpty { Text(store.syncMessage).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("operation-status") }
            } header: { Text("STRAVA") }
            Section {
                Button("Backup JSON",systemImage:"square.and.arrow.up") { export(full:false) }.disabled(!store.readable)
                Button("Importa JSON",systemImage:"square.and.arrow.down") { importing = true }.disabled(store.busy)
                DisclosureGroup("Altre opzioni di backup") {
                    Button("Incolla backup JSON",systemImage:"doc.on.clipboard") { pasting = true }.disabled(store.busy).accessibilityIdentifier("paste-backup")
                    Button("Backup completo con obiettivi e preferenze") { export(full:true) }.disabled(!store.readable)
                    if store.hasRecovery { Button("Ripristina archivio precedente") { restoring = true }.disabled(store.busy) }
                }.accessibilityIdentifier("backup-options")
                Button("PDF riepilogo anno",systemImage:"doc.richtext") {
                    do { shared = SharedFile(url:try AnnualReport.generate(store.activities,year:store.today.year)) } catch { store.report(error) }
                }.disabled(!store.readable)
                Button("Reset dati",systemImage:"trash",role:.destructive) { reset = true }.disabled(store.busy)
            } header: { Text("DATI E REPORT") } footer: { Text("Il backup JSON conserva il formato Bainzuretta web. Il backup completo include anche obiettivi e preferenze; non contiene credenziali.") }
        }.listStyle(.insetGrouped)
            .sheet(isPresented:$manual) { ManualActivityView().environment(store) }
            .sheet(isPresented:$goal) { GoalSettings().environment(store) }
            .sheet(isPresented:$configuration) { StravaSettings().environment(store) }
            .sheet(isPresented:$pasting,onDismiss:{
                if let data = pastedData { pastedData = nil; preview(data) }
            }) { PasteBackupView { data in pastedData = data } }
            .sheet(item:$shared) { ShareFileView(url:$0.url).presentationDetents([.medium,.large]) }
            .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:filename) { result in if case .failure(let error) = result { store.report(error) } }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.json],allowsMultipleSelection:false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    preview(try Data(contentsOf:url))
                } catch { store.report(error) }
            }
            .alert("Sostituire l’archivio?",isPresented:$confirmImport,presenting:candidate) { archive in
                Button("Sostituisci",role:.destructive) { do { try store.importArchive(archive); candidate = nil } catch { store.report(error) } }
                Button("Annulla",role:.cancel) { candidate = nil }
            } message: { archive in Text("Attuale: \(store.activities.count) attività. File selezionato: \(archive.activities.count). La copia precedente sarà conservata per il ripristino.") }
            .confirmationDialog("Ripristinare la copia precedente?",isPresented:$restoring,titleVisibility:.visible) {
                Button("Ripristina",role:.destructive) { do { try store.restore() } catch { store.report(error) } }
            } message: { Text("L’archivio attuale leggibile sarà conservato come copia di recupero.") }
            .confirmationDialog("Disconnettere Strava?",isPresented:$disconnecting,titleVisibility:.visible) {
                Button("Solo questo dispositivo") { Task { await store.disconnect(revoke:false) } }
                Button("Revoca anche l’autorizzazione",role:.destructive) { Task { await store.disconnect(revoke:true) } }
            } message: { Text("Le attività importate restano in Bainzuretta.") }
            .confirmationDialog("Reset dati Bainzuretta",isPresented:$reset,titleVisibility:.visible) {
                Button("Elimina tutti i dati locali",role:.destructive) { do { try store.reset() } catch { store.report(error) } }
            } message: { Text("Elimina attività, obiettivi, preferenze, backup locali e credenziali. Per conservare le attività annulla e usa prima BACKUP JSON. Strava non verrà modificato.") }
    }
    private func preview(_ data: Data) {
        let current = store.archive
        Task {
            do {
                let next = try await Task.detached(priority:.userInitiated) { try Archive.importing(data,current:current) }.value
                candidate = next; confirmImport = true
            } catch { store.report(error) }
        }
    }
    private func export(full: Bool) {
        do {
            let data = full ? try JSONEncoder().encode(store.archive) : try ArchiveCodec.encode(store.activities)
            filename = full ? "Bainzuretta-backup-completo" : "bainzuretta"
            document = JSONDocument(data:data); exporting = true
        } catch { store.report(error) }
    }
}

struct GoalCard: View {
    let goal: Goal, year: Int, action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false
    var color: Color {
        switch goal.pace { case .achieved: return .yellow; case .ahead: return Color(red:0.14,green:0.48,blue:0.22); case .warning: return Color(red:0.69,green:0.43,blue:0); case .behind: return Color(red:0.72,green:0.13,blue:0.14); case .empty: return Brand.orange }
    }
    var body: some View {
        Button(action:action) {
            VStack(alignment:.leading,spacing:12) {
                HStack { Label("OBIETTIVO \(year)",systemImage:goal.pace == .achieved ? "trophy.fill" : "flag.checkered").font(.caption.bold()); Spacer(); Image(systemName:"info.circle").accessibilityLabel("Modifica e informazioni sull’obiettivo") }
                if goal.pace == .achieved {
                    Text("Obiettivo raggiunto!").font(.system(.title,design:.rounded,weight:.bold))
                    Text("⭐️ ⭐️ ⭐️  \(Display.number(goal.km,0)) km · +\(Display.number(goal.km-goal.target,0)) km").font(.subheadline.bold())
                } else {
                    Text(Display.number(goal.remaining,goal.remaining.rounded() == goal.remaining ? 0 : 1)).font(.system(.largeTitle,design:.rounded,weight:.heavy)).monospacedDigit()
                    Text("KM AL TRAGUARDO").font(.caption.weight(.semibold))
                }
                HStack {
                    ProgressView(value:min(1,max(0,goal.progress))).tint(goal.pace == .achieved ? .brown : .white)
                    Text(Display.number(goal.progress * 100) + "%").font(.caption.bold()).monospacedDigit()
                }
                HStack(alignment:.top) {
                    column("Target",Display.number(goal.target,0)); Spacer(); column("Proiezione",Display.number(goal.projection,0)); Spacer(); column("Km/sett",Display.number(goal.weeklyRequired,0))
                }
                if goal.pace != .empty && goal.pace != .achieved {
                    Divider().overlay(.white.opacity(0.4))
                    Text(goal.delta >= 0 ? "✓ In anticipo di \(Display.number(abs(goal.delta),0)) km" : "In ritardo di \(Display.number(abs(goal.delta),0)) km").font(.subheadline.bold())
                    if let days = goal.arrivalDays, days.isFinite, days < 3_000_000 {
                        Text("Arrivo previsto: \(Date().addingTimeInterval(days*86400).formatted(.dateTime.day().month(.wide).year()))").font(.caption)
                    }
                }
            }.padding(20).foregroundStyle(goal.pace == .achieved ? Color(red:0.34,green:0.22,blue:0) : .white)
                .background(LinearGradient(colors:[color,color.opacity(goal.pace == .achieved && glow ? 0.6 : 0.9)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:24))
                .shadow(color:color.opacity(goal.pace == .achieved && glow ? 0.4 : 0.08),radius:glow ? 18 : 4,y:4)
        }.buttonStyle(.plain).accessibilityIdentifier("annual-goal")
            .sensoryFeedback(.success,trigger:goal.pace) { _, new in new == .achieved }
            .onChange(of:goal.pace) { _, new in
                if new == .achieved && !reduceMotion { withAnimation(.easeInOut(duration:2).repeatForever(autoreverses:true)) { glow = true } }
                else { glow = false }
            }
            .onAppear { if goal.pace == .achieved && !reduceMotion { withAnimation(.easeInOut(duration:2).repeatForever(autoreverses:true)) { glow = true } } }
    }
    private func column(_ title: String,_ value: String) -> some View { VStack(alignment:.leading,spacing:4) { Text(title).font(.caption2); Text(value).font(.system(.subheadline,design:.rounded,weight:.bold)).monospacedDigit() } }
}
struct GoalSettings: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Obiettivo annuale") { TextField("Chilometri",text:$value).keyboardType(.numberPad) }
                if let error { Text(error).foregroundStyle(.red) }
                Section("Legenda colori") {
                    Label("Verde · in anticipo sul passo necessario",systemImage:"checkmark.circle.fill").foregroundStyle(.green)
                    Label("Giallo · ritardo fino al 10%",systemImage:"exclamationmark.circle.fill").foregroundStyle(.orange)
                    Label("Rosso · ritardo oltre il 10%",systemImage:"minus.circle.fill").foregroundStyle(.red)
                    Label("Oro · obiettivo raggiunto",systemImage:"trophy.fill").foregroundStyle(.orange)
                }
                Section("Calcoli") {
                    Text("Proiezione = km fatti ÷ giorno dell’anno × giorni totali dell’anno.")
                    Text("Km/sett = km mancanti ÷ settimane rimanenti (almeno un giorno).")
                    Text("Arrivo previsto = data attuale + giorni necessari al passo medio attuale.")
                }.font(.footnote)
            }.navigationTitle("Obiettivo \(store.today.year)").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("Salva") { do { try store.setTarget(value); dismiss() } catch { self.error = error.localizedDescription } }.disabled(store.busy) } }
                .onAppear { value = String(format:"%.0f",store.target) }
        }
    }
}
struct StravaSettings: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = ""
    @State private var pairing = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Il collegamento sicuro protegge il Client Secret fuori dall’app. Completa una volta la configurazione descritta nella guida Strava del progetto.").font(.subheadline)
                    TextField("Indirizzo HTTPS del collegamento",text:$endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Chiave privata di abbinamento",text:$pairing).textInputAutocapitalization(.never).autocorrectionDisabled()
                } footer: { Text("Qui serve la chiave di abbinamento del collegamento, non il Client Secret Strava. Le credenziali sono conservate nel portachiavi di iOS.") }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Collega Strava").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("Salva") { do { try store.strava.configure(endpoint:endpoint,pairingKey:pairing); dismiss() } catch { self.error = error.localizedDescription } } } }
                .onAppear { endpoint = store.strava.endpointText }
        }
    }
}
struct PasteBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let receive: (Data) -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:12) {
                Text("Incolla il contenuto completo del file JSON. Dopo la verifica potrai confermare la sostituzione dell’archivio.").font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text:$text).font(.system(.footnote,design:.monospaced)).autocorrectionDisabled().textInputAutocapitalization(.never).accessibilityIdentifier("backup-text")
            }.padding().navigationTitle("Incolla backup JSON").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("Verifica") { let data = Data(text.utf8); dismiss(); receive(data) }.disabled(text.isEmpty) } }
        }
    }
}
