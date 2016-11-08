import Foundation

public func undoableFrom<T>(_ undoable: (T, Undoable)) -> Undoable {
    return undoable.1
}

/// Only use when you're sure the action should definitely be undoable, possibly
/// good way of testing things
public func undoableForceFrom<T>(_ undoable: (T, Undoable?)) -> Undoable {
    return undoable.1!
}

public func ignoreUndo<T>(_ undoable: (T, Undoable)) -> T {
    
    return undoable.0
}

public func registerUndo<T>(_ undoable: (T, Undoable)) -> T {
    
    SPUndoManagerGet()?.registerChange(undoable.1)
    return undoable.0
}

public func registerUndo<T>(_ undoable: (T, Undoable?)) -> T {
    
    if let undoable = undoable.1 {
        SPUndoManagerGet()?.registerChange(undoable)
    }
    return undoable.0
}

public func beginUndoGrouping(_ description: String) {
    SPUndoManagerGet()?.beginUndoGrouping(description)
}

public func endUndoGrouping() {
    SPUndoManagerGet()?.endUndoGrouping()
}

public func cancelUndoGrouping() {
    SPUndoManagerGet()?.cancelUndoGrouping()
}

public func groupUndoActions(_ description: String, closure: () -> ()) {
    beginUndoGrouping(description)
    closure()
    endUndoGrouping()
}

public func groupUndoActions(_ description: String, closure: () -> Bool) {
    beginUndoGrouping(description)
    
    if (closure()) {
        endUndoGrouping()
    }
    else {
        cancelUndoGrouping()
    }
}
