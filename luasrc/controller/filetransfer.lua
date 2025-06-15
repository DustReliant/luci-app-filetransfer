module("luci.controller.filetransfer", package.seeall)

-- 在控制器或页面的头部加载翻译
local translate = require "luci.i18n".translate
local sys = require "luci.sys"
local http = require "luci.http"
local util = require "luci.util"
local fs = require "nixio.fs"
local json = require "luci.jsonc"

-- CSRF Token 存储路径
local csrf_token_file = "/tmp/csrf_token.txt"
local log_file = "/tmp/filetransfer.log"  -- 日志文件路径

-- 配置常量
local UPLOAD_DIR = "/tmp/upload/"
local MAX_FILE_SIZE = 50 * 1024 * 1024  -- 50MB
local ALLOWED_EXTENSIONS = {
    ipk = true,
    tar = true,
    gz = true,
    zip = true,
    txt = true,
    conf = true,
    json = true
}

-- 记录日志到文件的函数
function log_to_file(message)
    local log_file = "/tmp/filetransfer.log"
    local file = io.open(log_file, "a")
    if file then
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
        file:close()
    end
end

-- 检查 CSRF Token
local function check_csrf()
    -- 首先尝试使用系统自带的 CSRF 验证
    if luci.csrf and luci.csrf.check_token then
        return luci.csrf.check_token()
    end
    
    -- 如果系统没有 CSRF 验证，使用自定义实现
    local token = http.getcookie("csrf_token")
    local form_token = http.formvalue("csrf_token")
    
    if not token or not form_token or token ~= form_token then
        return false
    end
    
    return true
end

-- 生成 CSRF Token
local function generate_csrf_token()
    local token = util.urandom(32)
    http.setcookie("csrf_token", token)
    return token
end

-- 检查文件类型
local function check_file_type(filename)
    local ext = filename:match("%.([^%.]+)$")
    return ext and ALLOWED_EXTENSIONS[ext:lower()]
end

-- 检查文件大小
local function check_file_size(size)
    return size and size <= MAX_FILE_SIZE
end

-- 安全地获取文件名
local function sanitize_filename(filename)
    filename = filename:match("([^/\\]+)$")
    filename = filename:gsub("[^%w%.%-_]", "")
    return filename
end

-- 确保上传目录存在并有正确的权限
local function ensure_upload_dir()
    if not fs.stat(UPLOAD_DIR) then
        fs.mkdir(UPLOAD_DIR)
    end
    fs.chmod(UPLOAD_DIR, 755)
end

-- 设置 CSRF 令牌
function index()
    -- 主入口页面
    entry({"admin", "system", "filetransfer"}, firstchild(), _("文件传输"), 89).dependent = false
    
    -- 文件传输主页面
    entry({"admin", "system", "filetransfer", "main"}, template("filetransfer/main"), _("文件传输"), 1)
    
    -- 文件管理页面
    entry({"admin", "system", "filetransfer", "manage"}, template("filetransfer/manage"), _("文件管理"), 2)
    
    -- 操作日志页面
    entry({"admin", "system", "filetransfer", "log"}, template("filetransfer/log"), _("操作日志"), 3)
    
    -- 设置页面
    entry({"admin", "system", "filetransfer", "settings"}, cbi("filetransfer/settings"), _("设置"), 4)

    -- API 接口
    -- 文件上传相关
    entry({"admin", "system", "filetransfer", "upload"}, call("action_upload")).leaf = true
    entry({"admin", "system", "filetransfer", "upload_progress"}, call("action_upload_progress")).leaf = true
    
    -- 文件下载相关
    entry({"admin", "system", "filetransfer", "download"}, call("action_download")).leaf = true
    entry({"admin", "system", "filetransfer", "download_progress"}, call("action_download_progress")).leaf = true
    
    -- 文件管理相关
    entry({"admin", "system", "filetransfer", "list"}, call("action_list")).leaf = true
    entry({"admin", "system", "filetransfer", "delete"}, call("action_delete")).leaf = true
    entry({"admin", "system", "filetransfer", "preview"}, call("action_preview")).leaf = true
    entry({"admin", "system", "filetransfer", "install_ipk"}, call("action_install_ipk")).leaf = true
    
    -- 日志相关
    entry({"admin", "system", "filetransfer", "get_logs"}, call("action_get_logs")).leaf = true
    entry({"admin", "system", "filetransfer", "clear_logs"}, call("action_clear_logs")).leaf = true
    entry({"admin", "system", "filetransfer", "export_logs"}, call("action_export_logs")).leaf = true
    
    -- 设置相关
    entry({"admin", "system", "filetransfer", "save_settings"}, call("action_save_settings")).leaf = true
    entry({"admin", "system", "filetransfer", "get_settings"}, call("action_get_settings")).leaf = true
