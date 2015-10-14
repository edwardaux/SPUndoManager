import Foundation

extension Array {
    func atIndex(index: Int) -> Element? {
        if index >= 0 && index < count {
            return self[index]
        }
        return nil
    }
    
    func each(function: (element: Element) -> Void) {
        for e in self {
            function(element: e)
        }
    }
    
    func eachForwards(function: (element: Element) -> Void) {
        for i in 0 ..< self.count {
            function(element: self[i])
        }
    }
    
    func eachBackwards(function: (element: Element) -> Void) {
        for i in (0..<self.count).reverse() {
            function(element: self[i])
        }
    }
}