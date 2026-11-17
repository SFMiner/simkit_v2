class_name SkHost
extends RefCounted
## Everything that touches the browser or the operating system, in one place, so the rest of your
## code never calls JavaScriptBridge directly. Every function is safe outside a web export:
## it either does something sensible (writes a file) or does nothing.
##
## The hosting contract it implements (found in the existing sims projects):
##   - a game inside an <iframe> tells the page it wants the keyboard back with
##     postMessage({type: 'sims:leave-game'}, location.origin)       -> leave_game()
##   - class settings arrive in the page address (?level=2)          -> query_string()
##   - the top-right 200 x 64 CSS px belongs to the host's Full screen button -> RESERVED_CSS
##   - screen-reader text goes to live regions in the HTML shell      -> announce()

# === CONSTANTS ===
const VERSION: String = "0.2.0"
const LEAVE_MESSAGE_TYPE: String = "sims:leave-game"
## Corner (CSS px) kept free of controls so the host page's Full screen button is never covered.
const RESERVED_CSS: Vector2 = Vector2(200.0, 64.0)
const ANNOUNCE_HISTORY: int = 30

# === STATIC VARIABLES ===
## Outside a web export there is no page address; set this (tests, desktop development) to simulate one.
static var query_override: String = ""
## The last things announce() was asked to say, newest last: {"text", "assertive"}. Tests read this.
static var announcements: Array[Dictionary] = []
static var leave_count: int = 0


# === PUBLIC METHODS ===
static func is_web() -> bool:
	return OS.has_feature("web")


## The page address query, "?a=1&b=2", or "" (outside the web: query_override).
static func query_string() -> String:
	if is_web():
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		if search is String:
			return search
		return ""
	return query_override


static func device_pixel_ratio() -> float:
	if is_web():
		var v: Variant = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if v is float or v is int:
			return clampf(float(v), 0.5, 6.0)
	return maxf(DisplayServer.screen_get_scale(), 0.5)


static func prefers_reduced_motion() -> bool:
	return _media("(prefers-reduced-motion: reduce)")


static func prefers_high_contrast() -> bool:
	return _media("(prefers-contrast: more)")


## Release keyboard focus and tell the host page the player wants out (Tab past the end, Escape).
## Counts the calls in `leave_count` so tests can check it. Outside an iframe nothing is sent.
static func leave_game() -> void:
	leave_count += 1
	if is_web():
		JavaScriptBridge.eval(
				"if (window.parent !== window) window.parent.postMessage({type: '%s'}, location.origin)" % LEAVE_MESSAGE_TYPE)


## Sends text to the page's live regions (the HTML shell in deploy/shell.html defines window.skAnnounce).
## `assertive` interrupts the screen reader: use it for failures and blocked actions only.
static func announce(text: String, assertive: bool = false) -> void:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return
	announcements.append({"text": clean, "assertive": assertive})
	while announcements.size() > ANNOUNCE_HISTORY:
		announcements.pop_front()
	if is_web():
		JavaScriptBridge.eval("if (window.skAnnounce) window.skAnnounce(%s, %s)" % [
				JSON.stringify(clean), "true" if assertive else "false"])


## Gives the player a text file: a browser download on the web, a file in user://exports/ elsewhere.
## Returns "" on the web (the browser decides where it goes) or the path written; returns
## "ERROR" if the file could not be written.
static func save_text_file(filename: String, text: String, mime: String = "text/plain") -> String:
	var safe: String = safe_filename(filename)
	if is_web():
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), safe, mime + ";charset=utf-8")
		return ""
	DirAccess.make_dir_recursive_absolute("user://exports")
	var path: String = "user://exports/" + safe
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "ERROR"
	file.store_string(text)
	file.close()
	return path


## Letters, digits, dot, dash and underscore only: a file name can never become a path.
static func safe_filename(name: String) -> String:
	var out: String = ""
	for i: int in range(name.length()):
		var c: String = name[i]
		var ok: bool = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") \
				or c == "." or c == "-" or c == "_"
		out += c if ok else "_"
	if out.is_empty() or out.begins_with("."):
		out = "file" + out
	return out.substr(0, 96)


static func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## On the web this must be called from a click or key press (a browser rule).
static func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen()
			else DisplayServer.WINDOW_MODE_FULLSCREEN)


# === PRIVATE METHODS ===
static func _media(query: String) -> bool:
	if not is_web():
		return false
	var v: Variant = JavaScriptBridge.eval(
			"(window.matchMedia && window.matchMedia('%s').matches) ? 1 : 0" % query, true)
	return (v is float or v is int) and int(v) == 1
