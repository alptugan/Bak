import Foundation
let defaults = UserDefaults(suiteName: "com.alptugan.Bak.Gor")
defaults?.set(18.0, forKey: "fontSize")
defaults?.synchronize()
print("Saved 18.0")
