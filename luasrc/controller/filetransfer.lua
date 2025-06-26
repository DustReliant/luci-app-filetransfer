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
    entry({"admin", "system", "filetransfer", "clear_all"}, call("action_clear_all")).leaf = true
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
    local dir = io.popen("ls -la '" .. UPLOAD_DIR .. "'")
    if dir then
        for line in dir:lines() do
            local file = {}
            local parts = {}
            for part in line:gmatch("%S+") do
                table.insert(parts, part)
            end
            if #parts >= 9 then
                file.name = parts[9] or ""
                file.size = parts[5] or "0"
                file.date = parts[6] .. " " .. parts[7] .. " " .. parts[8]
                file.mtime = os.time()
                if file.name ~= "" and file.name ~= "." and file.name ~= ".." then
                    table.insert(files, file)
                end
            end
        end
        dir:close()
    end
    http.write_json({files = files})
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

-- 清空所有文件函数
function action_clear_all()
    ensure_upload_dir()
    
    local success_count = 0
    local error_count = 0
    local dir = io.popen("ls -1 '" .. UPLOAD_DIR .. "'")
    
    if dir then
        for filename in dir:lines() do
            if filename ~= "" and filename ~= "." and filename ~= ".." then
                local path = UPLOAD_DIR .. filename
                if fs.unlink(path) then
                    success_count = success_count + 1
                else
                    error_count = error_count + 1
                end
            end
        end
        dir:close()
    end
    
    if success_count > 0 then
        log_to_file("Cleared " .. success_count .. " files from upload directory")
    end
    
    if error_count > 0 then
        log_to_file("Failed to delete " .. error_count .. " files")
    end
    
    http.write_json({
        status = "success", 
        message = "Cleared " .. success_count .. " files",
        success_count = success_count,
        error_count = error_count
    })
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
        log_to_file("Logs cleared by user")
        http.write_json({status = "success"})
    else
        http.status(500, "Failed to clear logs")
    end
end

-- 导出日志函数
function action_export_logs()
    local log_file = "/tmp/filetransfer.log"
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

-- 保存设置函数
function action_save_settings()
    local uci = require "luci.model.uci".cursor()
    local settings = http.formvalue()
    
    for key, value in pairs(settings) do
        if key ~= "token" then
            uci:set("filetransfer", "config", key, value)
        end
    end
    
    uci:commit("filetransfer")
    log_to_file("Settings saved")
    http.write_json({status = "success"})
end

-- 获取设置函数
function action_get_settings()
    local uci = require "luci.model.uci".cursor()
    local settings = {}
    
    settings.upload_dir = uci:get("filetransfer", "config", "upload_dir") or "/tmp/upload/"
    settings.max_file_size = uci:get("filetransfer", "config", "max_file_size") or "50"
    settings.allowed_extensions = uci:get("filetransfer", "config", "allowed_extensions") or "ipk,tar,gz,zip,txt,conf,json"
    settings.log_level = uci:get("filetransfer", "config", "log_level") or "info"
    settings.log_retention = uci:get("filetransfer", "config", "log_retention") or "7"
    settings.auto_clean = uci:get("filetransfer", "config", "auto_clean") or "1"
    settings.enable_csrf = uci:get("filetransfer", "config", "enable_csrf") or "1"
    settings.enable_ssl = uci:get("filetransfer", "config", "enable_ssl") or "0"
    settings.allowed_ips = uci:get("filetransfer", "config", "allowed_ips") or ""
    
    http.write_json(settings)
end

-- 上传进度函数
function action_upload_progress()
    -- 实现上传进度跟踪
    http.write_json({progress = 0})
end

-- 下载进度函数
function action_download_progress()
    -- 实现下载进度跟踪
    http.write_json({progress = 0})
end

-- 文件预览函数
function action_preview()
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
    
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        http.write_json({content = content})
    else
        http.status(500, "Failed to read file")
    end
end