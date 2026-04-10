import SwiftUI

struct PhotoDropDelegate: DropDelegate {

    let item: String
    @Binding var items: [String]
    let currentIndex: Int

    func performDrop(info: DropInfo) -> Bool {
        true
    }

    func dropEntered(info: DropInfo) {
        guard let fromIndex = items.firstIndex(of: item) else { return }
        guard fromIndex != currentIndex else { return }
        guard items.indices.contains(currentIndex) else { return }

        withAnimation {
            let movedItem = items.remove(at: fromIndex)
            items.insert(movedItem, at: currentIndex)
        }
    }
}
