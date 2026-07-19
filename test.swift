import Foundation

let highestClaimed = 0
let unlocksClaimed = false
let tiersCount = 30

let isMaxed = highestClaimed >= tiersCount - 1 && unlocksClaimed == true
print("isMaxed: \(isMaxed)")
