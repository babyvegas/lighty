import Foundation
import SwiftUI
internal import Combine

// MARK: - Store

final class RoutineStore: ObservableObject {
    @Published private(set) var routines: [Routine] = []

    func save(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    func routine(with id: Routine.ID) -> Routine? {
        routines.first { $0.id == id }
    }
}
