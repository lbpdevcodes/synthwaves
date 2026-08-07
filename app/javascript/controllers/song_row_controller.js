import { Controller } from "@hotwired/stimulus"
import { buildTrackFromElement } from "helpers/track_builder"

export default class extends Controller {
  static values = { trackId: Number, title: String, artist: String, streamUrl: String, youtubeVideoId: String, isLive: Boolean, coverUrl: String, isPodcast: Boolean, albumTitle: String, duration: Number, nativeStreamUrl: String, nativeCoverArtUrl: String, gainDb: Number }

  play(event) {
    event.preventDefault()
    event.stopPropagation()
    this.playTracks()
  }

  // Tapping anywhere on the row body plays — except on links, buttons, or
  // forms inside the row (title/artist links, favorite, remove, etc.),
  // which keep their own behavior.
  playFromRow(event) {
    if (event.target.closest("a, button, form, input, select")) return
    this.playTracks()
  }

  playTracks() {
    const container = this.element.parentElement
    const siblings = container ? container.querySelectorAll("[data-controller~='song-row']") : []

    if (siblings.length > 1) {
      const tracks = Array.from(siblings).map(el => buildTrackFromElement(el))
      const startIndex = Array.from(siblings).indexOf(this.element)
      document.dispatchEvent(new CustomEvent("queue:playAll", {
        detail: { tracks, startIndex: Math.max(startIndex, 0) }
      }))
    } else {
      const track = this.buildTrack()
      document.dispatchEvent(new CustomEvent("queue:playNow", { detail: track }))
    }
  }

  addToQueue() {
    const track = this.buildTrack()
    document.dispatchEvent(new CustomEvent("queue:add", { detail: track }))
  }

  buildTrack() {
    const track = {
      trackId: this.trackIdValue,
      title: this.titleValue,
      artist: this.artistValue
    }

    if (this.albumTitleValue) {
      track.albumTitle = this.albumTitleValue
    }

    if (this.durationValue) {
      track.duration = this.durationValue
    }

    if (this.isLiveValue) {
      track.isLive = true
    }

    if (this.coverUrlValue) {
      track.coverUrl = this.coverUrlValue
    }
    if (this.isPodcastValue) {
      track.isPodcast = true
    }

    if (this.streamUrlValue) {
      track.streamUrl = this.streamUrlValue
    }
    if (this.hasGainDbValue) {
      track.gainDb = this.gainDbValue
    }
    if (this.youtubeVideoIdValue) {
      track.youtubeVideoId = this.youtubeVideoIdValue
    }

    if (this.nativeStreamUrlValue) {
      track.nativeStreamUrl = this.nativeStreamUrlValue
    }

    if (this.nativeCoverArtUrlValue) {
      track.nativeCoverArtUrl = this.nativeCoverArtUrlValue
    }

    return track
  }
}
