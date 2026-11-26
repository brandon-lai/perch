import SwiftUI
import AppKit
import PerchCore

struct PreviewView: NSViewRepresentable {
    var pack: PetPack
    var action: Action
    var reduceMotion: Bool
    func makeNSView(context: Context) -> RigPreview { RigPreview(rig: PetRig(pack: pack)) }
    func updateNSView(_ view: RigPreview, context: Context) {
        if view.rig.pack != pack { view.rig = PetRig(pack: pack) }
        view.action = action; view.caption = "\(pack.name.isEmpty ? "Your pet" : pack.name) · \(pack.temperament.rawValue) company"
        view.phase = reduceMotion ? 0 : context.coordinator.phase
        view.needsDisplay = true
        context.coordinator.view = view; context.coordinator.reduced = reduceMotion
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    @MainActor
    final class Coordinator: NSObject {
        weak var view: RigPreview?
        var phase = 0
        var reduced = false
        var timer: Timer?
        override init() {
            super.init()
            timer = Timer(timeInterval: 1.0 / 12, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
            RunLoop.main.add(timer!, forMode: .common)
        }
        @objc func tick() {
            guard let view, view.window?.isVisible == true, !reduced else { return }
            phase = (phase + 1) % 12; view.phase = phase; view.needsDisplay = true
        }
    }
    static func dismantleNSView(_ view: RigPreview, coordinator: Coordinator) { coordinator.timer?.invalidate() }
}
struct SettingsView: View {
    @ObservedObject var controller: AppController
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var deleteConfirmation = false
    private let ink = Color(nsColor: NSColor(hex: "#293341"))
    private let primary = Color(nsColor: NSColor(hex: "#4265AC"))
    private let muted = Color(nsColor: NSColor(hex: "#616B7B"))
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Perch").font(.system(size: 30, weight: .bold))
                Spacer()
                Text("A little red panda for your desktop.").foregroundStyle(muted)
            }.padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 18)
            Divider()
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    PreviewView(pack: controller.draft, action: controller.previewAction,
                        reduceMotion: reduceMotion || controller.preferences.calm)
                        .frame(height: 285).accessibilityLabel("Preview of \(controller.draft.name)")
                    Picker("Preview pose", selection: $controller.previewAction) {
                        ForEach(Action.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Text("One pixel red panda. Its colors stay the same in every pose.")
                        .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                    Text(controller.status).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Label("Local by design", systemImage: "lock")
                        .font(.headline)
                    Text("No uploads, accounts, window titles, screen images or keyboard recording. It uses only where windows and the pointer are right now.")
                        .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                    Text("Bed shortcut  ⌃⌥⌘B").font(.callout.weight(.medium))
                }.frame(width: 280)
                ScrollViewReader { proxy in
                ScrollView {
                    Form {
                        Section {
                            TextField("Name", text: $controller.draft.name)
                            Text("Red pandas climb anywhere on a window: up its face, side on along its edges, and over the top. They grip with every paw, hang on through a brisk drag, catch hold of windows as they fall, and back down tail first.")
                                .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                            colorField("Coat", value: $controller.draft.coat)
                            colorField("Legs and ears", value: $controller.draft.earColor)
                            colorField("Face mask", value: $controller.draft.markingColor)
                            Button("Use red panda colors") {
                                let colors = Species.redPandaColors
                                controller.draft.coat = colors.coat; controller.draft.earColor = colors.ear
                                controller.draft.markingColor = colors.marking
                            }
                            Picker("Size", selection: $controller.draft.size) {
                                ForEach(PetSize.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                            }
                            Picker("Temperament", selection: $controller.draft.temperament) {
                                ForEach(Temperament.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                            }
                        } header: { Text("Your red panda").font(.headline) }
                        Section {
                            Toggle("Calm mode — slower wandering, no mischief", isOn: $controller.preferences.calm)
                            Toggle("Sleep during quiet hours", isOn: $controller.preferences.quietEnabled)
                            if controller.preferences.quietEnabled {
                                HStack {
                                    Picker("From", selection: $controller.preferences.quietStart) {
                                        ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) }
                                    }
                                    Picker("Until", selection: $controller.preferences.quietEnd) {
                                        ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) }
                                    }
                                }
                            }
                        } header: { Text("At your pace").font(.headline) }
                        Section {
                            Toggle("Show its tree", isOn: $controller.preferences.showsTree)
                            Picker("Display", selection: $controller.preferences.treeDisplay) {
                                Text("Main display").tag(String?.none)
                                ForEach(controller.homeDisplays) { display in
                                    Text(display.name).tag(Optional(display.id))
                                }
                                if let id = controller.preferences.treeDisplay, !controller.homeDisplays.contains(where: { $0.id == id }) {
                                    Text("Disconnected display (using main)").tag(Optional(id))
                                }
                            }.disabled(!controller.preferences.showsTree)
                            HStack {
                                Text("Position")
                                Slider(value: $controller.preferences.treePlace, in: 0...1) { Text("Tree position") }
                                    minimumValueLabel: { Text("Left") } maximumValueLabel: { Text("Right") }
                                    .disabled(!controller.preferences.showsTree)
                            }
                            Button("Send it to its tree") { controller.goToTree() }.disabled(!controller.preferences.showsTree)
                            Text("Your red panda climbs its tree to rest, wash and nap on the branch, and sleeps there at night. Drag the tree along the bottom of any display to move it.")
                                .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                        } header: { Text("Its tree").font(.headline) }
                        Section {
                            Toggle("Chew window edges", isOn: $controller.preferences.chews)
                            Text("Leaves a few nibble marks for 20 minutes. Perch draws them over the window's edge; the window itself is never changed.")
                                .font(.callout).foregroundStyle(muted)
                            Toggle("Chase the pointer", isOn: $controller.preferences.playsWithCursor)
                            Text("Anywhere on its display, your red panda goes after the pointer: along window edges, up window faces, with leaps. In reach, it swipes, grabs on and hangs there nibbling. Shake the pointer to drop it. Clicks always pass through, and Perch only uses where the pointer is right now.")
                                .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                            Toggle("Make the pointer bamboo", isOn: $controller.preferences.showsBamboo)
                                .disabled(!controller.preferences.playsWithCursor)
                            Text(controller.skinsPointer
                                 ? "Your arrow becomes a bamboo stalk, tip first. The panda chases it and eats it from the bottom up, and it grows back. Text cursors and other pointers stay as they are. Your usual arrow comes back when Perch quits, sleeps or is tucked away."
                                 : "Draws a bamboo stalk on the pointer's tip. The panda chases it and eats it from the bottom up, and it grows back. This Mac keeps its own arrow on top; the bamboo never takes clicks.")
                                .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                            Toggle("Push windows that are in the way", isOn: Binding(get: { controller.preferences.pushes }, set: { on in
                                if on { controller.setUpWindowPushing() } else { controller.preferences.pushes = false; controller.savePreferences() }
                            }))
                            Label(controller.accessibilityTrusted ? "Perch has Accessibility access" : "Perch needs Accessibility access to push windows",
                                  systemImage: controller.accessibilityTrusted ? "checkmark.circle.fill" : "hand.raised")
                                .foregroundStyle(controller.accessibilityTrusted ? primary : muted)
                            HStack {
                                Button("Test it") { controller.testWindowPush() }.disabled(!controller.accessibilityTrusted)
                                Text(controller.accessibilityTrusted ? "Opens a small Perch window and scoots it."
                                     : "Available once Perch has access.")
                                    .font(.callout).foregroundStyle(muted)
                            }
                            if controller.accessibilityTrusted {
                                Text("A short shove, only while you're not typing, clicking or pointing at that window, and never off screen.")
                                    .font(.callout).foregroundStyle(muted)
                            } else {
                                Button("Set up window pushing…") { controller.setUpWindowPushing() }
                                    .buttonStyle(.borderedProminent)
                                Text("1. Click Set up. System Settings opens at Accessibility.\n2. Switch on Perch (you may need your password).\n3. Come back here; this updates by itself.")
                                    .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Button("Reset and ask again") { controller.resetWindowPushingPermission() }
                                    Text("Perch is switched on but this still says it needs access? macOS remembered an older Perch.")
                                        .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                                }
                                Text("Perch reads only window positions and sizes, never titles or contents.")
                                    .font(.callout).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                            }
                            if let note = controller.pushSetupNote {
                                Text(note).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            }
                            HStack {
                                Button("Play ball") { controller.play() }
                                Button("Tidy up bite marks") { controller.tidyBites() }
                            }
                            Text("Calm mode and Reduce Motion turn mischief off.").font(.callout).foregroundStyle(muted)
                        } header: { Text("Mischief").font(.headline) }
                        Section {
                            HStack {
                                Button("Import pack…") { controller.chooseImport() }
                                Button("Export pack…") { controller.exportPack() }
                            }
                            Button("Delete saved pet…", role: .destructive) { deleteConfirmation = true }
                        } header: { Text("Your files").font(.headline) }.id("files")
                    }.formStyle(.grouped)
                }
                .onChange(of: controller.settingsScrollTarget) { _, target in
                    if let target { proxy.scrollTo(target, anchor: .bottom) }
                }
                }
            }.padding(28)
            Divider()
            HStack {
                Button("Send to bed") { controller.bed() }.keyboardShortcut("b", modifiers: [.control, .option, .command])
                Button("Hop to a window") { controller.hop() }
                Spacer()
                Button("Save & wake") { controller.commit() }.buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).controlSize(.large)
            }.padding(.horizontal, 28).padding(.vertical, 16)
        }
        .foregroundStyle(ink).tint(primary).background(Color(nsColor: NSColor(hex: "#F6F8FC")))
        .alert("Perch needs a moment", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
            Button("OK") { controller.error = nil }
        } message: { Text(controller.error ?? "") }
        .confirmationDialog("Delete the saved pet and settings?", isPresented: $deleteConfirmation) {
            Button("Delete saved pet", role: .destructive) { controller.deletePet() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Source photos were never saved. Export a pack first if you want to keep these traits.") }
    }
    private func colorField(_ label: String, value: Binding<String>) -> some View {
        HStack {
            TextField(label, text: value)
                .accessibilityHint("Enter a six-digit hex color, such as #C58B55")
            Circle().fill(Color(nsColor: NSColor(hex: value.wrappedValue))).frame(width: 18, height: 18).accessibilityHidden(true)
        }
    }
}
