import Foundation

extension Array {
    func atIndex(_ index: Int) -> Element? {
        if index >= 0 && index < count {
            return self[index]
        }
        return nil
    }
    
    func each(_ function: (_ element: Element) -> Void) {
        for e in self {
            function(e)
        }
    }
    
    func eachForwards(_ function: (_ element: Element) -> Void) {
        for i in 0 ..< self.count {
            function(self[i])
        }
    }
    
    func eachBackwards(_ function: (_ element: Element) -> Void) {
        for i in (0..<self.count).reversed() {
            function(self[i])
        }
    }
}
