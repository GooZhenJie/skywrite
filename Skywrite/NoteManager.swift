import AppKit
import SkywriteCore

final class NoteManager {
    private(set) var store: NoteStore
    private(set) var areNotesHidden = false
    var style: NoteStyle {
        didSet {
            guard style != oldValue else { return }
            controllers.values.forEach { $0.apply(style) }
        }
    }
    private var records: [NoteRecord] = []
    private var controllers: [UUID: NoteController] = [:]
    private var closedNotes: [UUID] = []
    private var pendingSave: Task<Void, Never>?
    private var mouseMonitors: [Any] = []
    private var hasReportedError = false
    /// Set while Skywrite uninstalls itself, so nothing writes notes.json back after it went to the Trash.
    private var isSavingStopped = false

    init(store: NoteStore, style: NoteStyle) {
        self.store = store
        self.style = style
        installMouseMonitors()
    }

    var canReopen: Bool {
        !closedNotes.isEmpty
    }

    func restoreNotes() {
        do {
            records = try store.loadRecords()
        } catch {
            report(error)
            records = []
        }
        records.removeAll { record in
            guard let fileName = record.fileName else { return true }
            return !store.fileExists(fileName)
        }
        EventLog.notes.notice("restore notes total=\(self.records.count, privacy: .public) onScreen=\(self.records.filter(\.isOnScreen).count, privacy: .public)")
        for record in records where record.isOnScreen {
            guard let fileName = record.fileName else { continue }
            do {
                show(record, text: try store.readText(fileName), editing: false)
            } catch {
                report(error)
            }
        }
    }

    /// A new note with `layout`: a plain note, or one split into cells.
    func createNote(from placement: NotePlacement, layout: NoteLayout = .single) {
        EventLog.notes.notice("create note layout=\(layout.description, privacy: .public)")
        showAllNotes()
        lockAll()
        let record = NoteRecord(
            topLeftX: placement.topLeft.x,
            topLeftY: placement.topLeft.y,
            fixedWidth: placement.fixedWidth.map(Double.init),
            minimumHeight: placement.minimumHeight.map(Double.init)
        )
        records.append(record)
        show(record, document: NoteDocument(layout: layout), editing: true)
    }

    func lockAll() {
        controllers.values.filter(\.isEditing).forEach { $0.lock() }
    }

    func textDidChange(_ controller: NoteController) {
        let text = controller.text
        guard let fileName = store.fileName(forSaving: text, existing: controller.record.fileName, createdAt: controller.record.createdAt) else { return }
        if controller.record.fileName == nil {
            controller.record.fileName = fileName
            sync(controller)
            scheduleSave()
        }
        do {
            try store.writeText(text, to: fileName)
        } catch {
            report(error)
        }
    }

    func layoutDidChange(_ controller: NoteController) {
        sync(controller)
        scheduleSave()
    }

    func didLock(_ controller: NoteController) {
        if controller.isBlank {
            discard(controller)
        } else {
            sync(controller)
            scheduleSave()
        }
    }

    func close(_ controller: NoteController) {
        EventLog.notes.notice("close \(controller.panel.identifier?.rawValue ?? "", privacy: .public) blank=\(controller.isBlank, privacy: .public)")
        // Closing the note you were typing in goes back to the app you came from, before the note goes away;
        // otherwise AppKit makes the settings window key and brings it forward.
        if controller.panel.isKeyWindow {
            NSApp.leaveClosingNote()
        }
        if controller.isBlank {
            discard(controller)
            return
        }
        controller.record.isOnScreen = false
        controller.record.closedAt = Date()
        sync(controller)
        controller.dismiss()
        controllers[controller.id] = nil
        closedNotes.append(controller.id)
        scheduleSave()
    }

    func reopenLastClosed() {
        while let id = closedNotes.popLast() {
            if reopen(id) {
                return
            }
        }
    }

