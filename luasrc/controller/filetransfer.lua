-- LuCI File Transfer Controller
-- Copyright 2024 DustReliant
-- Licensed to the public under the MIT License.

module("luci.controller.filetransfer", package.seeall)

local translate = require "luci.i18n".translate
local sys = require "luci.sys"
local http = require "luci.http"
local fs = require "nixio.fs"

-- JSON 编解码:优先 jsonc 绑定,回退纯 Lua 实现
local has_jsonc, json = pcall(require, "luci.jsonc")
if not has_jsonc then
	json = require "luci.json"
end

local log_file = "/tmp/filetransfer.log"

-- 与 /etc/config/filetransfer 保持一致的默认值
local DEFAULTS = {
	UPLOAD_DIR = "/tmp/upload/",
	MAX_FILE_SIZE = 100 * 1024 * 1024, -- 100MB
	LOG_LEVEL = "info",
	ENABLE_CSRF = true,
	ALLOWED_IPS = "",
	ALLOWED_EXTENSIONS = "ipk,tar,gz,zip,txt,conf,json,bin,img,sig,deb,rpm",
}

-- 请求级配置缓存(避免每次读日志/检查都重新解析 UCI)
local cached_config

local function get_config()
	if cached_config then
		return cached_config
	end

	local config = {
		UPLOAD_DIR = DEFAULTS.UPLOAD_DIR,
		MAX_FILE_SIZE = DEFAULTS.MAX_FILE_SIZE,
		LOG_LEVEL = DEFAULTS.LOG_LEVEL,
		ENABLE_CSRF = DEFAULTS.ENABLE_CSRF,
		ALLOWED_IPS = DEFAULTS.ALLOWED_IPS,
		ALLOWED_EXTENSIONS = {},
	}

	local ok, uci = pcall(require, "luci.model.uci")
	if ok and uci then
		uci = uci.cursor()
		config.UPLOAD_DIR = uci:get("filetransfer", "config", "upload_dir") or config.UPLOAD_DIR
		config.MAX_FILE_SIZE = (tonumber(uci:get("filetransfer", "config", "max_file_size")) or 100) * 1024 * 1024
		config.LOG_LEVEL = uci:get("filetransfer", "config", "log_level") or config.LOG_LEVEL
		config.ENABLE_CSRF = uci:get("filetransfer", "config", "enable_csrf") ~= "0"
		config.ALLOWED_IPS = uci:get("filetransfer", "config", "allowed_ips") or ""

		local extensions_str = uci:get("filetransfer", "config", "allowed_extensions") or DEFAULTS.ALLOWED_EXTENSIONS
		for ext in extensions_str:gmatch("[^,%s]+") do
			config.ALLOWED_EXTENSIONS[ext:lower()] = true
		end
	end

	cached_config = config
	return config
end

-- 结构化日志
local log_levels = {debug = 1, info = 2, warning = 3, error = 4}

local function log_message(level, message, context)
	local config = get_config()
	local current_level = log_levels[config.LOG_LEVEL] or 2
	if (log_levels[level] or 2) < current_level then
		return
	end

	local file = io.open(log_file, "a")
	if file then
		local log_line = string.format("[%s] %s: %s",
			os.date("%Y-%m-%d %H:%M:%S"), level:upper(), message)

		if context and next(context) then
			log_line = log_line .. " | " .. table.concat(context, ", ")
		end

		file:write(log_line .. "\n")
		file:close()
	end
end

function log_to_file(message)
	log_message("info", message)
end

-- 统一 JSON 响应
local function send_error_response(status_code, error_code, message, details)
	http.status(status_code, message)
	http.prepare_content("application/json")
	http.write_json({
		status = "error",
		error = true,
		code = error_code,
		message = message,
		details = details or {},
		timestamp = os.time()
	})
	log_message("error", message, {error_code, tostring(details)})
end

local function send_success_response(data, message)
	http.prepare_content("application/json")
	http.write_json({
		status = "success",
		success = true,
		message = message or "Operation completed successfully",
		data = data or {},
		timestamp = os.time()
	})
end

-- shell 参数转义,防止命令注入
local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- IP 白名单
local function check_ip_whitelist()
	local config = get_config()
	if not config.ALLOWED_IPS or config.ALLOWED_IPS == "" then
		return true
	end

	local client_ip = http.getenv("REMOTE_ADDR") or ""
	for ip in config.ALLOWED_IPS:gmatch("[^,%s]+") do
		if client_ip == ip then
			return true
		end
	end

	log_message("warning", "IP address not in whitelist", {client_ip})
	return false