end

function action_start()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
			startlog = startlog();
	})
end


function action_refresh_log()
    luci.http.prepare_content("application/json")

    -- 确保文件存在
    local create_file = luci.sys.exec("touch /tmp/filetransfer.log")
    local logfile = "/tmp/filetransfer.log"

    -- 调试代码：检查日志文件写入
    local output = luci.sys.exec("echo Hello world！ > /tmp/filetransfer.log")
    log_to_file("Command output: " .. output)

    local file = io.open(logfile, "r+")
    local info, len, line, lens, cache, ex_match, line_trans
    local data = ""
    local limit = 1000
    local log_tb = {}
    local log_len = tonumber(luci.http.formvalue("log_len")) or 0
    if file == nil then
        return nil
    end
    file:seek("set")
    info = file:read("*all")
    info = info:reverse()
    file:close()

    cache, len = string.gsub(info, '[^\n]+', "")
    if len == log_len then return nil end
    if log_len == 0 then
        if len > limit then lens = limit else lens = len end
    else
        lens = len - log_len
    end

    string.gsub(info, '[^\n]+', function(w) table.insert(log_tb, w) end, lens)
    for i = 1, lens do
        line = log_tb[i]:reverse()
        line_trans = line
        ex_match = false
        core_match = false
        time_format = false
        while true do
            ex_keys = {"UDP%-Receive%-Buffer%-Size", "^Sec%-Fetch%-Mode", "^User%-Agent", "^Access%-Control", "^Accept", "^Origin", "^Referer", "^Connection", "^Pragma", "^Cache-"}
            for key = 1, #ex_keys do
                if string.find(line, ex_keys[key]) then
                    ex_match = true
                    break
                end
            end
            if ex_match then break end

            core_keys = {" DBG ", " INF ", "level=", " WRN ", " ERR ", " FTL "}
            for key = 1, #core_keys do
                if string.find(string.sub(line, 0, 13), core_keys[key]) or (string.find(line, core_keys[key]) and core_keys[key] == "level=") then
                    core_match = true
                    if core_keys[key] ~= "level=" then
                        time_format = true
                    end
                    break
                end
            end
            if time_format then
                if string.match(string.sub(line, 0, 8), "%d%d:%d%d:%d%d") then
                    line_trans = '"' .. os.date("%Y-%m-%d %H:%M:%S", tonumber(string.sub(line, 0, 8))) .. '"' .. string.sub(line, 9, -1)
                end
            end
            if not core_match then
                if not string.find(line, "【") or not string.find(line, "】") then
                    line_trans = trans_line_nolabel(line)
                else
                    line_trans = trans_line(line)
                end
            end
            if data == "" then
                data = line_trans
            elseif log_len == 0 and i == limit then
                data = data .. "\n" .. line_trans .. "\n..."
            else
                data = data .. "\n" .. line_trans
            end
            break
        end
    end

    luci.http.write_json({
        len = len,
        log = data;
    })
end


function action_del_log()
	luci.sys.exec(": > /tmp/filetransfer.log")
	return
end

function action_del_start_log()
	luci.sys.exec(": > /tmp/filetransfer_start.log")
	return
end

function action_log_level()
	local level, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		if not daip or not cn_port then return end
		info = json.parse(luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs', dase, daip, cn_port)))
		if info then
			level = info["log-level"]
		else
			level = uci:get("filetransfer", "config", "log_level") or "info"
		end
	else
		level = uci:get("filetransfer", "config", "log_level") or "info"
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		log_level = level;
	})
end

