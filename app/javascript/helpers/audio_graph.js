// Web Audio graph for the player: 5-band EQ + per-element gain (loudness
// normalization and crossfade volume) per recycled <audio> element.
//
// Why per-element chains: createMediaElementSource can only be called once
// per element, the player recycles two elements through its crossfade swap,
// and during a crossfade both elements sound at once with different tracks —
// so each element gets its own filter chain and gain node. Band settings are
// mirrored across chains; element gain is per chain.
//
// Elements must be crossOrigin="anonymous" and play same-origin (proxied)
// URLs before being connected, or the graph outputs silence.
export const EQ_BANDS = [
  {key: "60", type: "lowshelf", frequency: 60},
  {key: "250", type: "peaking", frequency: 250},
  {key: "1000", type: "peaking", frequency: 1000},
  {key: "4000", type: "peaking", frequency: 4000},
  {key: "12000", type: "highshelf", frequency: 12000}
]

export const EQ_PRESETS = {
  flat: {60: 0, 250: 0, 1000: 0, 4000: 0, 12000: 0},
  bass: {60: 6, 250: 4, 1000: 0, 4000: 0, 12000: 0},
  vocal: {60: -2, 250: 2, 1000: 4, 4000: 3, 12000: 1},
  treble: {60: 0, 250: 0, 1000: 0, 4000: 3, 12000: 5}
}

export class AudioGraph {
  constructor() {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    this.context = new AudioContextClass()
    this.chains = new Map()
  }

  resume() {
    if (this.context.state !== "running") this.context.resume()
  }

  connect(element) {
    if (this.chains.has(element)) return

    const source = this.context.createMediaElementSource(element)
    const filters = EQ_BANDS.map((band) => {
      const filter = this.context.createBiquadFilter()
      filter.type = band.type
      filter.frequency.value = band.frequency
      if (band.type === "peaking") filter.Q.value = 1
      filter.gain.value = 0
      return filter
    })
    const gain = this.context.createGain()
    gain.gain.value = 1

    let node = source
    for (const filter of filters) {
      node.connect(filter)
      node = filter
    }
    node.connect(gain)
    gain.connect(this.context.destination)

    this.chains.set(element, {source, filters, gain})
  }

  isConnected(element) {
    return this.chains.has(element)
  }

  setBandGain(bandKey, decibels) {
    const index = EQ_BANDS.findIndex((band) => band.key === bandKey)
    if (index === -1) return
    for (const {filters} of this.chains.values()) {
      filters[index].gain.value = decibels
    }
  }

  setElementGain(element, value) {
    const chain = this.chains.get(element)
    if (chain) chain.gain.gain.value = value
  }

  elementGain(element) {
    return this.chains.get(element)?.gain.gain.value ?? 1
  }
}
