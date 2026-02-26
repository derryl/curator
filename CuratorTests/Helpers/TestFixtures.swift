import Foundation

enum TestFixtures {

    // MARK: - URL Session

    static func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func httpResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    // MARK: - Movie Details JSON

    static let movieDetailsJSON: Data = {
        let json: [String: Any] = [
            "id": 550,
            "title": "Fight Club",
            "originalTitle": "Fight Club",
            "overview": "A ticking-Loss-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy.",
            "posterPath": "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            "backdropPath": "/hZkgoQYus5dXo3H8T7Uef6DNknx.jpg",
            "voteAverage": 8.4,
            "releaseDate": "1999-10-15",
            "runtime": 139,
            "genres": [
                ["id": 18, "name": "Drama"],
                ["id": 53, "name": "Thriller"],
            ],
            "credits": [
                "cast": [
                    ["id": 819, "name": "Edward Norton", "character": "The Narrator", "profilePath": "/123.jpg"],
                    ["id": 287, "name": "Brad Pitt", "character": "Tyler Durden", "profilePath": "/456.jpg"],
                ],
            ],
            "relatedVideos": [
                ["url": "https://youtube.com/watch?v=abc123", "key": "abc123", "name": "Official Trailer", "site": "YouTube", "type": "Trailer", "size": 1080],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - TV Details JSON

    static let tvDetailsJSON: Data = {
        let json: [String: Any] = [
            "id": 1399,
            "name": "Breaking Bad",
            "originalName": "Breaking Bad",
            "overview": "A chemistry teacher diagnosed with lung cancer teams up with a former student to cook methamphetamine.",
            "posterPath": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            "backdropPath": "/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg",
            "voteAverage": 8.9,
            "firstAirDate": "2008-01-20",
            "numberOfSeasons": 5,
            "numberOfEpisodes": 62,
            "genres": [
                ["id": 18, "name": "Drama"],
                ["id": 80, "name": "Crime"],
            ],
            "seasons": [
                ["id": 3572, "seasonNumber": 1, "name": "Season 1", "episodeCount": 7, "overview": "Season 1 overview", "posterPath": "/s1.jpg"],
                ["id": 3573, "seasonNumber": 2, "name": "Season 2", "episodeCount": 13, "overview": "Season 2 overview", "posterPath": "/s2.jpg"],
            ],
            "credits": [
                "cast": [
                    ["id": 17419, "name": "Bryan Cranston", "character": "Walter White", "profilePath": "/789.jpg"],
                ],
            ],
            "relatedVideos": [
                ["url": "https://youtube.com/watch?v=def456", "key": "def456", "name": "Official Trailer", "site": "YouTube", "type": "Trailer", "size": 1080],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Search Results JSON

    static let searchResultsJSON: Data = {
        let json: [String: Any] = [
            "page": 1,
            "totalPages": 1,
            "totalResults": 2,
            "results": [
                [
                    "id": 550,
                    "mediaType": "movie",
                    "title": "Fight Club",
                    "posterPath": "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
                    "backdropPath": "/hZkgoQYus5dXo3H8T7Uef6DNknx.jpg",
                    "overview": "A ticking-Loss-bomb insomniac...",
                    "voteAverage": 8.4,
                    "genreIds": [18, 53],
                ],
                [
                    "id": 1399,
                    "mediaType": "tv",
                    "name": "Breaking Bad",
                    "posterPath": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
                    "backdropPath": "/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg",
                    "overview": "A chemistry teacher...",
                    "voteAverage": 8.9,
                    "genreIds": [18, 80],
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Media Request Response JSON

    static let mediaRequestJSON: Data = {
        let json: [String: Any] = [
            "id": 42,
            "status": 2,
            "mediaType": "movie",
            "createdAt": "2024-01-01T00:00:00.000Z",
            "updatedAt": "2024-01-01T00:00:00.000Z",
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Similar / Recommendations (Paged)

    static let similarMoviesJSON: Data = {
        let json: [String: Any] = [
            "page": 1,
            "totalPages": 1,
            "totalResults": 1,
            "results": [
                [
                    "id": 680,
                    "mediaType": "movie",
                    "title": "Pulp Fiction",
                    "posterPath": "/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg",
                    "overview": "A burger-loving hit man...",
                    "voteAverage": 8.5,
                    "genreIds": [53, 80],
                ] as [String: Any],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    static let recommendedMoviesJSON: Data = {
        let json: [String: Any] = [
            "page": 1,
            "totalPages": 1,
            "totalResults": 1,
            "results": [
                [
                    "id": 807,
                    "mediaType": "movie",
                    "title": "Se7en",
                    "posterPath": "/6yoghtyTpznpBik8EngEmJskVUO.jpg",
                    "overview": "Two detectives...",
                    "voteAverage": 8.3,
                    "genreIds": [18, 53, 80],
                ] as [String: Any],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Service / Quality Profiles JSON

    static let radarrServicesJSON: Data = {
        let json: [[String: Any]] = [
            [
                "id": 1,
                "name": "Radarr",
                "is4k": false,
                "isDefault": true,
                "activeProfileId": 4,
                "activeDirectory": "/movies",
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    static let radarrServiceDetailsJSON: Data = {
        let json: [String: Any] = [
            "server": [
                "id": 1,
                "name": "Radarr",
                "is4k": false,
                "isDefault": true,
                "activeProfileId": 4,
                "activeDirectory": "/movies",
            ],
            "profiles": [
                ["id": 4, "name": "HD-1080p"],
                ["id": 7, "name": "Ultra-HD 4K"],
                ["id": 1, "name": "Any"],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Person Combined Credits JSON

    static let personCombinedCreditsJSON: Data = {
        let json: [String: Any] = [
            "id": 138,
            "cast": [
                [
                    "id": 100,
                    "mediaType": "movie",
                    "title": "Other Movie A",
                    "posterPath": "/a.jpg",
                    "backdropPath": "/a_bd.jpg",
                    "voteAverage": 7.8,
                    "releaseDate": "2005-06-15",
                ] as [String: Any],
                [
                    "id": 550,
                    "mediaType": "movie",
                    "title": "Fight Club",
                    "posterPath": "/fc.jpg",
                    "backdropPath": "/fc_bd.jpg",
                    "voteAverage": 8.4,
                    "releaseDate": "1999-10-15",
                ] as [String: Any],
                [
                    "id": 200,
                    "mediaType": "movie",
                    "title": "Other Movie B",
                    "posterPath": "/b.jpg",
                    "backdropPath": "/b_bd.jpg",
                    "voteAverage": 6.5,
                    "releaseDate": "2010-03-20",
                ] as [String: Any],
            ],
            "crew": [
                [
                    "id": 300,
                    "mediaType": "movie",
                    "title": "Directed Movie",
                    "posterPath": "/d.jpg",
                    "backdropPath": "/d_bd.jpg",
                    "voteAverage": 8.0,
                    "job": "Director",
                    "department": "Directing",
                    "releaseDate": "2015-07-10",
                ] as [String: Any],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Movie Details with Crew JSON

    static let movieDetailsWithCrewJSON: Data = {
        let json: [String: Any] = [
            "id": 550,
            "title": "Fight Club",
            "overview": "An insomniac office worker...",
            "posterPath": "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            "backdropPath": "/hZkgoQYus5dXo3H8T7Uef6DNknx.jpg",
            "voteAverage": 8.4,
            "releaseDate": "1999-10-15",
            "runtime": 139,
            "genres": [
                ["id": 18, "name": "Drama"],
                ["id": 53, "name": "Thriller"],
            ],
            "credits": [
                "cast": [
                    ["id": 819, "name": "Edward Norton", "character": "The Narrator", "profilePath": "/123.jpg"],
                    ["id": 287, "name": "Brad Pitt", "character": "Tyler Durden", "profilePath": "/456.jpg"],
                ],
                "crew": [
                    ["id": 7467, "name": "David Fincher", "job": "Director", "department": "Directing", "profilePath": "/df.jpg"],
                    ["id": 999, "name": "Art Linson", "job": "Producer", "department": "Production", "profilePath": "/al.jpg"],
                ],
            ],
            "relatedVideos": [
                ["url": "https://youtube.com/watch?v=abc123", "key": "abc123", "name": "Official Trailer", "site": "YouTube", "type": "Trailer", "size": 1080],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - TV Details with Crew JSON

    static let tvDetailsWithCrewJSON: Data = {
        let json: [String: Any] = [
            "id": 1399,
            "name": "Breaking Bad",
            "overview": "A chemistry teacher...",
            "posterPath": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            "backdropPath": "/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg",
            "voteAverage": 8.9,
            "firstAirDate": "2008-01-20",
            "numberOfSeasons": 5,
            "numberOfEpisodes": 62,
            "genres": [
                ["id": 18, "name": "Drama"],
                ["id": 80, "name": "Crime"],
            ],
            "seasons": [
                ["id": 3572, "seasonNumber": 1, "name": "Season 1", "episodeCount": 7, "overview": "S1", "posterPath": "/s1.jpg"],
            ],
            "credits": [
                "cast": [
                    ["id": 17419, "name": "Bryan Cranston", "character": "Walter White", "profilePath": "/789.jpg"],
                ],
                "crew": [
                    ["id": 66633, "name": "Vince Gilligan", "job": "Executive Producer", "department": "Production", "profilePath": "/vg.jpg"],
                ],
            ],
            "relatedVideos": [
                ["url": "https://youtube.com/watch?v=def456", "key": "def456", "name": "Official Trailer", "site": "YouTube", "type": "Trailer", "size": 1080],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    // MARK: - Error JSON

    static func errorJSON(message: String = "Internal Server Error") -> Data {
        let json: [String: Any] = ["message": message]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - YouTube Innertube API Responses

    /// Response with both adaptive (separate video+audio) and progressive (combined) formats.
    /// Adaptive has 1080p video + 128kbps audio; progressive has 360p and 720p combined.
    static let youtubeInnertubeResponseJSON: Data = {
        let json: [String: Any] = [
            "streamingData": [
                "adaptiveFormats": [
                    [
                        "itag": 137,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=137",
                        "mimeType": "video/mp4; codecs=\"avc1.640028\"",
                        "width": 1920,
                        "height": 1080,
                        "bitrate": 4000000,
                        "quality": "hd1080",
                    ] as [String: Any],
                    [
                        "itag": 136,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=136",
                        "mimeType": "video/mp4; codecs=\"avc1.4d401f\"",
                        "width": 1280,
                        "height": 720,
                        "bitrate": 2500000,
                        "quality": "hd720",
                    ] as [String: Any],
                    [
                        "itag": 140,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=140",
                        "mimeType": "audio/mp4; codecs=\"mp4a.40.2\"",
                        "bitrate": 128000,
                        "audioQuality": "AUDIO_QUALITY_MEDIUM",
                    ] as [String: Any],
                    [
                        "itag": 249,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=249",
                        "mimeType": "audio/webm; codecs=\"opus\"",
                        "bitrate": 50000,
                        "audioQuality": "AUDIO_QUALITY_LOW",
                    ] as [String: Any],
                ],
                "formats": [
                    [
                        "itag": 18,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=18",
                        "mimeType": "video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"",
                        "width": 640,
                        "height": 360,
                        "quality": "medium",
                    ] as [String: Any],
                    [
                        "itag": 22,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=22",
                        "mimeType": "video/mp4; codecs=\"avc1.64001F, mp4a.40.2\"",
                        "width": 1280,
                        "height": 720,
                        "quality": "hd720",
                    ] as [String: Any],
                ],
            ] as [String: Any],
            "videoDetails": [
                "videoId": "dQw4w9WgXcQ",
                "title": "Test Video",
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    /// Response with only progressive formats (no adaptiveFormats).
    static let youtubeInnertubeProgressiveOnlyJSON: Data = {
        let json: [String: Any] = [
            "streamingData": [
                "formats": [
                    [
                        "itag": 18,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=18",
                        "mimeType": "video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"",
                        "width": 640,
                        "height": 360,
                        "quality": "medium",
                    ] as [String: Any],
                    [
                        "itag": 22,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=22",
                        "mimeType": "video/mp4; codecs=\"avc1.64001F, mp4a.40.2\"",
                        "width": 1280,
                        "height": 720,
                        "quality": "hd720",
                    ] as [String: Any],
                ],
            ] as [String: Any],
            "videoDetails": [
                "videoId": "dQw4w9WgXcQ",
                "title": "Test Video",
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    static let youtubeInnertubeNoFormatsJSON: Data = {
        let json: [String: Any] = [
            "streamingData": [
                "adaptiveFormats": [
                    [
                        "itag": 137,
                        "signatureCipher": "s=encrypted_sig",
                    ] as [String: Any],
                ],
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    static let youtubeInnertubeErrorJSON: Data = {
        let json: [String: Any] = [
            "playabilityStatus": [
                "status": "ERROR",
                "reason": "Video unavailable",
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    /// Response with LOGIN_REQUIRED status but valid streamingData.
    /// The extractor should reject this because playabilityStatus isn't OK.
    static let youtubeInnertubeLoginRequiredJSON: Data = {
        let json: [String: Any] = [
            "playabilityStatus": [
                "status": "LOGIN_REQUIRED",
                "reason": "Sign in to confirm your age",
            ] as [String: Any],
            "streamingData": [
                "formats": [
                    [
                        "itag": 18,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?itag=18",
                        "mimeType": "video/mp4",
                        "height": 360,
                    ] as [String: Any],
                ],
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    static let youtubeHTMLWithHLS: Data = {
        let html = """
        <html><body><script>var ytInitialPlayerResponse = {"streamingData":{"hlsManifestUrl":"https://manifest.googlevideo.com/api/manifest/hls_variant/expire/123/id/abc"}};</script></body></html>
        """
        return html.data(using: .utf8)!
    }()

    static let youtubeHTMLWithProgressiveFormats: Data = {
        let html = """
        <html><body><script>var ytInitialPlayerResponse = {"streamingData":{"formats":[{"itag":18,"url":"https://rr1---sn-example.googlevideo.com/videoplayback?itag=18","mimeType":"video/mp4","width":640,"height":360}]}};</script></body></html>
        """
        return html.data(using: .utf8)!
    }()

    // MARK: - Codec Filtering Fixtures

    /// Response where the highest-quality adaptive video is VP9 (incompatible with tvOS).
    /// The extractor should skip VP9 and select the next-best mp4 format.
    static let youtubeInnertubeWithVP9JSON: Data = {
        let json: [String: Any] = [
            "streamingData": [
                "adaptiveFormats": [
                    [
                        "itag": 271,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=271",
                        "mimeType": "video/webm; codecs=\"vp9\"",
                        "width": 2560,
                        "height": 1440,
                        "bitrate": 8000000,
                        "quality": "hd1440",
                    ] as [String: Any],
                    [
                        "itag": 136,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=136",
                        "mimeType": "video/mp4; codecs=\"avc1.4d401f\"",
                        "width": 1280,
                        "height": 720,
                        "bitrate": 2500000,
                        "quality": "hd720",
                    ] as [String: Any],
                    [
                        "itag": 140,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=140",
                        "mimeType": "audio/mp4; codecs=\"mp4a.40.2\"",
                        "bitrate": 128000,
                        "audioQuality": "AUDIO_QUALITY_MEDIUM",
                    ] as [String: Any],
                ],
                "formats": [
                    [
                        "itag": 18,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=18",
                        "mimeType": "video/mp4; codecs=\"avc1.42001E, mp4a.40.2\"",
                        "width": 640,
                        "height": 360,
                        "quality": "medium",
                    ] as [String: Any],
                ],
            ] as [String: Any],
            "videoDetails": [
                "videoId": "test",
                "title": "VP9 Test Video",
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()

    /// Response where the only audio format is Opus/WebM (incompatible with tvOS AVPlayer).
    /// The extractor should return video-only since no compatible audio is available.
    static let youtubeInnertubeOpusOnlyAudioJSON: Data = {
        let json: [String: Any] = [
            "streamingData": [
                "adaptiveFormats": [
                    [
                        "itag": 137,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=137",
                        "mimeType": "video/mp4; codecs=\"avc1.640028\"",
                        "width": 1920,
                        "height": 1080,
                        "bitrate": 4000000,
                        "quality": "hd1080",
                    ] as [String: Any],
                    [
                        "itag": 249,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=249",
                        "mimeType": "audio/webm; codecs=\"opus\"",
                        "bitrate": 50000,
                        "audioQuality": "AUDIO_QUALITY_LOW",
                    ] as [String: Any],
                    [
                        "itag": 250,
                        "url": "https://rr1---sn-example.googlevideo.com/videoplayback?id=abc123&itag=250",
                        "mimeType": "audio/webm; codecs=\"opus\"",
                        "bitrate": 70000,
                        "audioQuality": "AUDIO_QUALITY_LOW",
                    ] as [String: Any],
                ],
            ] as [String: Any],
            "videoDetails": [
                "videoId": "test",
                "title": "Opus Only Audio Test",
            ] as [String: Any],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }()
}