end

-- CSRF 校验:优先使用 LuCI 平台令牌(模板中的 <%=token%>),
-- 无法获取平台令牌时回退为双重提交 Cookie 校验
local function check_csrf()
	local config = get_config()
	if not config.ENABLE_CSRF then
		return true
	end

	if http.getenv("REQUEST_METHOD") == "GET" then
		return true
	end

	local ok, dispatcher = pcall(require, "luci.dispatcher")
	if ok and dispatcher and dispatcher.context
		and type(dispatcher.context.authtoken) == "string" then
		return http.formvalue("token") == dispatcher.context.authtoken
	end

	local token_cookie = http.getcookie("csrf_token")
	local token_submitted = http.getenv("HTTP_X_CSRF_TOKEN") or http.formvalue("csrf_token")

	if not token_cookie or not token_submitted or token_cookie ~= token_submitted then
		log_message("warning", "CSRF token validation failed", {
			"cookie=" .. tostring(token_cookie),
			"submitted=" .. tostring(token_submitted)
		})
		return false
	end

	return true
end

-- 文件名安全化:仅保留最后一段,剔除危险字符
local function sanitize_filename(filename)
	if type(filename) ~= "string" then
		return nil
	end

	local name = filename:match("([^/\\]+)$")
	if not name then
		return nil
	end

	name = name:gsub("[/\\<>:\"|?*%c]", "")

	if name == "" or name:match("^%.+$") then
		return nil
	end

	return name
end

local function check_file_type(filename)
	local config = get_config()
	local ext = filename:match("%.([^%.]+)$")
	if not ext then
		return false
	end
	return config.ALLOWED_EXTENSIONS[ext:lower()] == true
end

local function ensure_upload_dir()
	local config = get_config()
	if not fs.stat(config.UPLOAD_DIR) then
		fs.mkdirr(config.UPLOAD_DIR)
	end
end

-- 路径规范化:折叠重复分隔符、消除 ./ 与 ../
local function normalize_path(path)
	path = path:gsub("\\", "/")
	path = path:gsub("//+", "/")
	while true do
		local new = path:gsub("/[^/]+/%.%.(/?)", "/%1")
		if new == path then break end
		path = new
	end
	if path == "" then path = "/" end
	return path
end

function index()
	entry({"admin", "system", "filetransfer"}, firstchild(), translate("文件传输"), 89).dependent = false

	entry({"admin", "system", "filetransfer", "main"}, template("filetransfer/main"), translate("文件传输"), 1)
	entry({"admin", "system", "filetransfer", "manage"}, template("filetransfer/manage"), translate("文件管理"), 2)
	entry({"admin", "system", "filetransfer", "log"}, template("filetransfer/log"), translate("操作日志"), 3)
	entry({"admin", "system", "filetransfer", "settings"}, cbi("filetransfer"), translate("设置"), 4)

	-- 文件上传/下载
	entry({"admin", "system", "filetransfer", "upload"}, call("action_upload")).leaf = true
	entry({"admin", "system", "filetransfer", "upload_progress"}, call("action_upload_progress")).leaf = true
	entry({"admin", "system", "filetransfer", "download"}, call("action_download")).leaf = true
	entry({"admin", "system", "filetransfer", "download_progress"}, call("action_download_progress")).leaf = true

	-- 文件管理
	entry({"admin", "system", "filetransfer", "list"}, call("action_list")).leaf = true
	entry({"admin", "system", "filetransfer", "delete"}, call("action_delete")).leaf = true
	entry({"admin", "system", "filetransfer", "clear_all"}, call("action_clear_all")).leaf = true
	entry({"admin", "system", "filetransfer", "preview"}, call("action_preview")).leaf = true
	entry({"admin", "system", "filetransfer", "install_ipk"}, call("action_install_ipk")).leaf = true
	entry({"admin", "system", "filetransfer", "browse_files"}, call("action_browse_files")).leaf = true

	-- 日志
	entry({"admin", "system", "filetransfer", "get_logs"}, call("action_get_logs")).leaf = true
	entry({"admin", "system", "filetransfer", "clear_logs"}, call("action_clear_logs")).leaf = true
	entry({"admin", "system", "filetransfer", "export_logs"}, call("action_export_logs")).leaf = true

	-- 设置
	entry({"admin", "system", "filetransfer", "save_settings"}, call("action_save_settings")).leaf = true
	entry({"admin", "system", "filetransfer", "get_settings"}, call("action_get_settings")).leaf = true

	-- 前端错误上报
	entry({"admin", "system", "filetransfer", "log_error"}, call("action_log_error")).leaf = true
