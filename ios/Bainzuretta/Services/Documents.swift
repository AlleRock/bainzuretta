import SwiftUI
import UniformTypeIdentifiers
import BainzurettaCore

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}
struct SharedFile: Identifiable { let url: URL; var id: URL { url } }
struct ShareFileView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems:[url],applicationActivities:nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController,context: Context) {}
}

@MainActor enum AnnualReport {
    static func generate(_ data: [Activity], year: Int) throws -> URL {
        let items = Statistics.year(data,year).reversed(), list = Array(items)
        guard !list.isEmpty else { throw ArchiveError.invalid("nessun dato per il \(year)") }
        let summary = Summary(list), bounds = CGRect(x:0,y:0,width:595,height:842)
        let renderer = UIGraphicsPDFRenderer(bounds:bounds)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Bainzuretta_\(year).pdf")
        try renderer.writePDF(to:url) { context in
            var y: CGFloat = 0, page = 0
            let black = UIColor.black, orange = UIColor(red:0.984,green:0.549,blue:0,alpha:1)
            func newPage() {
                context.beginPage(); page += 1
                UIColor.white.setFill(); context.cgContext.fill(bounds)
                let header = "Bainzuretta · Riepilogo \(year)"
                header.draw(at:CGPoint(x:36,y:26),withAttributes:[.font:UIFont.boldSystemFont(ofSize:18),.foregroundColor:orange])
                "Pagina \(page) · \(Date().formatted(date:.numeric,time:.omitted))".draw(at:CGPoint(x:36,y:815),withAttributes:[.font:UIFont.systemFont(ofSize:9),.foregroundColor:UIColor.gray])
                y = 62
            }
            func write(_ text: String, size: CGFloat = 10, bold: Bool = false, color: UIColor = .black) {
                let attributes: [NSAttributedString.Key:Any] = [.font:bold ? UIFont.boldSystemFont(ofSize:size) : UIFont.systemFont(ofSize:size),.foregroundColor:color]
                let height = ceil((text as NSString).boundingRect(with:CGSize(width:523,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attributes,context:nil).height) + 8
                if y + height > 800 { newPage() }
                (text as NSString).draw(in:CGRect(x:36,y:y,width:523,height:height),withAttributes:attributes); y += height
            }
            func section(_ title: String) { y += 10; write(title,size:13,bold:true,color:orange) }
            newPage()
            write("\(Display.number(summary.km)) km · \(summary.count) uscite · \(Display.fixed(summary.reportSpeed,2)) km/h media ponderata",size:13,bold:true)
            write("\(Display.number(summary.km/Double(summary.count))) km medi/uscita · \(Int(summary.storedHours))h \(Int(floor(summary.storedHours.truncatingRemainder(dividingBy:1)*60+0.5)))m in sella · \(Display.fixed(summary.km/40075,3)) giri del mondo")
            section("Top 5 Uscite per Distanza")
            for (i,a) in list.sorted(by:{$0.distance > $1.distance}).prefix(5).enumerated() {
                write("\(i+1). \(a.civil.display) · \(a.name.isEmpty ? "—" : a.name) · \(Display.number(a.distance)) km · \(Display.fixed(a.speed,2)) km/h")
            }
            section("Top 5 Uscite per Velocità")
            for (i,a) in list.filter({$0.speed>0}).sorted(by:{$0.speed>$1.speed}).prefix(5).enumerated() {
                write("\(i+1). \(a.civil.display) · \(a.name.isEmpty ? "—" : a.name) · \(Display.fixed(a.speed,2)) km/h · \(Display.number(a.distance)) km")
            }
            section("Statistiche Mensili")
            for group in Statistics.groups(list,by:.month).reversed() {
                write("\(group.label) · \(Display.number(group.summary.km)) km · \(group.summary.count) uscite · \(Display.number(group.summary.km/Double(group.summary.count))) km/uscita")
            }
            if let best = list.filter({$0.cadence > 0}).max(by:{$0.cadence <= $1.cadence}) {
                section("Record Cadenza \(year)")
                write("\(Display.number(best.cadence,0)) rpm · \(best.civil.display) · \(best.name)")
            }
            section("Tutte le Attività \(year)")
            for (i,a) in list.enumerated() {
                write("\(i+1). \(a.civil.display) · \(a.name.isEmpty ? "—" : a.name)",bold:true,color:black)
                write("\(Display.number(a.distance)) km · \(Display.time(a.hours)) · \(Display.fixed(a.speed,2)) km/h · D+ \(a.elevation > 0 ? Display.number(a.elevation,0)+" m" : "—") · \(a.cadence > 0 ? Display.number(a.cadence,0)+" rpm" : "—")")
            }
        }
        return url
    }
}
