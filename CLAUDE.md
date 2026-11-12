# synthwaves.fm

Music streaming web application built with Rails 8.

## Project Management

Every piece of work in this repo runs through a card on the Synthwaves kanban
board: project 13, board 15, at https://gosynapse.io/synapse/boards/15. No
behavior change, fix, feature, refactor or production run starts without a card.

- The rule: `.claude/rules/project-management.md`
- The column ids, the tool calls and the traps: the `synthwaves-board` skill
- Access key: `config/go_synapse_api_key` (gitignored, mode 600)

## Common Commands

```bash
bin/dev                  # Start dev server (Rails + Tailwind watcher)
bundle exec rspec        # Run full test suite
bundle exec rspec spec/models/   # Run model specs only
bin/rails db:migrate     # Run migrations
bin/rails db:seed        # Seed database
bin/setup                # Install deps, prepare DB, start server
bundle exec standardrb   # Lint Ruby code
bundle exec brakeman     # Security scan
```

## Architecture

- **Rails 8.1** with Propshaft asset pipeline
- **Hotwire**: Turbo for navigation, Stimulus for interactivity
- **Importmap** for JavaScript (no bundler)
- **Tailwind CSS** via tailwindcss-rails
- **ViewComponent** for reusable UI components (app/components/)
- **SQLite** for all databases (primary, cache, queue, cable)
- **Solid Queue/Cache/Cable** for background jobs, caching, and WebSockets
- **Pagy** for pagination
- **Flipper** for the `:open_registration` feature flag (sole remaining flag)

### Key Gems

- **wahwah** - Audio metadata extraction
- **ffmpeg** - Audio format conversion (handled by AudioConversionJob)
- **ahoy_matey** - Analytics/event tracking
- **madmin** - Admin panel at `/admin`

## Domain Models

```
Artist
  has_many :albums
  has_many :tracks
  validates name uniqueness

Album
  belongs_to :artist
  has_many :tracks (dependent: :destroy)
  has_one_attached :cover_image
  validates title uniqueness scoped to artist

Track
  belongs_to :album
  belongs_to :artist
  has_one_attached :audio_file
  has_many :playlist_tracks, :favorites, :play_histories

Playlist
  belongs_to :user
  has_many :playlist_tracks (ordered by position)
  has_many :tracks (through: :playlist_tracks)

PlaylistTrack  -- join table with position column

User
  include Themeable
  has_many :playlists, :favorites, :play_histories, :api_keys, :sessions
  has_secure_password
  theme (string, default: "synthwave") — validated against Themeable::THEMES

Favorite  -- polymorphic (favorable: Track | Album | Artist)
PlayHistory  -- records play events per user/track

APIKey
  belongs_to :user
  has_secure_password :secret_key
  client_id format: "bc_" + 32 hex chars

Session  -- tracks user_agent, ip_address
Current  -- ActiveSupport::CurrentAttributes holding current session/user
```

## Authentication

Four authentication layers:

1. **Web sessions** - Signed HTTP-only cookies via `Authentication` concern. Session records track user_agent and ip_address.

2. **JWT API** (`/api/v1/`) - Client authenticates with `client_id` + `secret_key` to `POST /api/v1/auth/token`. Returns HS256 JWT (1-hour expiry) using `JWTService`. API requests use `Authorization: Bearer <token>` header. Validated in `API::V1::BaseController`.

3. **Subsonic API** (`/rest/` and `/api/rest/`) - Username via `:u` param (email_address). Two auth methods: MD5 token (`:t` + `:s` salt) or plaintext password (`:p` param, optional hex encoding with `enc:` prefix). Uses `subsonic_password` field on User. Response format controlled by `:f` param (JSON or XML).

4. **MCP Server** (`/mcp`) - HTTP Basic with API key `client_id`:`secret_key` (long-lived, unlike the 1-hour JWTs). Stateless JSON-RPC 2.0 via the `mcp` gem; a fresh `MCP::Server` is built per request in `AgentGatewayController`. Gateway code lives in `app/services/agent_gateway/` (named AgentGateway, not Mcp*, because `mcp` is inflection-risky for Zeitwerk). Tools are thin user-scoped wrappers over existing services/models. See `docs/api/mcp.md`.

