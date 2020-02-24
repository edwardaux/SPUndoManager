import Foundation

protocol SPUndoManagerAction {
    
    var done: Bool { get }
    func undo()
    func redo()
    var description: String { get }
}

class SPUndoManagerStandardAction : SPUndoManagerAction {
    
    /// Assumes action already performed
    init(description: String, forwards: @escaping Closure, backwards: @escaping Closure) {
        
        self.forwards = forwards
        self.backwards = backwards
        self.description = description
        self.done = true
    }
    
    var done: Bool
    var backwards: Closure
    var forwards: Closure
    var description: String
    
    func undo() {
        assert(done)
        backwards()
        done = false
    }
    
    func redo() {
        assert(!done)
        forwards()
        done = true
    }
}


class SPUndoManagerSuperDynamicAction : SPUndoManagerAction {
    
    var undoable: Undoable
    var description: String
    var actionCompletion: ActionCallbackClosure?
    
    /// Assumes action performed, in 'done' state by default
    init(undoable: Undoable, actionCompletion: ActionCallbackClosure? = nil) {
        self.undoable = undoable
        self.description = undoable.description
        self.done = true
        self.actionCompletion = actionCompletion
    }
    
    var done: Bool
    func undo() {
        assert(done)
        self.undoable = undoable.undo()
        done = false
        actionCompletion?(.undo)
    }
    func redo() {
        assert(!done)
        self.undoable = undoable.undo()
        done = true
        actionCompletion?(.redo)
    }
}

class SPUndoManagerGroupAction : SPUndoManagerAction {
    
    init(description: String) {
        self.description = description
    }
    
    var done: Bool = false
    var nestedActions = [SPUndoManagerAction]()
    
    func undo() {
        assert(done)
        self.nestedActions.eachBackwards { $0.undo() }
        done = false
    }
    
    func redo() {
        assert(!done)
        self.nestedActions.eachForwards { $0.redo() }
        done = true
    }
    
    var description: String
}