end

-- 文件上传
function action_upload()
	log_message("info", "开始处理文件上传请求", {
		"method=" .. (http.getenv("REQUEST_METHOD") or "unknown"),
		"content_length=" .. (http.getenv("CONTENT_LENGTH") or "unknown")
	})

	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	if not check_ip_whitelist() then
		send_error_response(403, "IP_BLOCKED", "IP address not in whitelist")
		return
	end

	ensure_upload_dir()

	local config = get_config()
	local upload    -- 进行中的上传状态;rejected 字段标记被拒绝的原因
	local result    -- 上传成功的结果

	http.setfilehandler(function(meta, chunk, eof)
		if not upload then
			local filename = meta.file or meta.name
			if not filename then
				upload = {rejected = "MISSING_FILENAME"}
				return
			end

			filename = sanitize_filename(filename)
			if not filename then
				upload = {rejected = "INVALID_FILENAME"}
				return
			end

			if not check_file_type(filename) then
				upload = {rejected = "INVALID_FILE_TYPE", filename = filename}
				return
			end

			local filepath = config.UPLOAD_DIR .. filename
			local file_handle = io.open(filepath, "wb")
			if not file_handle then
				upload = {rejected = "CREATE_FAILED", filename = filename}
				return
			end

			upload = {
				handle = file_handle,
				filename = filename,
				filepath = filepath,
				size = 0
			}
			log_to_file("开始上传文件: " .. filename)
		end

		-- 已被拒绝的上传:忽略后续数据
		if upload.rejected then
			return
		end

		if chunk then
			upload.handle:write(chunk)
			upload.size = upload.size + #chunk

			if upload.size > config.MAX_FILE_SIZE then
				upload.handle:close()
				fs.unlink(upload.filepath)
				log_to_file("文件过大,上传终止: " .. upload.filename)
				upload = {rejected = "FILE_TOO_LARGE", filename = upload.filename}
				return
			end
		end

		if eof then
			upload.handle:close()
			log_to_file("文件上传完成: " .. upload.filename .. ", 大小: " .. upload.size)
			result = {
				filename = upload.filename,
				filepath = upload.filepath,
				size = upload.size
			}
		end
	end)

	-- 触发表单解析,驱动 setfilehandler 回调
	http.formvalue()

	if result then
		http.prepare_content("application/json")
		http.write_json({
			status = "success",
			filename = result.filename,
			path = result.filepath,
			size = result.size
		})
	else
		local reason = upload and upload.rejected or "NO_FILE_DATA"
		local messages = {
			MISSING_FILENAME = "No file name provided",
			INVALID_FILENAME = "Invalid file name",
			INVALID_FILE_TYPE = "File type not allowed",
			CREATE_FAILED = "Failed to create file on target",
			FILE_TOO_LARGE = "File exceeds the configured size limit",
			NO_FILE_DATA = "No file uploaded"
		}
		local code = (reason == "FILE_TOO_LARGE") and 413 or 400
		send_error_response(code, reason, messages[reason] or "Upload failed")
	end
end

-- 文件下载(仅限上传目录内的文件)
function action_download()
	local filename = sanitize_filename(http.formvalue("filename"))
	if not filename then
		send_error_response(400, "INVALID_FILENAME", "Invalid filename")
		return
	end

	local config = get_config()
	local path = config.UPLOAD_DIR .. filename
	if not fs.stat(path) then
		http.status(404, "File not found")
		return
	end

	http.header("Content-Disposition", "attachment; filename=" .. filename)
	http.header("Content-Type", "application/octet-stream")

	local f = io.open(path, "r")
	if f then
		http.write(f:read("*all"))
		f:close()
		log_to_file("File downloaded: " .. filename)
	else
		http.status(500, "Failed to read file")
	end
end

-- 上传目录文件列表(直接用 nixio.fs,避免 shell 开销)
function action_list()
	local config = get_config()
	local files = {}

	local iter, err = fs.dir(config.UPLOAD_DIR)
	if iter then
		for name in iter do
			local stat = fs.stat(config.UPLOAD_DIR .. name)
			if stat and stat.type == "reg" then
				table.insert(files, {
					name = name,
					size = tostring(stat.size),
					date = os.date("%m-%d %H:%M", stat.mtime),
					mtime = stat.mtime
				})
			end
		end
	else
		send_error_response(500, "LIST_FAILED", "Failed to read upload directory", tostring(err))
		return
	end

	send_success_response({files = files}, "File list retrieved successfully")
end

