import Foundation

struct ValidStartTimeService {
    
    static func validStartTimes(
        slots: [AvailableSlot],
        serviceDurationMinutes: Int
    ) -> [AvailableSlot] {
        
        let sortedSlots = slots.sorted { $0.startTime < $1.startTime }
        
        let requiredSlots = serviceDurationMinutes / 30
        
        guard requiredSlots > 0 else { return [] }
        
        var valid: [AvailableSlot] = []
        
        for i in 0..<sortedSlots.count {
            
            let startSlot = sortedSlots[i]
            
            var isValid = true
            
            for j in 0..<requiredSlots {
                
                let index = i + j
                
                if index >= sortedSlots.count {
                    isValid = false
                    break
                }
                
                let current = sortedSlots[index]
                
                if current.isBooked {
                    isValid = false
                    break
                }
                
                if j > 0 {
                    let prev = sortedSlots[index - 1]
                    
                    let expected = prev.startTime.addingTimeInterval(60 * 30)
                    
                    if current.startTime != expected {
                        isValid = false
                        break
                    }
                }
            }
            
            if isValid {
                valid.append(startSlot)
            }
        }
        
        return valid
    }
}