function action_switch_log()
	local level, info
	if is_running() then
		local daip = daip()
		local dase = dase() or ""
		local cn_port = cn_port()
		level = luci.http.formvalue("log_level")
		if not daip or not cn_port then luci.http.status(500, "Switch Faild") return end
		info = luci.sys.exec(string.format('curl -sL -m 3 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"log-level\": \"%s\"}\'', dase, daip, cn_port, level))
		if info ~= "" then
			luci.http.status(500, "Switch Faild")
		end
	else
		luci.http.status(500, "Switch Faild")
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		info = info;
	})
end

-- 文件上传处理函数
function action_upload()
    ensure_upload_dir()
    
    local file = http.formvalue("file")
    local filename = http.formvalue("filename")
    
    if not file or not filename then
        http.status(400, "Bad Request")
        return
    end
    
    filename = sanitize_filename(filename)
    if not filename then
        http.status(400, "Invalid filename")
        return
    end
    
    if not check_file_type(filename) then
        http.status(400, "File type not allowed")
        return
    end
    
    if not check_file_size(file:len()) then
        http.status(413, "File too large")
        return
    end
    
    local f = io.open(UPLOAD_DIR .. filename, "w")
    if f then
        f:write(file)
        f:close()
        log_to_file("File uploaded: " .. filename)
        http.write_json({status = "success", path = UPLOAD_DIR .. filename})
    else
        http.status(500, "Failed to save file")
    end
end

-- 文件下载处理函数
function action_download()
    local filename = http.formvalue("filename")
    if not filename then
        http.status(400, "Bad Request")
        return
    end
    
    filename = sanitize_filename(filename)
    if not filename then
        http.status(400, "Invalid filename")
        return
    end
    
    local path = UPLOAD_DIR .. filename
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

-- 文件列表获取函数
function action_list()
    local files = {}
    local dir = io.popen("ls -l " .. UPLOAD_DIR)
    if dir then
        for line in dir:lines() do
            local file = {}
            file.name = line:match("[^%s]+$")
            file.size = line:match("(%d+)")
            file.date = line:match("%w+%s+%d+%s+%d+:%d+")
            if file.name and file.name ~= "." and file.name ~= ".." then
                table.insert(files, file)
            end
        end
        dir:close()
    end
    
    http.write_json(files)
end

-- 文件删除函数
function action_delete()
    local filename = http.formvalue("filename")
    if not filename then
        http.status(400, "Bad Request")
        return
    end
    
    filename = sanitize_filename(filename)
    if not filename then
        http.status(400, "Invalid filename")
        return
    end
    
    local path = UPLOAD_DIR .. filename
    if not fs.stat(path) then
        http.status(404, "File not found")
        return
    end
    
    if fs.unlink(path) then
        log_to_file("File deleted: " .. filename)
        http.write_json({status = "success"})
    else
        http.status(500, "Failed to delete file")
    end
end

-- 安装 IPK 文件
function action_install_ipk()
    -- 检查 CSRF Token
    if not check_csrf() then
        http.status(403, "CSRF token validation failed")
        return
    end
    
    local filename = http.formvalue("filename")
    if not filename then
        http.status(400, "Bad Request")
        return
    end
    
    -- 安全处理文件名
    filename = sanitize_filename(filename)
    if not filename then
        http.status(400, "Invalid filename")
        return
    end
    
    if not filename:match("%.ipk$") then
        http.status(400, "Not an IPK file")
        return
    end
    
    local path = UPLOAD_DIR .. filename
    if not fs.stat(path) then
        http.status(404, "File not found")
        return
    end
    
    -- 安装 IPK
    local result = sys.exec("opkg install " .. path)
    if result:match("^Installing") then
        log_to_file("IPK installed: " .. filename)
        http.write_json({status = "success", message = result})
    else
        http.status(500, "Failed to install IPK: " .. result)
    end
end

-- 获取日志函数
function action_get_logs()
    local logs = {}
    local log_file = "/tmp/filetransfer.log"
    local file = io.open(log_file, "r")
    if file then
        for line in file:lines() do
            table.insert(logs, line)
        end
        file:close()
    end
    http.write_json(logs)
end

-- 清除日志函数
function action_clear_logs()
    local log_file = "/tmp/filetransfer.log"
    local file = io.open(log_file, "w")
    if file then
        file:write("")
        file:close()
        http.write_json({status = "success"})
    else
        http.status(500, "Failed to clear logs")
    end
end