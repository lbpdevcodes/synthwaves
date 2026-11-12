import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "video"

  connect() {
    super.connect()

    this.turboLoadHandler = () => this.scanForNativeVideo()
    this.turboBeforeVisitHandler = () => this.stopNativeVideo()

    document.addEventListener("turbo:load", this.turboLoadHandler)
    document.addEventListener("turbo:before-visit", this.turboBeforeVisitHandler)

    // Scan immediately in case page already loaded
    this.scanForNativeVideo()
  }

  disconnect() {
    super.disconnect()

    document.removeEventListener("turbo:load", this.turboLoadHandler)
    document.removeEventListener("turbo:before-visit", this.turboBeforeVisitHandler)
  }

  scanForNativeVideo() {
    const el = document.querySelector("[data-video-native-type]")
    if (!el) return

    const video = {
      streamURL: el.dataset.videoNativeStreamUrl || "",
      title: el.dataset.videoNativeTitle || "",
      type: el.dataset.videoNativeType,
      id: el.dataset.videoNativeId || "",
      thumbnailURL: el.dataset.videoNativeThumbnailUrl || "",
      duration: parseFloat(el.dataset.videoNativeDuration) || 0,
      isLive: false
    }

    this.send("playVideo", { video })

    // Hide the web <video> element
    const webVideo = el.querySelector("video")
    if (webVideo) webVideo.style.display = "none"
  }

  stopNativeVideo() {
    this.send("stopVideo", {})
  }
}
