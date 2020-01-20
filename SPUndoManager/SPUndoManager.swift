import Foundation

/// Get the shared document controller's undo manager and cast to SPUndoManager
///
/// Make your own wrapper around this for brevity if you want
public func SPUndoManagerGet() -> SPUndoManager? {
    return (NSDocumentController.shared.currentDocument?.undoManager as? SPUndoManager)
}

public typealias Closure = () -> Void

open class SPUndoManager : UndoManager {
    
    public override init() {
        super.init()
    }
    
    var changes: [SPUndoManagerAction] = []
    var pendingGroups: [SPUndoManagerGroupAction] = []
    var stateIndex = -1
    
    // MARK: Registering changes
    
    /// Add a change to be undone with separate forwards and backwards transformers.
    ///
    /// If an undo grouping has been started, the action will be added to that group.
    open func registerChange(_ description: String, forwards: @escaping Closure, backwards: @escaping Closure) -> Closure {

        let standardAction = SPUndoManagerStandardAction(description: description, forwards: forwards, backwards: backwards)
        
        addAction(standardAction)
        
        return forwards
    }
    
    /// Add a super cool undoable action which always returns an undoable version 
    /// of itself upon undoing or redoing (both are classed as undo)
    open func registerChange(_ undoable: Undoable) {
        
        addAction(SPUndoManagerSuperDynamicAction(undoable: undoable))
    }
    
    // MARK: Grouping
    
    open override var groupingLevel: Int {
        return pendingGroups.count
    }
    
    open func beginUndoGrouping(_ description: String) {
        let newGroup = SPUndoManagerGroupAction(description: description)
        
        addAction(newGroup)
        
        pendingGroups += [newGroup]
        
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerCheckpoint, object: self)
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerDidOpenUndoGroup, object: self)
    }
    
    open override func beginUndoGrouping() {
        beginUndoGrouping("Multiple Changes")
    }
    
    open func cancelUndoGrouping() {
        assert(!pendingGroups.isEmpty && pendingGroups.last!.done == false, "Attempting to cancel an undo grouping that was never started")
        
        let cancelled = pendingGroups.removeLast()
        cancelled.done = true
        cancelled.undo()
        
        removeLastAction()
    }
    
    open override func endUndoGrouping() {
        assert(!pendingGroups.isEmpty, "Attempting to end an undo grouping that was never started")
        
        let grouping = pendingGroups.removeLast()
        grouping.done = true
        
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerCheckpoint, object: self)
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerDidCloseUndoGroup, object: self)
    }
    
    open override func undoNestedGroup() {
        fatalError("Unimplemented")
    }
    
    // MARK: Removing changes
    
    open override func removeAllActions() {
        stateIndex = -1
        changes = []
        pendingGroups = []
    }
    
    open override func removeAllActions(withTarget target: Any) {
        fatalError("Not implemented")
    }
    
    // MARK: Undo/redo
    
    open override func undo() {
        while !pendingGroups.isEmpty {
            endUndoGrouping()
        }
        
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerWillUndoChange, object: self)
        
        _undoing = true
        
        let change = changes[stateIndex]
        change.undo()
        stateIndex -= 1
        
        _undoing = false
        
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: self)
        
    }
    
    open override func redo() {
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerWillRedoChange, object: self)
        
        _redoing = true
        
        let change = changes[stateIndex + 1]
        change.redo()
        stateIndex += 1
        
        _redoing = false
        
        NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: self)
    }
    
    open override var undoActionName: String {
        return changes.atIndex(stateIndex)?.description ?? ""
    }
    
    open override var redoActionName: String {
        return changes.atIndex(stateIndex + 1)?.description ?? ""
    }
    
    open override var canUndo: Bool {
        return changes.count > 0 && stateIndex >= 0
    }
    
    open override var canRedo: Bool {
        return changes.count > 0 && stateIndex < changes.count - 1
    }
    
    var _undoing: Bool = false
    var _redoing: Bool = false
    
    open override var isUndoing: Bool {
        return _undoing
    }
    
    open override var isRedoing: Bool {
        return _redoing
    }
    
    // MARK: Private
    
    func addAction(_ action: SPUndoManagerAction) {
        if isUndoing || isRedoing || !isUndoRegistrationEnabled {
            return
        }
        
        if pendingGroups.isEmpty {
            
            clearRedoAfterState()
            
            while levelsOfUndo > 0 && changes.count >= levelsOfUndo {
                changes.remove(at: 0)
                stateIndex -= 1
            }
            
            changes += [action]
            stateIndex += 1
            
            NotificationCenter.default.post(name: NSNotification.Name.NSUndoManagerDidCloseUndoGroup, object: self)
        }
        else {
            pendingGroups.last!.nestedActions += [action]
        }
    }
    
    func clearRedoAfterState() {
        changes.removeSubrange(min(stateIndex + 1, changes.count) ..< changes.count)
    }
    
    func removeLastAction() {
        if pendingGroups.isEmpty {
            changes.removeLast()
        }
        else {
            pendingGroups.last!.nestedActions.removeLast()
        }
    }
}

/// A forever undoable struct, should always return the inverse operation of itself
public struct Undoable {
    public init(description: String, undo: @escaping () -> Undoable) {
        self.description = description
        self.undo = undo
    }
    
    var description: String
    var undo: () -> Undoable
    
    /// Will register with document's SPUndoManager if available
    public func registerUndo() {
        SPUndoManagerGet()?.registerChange(self)
    }
}
