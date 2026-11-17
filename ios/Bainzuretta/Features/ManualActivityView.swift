import SwiftUI
import BainzurettaCore

struct ManualActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Activity?
    @State private var date = Date(), distance = "", duration = ""
    @State private var error: String?
    private func dateText() -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier:.gregorian); f.locale = Locale(identifier:"en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from:date)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Attività manuale") {
                    DatePicker("Data",selection:$date,displayedComponents:.date).environment(\.calendar,Calendar(identifier:.gregorian))
                    TextField("Distanza (km)",text:$distance).keyboardType(.decimalPad).accessibilityIdentifier("manual-distance")
                    TextField("Durata HH:MM:SS",text:$duration).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("manual-duration")
                }
                Section { Text("La velocità media viene calcolata dalla distanza e dalla durata. Puoi inserire anche ore decimali.").font(.footnote).foregroundStyle(.secondary) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle(existing == nil ? "Aggiungi attività" : "Modifica attività").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement:.confirmationAction) {
                    Button("Salva") {
                        do { try store.saveManual(day:dateText(),distance:distance,duration:duration,existing:existing); dismiss() } catch { self.error = error.localizedDescription }
                    }.bold().disabled(store.busy).accessibilityIdentifier("manual-save")
                }
            }
            .onAppear {
                if let existing {
                    let f = DateFormatter(); f.calendar = Calendar(identifier:.gregorian); f.locale = Locale(identifier:"en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
                    date = f.date(from:existing.civil.isoDay) ?? Date(); distance = String(existing.distance); duration = Display.time(existing.hours)
                }
            }
        }
    }
}
