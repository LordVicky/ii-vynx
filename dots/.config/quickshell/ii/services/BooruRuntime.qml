pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell
import QtQuick

/**
 * Destroyable Booru backend. All provider maps, response QObjects and XMLHttpRequest
 * instances belong to this object so disabling the Anime extension can reclaim them.
 */
QtObject {
    id: root

    signal tagSuggestion(string query, var suggestions)
    signal responseFinished()

    property Component booruResponseDataComponent: BooruResponseData {}
    property string failMessage: Translation.tr("That didn't work. Tips:\n- Check your tags and NSFW settings\n- If you don't have a tag in mind, type a page number")
    property var responses: []
    property int maxResponses: 3
    property int runningRequests: 0
    property bool shuttingDown: false
    property var activeRequests: []
    property var currentTagRequest: null
    property var defaultUserAgent: Config.options?.networking?.userAgent
        || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"

    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property string currentProvider: Persistent.states.booru.provider

    property var providers: ({
        "system": {
            "name": Translation.tr("System")
        },
        "yandere": {
            "name": "yande.re",
            "url": "https://yande.re",
            "api": "https://yande.re/post.json",
            "description": Translation.tr("All-rounder | Good quality, decent quantity"),
            "tagSearchTemplate": "https://yande.re/tag.json?order=count&limit=10&name={{query}}*"
        },
        "konachan": {
            "name": "Konachan",
            "url": "https://konachan.net",
            "api": "https://konachan.net/post.json",
            "description": Translation.tr("For desktop wallpapers | Good quality, decent quantity"),
            "tagSearchTemplate": "https://konachan.net/tag.json?order=count&limit=10&name={{query}}*"
        },
        "zerochan": {
            "name": "Zerochan",
            "url": "https://www.zerochan.net",
            "api": "https://www.zerochan.net/?json",
            "description": Translation.tr("Clean stuff | Excellent quality, no NSFW")
        },
        "danbooru": {
            "name": "Danbooru",
            "url": "https://danbooru.donmai.us",
            "api": "https://danbooru.donmai.us/posts.json",
            "description": Translation.tr("The popular one | Best quantity, but quality can vary wildly"),
            "tagSearchTemplate": "https://danbooru.donmai.us/tags.json?limit=10&search[name_matches]={{query}}*"
        },
        "gelbooru": {
            "name": "Gelbooru",
            "url": "https://gelbooru.com",
            "api": "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1",
            "description": Translation.tr("The hentai one | Great quantity, a lot of NSFW, quality varies wildly"),
            "tagSearchTemplate": "https://gelbooru.com/index.php?page=dapi&s=tag&q=index&json=1&orderby=count&limit=10&name_pattern={{query}}%"
        },
        "waifu.im": {
            "name": "waifu.im",
            "url": "https://waifu.im",
            "api": "https://api.waifu.im/images",
            "description": Translation.tr("Waifus only | Excellent quality, limited quantity"),
            "tagSearchTemplate": "https://api.waifu.im/tags?Name={{query}}"
        },
        "t.alcy.cc": {
            "name": "Alcy",
            "url": "https://t.alcy.cc",
            "api": "https://t.alcy.cc/",
            "description": Translation.tr("Large images | God tier quality, no NSFW."),
            "fixedTags": [
                { "name": "ycy", "count": "General" },
                { "name": "moez", "count": "Moe" },
                { "name": "ysz", "count": "Genshin Impact" },
                { "name": "fj", "count": "Landscape" },
                { "name": "bd", "count": "Girl on white background" },
                { "name": "xhl", "count": "Shiggy" }
            ]
        }
    })

    readonly property var providerList: Object.keys(root.providers)
        .filter(provider => provider !== "system" && root.providers[provider].api)

    function getWorkingImageSource(url) {
        if (url?.includes("pximg.net")) {
            return `https://www.pixiv.net/en/artworks/${url.substring(url.lastIndexOf("/") + 1).replace(/_p\d+\.(png|jpg|jpeg|gif)$/, "")}`
        }
        return url
    }

    function setProvider(provider) {
        provider = provider.toLowerCase()
        if (root.providerList.indexOf(provider) !== -1) {
            Persistent.states.booru.provider = provider
            root.addSystemMessage(Translation.tr("Provider set to ") + root.providers[provider].name
                + (provider === "zerochan" ? Translation.tr(". Notes for Zerochan:\n- You must enter a color\n- Set your zerochan username in `sidebar.booru.zerochan.username` config option.") : ""))
        } else {
            root.addSystemMessage(Translation.tr("Invalid API provider. Supported: \n- ") + root.providerList.join("\n- "))
        }
    }

    function _destroyResponse(response) {
        if (!response)
            return
        try {
            response.destroy()
        } catch (error) {
            console.warn("[Booru] Failed to destroy response object:", error)
        }
    }

    function _dropPreviewFiles(response) {
        if (!response?.images)
            return
        response.images.forEach(image => {
            [image.preview_url, image.sample_url, image.file_url].forEach(url => {
                if (!url)
                    return
                const cleanUrl = url.split("?")[0]
                const fileName = decodeURIComponent(cleanUrl.substring(cleanUrl.lastIndexOf("/") + 1))
                Quickshell.execDetached(["rm", "-f", `${Directories.booruPreviews}/${fileName}`])
            })
        })
    }

    function replaceResponses(nextResponses) {
        const next = nextResponses ? Array.from(nextResponses) : []
        const previous = root.responses ? Array.from(root.responses) : []
        root.responses = next
        previous.forEach(response => {
            if (!next.includes(response))
                root._destroyResponse(response)
        })
    }

    function clearResponses() {
        root.replaceResponses([])
    }

    function addResponse(newResponse) {
        let next = [...root.responses, newResponse]
        if (next.length > root.maxResponses) {
            const toRemove = next.slice(0, next.length - root.maxResponses)
            toRemove.forEach(response => {
                root._dropPreviewFiles(response)
                root._destroyResponse(response)
            })
            next = next.slice(next.length - root.maxResponses)
        }
        root.responses = next
        root.responseFinished()
    }

    function addSystemMessage(message) {
        if (root.shuttingDown)
            return
        const response = root.booruResponseDataComponent.createObject(root, {
            "provider": "system",
            "tags": [],
            "page": -1,
            "images": [],
            "message": `${message}`
        })
        if (response)
            root.addResponse(response)
    }

    function resetApiKeys(provider) {
        if (!root.providers[provider])
            return
        KeyringStorage.setNestedField(["apiKeys", provider], undefined)
        KeyringStorage.setNestedField(["apiKeys", provider + "_user_id"], undefined)
        KeyringStorage.setNestedField(["apiKeys", provider + "_pass_hash"], undefined)
        root.addSystemMessage(Translation.tr("API keys reset for %1").arg(root.providers[provider].name))
    }

    function constructRequestUrl(tags, nsfw = true, limit = 20, page = 1) {
        const providerId = root.currentProvider
        const provider = root.providers[providerId]
        if (!provider?.api)
            return ""

        const baseUrl = provider.api
        let url = baseUrl
        let tagString = tags.join(" ")
        if (!nsfw && !["zerochan", "waifu.im", "t.alcy.cc"].includes(providerId)) {
            tagString += providerId === "gelbooru" ? " rating:general" : " rating:safe"
        }

        const params = []
        if (providerId === "zerochan") {
            params.push("c=" + tagString)
            params.push("l=" + limit)
            params.push("s=fav")
            params.push("t=1")
            params.push("p=" + page)
        } else if (providerId === "waifu.im") {
            tagString.split(" ").forEach(tag => {
                params.push("IncludedTags=" + encodeURIComponent(tag.toLowerCase()))
            })
            params.push("PageSize=" + Math.min(limit, 30))
            params.push("IsNsfw=" + (nsfw ? "All" : "False"))
        } else if (providerId === "t.alcy.cc") {
            url += tagString
            params.push("json")
            params.push("quantity=" + limit)
        } else {
            params.push("tags=" + encodeURIComponent(tagString))
            params.push("limit=" + limit)
            if (providerId === "gelbooru") {
                params.push("pid=" + (page - 1))
                if (root.apiKeys["gelbooru"] && root.apiKeys["gelbooru_user_id"]) {
                    params.push("api_key=" + root.apiKeys["gelbooru"])
                    params.push("user_id=" + root.apiKeys["gelbooru_user_id"])
                    if (root.apiKeys["gelbooru_pass_hash"])
                        params.push("pass_hash=" + root.apiKeys["gelbooru_pass_hash"])
                }
            } else if (providerId === "danbooru") {
                params.push("page=" + page)
                if (root.apiKeys["danbooru"] && root.apiKeys["danbooru_user_id"]) {
                    params.push("api_key=" + root.apiKeys["danbooru"])
                    params.push("login=" + root.apiKeys["danbooru_user_id"])
                }
            } else {
                params.push("page=" + page)
            }
        }

        url += (baseUrl.indexOf("?") === -1 ? "?" : "&") + params.join("&")
        return url
    }

    function _mapResponse(providerId, response) {
        if (providerId === "yandere" || providerId === "konachan") {
            return response.map(item => ({
                "id": item.id,
                "width": item.width,
                "height": item.height,
                "aspect_ratio": item.width / item.height,
                "tags": item.tags,
                "rating": item.rating,
                "is_nsfw": item.rating !== "s",
                "md5": item.md5,
                "preview_url": item.preview_url,
                "sample_url": item.sample_url ?? item.file_url,
                "file_url": item.file_url,
                "file_ext": item.file_ext,
                "source": root.getWorkingImageSource(item.source) ?? item.file_url
            }))
        }

        if (providerId === "zerochan") {
            return response.items.map(item => ({
                "id": item.id,
                "width": item.width,
                "height": item.height,
                "aspect_ratio": item.width / item.height,
                "tags": item.tags.join(" "),
                "rating": "safe",
                "is_nsfw": false,
                "md5": item.md5,
                "preview_url": item.thumbnail,
                "sample_url": item.thumbnail,
                "file_url": item.thumbnail,
                "file_ext": "avif",
                "source": root.getWorkingImageSource(item.source) ?? item.thumbnail,
                "character": item.tag
            }))
        }

        if (providerId === "danbooru") {
            return response.map(item => ({
                "id": item.id,
                "width": item.image_width,
                "height": item.image_height,
                "aspect_ratio": item.image_width / item.image_height,
                "tags": item.tag_string,
                "rating": item.rating,
                "is_nsfw": item.rating !== "s",
                "md5": item.md5,
                "preview_url": item.preview_file_url,
                "sample_url": item.file_url ?? item.large_file_url,
                "file_url": item.large_file_url,
                "file_ext": item.file_ext,
                "source": root.getWorkingImageSource(item.source) ?? item.file_url
            }))
        }

        if (providerId === "gelbooru") {
            return (response.post ?? []).map(item => ({
                "id": item.id,
                "width": item.width,
                "height": item.height,
                "aspect_ratio": item.width / item.height,
                "tags": item.tags,
                "rating": item.rating.replace("general", "s").charAt(0),
                "is_nsfw": item.rating !== "s",
                "md5": item.md5,
                "preview_url": item.preview_url,
                "sample_url": item.sample_url ?? item.file_url,
                "file_url": item.file_url,
                "file_ext": item.file_url.split(".").pop(),
                "source": root.getWorkingImageSource(item.source) ?? item.file_url
            }))
        }

        if (providerId === "waifu.im") {
            return (response.items ?? []).map(item => ({
                "id": item.id,
                "width": item.width,
                "height": item.height,
                "aspect_ratio": item.width / item.height,
                "tags": item.tags.map(tag => tag.name).join(" "),
                "rating": item.isNsfw ? "e" : "s",
                "is_nsfw": item.isNsfw,
                "md5": item.md5,
                "preview_url": item.sample_url ?? item.url,
                "sample_url": item.url,
                "file_url": item.url,
                "file_ext": item.extension,
                "source": root.getWorkingImageSource(item.source) ?? item.url
            }))
        }

        if (providerId === "t.alcy.cc") {
            return String(response).trim().split("\n").filter(line => line.length > 0).map(line => ({
                "id": Qt.md5(line),
                "width": 1000,
                "height": 1000,
                "aspect_ratio": 1,
                "tags": "[no tags]",
                "rating": "s",
                "is_nsfw": false,
                "md5": Qt.md5(line),
                "preview_url": line,
                "sample_url": line,
                "file_url": line,
                "file_ext": line.split(".").pop(),
                "source": ""
            }))
        }

        return []
    }

    function _trackRequest(xhr) {
        root.activeRequests = [...root.activeRequests, xhr]
    }

    function _untrackRequest(xhr) {
        root.activeRequests = root.activeRequests.filter(request => request !== xhr)
    }

    function makeRequest(tags, nsfw = false, limit = 20, page = 1) {
        if (root.shuttingDown)
            return

        const providerId = root.currentProvider
        const provider = root.providers[providerId]
        const url = root.constructRequestUrl(tags, nsfw, limit, page)
        if (!provider?.api || !url)
            return

        console.log("[Booru] Making request to " + url)
        const newResponse = root.booruResponseDataComponent.createObject(root, {
            "provider": providerId,
            "tags": tags,
            "page": page,
            "images": [],
            "message": ""
        })
        if (!newResponse)
            return

        const xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        root._trackRequest(xhr)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            root._untrackRequest(xhr)
            if (root.shuttingDown)
                return

            try {
                if (xhr.status === 200) {
                    const parsed = providerId === "t.alcy.cc" ? xhr.responseText : JSON.parse(xhr.responseText)
                    const mapped = root._mapResponse(providerId, parsed)
                    newResponse.images = mapped
                    newResponse.message = mapped.length > 0 ? "" : root.failMessage
                    } else {
                    console.log("[Booru] Request failed with status: " + xhr.status)
                    newResponse.message = root.failMessage
                }
            } catch (error) {
                console.log("[Booru] Failed to parse response: " + error)
                newResponse.message = root.failMessage
            } finally {
                root.runningRequests = Math.max(0, root.runningRequests - 1)
                root.addResponse(newResponse)
            }
        }

        try {
            if (providerId === "danbooru") {
                xhr.setRequestHeader("User-Agent", "Quickshell-Booru/1.0")
            } else if (["konachan", "t.alcy.cc"].includes(providerId)) {
                xhr.setRequestHeader("User-Agent", root.defaultUserAgent)
            } else if (providerId === "zerochan") {
                const userAgent = Config.options?.sidebar?.booru?.zerochan?.username
                    ? `Desktop sidebar booru viewer - username: ${Config.options.sidebar.booru.zerochan.username}`
                    : root.defaultUserAgent
                xhr.setRequestHeader("User-Agent", userAgent)
            }
            root.runningRequests++
            xhr.send()
        } catch (error) {
            root._untrackRequest(xhr)
            root.runningRequests = Math.max(0, root.runningRequests - 1)
            root._destroyResponse(newResponse)
            console.log("Could not send Booru request:", error)
        }
    }

    function _mapTagResponse(providerId, response) {
        if (providerId === "yandere" || providerId === "konachan")
            return response.map(item => ({ "name": item.name, "count": item.count }))
        if (providerId === "danbooru")
            return response.map(item => ({ "name": item.name, "count": item.post_count }))
        if (providerId === "gelbooru")
            return (response.tag ?? []).map(item => ({ "name": item.name, "count": item.count }))
        if (providerId === "waifu.im")
            return (response.items ?? []).map(item => ({ "name": item.name }))
        return []
    }

    function triggerTagSearch(query) {
        if (root.shuttingDown)
            return
        if (root.currentTagRequest) {
            try {
                root.currentTagRequest.onreadystatechange = null
                root.currentTagRequest.abort()
            } catch (error) {
                console.warn("[Booru] Failed to abort previous tag request:", error)
            }
            root.currentTagRequest = null
        }

        const providerId = root.currentProvider
        const provider = root.providers[providerId]
        if (!provider)
            return
        if (provider.fixedTags) {
            root.tagSuggestion(query, provider.fixedTags)
            return provider.fixedTags
        }
        if (!provider.tagSearchTemplate)
            return

        let url = provider.tagSearchTemplate.replace("{{query}}", encodeURIComponent(query))
        if (providerId === "gelbooru" && root.apiKeys["gelbooru"] && root.apiKeys["gelbooru_user_id"]) {
            url += "&api_key=" + root.apiKeys["gelbooru"]
            url += "&user_id=" + root.apiKeys["gelbooru_user_id"]
        }

        const xhr = new XMLHttpRequest()
        root.currentTagRequest = xhr
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (root.currentTagRequest === xhr)
                root.currentTagRequest = null
            if (root.shuttingDown)
                return
            if (xhr.status !== 200) {
                console.log("[Booru] Tag request failed with status: " + xhr.status)
                return
            }
            try {
                const response = JSON.parse(xhr.responseText)
                root.tagSuggestion(query, root._mapTagResponse(providerId, response))
            } catch (error) {
                console.log("[Booru] Failed to parse tag response: " + error)
            }
        }

        try {
            if (providerId === "danbooru") {
                xhr.setRequestHeader("User-Agent", "Quickshell-Booru/1.0")
            } else if (providerId === "konachan") {
                xhr.setRequestHeader("User-Agent", root.defaultUserAgent)
            }
            xhr.send()
        } catch (error) {
            if (root.currentTagRequest === xhr)
                root.currentTagRequest = null
            console.log("Could not send Booru tag request:", error)
        }
    }

    function shutdown() {
        if (root.shuttingDown)
            return
        root.shuttingDown = true

        if (root.currentTagRequest) {
            try {
                root.currentTagRequest.onreadystatechange = null
                root.currentTagRequest.abort()
            } catch (error) {
                console.warn("[Booru] Failed to abort tag request during shutdown:", error)
            }
            root.currentTagRequest = null
        }

        const requests = Array.from(root.activeRequests)
        root.activeRequests = []
        requests.forEach(xhr => {
            try {
                xhr.onreadystatechange = null
                xhr.abort()
            } catch (error) {
                console.warn("[Booru] Failed to abort request during shutdown:", error)
            }
        })

        root.runningRequests = 0
        // Response objects are children of the runtime and will be deleted with it.
        // Drop the public list now, but avoid scheduling child destroy() calls while
        // this parent is itself being destroyed.
        root.responses = []
    }

    Component.onDestruction: root.shutdown()
}