    @discardableResult
    func reopen(_ id: UUID) -> Bool {
        guard let index = records.firstIndex(where: { $0.id == id }), let fileName = records[index].fileName else { return false }
        guard let text = try? store.readText(fileName) else { return false }
        showAllNotes()
        closedNotes.removeAll { $0 == id }
        records[index].isOnScreen = true
        records[index].closedAt = nil
        let record = records.remove(at: index)
        records.append(record)
        show(record, text: text, editing: false)
        scheduleSave()
        return true
    }

    func showNote(_ id: UUID) {
        guard let controller = controllers[id] else {
            reopen(id)
            return
        }
        showAllNotes()
        controller.panel.orderFrontRegardless()
        bringToFront(controller)
        scheduleSave()
    }

    func toggleAllNotes() {
        EventLog.notes.notice("toggle all notes hiddenBefore=\(self.areNotesHidden, privacy: .public)")
        if areNotesHidden {
            showAllNotes()
        } else {
            lockAll()
            areNotesHidden = true
            controllers.values.forEach { $0.panel.orderOut(nil) }
        }
    }

    func showAllNotes() {
        guard areNotesHidden else { return }
        areNotesHidden = false
        orderedControllers.forEach { $0.panel.orderFrontRegardless() }
    }

    var hasNotes: Bool {
        records.contains { $0.fileName != nil }
    }

    var noteCount: Int {
        records.filter { $0.fileName != nil }.count
    }

    private var orderedControllers: [NoteController] {
        records.compactMap { controllers[$0.id] }
    }

    func bringToFront(_ controller: NoteController) {
        guard let index = records.firstIndex(where: { $0.id == controller.id }) else { return }
        records.append(records.remove(at: index))
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard !isSavingStopped else { return }
        records = records.updating(with: controllers.values.map(\.record))
        do {
            try store.saveRecords(records)
        } catch {
            report(error)
        }
    }

    private func show(_ record: NoteRecord, text: String, editing: Bool) {
        show(record, document: NoteDocument.parse(text), editing: editing)
    }

    private func show(_ record: NoteRecord, document: NoteDocument, editing: Bool) {
        let controller = NoteController(record: record, document: document, style: style, manager: self)
        controllers[record.id] = controller
        controller.show(editing: editing)
    }

    private func discard(_ controller: NoteController) {
        controller.dismiss()
        controllers[controller.id] = nil
        if let fileName = controller.record.fileName {
            do {
                try store.moveToTrash(fileName)
            } catch {
                report(error)
            }
        }
        records.removeAll { $0.id == controller.id }
        scheduleSave()
    }

    private func sync(_ controller: NoteController) {
        guard let index = records.firstIndex(where: { $0.id == controller.id }) else { return }
        records[index] = controller.record
    }

    private func scheduleSave() {
        guard pendingSave == nil else { return }
        pendingSave = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(NoteMetrics.recordSaveDelay))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func installMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            self?.updateClickThrough()
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.updateClickThrough()
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    private func updateClickThrough() {
        let location = NSEvent.mouseLocation
        controllers.values.forEach { $0.updateClickThrough(mouseLocation: location) }
    }

    private func report(_ error: Error) {
        NSLog("Skywrite: %@", error.localizedDescription)
        guard !hasReportedError else { return }
        hasReportedError = true
        NSAlert(error: error).runModal()
    }
}

extension NoteManager {
    /// Brings every note that isn't wholly in sight all the way onto a screen, shrinking any that's too big for it: onto
    /// the screen it overlaps most, or the one with the pointer when it's on none. For a note lost behind the menu bar,
    /// past an edge, or on a screen that's gone.
    func moveNotesBackOnScreen() {
        let screens = NSScreen.screens
        let visibleFrames = screens.map(\.visibleFrame)
        var moved = 0
        for controller in controllers.values where !ScreenPlacement.isWhollyVisible(controller.boxInScreen, in: visibleFrames) {
            let box = controller.boxInScreen
            let overlapping = screens.max { overlap($0.visibleFrame, box) < overlap($1.visibleFrame, box) }
            guard let target = overlapping.flatMap({ overlap($0.visibleFrame, box) > 0 ? $0 : nil }) ?? NSScreen.withPointer else { continue }
            controller.bringWhollyOnScreen(target.visibleFrame)
            moved += 1
        }
        EventLog.app.notice("move notes back on screen moved=\(moved, privacy: .public) of \(self.controllers.count, privacy: .public)")
        showAllNotes()
    }

