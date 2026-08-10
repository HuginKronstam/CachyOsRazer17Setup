// Exponential smoothing: chases `target` on a fast tick, moving a fraction
// of the remaining gap each step - bigger gap, bigger step, easing in as it
// closes. Used to de-jitter noisy instantaneous sensor readings (CPU/GPU
// usage) without needing an actual averaged sensor.
import QtQuick

QtObject {
    id: root

    property real target: 0
    property real value: target
    // Fraction of the remaining gap closed per tick (0..1). Lower = smoother
    // but slower to react; higher = snappier but closer to raw jitter.
    property real smoothing: 0.12
    // How often to step, in ms. Independent of how often the underlying
    // sensor actually updates.
    property int tickInterval: 100

    property Timer _timer: Timer {
        interval: root.tickInterval
        running: true
        repeat: true
        onTriggered: root.value = root.value + (root.target - root.value) * root.smoothing
    }
}
