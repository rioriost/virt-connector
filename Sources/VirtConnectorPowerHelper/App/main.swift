import AppKit

let app = NSApplication.shared
let delegate = VirtConnectorPowerHelperApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
