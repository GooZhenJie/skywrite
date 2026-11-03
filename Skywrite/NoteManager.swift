import AppKit
import SkywriteCore

final class NoteManager {
    let store: NoteStore
    private var records: [NoteRecord] = []
    private var controllers: [UUID: NoteController] = [:]
    private var closedNotes: [UUID] = []
    private var pendingSave: Task<Void, Never>?
    private var mouseMonitors: [Any] = []
    private var hasReportedError = false

    init(store: NoteStore) {
        self.store = store
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
        for record in records where record.isOnScreen {
            guard let fileName = record.fileName else { continue }
            do {
                show(record, text: try store.readText(fileName), editing: false)
            } catch {
                report(error)
            }
        }
    }

    func createNote(from placement: PlacementResult) {
        lockAll()
        let record = NoteRecord(
            topLeftX: placement.topLeft.x,
            topLeftY: placement.topLeft.y,
            fixedWidth: placement.fixedWidth.map(Double.init),
            minimumHeight: placement.minimumHeight.map(Double.init)
        )
        records.append(record)
        show(record, text: "", editing: true)
    }

    func lockAll() {
        controllers.values.filter(\.isEditing).forEach { $0.lock() }
    }

    func textDidChange(_ controller: NoteController) {
        let text = controller.text
        if controller.record.fileName == nil {
            guard !text.isEmpty else { return }
            controller.record.fileName = store.makeFileName(createdAt: controller.record.createdAt)
            sync(controller)
            scheduleSave()
        }
        guard let fileName = controller.record.fileName else { return }
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
        if controller.isBlank {
            discard(controller)
            return
        }
        controller.record.isOnScreen = false
        sync(controller)
        controller.dismiss()
        controllers[controller.id] = nil
        closedNotes.append(controller.id)
        scheduleSave()
    }

    func reopenLastClosed() {
        while let id = closedNotes.popLast() {
            guard let index = records.firstIndex(where: { $0.id == id }), let fileName = records[index].fileName else { continue }
            guard let text = try? store.readText(fileName) else { continue }
            records[index].isOnScreen = true
            let record = records.remove(at: index)
            records.append(record)
            show(record, text: text, editing: false)
            scheduleSave()
            return
        }
    }

    func bringToFront(_ controller: NoteController) {
        guard let index = records.firstIndex(where: { $0.id == controller.id }) else { return }
        records.append(records.remove(at: index))
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        controllers.values.forEach(sync)
        do {
            try store.saveRecords(records)
        } catch {
            report(error)
        }
    }

    private func show(_ record: NoteRecord, text: String, editing: Bool) {
        let controller = NoteController(record: record, text: text, manager: self)
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