    private func overlap(_ frame: CGRect, _ box: CGRect) -> CGFloat {
        let shared = frame.intersection(box)
        return shared.isNull ? 0 : shared.width * shared.height
    }

    func menuNotes() -> (pinned: [RecentNote], recent: [RecentNote]) {
        let store = store
        let modified = records.reduce(into: [UUID: Date]()) { result, record in
            result[record.id] = record.fileName.flatMap(store.modificationDate(of:)) ?? record.createdAt
        }
        let entries: ([NoteRecord]) -> [RecentNote] = { picked in
            picked.compactMap { record in
                guard let fileName = record.fileName else { return nil }
                let text = self.controllers[record.id]?.text ?? (try? store.readText(fileName)) ?? ""
                let title = NoteTitle.title(from: text)
                return RecentNote(id: record.id, title: title.isEmpty ? fileName : title, isOnScreen: self.controllers[record.id] != nil, modifiedAt: modified[record.id] ?? record.createdAt)
            }
        }
        return (entries(RecentNotes.pinned(records, modifiedAt: { modified[$0.id] })), entries(RecentNotes.pick(records, modifiedAt: { modified[$0.id] })))
    }

    /// Every saved note with its whole text, for the quick panel to search.
    func searchableNotes() -> [SearchableNote] {
        let store = store
        return records.compactMap { record in
            guard let fileName = record.fileName else { return nil }
            let controller = controllers[record.id]
            let text = controller?.text ?? (try? store.readText(fileName)) ?? ""
            let modifiedAt = store.modificationDate(of: fileName) ?? record.createdAt
            let isPinned = controller?.record.isPinned ?? record.isPinned
            return SearchableNote(id: record.id, fileText: text, fileName: fileName, modifiedAt: modifiedAt, createdAt: record.createdAt, isOnScreen: controller != nil, isPinned: isPinned)
        }
    }

    func togglePin(_ controller: NoteController) {
        controller.record.isPinned.toggle()
        EventLog.notes.notice("pin \(controller.panel.identifier?.rawValue ?? "", privacy: .public) pinned=\(controller.record.isPinned, privacy: .public)")
        sync(controller)
        scheduleSave()
    }

    func expiredNotes(for retention: NoteRetention, now: Date = Date()) -> [NoteRecord] {
        store.expiredNotes(in: records, retention: retention, now: now, shownIDs: Set(controllers.keys))
    }

    /// Moves closed notes that have been left alone for the chosen period to the Trash, the same way deleting a note does.
    func moveExpiredNotesToTrash(retention: NoteRetention) {
        let expired = expiredNotes(for: retention)
        guard !expired.isEmpty else { return }
        let result = store.moveNotesToTrash(expired)
        result.errors.forEach(report)
        let removed = Set(result.removedIDs)
        records.removeAll { removed.contains($0.id) }
        closedNotes.removeAll { removed.contains($0) }
        EventLog.notes.notice("moved expired notes to trash count=\(result.movedCount, privacy: .public) retentionDays=\(retention.rawValue, privacy: .public)")
        scheduleSave()
    }

    /// The files of every note Skywrite knows about, on screen or closed.
    var noteFileNames: [String] {
        records.updating(with: controllers.values.map(\.record)).compactMap(\.fileName)
    }

    /// Saves one last time, then hides every note and stops saving, for uninstalling.
    func stopSavingAndHideNotes() {
        saveNow()
        isSavingStopped = true
        controllers.values.forEach { $0.panel.orderOut(nil) }
    }

    func changeNotesFolder(to folder: URL) throws {
        saveNow()
        let result = try store.movingNotes(records.compactMap(\.fileName), to: folder)
        store = result.store
        for index in records.indices {
            guard let fileName = records[index].fileName, let renamed = result.renamed[fileName] else { continue }
            records[index].fileName = renamed
            controllers[records[index].id]?.record.fileName = renamed
        }
        saveNow()
    }
}
