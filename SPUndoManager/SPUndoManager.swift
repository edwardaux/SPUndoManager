import Foundation

/// Get the shared document controller's undo manager and cast to SPUndoManager
///
/// Make your own wrapper around this for brevity if you want
public func SPUndoManagerGet() -> SPUndoManager? {
    return (NSDocumentController.sharedDocumentController().currentDocument?.undoManager as? SPUndoManager)
}

public typealias Closure = () -> Void

public class SPUndoManager : NSUndoManager {
    
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
    public func registerChange(description: String, forwards: Closure, backwards: Closure) -> Closure {

        let standardAction = SPUndoManagerStandardAction(description: description, forwards: forwards, backwards: backwards)
        
        addAction(standardAction)
        
        return forwards
    }
    
    /// Add a super cool undoable action which always returns an undoable version 
    /// of itself upon undoing or redoing (both are classed as undo)
    public func registerChange(undoable: Undoable) {
        
        addAction(SPUndoManagerSuperDynamicAction(undoable: undoable))
    }
    
    // MARK: Grouping
    
    public override var groupingLevel: Int {
        return pendingGroups.count
    }
    
    public func beginUndoGrouping(description: String) {
        let newGroup = SPUndoManagerGroupAction(description: description)
        
        addAction(newGroup)
        
        pendingGroups += [newGroup]
        
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerCheckpointNotification, object: self)
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerDidOpenUndoGroupNotification, object: self)
    }
    
    public override func beginUndoGrouping() {
        beginUndoGrouping("Multiple Changes")
    }
    
    public func cancelUndoGrouping() {
        assert(!pendingGroups.isEmpty && pendingGroups.last!.done == false, "Attempting to cancel an undo grouping that was never started")
        
        let cancelled = pendingGroups.removeLast()
        cancelled.done = true
        cancelled.undo()
        
        removeLastAction()
    }
    
    public override func endUndoGrouping() {
        assert(!pendingGroups.isEmpty, "Attempting to end an undo grouping that was never started")
        
        let grouping = pendingGroups.removeLast()
        grouping.done = true
        
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerCheckpointNotification, object: self)
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerDidCloseUndoGroupNotification, object: self)
    }
    
    public override func undoNestedGroup() {
        fatalError("Unimplemented")
    }
    
    // MARK: Removing changes
    
    public override func removeAllActions() {
        stateIndex = -1
        changes = []
        pendingGroups = []
    }
    
    public override func removeAllActionsWithTarget(target: AnyObject) {
        fatalError("Not implemented")
    }
    
    // MARK: Undo/redo
    
    public override func undo() {
        while !pendingGroups.isEmpty {
            endUndoGrouping()
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerWillUndoChangeNotification, object: self)
        
        _undoing = true
        
        let change = changes[stateIndex]
        change.undo()
        stateIndex--
        
        _undoing = false
        
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerDidUndoChangeNotification, object: self)
        
    }
    
    public override func redo() {
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerWillRedoChangeNotification, object: self)
        
        _redoing = true
        
        let change = changes[stateIndex + 1]
        change.redo()
        stateIndex++
        
        _redoing = false
        
        NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerDidRedoChangeNotification, object: self)
    }
    
    public override var undoActionName: String {
        return changes.atIndex(stateIndex)?.description ?? ""
    }
    
    public override var redoActionName: String {
        return changes.atIndex(stateIndex + 1)?.description ?? ""
    }
    
    public override var canUndo: Bool {
        return changes.count > 0 && stateIndex >= 0
    }
    
    public override var canRedo: Bool {
        return changes.count > 0 && stateIndex < changes.count - 1
    }
    
    var _undoing: Bool = false
    var _redoing: Bool = false
    
    public override var undoing: Bool {
        return _undoing
    }
    
    public override var redoing: Bool {
        return _redoing
    }
    
    // MARK: Private
    
    func addAction(action: SPUndoManagerAction) {
        if undoing || redoing || !undoRegistrationEnabled {
            return
        }
        
        if pendingGroups.isEmpty {
            
            clearRedoAfterState()
            
            while levelsOfUndo > 0 && changes.count >= levelsOfUndo {
                changes.removeAtIndex(0)
                stateIndex--
            }
            
            changes += [action]
            stateIndex++
            
            NSNotificationCenter.defaultCenter().postNotificationName(NSUndoManagerDidCloseUndoGroupNotification, object: self)
        }
        else {
            pendingGroups.last!.nestedActions += [action]
        }
    }
    
    func clearRedoAfterState() {
        changes.removeRange(min(stateIndex + 1, changes.count) ..< changes.count)
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
    public init(description: String, undo: () -> Undoable) {
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