function action_delete()
	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	local filename = sanitize_filename(http.formvalue("filename"))
	if not filename then
		send_error_response(400, "INVALID_FILENAME", "Invalid filename")
		return
	end

	local config = get_config()
	local path = config.UPLOAD_DIR .. filename
	if not fs.stat(path) then
		send_error_response(404, "FILE_NOT_FOUND", "File not found: " .. filename)
		return
	end

	if fs.unlink(path) then
		log_message("info", "File deleted", {filename})
		send_success_response({filename = filename}, "File deleted successfully")
	else
		send_error_response(500, "DELETE_FAILED", "Failed to delete file: " .. filename)
	end
end

function action_clear_all()
	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	local config = get_config()
	ensure_upload_dir()

	local success_count, error_count = 0, 0

	for name in fs.dir(config.UPLOAD_DIR) do
		local stat = fs.stat(config.UPLOAD_DIR .. name)
		if stat and stat.type == "reg" then
			if fs.unlink(config.UPLOAD_DIR .. name) then
				success_count = success_count + 1
			else
				error_count = error_count + 1
			end
		end
	end

	local message = string.format("Cleared %d files", success_count)
	if error_count > 0 then
		message = message .. string.format(", failed to delete %d files", error_count)
	end

	log_message(error_count > 0 and "warning" or "info", "Clear all files", {
		"success=" .. success_count, "errors=" .. error_count
	})

	send_success_response({
		success_count = success_count,
		error_count = error_count
	}, message)
end

function action_install_ipk()
	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	if not check_ip_whitelist() then
		send_error_response(403, "IP_BLOCKED", "IP address not in whitelist")
		return
	end

	local filename = sanitize_filename(http.formvalue("filename"))
	if not filename then
		send_error_response(400, "INVALID_FILENAME", "Invalid filename")
		return
	end

	if not filename:lower():match("%.ipk$") then
		send_error_response(400, "INVALID_FILE_TYPE", "File must be an IPK package")
		return
	end

	local config = get_config()
	local path = config.UPLOAD_DIR .. filename
	if not fs.stat(path) then
		send_error_response(404, "FILE_NOT_FOUND", "IPK file not found: " .. filename)
		return
	end

	log_message("info", "Installing IPK package", {filename})
	local result = sys.exec("opkg install " .. shell_quote(path) .. " 2>&1")

	if result:match("Installing") or result:match("Upgrading") or result:match("Configuring") then
		log_message("info", "IPK installed successfully", {filename})
		send_success_response({filename = filename, output = result}, "IPK package installed successfully")
	else
		log_message("error", "IPK installation failed", {filename, result})
		send_error_response(500, "INSTALL_FAILED", "Failed to install IPK package", result)
	end
end

function action_get_logs()
	local logs = {}
	local file = io.open(log_file, "r")
	if file then
		for line in file:lines() do
			table.insert(logs, line)
		end
		file:close()
	end
	http.prepare_content("application/json")
	http.write_json(logs)
end

function action_clear_logs()
	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	local file = io.open(log_file, "w")
	if file then
		file:close()
		log_to_file("Logs cleared by user")
		http.prepare_content("application/json")
		http.write_json({status = "success"})
	else
		http.status(500, "Failed to clear logs")
	end
end

function action_export_logs()
	local file = io.open(log_file, "r")
	if file then
		local content = file:read("*all")
		file:close()

		http.header("Content-Disposition", "attachment; filename=filetransfer_logs_" .. os.date("%Y%m%d") .. ".txt")
		http.header("Content-Type", "text/plain")
		http.write(content)
	else
		http.status(404, "Log file not found")
	end
end

-- 允许写入 UCI 的设置项白名单
local setting_keys = {
	upload_dir = true,
	max_file_size = true,
	allowed_extensions = true,
	max_upload_sessions = true,
	session_timeout = true,
	log_level = true,
	log_retention = true,
	auto_clean = true,
	enable_csrf = true,
	enable_ssl = true,
	enable_file_validation = true,
	allowed_ips = true,
}

function action_save_settings()
	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	local ok, uci = pcall(require, "luci.model.uci")
	if not ok or not uci then
		send_error_response(500, "UCI_FAILED", "UCI backend unavailable")
		return
	end

	uci = uci.cursor()
	local settings = http.formvalue()

	for key, value in pairs(settings) do
		if setting_keys[key] and type(value) ~= "table" then
			uci:set("filetransfer", "config", key, tostring(value))
		end
	end

	uci:commit("filetransfer")
	cached_config = nil  -- 使配置缓存失效

	log_to_file("Settings saved")
	http.prepare_content("application/json")
	http.write_json({status = "success"})