## Theming

Four music-genre-inspired themes: **Synthwave** (default), **Reggae**, **Punk**, **Jazz**. Themes swap CSS custom properties via `[data-theme]` selectors — no template changes needed.

### How It Works

- `Themeable` concern (`app/models/concerns/themeable.rb`) is the single source of truth for the theme registry (label, font, meta color per theme)
- `ThemeHelper` provides `current_theme` (`Current.user&.theme` or default), `current_theme_font_url`, etc. to layouts
- `@theme` vars in `app/assets/tailwind/application.css` define the default (synthwave) palette; `[data-theme="reggae|punk|jazz"]` blocks override the same `--color-*` vars
- `theme_controller.js` handles instant client-side switching (CSS var swap + font swap + server persist via JSON PATCH) and syncs the server-rendered `data-theme` attribute on Turbo navigations via `turbo:before-render`
- Users choose their theme on the profile edit page

### Adding a New Theme

1. Add an entry to `Themeable::THEMES` in `app/models/concerns/themeable.rb`
2. Add a `[data-theme="name"]` CSS block in `app/assets/tailwind/application.css` overriding `--color-*` and `--theme-*` vars

No template changes, no new controllers, no new routes.

## Key Patterns

### Playback Event Chain (Stimulus)

Three Stimulus controllers coordinate playback via custom DOM events:

```
song_row_controller  -->  queue_controller  -->  player_controller
   play()                   playNow()              playTrack()
   dispatches               manages queue           controls <audio>
   "queue:playNow"          in localStorage          element, MediaSession
   "queue:add"              dispatches               API, records
                            "player:play"            play history
```

- **Queue persistence**: localStorage keys `playerQueue` and `playerQueueIndex`
- **MediaSession API**: Enables native OS media controls (lock screen, etc.)

### Loudness Normalization

Per-track playback gain, ReplayGain-style (analysis only, applied at playback):

- `LoudnessAnalyzer` runs `ffmpeg -af loudnorm` (analysis pass) and computes gain toward −14 LUFS, clamped to a −1 dBTP true-peak ceiling
- `LoudnessAnalysisJob` (conversion queue) stores `loudness_lufs` / `loudness_gain_db` on the track; enqueued at track create (formats needing no conversion), at the end of `AudioConversionJob`, and after `MediaDownloadJob`
- `Maintenance::LoudnessBackfillTask` backfills existing tracks
- Gain reaches the web player via `data-song-row-gain-db-value` → `track_builder.js` → queue → `player_controller`, which applies slider × gain as effective volume (attenuate-only unless the EQ graph is active)

### Equalizer (Web Audio)

The player bar EQ routes both recycled `<audio>` elements through a Web Audio graph (`app/javascript/helpers/audio_graph.js`): 5 bands (60Hz lowshelf, 250/1k/4k peaking, 12kHz highshelf) plus a per-element gain node that also carries loudness gain (full ±12dB when EQ is on) and crossfade ramps.

Constraints that shape the design:

- `MediaElementSource` requires CORS-clean media — while EQ is on, playback uses the `?proxy=1` same-origin stream URL (same trick as the visualizer), so no S3 bucket CORS changes are needed
- `createMediaElementSource` is one-way per element and element `volume`/`muted` stop affecting routed audio — output goes through the graph's per-element gain node (`_setOutputVolume` in `player_controller.js`)
- During AirPlay the device receives the element's flat feed; the local graph output is silenced so the two don't double up

### Modal Editing

Owners edit their own artists, albums and tracks in a modal over the current page:

- The layout carries an empty `<turbo-frame id="modal">`. Edit links target it with `data-turbo-frame="modal"` (the pencil in `TrackActions::Component`, `shared/_card_edit_link` on cards, the show-page Edit buttons).
- An edit view renders through `shared/_modal_or_page`: inside `Modal::Component` when `turbo_frame_request?`, as a plain page when visited directly. `shared/_form_actions` makes Cancel close the modal; `shared/_delete_record` submits Delete as a full page (`data-turbo-frame="_top"`).
- `ModalForm#respond_saved` answers a save from the modal with `turbo_stream.refresh(request_id: nil)`, so the page under the modal morphs and the empty frame closes it. The `request_id: nil` matters: Turbo ignores a refresh carrying the id of its own request.
- `DestroyRedirect#redirect_after_destroy` returns to the referring page, or to the parent when the delete came from the record's own page.
- Track edits go through `TrackUpdate`, which routes title/artist/album/year through `TrackRetagService` so a track and its album keep the same artist. Artist and album are typed names (find-or-create in the owner's library).
- Album create and edit go through `AlbumSave`: the artist is a typed name resolved with `Artist.find_or_create_named!`, rolled back if the album fails to save.
- `ModalForm#respond_created` answers a create from the modal with a custom `<turbo-stream action="visit" location="...">` (registered in `application.js`), landing on the new record.
- Playlists use the same modal for New Playlist and Rename. Adding or removing a track, and "New playlist…" in a row's add menu, answer through `InPlaceRefresh#respond_in_place`: a Turbo request gets a flash ("Added to X.", "Already in X.", "Removed from X.") plus a refresh, so the user stays on the page. `Playlist#remove_track` closes the gap so positions stay 1..N.
- Playlist rows reorder by drag (`sortable_controller.js`, SortableJS pinned in `vendor/javascript`) or by Move up / Move down buttons. Both `PATCH /playlists/:id/tracks/:id` — a drag with the `position` it was dropped on (`Playlist#move_track!`), a button with a `direction` (`Playlist#step_track!`, which finds the real neighbour across pages and numbering gaps). Controls hide while the list is filtered. The API and MCP full-order rewrite share `Playlist#reorder!`.
- "Upload tracks" (album More menu, artist page) opens `track_uploads/new`: `bulk_upload_controller.js` direct-uploads several files, then `TrackUpload` files them as tracks in one album (titled by file name) and enqueues `MetadataExtractionJob` to read the tags — except for `AudioConversionJob::CONVERTIBLE_FORMATS`, whose conversion reads them.

### Video Folders

A `Folder` is a series of videos, ordered by `season_number` and `episode_number`. Owners manage folders in the modal, like the rest of the library:

- **New Folder** (TV → Videos) opens `folders/new`. Creating one lands on its empty page, which offers **Upload videos**. Edit and Delete sit under the folder page's More menu and behind the pencil on `FolderCard`.
- Deleting a folder keeps its videos (`dependent: :nullify`), which go back to the Videos grid. The confirmation (`folder_delete_confirmation`) and the flash both give the count.
- **Upload videos** opens `folder_uploads/new`: `bulk_upload_controller.js` direct-uploads the files, then `FolderVideoUploadService` files one video per blob in that folder, reading the season, episode and title from each file name (`FilenameEpisodeParser`). The page under the modal refreshes. The grid lists ready videos only, so the header counts the new ones as processing until `VideoConversionJob` finishes.
- A video's folder must belong to the video's owner (`Video#folder_in_same_library`), whichever path sets it: the web form or the import API.
- `Folder#cover` is the folder's own cover image, else its first ready episode's thumbnail. The card and the folder page both use it.

### Video Subtitles

An uploaded video's subtitles are `VideoSubtitle` rows (`label`, `language`, `kind` subtitles/captions, `vtt` text). The video page renders one `<track>` per row, so the browser's own captions menu switches them.

- **Served from the app, never storage.** Production streams the video from a presigned bucket URL on another origin, and a `<track>` only loads same-origin. `VideoSubtitlesController#show` renders the stored WebVTT itself; no bucket CORS needed.
- `SubtitleText` turns SRT or WebVTT bytes into WebVTT: it reads UTF-8, UTF-16 with a byte order mark, or Windows-1252; rewrites SRT timings; drops `<font>` and `{\an8}` tags a browser would print; and refuses a file with no cues.
- `SubtitleFilename` reads the label, language and kind from the file name against the video's own (`Canadian.fre.srt` → "French (Canadian)", `SDH.eng.HI.srt` → "English (SDH)" captions); `SubtitleLanguage` holds the language codes.
- `SubtitleImport` files one file (numbering a label the video already has). The edit page (add/remove) and `POST /api/import/videos/:id/subtitles` both go through it.
- **Native apps read them over Subsonic.** `getVideo` lists a video's tracks (`Subsonic::VideoSerializer.to_detail`, without the WebVTT text), and `getVideoSubtitle?videoId=&id=` serves one track's WebVTT. The list endpoints leave tracks out, since `getVideos` isn't paged. The Mac app draws them itself (card SYN-46); the iOS app doesn't show them yet (card SYN-42).

### ViewComponents

`TrackRow::Component` renders a track in list views with configurable options: `link_title`, `link_subtitle`, `show_album`, `hide_artist_if`, `show_duration`, `number`.

### YouTube Playlist Imports

`YoutubePlaylistImportService` fetches a playlist (YouTube Data API, or yt-dlp when the user has no API key) and hands each video to a filing:

- **Music** → `YoutubeMusicFiling`. `YoutubeTrackAttribution` credits the performer from the video's *own* metadata, strongest first: the "Provided to YouTube by" release note (`YoutubeReleaseNote`: artist, title, album, ℗ year), an "Artist - Title" video title, a full-album playlist title, then the video's own channel — never the playlist owner, whose channel name is how "Rock Collection" became an artist. The album is the note's album, the playlist for a full-album rip, else the artist's "Singles". A track and its album always share an artist.
- **Podcast** → `YoutubePodcastFiling`: the channel is the artist and the playlist is one album, refreshable with "Refresh from YouTube".

It returns a `YoutubeImport` (title, tracks in playlist order, playlist). `YoutubeAlbumImportService` adds the tracks to a library playlist: for music, one named after the YouTube playlist (found by name, so re-runs reuse it) unless `playlist_id` or `new_playlist_name` names another. `YoutubeImport#summary` is the reply of both `POST /api/v1/youtube_imports` and the MCP `import_youtube_playlist` tool; `album_id` is set only when every track landed in one album, and `missing_audio` is the list `bin/import_audio` pushes.

### Service Objects (app/services/)

- `JWTService` - Encode/decode JWT tokens
- `MetadataExtractor` - Parse audio file tags via WahWah (title, artist, album, year, genre, track_number, duration, bitrate, cover_art)
- `SearchService` - Text search across artists, albums, and tracks using LIKE patterns

### Background Jobs (app/jobs/)

Three Solid Queue queues isolate work by resource profile (configured in `config/queue.yml`):

- **conversion** (2 threads) — CPU-heavy ffmpeg work: `AudioConversionJob`, `VideoConversionJob`, `StreamRecordingJob`
- **imports** (2 threads) — long-running network downloads: `MediaDownloadJob`, `VideoDownloadJob`, `YoutubeImportJob`
- **default** (3 threads) — everything else: `MetadataExtractionJob`, `DownloadZipJob`, and other lightweight/quick jobs

When adding a new job, assign it to the appropriate queue via `queue_as` in the job class. Default is `:default` if omitted.

- **Solid Queue runs only on the job server.** `SOLID_QUEUE_IN_PUMA` is not set — the web server does not process jobs.
- **After deploying, restart the job server** if you changed job classes: `bin/kamal app stop -r job && bin/kamal app boot -r job`.

## Routes

- Standard RESTful: artists, albums, tracks, playlists, favorites, play_histories
- `GET /track_uploads/new`, `POST /track_uploads` - Multi-file track upload into an album (`album_id`, or `artist_id` + `album_title`)
- `GET /folders/:folder_id/uploads/new`, `POST /folders/:folder_id/uploads` - Multi-file video upload into a folder (optional `season_number`)
- `POST /albums/:id/create_playlist` - Create playlist from album
- `GET /tracks/:id/stream` - Audio streaming endpoint
- `GET /search`, `GET /search/dropdown` - Search
- `/rest/*`, `/api/rest/*` - Subsonic-compatible API (32 endpoints)
- `/api/v1/*` - JWT-authenticated REST API
- `POST /api/v1/youtube_imports` - Synchronous playlist import (metadata only, no audio downloads); replies with `playlist_id`, `track_ids` and `missing_audio`
- `POST /api/v1/tracks/:id/audio` - Attach audio to an existing track (no-op if already attached)
- `GET /videos/:video_id/subtitles/:id` - A subtitle's WebVTT, for the video page's `<track>`; `POST`/`DELETE` add and remove from the edit page
- `POST /api/import/videos/:video_id/subtitles` - Add a subtitle file (base64) to a video
- `/admin` - Madmin admin panel
- `/jobs` - Mission Control Jobs dashboard

## Local Audio Import (YouTube bot-check workaround)

The production server's datacenter IP is bot-checked by YouTube ("Sign in to confirm you're not a bot"), so `MediaDownloadJob` audio downloads fail there. Workaround: `bin/import_audio` runs yt-dlp on a local (residential-IP) machine, pushes files to prod via the API, and deletes them after each successful push.

```bash
export SYNTHWAVES_CLIENT_ID=bc_...    # create a key at /api_keys
export SYNTHWAVES_SECRET_KEY=...
bin/import_audio "<youtube playlist URL>" [--category C] [--playlist ID | --new-playlist NAME]
bin/import_audio --album 42 [--limit N]  # push audio for an existing album only
```

The CLI is idempotent — it only pushes the tracks the import reply lists in `missing_audio`, so re-running resumes after transient YouTube 403/429 failures (the re-import skips videos already imported and reuses the playlist it created). Known local dev gotcha: JWT API auth is broken in development unless development credentials contain `secret_key_base`.

## Local Video Import (large files)

The browser upload at `/videos/new` posts the whole file through Rails in one request, so a movie-sized file times out. `bin/import_video` uploads one local video file from the terminal instead, with the same API key as `bin/import_audio`:

```bash
bin/import_video ~/Movies/Heat.mkv [--title T]
bin/import_video s01e02.mkv --folder "The Wire" --season 1 --episode 2
bin/import_video clip.webm --no-encode   # skip the local encode; the server converts
bin/import_video Heat.mkv --subtitle Heat.English.srt   # send these subtitles, not the ones found
bin/import_video Heat.mkv --no-subtitles
```

**It converts locally first.** The production server has 1 CPU. `VideoConversionJob` re-encodes any video that is not H.264 (`:full`, hours for a feature), converts surround or non-AAC sound to stereo AAC (`:transcode_audio`), and repackages H.264 + stereo AAC from another container as MP4 (`:remux`). Each conversion also uploads the whole file to storage again: The Odyssey (3 GB) took 516 s to be ready when the server converted its sound, against 148 s when the sound came converted. So the script probes the file with ffprobe, makes the job's own choice with the same method's exact ffmpeg arguments (`VideoImport::Conversion`), converts into a temporary MP4, uploads that and deletes it. An H.264, stereo AAC MP4 uploads as it is. Needs ffmpeg (`brew install ffmpeg`). `spec/lib/cli/video_import/server_agreement_spec.rb` runs the real `VideoConversionJob` on the script's output for each path, so changing the server's choice or settings without the script's fails a spec. One shape still converts on the server: an H.264 video with no sound, which the job sends down its audio path every time.

Then it asks `POST /api/import/direct_uploads` for a presigned URL, PUTs the file straight to object storage as one stream (Rails never sees the bytes, memory stays flat), and files it with `POST /api/import/videos`.

**The server never downloads it either.** For the file it uploads, the script also reads the details the job would store (`Probe#details`, `VideoMetadataExtractor`'s fields) and makes the thumbnail with the job's exact command (`VideoImport::ReadyDetails`). It uploads the thumbnail the same way and files the video with both. When the details say the job would keep the file as it is (`VideoConversionStrategy`, which the job and the endpoint share), `PreparedVideo` files it `ready` with them and no job runs (`Video#convert_video` skips a ready video). A video's file is also never handed to ActiveStorage's analyzer (`has_one_attached :file, analyze: :lazily`), which would otherwise download the whole file once more for every upload, browser uploads included, to read metadata nothing uses. The video plays as soon as the script prints `Filed`. `ready_details_agreement_spec.rb` makes the details and thumbnail on both sides from the same file and expects them equal, byte for byte. `--no-encode`, a file the job would still convert (an H.264 video with no sound) and a thumbnail that fails all leave both to the job, as before. Each API call fetches a fresh JWT, so an upload longer than the token's hour still files. The source file is never deleted or changed. It shows under Watch → Videos once `ready`.

**Subtitles go up after the video.** Before uploading, the script lists the `.srt`/`.vtt` files that came with the video (`VideoImport::SubtitleFiles`): those in `Subs/` beside it or `Subs/<video name>/`, then those beside it named after it (`Heat.en.srt`). It looks beside the original file, never the temp encode, and sends a byte-identical file once. Once the video is filed, `VideoImport::SubtitleUpload` posts each to `POST /api/import/videos/:id/subtitles`. A refused file does not stop the rest; the script names it, points at the video's edit page, and exits 1.

- The code is stdlib-only, in `lib/cli/video_import/`, which `autoload_lib` ignores so Rails never loads it.
- One PUT has no resume: a dropped connection restarts from zero. S3-style storage caps one PUT at 5 GB; a larger file needs multipart upload, which nothing here supports yet.
- `rake videos:push` (`lib/tasks/push_videos.rake`) is the older bulk path: it reads `credentials.remote`, walks a folder, re-encodes locally and **deletes each source file after upload**.

### A whole folder: `bin/import_videos`

```bash
bin/import_videos ~/Movies --dry-run   # what it would upload, and why it skips the rest
bin/import_videos ~/Movies
```

It runs the same upload as `bin/import_video`, in-process, once per video file under the folder (mkv, mp4, m4v, mov, avi, webm; `VideoImport::FolderScan`), sorted by path, and carries on past a failure. It ends with an Uploaded / Skipped / Failed summary and exits 1 when anything failed. `VideoImport::FolderImport` is the loop.

- **Titles come from file names** (`VideoImport::VideoTitle`). The title is the words before the release year, or before the first quality tag when there is no year (`Dazed.and.Confused.1993.1080p.BluRay.x264-GalaxyRG.mkv` → "Dazed and Confused"). The last year before the tags counts, so `Blade.Runner.2049.2017` keeps 2049. Trailing edition words (EXTENDED, UNRATED, REMASTERED…) are dropped and the words title-cased. A file name cannot carry an apostrophe or a colon, so fixes go in `FOLDER/synthwaves-titles.txt`, one `Theres Something About Mary = There's Something About Mary` per line (`VideoImport::TitleFixes`). A line without `=` stops the run and names the line.
- **A rerun never uploads a title twice.** Each video the server files goes into `FOLDER/synthwaves-uploaded.log` (`title<TAB>video N<TAB>time`, `VideoImport::UploadLog`) before its subtitles are sent, and titles in the log are skipped. The log knows only what this tool filed. A video uploaded another way needs a line added by hand, or it goes up again.
- **Unfinished downloads are skipped** (`VideoImport::UnfinishedDownload`): a `.part` file beside the video, or a file another program has open to write (`lsof`). Rerun once they finish.
- **A folder it may not read is skipped, by name** (`VideoImport::FolderScan`): `Skipping the folder ~/Movies/TV: it can't be read (Operation not permitted)`. macOS keeps `~/Movies/TV`, the TV app's library, from a terminal that has not been given access to it. Hidden files are left out and links to folders are not followed.
- **Subtitles:** the files beside the video, as `bin/import_video` finds them. When there are none, `VideoImport::EmbeddedSubtitles` writes the text tracks inside the file (an MKV's subrip) to temporary `.srt` files named for `SubtitleFilename` (`eng.srt`, `SDH.eng.srt`, and `2_eng.srt` for a repeat, which the server labels "English 2"; `subtitle_names_agreement_spec.rb` runs the real `SubtitleImport` on them) and sends those. Image subtitles (Blu-ray PGS) can't become text, so they are left out.
- On macOS it keeps the Mac awake with `caffeinate` while it runs.

## Git Workflow

Branch protection is enabled on `main` — direct pushes are not allowed. All changes must go through a pull request.

1. Create a feature branch from `main`
2. Commit changes to the branch
3. Push the branch and open a PR
4. CI must pass (tests, lint, security scans)
5. Merge via PR

## Testing

RSpec with FactoryBot, shoulda-matchers, and webmock. Test directories mirror app structure: `spec/{models,requests,services,jobs,components,helpers,factories}/`.
