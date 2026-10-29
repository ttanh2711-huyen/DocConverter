import Foundation
import Testing
@testable import DocConverterKit

@Test(arguments: [
    (ConversionOptions.PDFFormat.markdown, "md"),
    (.word, "docx"),
    (.both, "md,docx"),
])
func formatArgument(format: ConversionOptions.PDFFormat, expected: String) {
    let args = ConversionOptions(pdfFormat: format).arguments
    #expect(args.starts(with: ["--to", expected]))
}

@Test func besideSourceIsDefault() {
    #expect(ConversionOptions().arguments == ["--to", "md", "--out-mode", "beside"])
}

@Test func customFolderPassesOutPath() {
    let options = ConversionOptions(pdfFormat: .both, location: .folder(URL(fileURLWithPath: "/Users/a/Kết quả")))
    #expect(options.arguments == ["--to", "md,docx", "--out-mode", "dir", "--out", "/Users/a/Kết quả"])
}

@Test func manifestCarriesBaseForStructure() throws {
    var item = JobItem(url: URL(fileURLWithPath: "/in/sub/x.pdf"), base: URL(fileURLWithPath: "/in"))
    item.status = .pending
    let data = ConversionOptions.manifest(for: [item])
    let list = try JSONSerialization.jsonObject(with: data) as! [[String: String]]
    #expect(list == [["src": "/in/sub/x.pdf", "base": "/in"]])
}

@Test func optionsRoundTripThroughUserDefaults() throws {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    #expect(ConversionOptions.load(from: defaults) == ConversionOptions(register: ConversionOptions.defaultRegister))
    let options = ConversionOptions(pdfFormat: .word, location: .folder(URL(fileURLWithPath: "/tmp/Đầu ra")),
                                    register: URL(fileURLWithPath: "/tmp/Sổ văn bản.xlsx"))
    options.save(to: defaults)
    #expect(ConversionOptions.load(from: defaults) == options)
}

@Test func ocrFlagsOnlyWhenNotDefault() {
    var options = ConversionOptions()
    options.ocr = .init(mode: .force, engine: .easyocr, tables: false)
    #expect(options.arguments == ["--to", "md", "--out-mode", "beside",
                                  "--ocr", "force", "--ocr-engine", "easyocr", "--no-tables"])
}

@Test func ocrSettingsRoundTrip() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    var options = ConversionOptions()
    options.ocr = .init(mode: .off, engine: .ocrmac, tables: true)
    options.save(to: defaults)
    #expect(ConversionOptions.load(from: defaults).ocr == options.ocr)
}

@Test func registerArgumentAndDisabling() {
    let book = URL(fileURLWithPath: "/Users/a/Tổng hợp văn bản.xlsx")
    #expect(ConversionOptions(register: book).arguments
            == ["--to", "md", "--out-mode", "beside", "--register", "/Users/a/Tổng hợp văn bản.xlsx"])
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    defaults.set(false, forKey: ConversionOptions.Keys.registerEnabled)
    #expect(ConversionOptions.load(from: defaults).register == nil)
}
