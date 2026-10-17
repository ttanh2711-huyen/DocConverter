import SwiftUI

@main
struct DocConverterApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("DocConverter", id: "main") {
            ContentView(model: model)
        }
    }
}
