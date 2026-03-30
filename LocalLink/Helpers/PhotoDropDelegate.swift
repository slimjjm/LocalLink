import SwiftUI

struct PhotoDropDelegate: DropDelegate {

    let item: String
    @Binding var items: [String]
    let currentIndex: Int

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let fromIndex = items.firstIndex(of: item) else { return }

        if fromIndex != currentIndex {
            withAnimation {
                let movedItem = items.remove(at: fromIndex)
                items.insert(movedItem, at: currentIndex)
            }
        }
    }
}