end

function action_get_settings()
	local ok, uci = pcall(require, "luci.model.uci")
	local settings = {}

	if ok and uci then
		uci = uci.cursor()
		for key in pairs(setting_keys) do
			settings[key] = uci:get("filetransfer", "config", key) or ""
		end
	end

	http.prepare_content("application/json")
	http.write_json(settings)
end

function action_upload_progress()
	http.prepare_content("application/json")
	http.write_json({progress = 0})
end

function action_download_progress()
	http.prepare_content("application/json")
	http.write_json({progress = 0})
end

function action_preview()
	local filename = sanitize_filename(http.formvalue("filename"))
	if not filename then
		http.status(400, "Invalid filename")
		return
	end

	local config = get_config()
	local path = config.UPLOAD_DIR .. filename
	if not fs.stat(path) then
		http.status(404, "File not found")
		return
	end

	local f = io.open(path, "r")
	if f then
		local content = f:read("*all")
		f:close()
		http.prepare_content("application/json")
		http.write_json({content = content})
	else
		http.status(500, "Failed to read file")
	end
end

-- 系统文件浏览(仅管理员,经 LuCI 会话鉴权)
function action_browse_files()
	local path = normalize_path(http.formvalue("path") or "/")
	local show_hidden = http.formvalue("show_hidden") == "true"
	local sort_by = http.formvalue("sort_by") or "name"

	local files = {}

	local parent = path:gsub("([^/]+)$", "")
	parent = (parent == "" or parent == "/") and "/" or parent:gsub("/$", "")
	table.insert(files, {
		name = "..",
		type = "directory",
		size = 0,
		path = parent,
		mtime = 0,
		hidden = false
	})

	local iter, err = fs.dir(path)
	if iter then
		for name in iter do
			if name ~= "." and name ~= ".." then
				local file_path = (path == "/") and ("/" .. name) or (path .. "/" .. name)
				local stat = fs.stat(file_path)
				if stat and (show_hidden or name:sub(1, 1) ~= ".") then
					table.insert(files, {
						name = name,
						type = (stat.type == "dir") and "directory" or "file",
						size = tonumber(stat.size) or 0,
						path = file_path,
						mtime = stat.mtime or 0,
						modified = os.date("%Y-%m-%d %H:%M", stat.mtime or 0),
						hidden = name:sub(1, 1) == "."
					})
				end
			end
		end
	else
		send_error_response(400, "BROWSE_FAILED", "Cannot open directory: " .. path, tostring(err))
		return
	end

	if sort_by == "size" then
		table.sort(files, function(a, b)
			if a.type ~= b.type then return a.type == "directory" end
			if a.name == ".." then return true end
			if b.name == ".." then return false end
			return a.size > b.size
		end)
	elseif sort_by == "date" then
		table.sort(files, function(a, b)
			if a.type ~= b.type then return a.type == "directory" end
			if a.name == ".." then return true end
			if b.name == ".." then return false end
			return a.mtime > b.mtime
		end)
	else
		table.sort(files, function(a, b)
			if a.type ~= b.type then return a.type == "directory" end
			if a.name == ".." then return true end
			if b.name == ".." then return false end
			return a.name:lower() < b.name:lower()
		end)
	end

	log_to_file("浏览文件夹: " .. path .. " (找到 " .. #files .. " 个项目)")

	http.prepare_content("application/json")
	http.write_json({
		status = "success",
		path = path,
		files = files,
		count = #files
	})
end

-- 前端错误上报
function action_log_error()
	if not check_csrf() then
		send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
		return
	end

	local error_type = http.formvalue("error_type") or "error"
	local error_message = http.formvalue("error_message")
	local error_details = http.formvalue("error_details")
	local error_url = http.formvalue("error_url") or "unknown"
	local error_user_agent = http.getenv("HTTP_USER_AGENT") or "unknown"
	local error_timestamp = http.formvalue("error_timestamp") or os.date("%Y-%m-%d %H:%M:%S")

	if not error_message or error_message == "" then
		http.status(400, "Bad Request")
		return
	end

	log_to_file(string.format(
		"[%s] BROWSER_ERROR: %s - %s | URL: %s | Details: %s | User-Agent: %s",
		error_timestamp, error_type, error_message, error_url,
		error_details or "none", error_user_agent))

	sys.exec(string.format("logger -t filetransfer %s %s",
		shell_quote("Browser Error: " .. error_type),
		shell_quote(error_message)))

	http.prepare_content("application/json")
	http.write_json({status = "success", message = "Error logged successfully"})
end
