module("luci.controller.filetransfer", package.seeall)

-- 在控制器或页面的头部加载翻译
local translate = require "luci.i18n".translate
local sys = require "luci.sys"
local http = require "luci.http"
local util = require "luci.util"
local fs = require "nixio.fs"
-- 使用更兼容的JSON处理方式
local json
local success, result = pcall(function()
    return require "luci.jsonc"
end)
if success then
    json = result
else
    success, result = pcall(function()
        return require "luci.json"
    end)
    if success then
        json = result
    else
        success, result = pcall(function()
            return require "cjson"
        end)
        if success then
            json = result
        end
    end
end

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

-- 配置读取函数
local function get_config()
    local config = {
        UPLOAD_DIR = "/tmp/upload/",
        MAX_FILE_SIZE = 50 * 1024 * 1024,
        LOG_LEVEL = "info",
        ENABLE_CSRF = true,
        ALLOWED_IPS = "",
        ALLOWED_EXTENSIONS = {ipk = true, tar = true, gz = true, zip = true, txt = true, conf = true, json = true}
    }
    
    -- 尝试从UCI读取配置
    local uci = require "luci.model.uci".cursor()
    if uci then
        uci:load("filetransfer")
        config.UPLOAD_DIR = uci:get("filetransfer", "config", "upload_dir") or config.UPLOAD_DIR
        config.MAX_FILE_SIZE = tonumber(uci:get("filetransfer", "config", "max_file_size") or "50") * 1024 * 1024
        config.LOG_LEVEL = uci:get("filetransfer", "config", "log_level") or config.LOG_LEVEL
        config.ENABLE_CSRF = uci:get("filetransfer", "config", "enable_csrf") ~= "0"
        config.ALLOWED_IPS = uci:get("filetransfer", "config", "allowed_ips") or ""
        
        -- 解析允许的文件扩展名
        local extensions_str = uci:get("filetransfer", "config", "allowed_extensions") or "ipk,tar,gz,zip,txt,conf,json"
        config.ALLOWED_EXTENSIONS = {}
        for ext in extensions_str:gmatch("[^,]+") do
            config.ALLOWED_EXTENSIONS[ext:gsub("%s+", "")] = true
        end
    end
    
    return config
end

-- 结构化日志记录函数
local function log_message(level, message, context)
    local config = get_config()
    local log_levels = {debug = 1, info = 2, warning = 3, error = 4}
    local current_level = log_levels[config.LOG_LEVEL] or 2
    
    if log_levels[level] >= current_level then
        local file = io.open(log_file, "a")
        if file then
            local log_entry = {
                timestamp = os.date("%Y-%m-%d %H:%M:%S"),
                level = level:upper(),
                message = message,
                context = context or {}
            }
            
            local log_line = string.format("[%s] %s: %s", 
                log_entry.timestamp, log_entry.level, log_entry.message)
            
            if next(log_entry.context) then
                log_line = log_line .. " | " .. table.concat(log_entry.context, ", ")
            end
            
            file:write(log_line .. "\n")
            file:close()
        end
    end
end

-- 兼容旧函数
function log_to_file(message)
    log_message("info", message)
end

-- 统一错误响应函数
local function send_error_response(status_code, error_code, message, details)
    http.status(status_code, message)
    local response = {
        error = true,
        code = error_code,
        message = message,
        details = details or {},
        timestamp = os.time()
    }
    
    if json then
        http.write_json(response)
    else
        http.write(string.format('{"error":true,"code":"%s","message":"%s","timestamp":%d}',
            error_code, message, response.timestamp))
    end
    
    log_message("error", message, {error_code, tostring(details)})
end

-- 统一成功响应函数
local function send_success_response(data, message)
    local response = {
        success = true,
        message = message or "Operation completed successfully",
        data = data or {},
        timestamp = os.time()
    }
    
    if json then
        http.write_json(response)
    else
        http.write('{"success":true,"message":"' .. response.message .. '","timestamp":' .. response.timestamp .. '}')
    end
end

-- IP地址白名单检查
local function check_ip_whitelist()
    local config = get_config()
    if not config.ALLOWED_IPS or config.ALLOWED_IPS == "" then
        return true
    end
    
    local client_ip = http.getenv("REMOTE_ADDR")
    for ip in config.ALLOWED_IPS:gmatch("[^,]+") do
        if client_ip == ip:gsub("%s+", "") then
            return true
        end
    end
    
    log_message("warning", "IP address not in whitelist", {client_ip})
    return false
end

-- 增强的CSRF检查
local function check_csrf()
    local config = get_config()
    if not config.ENABLE_CSRF then
        return true
    end
    
    -- 检查请求方法
    local method = http.getenv("REQUEST_METHOD")
    if method == "GET" then
        return true -- GET请求通常不需要CSRF保护
    end
    
    -- 首先尝试使用系统自带的 CSRF 验证
    if luci.csrf and luci.csrf.check_token then
        return luci.csrf.check_token()
    end
    
    -- 如果系统没有 CSRF 验证，使用自定义实现
    local token_cookie = http.getcookie("csrf_token")
    local token_header = http.getenv("HTTP_X_CSRF_TOKEN")
    local token_form = http.formvalue("csrf_token")
    
    local submitted_token = token_header or token_form
    
    if not token_cookie or not submitted_token or token_cookie ~= submitted_token then
        log_message("warning", "CSRF token validation failed", {
            "cookie=" .. tostring(token_cookie),
            "submitted=" .. tostring(submitted_token),
            "method=" .. tostring(method)
        })
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
    local config = get_config()
    local ext = filename:match("%.([^%.]+)$")
    if not ext then
        log_message("debug", "文件没有扩展名", {filename})
        return false
    end
    
    ext = ext:lower()
    if not config.ALLOWED_EXTENSIONS[ext] then
        log_message("debug", "不允许的扩展名", {ext, filename})
        return false
    end
    
    return true, ext
end

-- 检查文件大小
local function check_file_size(size)
    local config = get_config()
    return size and size <= config.MAX_FILE_SIZE
end

-- 安全地获取文件名
local function sanitize_filename(filename)
    -- 只保留最后的文件名部分
    local name = filename:match("([^/\\]+)$")
    if not name then
        log_to_file("sanitize_filename: filename无效:" .. tostring(filename))
        return nil
    end
    
    -- 移除危险字符，但保留中文字符和扩展名
    -- 只移除路径分隔符和一些特殊字符，保留其他字符包括中文
    name = name:gsub("[/\\<>:\"|?*]", "")
    
    -- 确保文件名不为空且不以点开头（除非是隐藏文件且有扩展名）
    if name == "" or name == "." or name == ".." then
        log_to_file("sanitize_filename: 文件名为空或非法:" .. name)
        return nil
    end
    
    -- 如果文件名只是一个点，也认为是无效的
    if name:match("^%.+$") then
        log_to_file("sanitize_filename: 文件名只包含点:" .. name)
        return nil
    end
    
    return name
end

-- 确保上传目录存在并有正确的权限
local function ensure_upload_dir()
    local config = get_config()
    if not fs.stat(config.UPLOAD_DIR) then
        fs.mkdirr(config.UPLOAD_DIR)
    end
    fs.chmod(config.UPLOAD_DIR, 755)
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
    entry({"admin", "system", "filetransfer", "settings"}, cbi("filetransfer"), _("设置"), 4)

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
    entry({"admin", "system", "filetransfer", "browse_files"}, call("action_browse_files")).leaf = true
    
    -- 日志相关
    entry({"admin", "system", "filetransfer", "get_logs"}, call("action_get_logs")).leaf = true
    entry({"admin", "system", "filetransfer", "clear_logs"}, call("action_clear_logs")).leaf = true
    entry({"admin", "system", "filetransfer", "export_logs"}, call("action_export_logs")).leaf = true
    
    -- 设置相关
    entry({"admin", "system", "filetransfer", "save_settings"}, call("action_save_settings")).leaf = true
    entry({"admin", "system", "filetransfer", "get_settings"}, call("action_get_settings")).leaf = true
    
    -- 错误日志相关
    entry({"admin", "system", "filetransfer", "log_error"}, call("action_log_error")).leaf = true
    
    -- 文件浏览相关
    entry({"admin", "system", "filetransfer", "browse_files"}, call("action_browse_files")).leaf = true
    
    -- 调试API路由（不需要认证）
    entry({"filetransfer", "debug", "log_error"}, call("action_debug_log_error")).leaf = true
    entry({"filetransfer", "debug", "get_logs"}, call("action_get_logs")).leaf = true
    entry({"filetransfer", "debug", "clear_logs"}, call("action_clear_logs")).leaf = true
    entry({"filetransfer", "debug", "export_logs"}, call("action_export_logs")).leaf = true

end

-- 文件上传处理函数
function action_upload()
    log_message("info", "开始处理文件上传请求", {
        "method=" .. (http.getenv("REQUEST_METHOD") or "unknown"),
        "content_type=" .. (http.getenv("CONTENT_TYPE") or "unknown"),
        "content_length=" .. (http.getenv("CONTENT_LENGTH") or "unknown")
    })
    
    -- 检查CSRF token
    if not check_csrf() then
        send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
        return
    end
    
    -- 检查IP白名单
    if not check_ip_whitelist() then
        send_error_response(403, "IP_BLOCKED", "IP address not in whitelist")
        return
    end
    
    -- 添加错误处理包装
    local status, err = pcall(function()
        ensure_upload_dir()
        
        -- 使用正确的文件处理方式
        local upload_info = nil
        
        -- 设置文件处理器来正确接收文件内容
        http.setfilehandler(
            function(meta, chunk, eof)
                if not upload_info then
                                    -- 初始化上传信息
                local filename = meta.file or meta.name
                log_to_file("DEBUG: meta.file=" .. tostring(meta.file) .. ", meta.name=" .. tostring(meta.name))
                if not filename then
                    log_to_file("上传文件名缺失")
                    return
                end
                    
                    filename = sanitize_filename(filename)
                    if not filename then
                        log_to_file("文件名不合法: " .. tostring(meta.name or meta.file))
                        return
                    end
                    
                    if not check_file_type(filename) then
                        log_to_file("文件类型不允许: " .. filename)
                        return
                    end
                    
                    local config = get_config()
                    local filepath = config.UPLOAD_DIR .. filename
                    local file_handle = io.open(filepath, "wb")
                    if not file_handle then
                        log_to_file("无法创建文件: " .. filepath)
                        return
                    end
                    
                    upload_info = {
                        handle = file_handle,
                        filename = filename,
                        filepath = filepath,
                        size = 0
                    }
                    
                    log_to_file("开始上传文件: " .. filename)
                end
                
                -- 写入文件块
                if chunk and upload_info and upload_info.handle then
                    upload_info.handle:write(chunk)
                    upload_info.size = upload_info.size + #chunk
                    
                    -- 检查文件大小
                    if upload_info.size > MAX_FILE_SIZE then
                        upload_info.handle:close()
                        fs.unlink(upload_info.filepath)
                        log_to_file("文件过大，上传终止: " .. upload_info.filename)
                        upload_info = nil
                        return
                    end
                end
                
                -- 文件上传完成
                if eof and upload_info and upload_info.handle then
                    upload_info.handle:close()
                    log_to_file("文件上传完成: " .. upload_info.filename .. ", 大小: " .. upload_info.size)
                    
                    -- 存储到全局变量供后续使用
                    http.context.upload_result = upload_info
                end
            end
        )
        
        -- 获取表单数据以触发文件处理
        local form_data = http.formvalue()
        
        -- 检查上传结果
        if http.context.upload_result then
            local result = http.context.upload_result
            if json then
                http.write_json({
                    status = "success", 
                    filename = result.filename,
                    path = result.filepath,
                    size = result.size
                })
            else
                http.write(string.format('{"status": "success", "filename": "%s", "path": "%s", "size": %d}',
                    result.filename, result.filepath, result.size))
            end
        else
            log_to_file("没有接收到文件上传数据")
            http.status(400, "No file uploaded")
        end
    end)
    
    if not status then
        log_to_file("文件上传处理失败: " .. err)
        http.status(500, "Internal Server Error")
    end
end

-- 文件下载处理函数
function action_download()
    local filename = http.formvalue("filename")
    if not filename then
        send_error_response(400, "MISSING_FILENAME", "Filename parameter is required")
        return
    end
    
    filename = sanitize_filename(filename)
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

-- 文件列表获取函数（优化版本）
function action_list()
    local config = get_config()
    local files = {}
    
    -- 使用 nixio.fs 替代 shell 命令提高性能
    for name in fs.dir(config.UPLOAD_DIR) do
        if name ~= "." and name ~= ".." then
            local path = config.UPLOAD_DIR .. name
            local stat = fs.stat(path)
            if stat and stat.type == "reg" then
                table.insert(files, {
                    name = name,
                    size = tostring(stat.size),
                    date = os.date("%m-%d %H:%M", stat.mtime),
                    mtime = stat.mtime
                })
            end
        end
    end
    
    send_success_response({files = files}, "File list retrieved successfully")
end

-- 备用的文件列表获取函数（如果nixio.fs不可用）
function action_list_fallback()
    local config = get_config()
    local files = {}
    local dir = io.popen("ls -la '" .. config.UPLOAD_DIR .. "'")
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
    send_success_response({files = files}, "File list retrieved successfully")
end

-- 文件删除函数
function action_delete()
    -- 检查CSRF token
    if not check_csrf() then
        send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
        return
    end
    
    local filename = http.formvalue("filename")
    if not filename then
        send_error_response(400, "MISSING_FILENAME", "Filename parameter is required")
        return
    end
    
    filename = sanitize_filename(filename)
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

-- 清空所有文件函数
function action_clear_all()
    -- 检查CSRF token
    if not check_csrf() then
        send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
        return
    end
    
    local config = get_config()
    ensure_upload_dir()
    
    local success_count = 0
    local error_count = 0
    
    -- 使用 nixio.fs 提高性能
    for name in fs.dir(config.UPLOAD_DIR) do
        if name ~= "." and name ~= ".." then
            local path = config.UPLOAD_DIR .. name
            local stat = fs.stat(path)
            if stat and stat.type == "reg" then
                if fs.unlink(path) then
                    success_count = success_count + 1
                else
                    error_count = error_count + 1
                end
            end
        end
    end
    
    local message = string.format("Cleared %d files", success_count)
    if error_count > 0 then
        message = message .. string.format(", failed to delete %d files", error_count)
        log_message("warning", "Some files failed to delete", {
            "success=" .. success_count, "errors=" .. error_count
        })
    else
        log_message("info", "All files cleared successfully", {
            "count=" .. success_count
        })
    end
    
    send_success_response({
        success_count = success_count,
        error_count = error_count
    }, message)
end

-- 安装 IPK 文件
function action_install_ipk()
    -- 检查CSRF token
    if not check_csrf() then
        send_error_response(403, "CSRF_FAILED", "CSRF token validation failed")
        return
    end
    
    -- 检查IP白名单
    if not check_ip_whitelist() then
        send_error_response(403, "IP_BLOCKED", "IP address not in whitelist")
        return
    end
    
    local filename = http.formvalue("filename")
    if not filename then
        send_error_response(400, "MISSING_FILENAME", "Filename parameter is required")
        return
    end
    
    -- 安全处理文件名
    filename = sanitize_filename(filename)
    if not filename then
        send_error_response(400, "INVALID_FILENAME", "Invalid filename")
        return
    end
    
    if not filename:match("%.ipk$") then
        send_error_response(400, "INVALID_FILE_TYPE", "File must be an IPK package")
        return
    end
    
    local config = get_config()
    local path = config.UPLOAD_DIR .. filename
    if not fs.stat(path) then
        send_error_response(404, "FILE_NOT_FOUND", "IPK file not found: " .. filename)
        return
    end
    
    -- 安装 IPK
    log_message("info", "Installing IPK package", {filename})
    local result = sys.exec("opkg install '" .. path .. "' 2>&1")
    
    if result:match("Installing") or result:match("Upgrading") or result:match("Configuring") then
        log_message("info", "IPK installed successfully", {filename, result})
        send_success_response({
            filename = filename,
            output = result
        }, "IPK package installed successfully")
    else
        log_message("error", "IPK installation failed", {filename, result})
        send_error_response(500, "INSTALL_FAILED", "Failed to install IPK package", result)
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
    if json then
        http.write_json(logs)
    else
        local json_str = '['
        for i, log in ipairs(logs) do
            if i > 1 then json_str = json_str .. ',' end
            json_str = json_str .. '"' .. log:gsub('"', '\\"') .. '"'
        end
        json_str = json_str .. ']'
        http.write(json_str)
    end
end

-- 清除日志函数
function action_clear_logs()
    local log_file = "/tmp/filetransfer.log"
    local file = io.open(log_file, "w")
    if file then
        file:write("")
        file:close()
        log_to_file("Logs cleared by user")
        if json then
            http.write_json({status = "success"})
        else
            http.write('{"status": "success"}')
        end
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
    if json then
        http.write_json({status = "success"})
    else
        http.write('{"status": "success"}')
    end
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
    
    if json then
        http.write_json(settings)
    else
        local json_str = '{'
        local first = true
        for key, value in pairs(settings) do
            if not first then json_str = json_str .. ',' end
            json_str = json_str .. '"' .. key .. '": "' .. value .. '"'
            first = false
        end
        json_str = json_str .. '}'
        http.write(json_str)
    end
end

-- 上传进度函数
function action_upload_progress()
    -- 实现上传进度跟踪
    if json then
        http.write_json({progress = 0})
    else
        http.write('{"progress": 0}')
    end
end

-- 下载进度函数
function action_download_progress()
    -- 实现下载进度跟踪
    if json then
        http.write_json({progress = 0})
    else
        http.write('{"progress": 0}')
    end
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
        if json then
            http.write_json({content = content})
        else
            http.write('{"content": "' .. content:gsub('"', '\\"') .. '"}')
        end
    else
        http.status(500, "Failed to read file")
    end
end

-- 文件浏览处理函数
function action_browse_files()
    local path = http.formvalue("path") or "/"
    local show_hidden = http.formvalue("show_hidden") == "true"
    local sort_by = http.formvalue("sort_by") or "name"
    
    -- 安全检查路径
    if not path:match("^/") then
        path = "/" .. path
    end
    
    -- 防止路径遍历攻击
    path = path:gsub("%.%./", "")
    
    local files = {}
    
    -- 使用ls命令获取文件列表
    local cmd = string.format("ls -la '%s' 2>/dev/null", path:gsub("'", "'\"'\"'"))
    local handle = io.popen(cmd)
    
    if handle then
        local first_line = true
        for line in handle:lines() do
            if not first_line then  -- 跳过第一行 "total xxx"
                local parts = {}
                for part in line:gmatch("%S+") do
                    table.insert(parts, part)
                end
                
                if #parts >= 9 then
                    local permissions = parts[1]
                    local size = tonumber(parts[5]) or 0
                    local month = parts[6]
                    local day = parts[7]
                    local time = parts[8]
                    local name = table.concat(parts, " ", 9)
                    
                    -- 跳过当前目录项
                    if name ~= "." then
                        local is_directory = permissions:sub(1,1) == "d"
                        local is_hidden = name:sub(1,1) == "."
                        
                        -- 根据设置决定是否显示隐藏文件
                        if show_hidden or not is_hidden or name == ".." then
                            local file_path
                            if name == ".." then
                                -- 上级目录路径处理
                                local parts = {}
                                for part in path:gmatch("[^/]+") do
                                    table.insert(parts, part)
                                end
                                if #parts > 0 then
                                    table.remove(parts) -- 移除最后一个部分
                                end
                                file_path = "/" .. table.concat(parts, "/")
                                if file_path == "/" then
                                    file_path = "/"
                                elseif file_path:sub(-1) == "/" and #file_path > 1 then
                                    file_path = file_path:sub(1, -2)
                                end
                            else
                                -- 普通文件或文件夹路径
                                if path:sub(-1) == "/" then
                                    file_path = path .. name
                                else
                                    file_path = path .. "/" .. name
                                end
                            end
                            
                            table.insert(files, {
                                name = name,
                                type = is_directory and "directory" or "file",
                                size = size,
                                permissions = permissions,
                                path = file_path,
                                modified = string.format("%s %s %s", month, day, time),
                                hidden = is_hidden
                            })
                        end
                    end
                end
            else
                first_line = false
            end
        end
        handle:close()
    end
    
    -- 排序文件
    if sort_by == "name" then
        table.sort(files, function(a, b)
            -- 目录优先
            if a.type ~= b.type then
                return a.type == "directory"
            end
            return a.name:lower() < b.name:lower()
        end)
    elseif sort_by == "size" then
        table.sort(files, function(a, b)
            if a.type ~= b.type then
                return a.type == "directory"
            end
            return a.size > b.size
        end)
    elseif sort_by == "date" then
        table.sort(files, function(a, b)
            if a.type ~= b.type then
                return a.type == "directory"
            end
            return a.modified > b.modified
        end)
    end
    
    log_to_file("浏览文件夹: " .. path .. " (找到 " .. #files .. " 个项目)")
    
    if json then
        http.write_json({
            status = "success",
            path = path,
            files = files,
            count = #files
        })
    else
        local json_str = '{"status": "success", "path": "' .. path .. '", "files": ['
        for i, file in ipairs(files) do
            if i > 1 then json_str = json_str .. ',' end
            json_str = json_str .. string.format(
                '{"name": "%s", "type": "%s", "size": %d, "permissions": "%s", "path": "%s", "modified": "%s", "hidden": %s}',
                file.name:gsub('"', '\\"'),
                file.type,
                file.size,
                file.permissions,
                file.path:gsub('"', '\\"'),
                file.modified,
                file.hidden and "true" or "false"
            )
        end
        json_str = json_str .. '], "count": ' .. #files .. '}'
        http.write(json_str)
    end
end

-- 错误日志处理函数
function action_log_error()
    -- 错误日志API不需要认证，用于调试
    local error_type = http.formvalue("error_type")
    local error_message = http.formvalue("error_message")
    local error_details = http.formvalue("error_details")
    local error_url = http.formvalue("error_url")
    local error_user_agent = http.formvalue("error_user_agent")
    local error_timestamp = http.formvalue("error_timestamp")
    
    if not error_type or not error_message then
        http.status(400, "Bad Request")
        return
    end
    
    -- 构建错误日志条目
    local log_entry = string.format(
        "[%s] BROWSER_ERROR: %s - %s | URL: %s | Details: %s | User-Agent: %s",
        error_timestamp or os.date("%Y-%m-%d %H:%M:%S"),
        error_type,
        error_message,
        error_url or "unknown",
        error_details or "none",
        error_user_agent or "unknown"
    )
    
    -- 记录到文件传输日志
    log_to_file(log_entry)
    
    -- 使用系统命令记录到系统日志
    local syslog_cmd = string.format("logger -t filetransfer 'Browser Error: %s - %s'", error_type, error_message)
    os.execute(syslog_cmd)
    
    if json then
        http.write_json({status = "success", message = "Error logged successfully"})
    else
        http.write('{"status": "success", "message": "Error logged successfully"}')
    end
end

-- 调试错误日志函数（不需要认证）
function action_debug_log_error()
    log_to_file("=== 调试错误日志API调用 ===")
    
    local error_type = http.formvalue("error_type") or http.formvalue("type") or "error"
    local error_message = http.formvalue("error_message") or http.formvalue("message") or ""
    local error_details = http.formvalue("error_details") or http.formvalue("details") or ""
    local error_url = http.formvalue("error_url") or http.formvalue("url") or ""
    local error_user_agent = http.getenv("HTTP_USER_AGENT") or ""
    local error_timestamp = os.date("%Y-%m-%d %H:%M:%S")
    
    if error_message == "" then
        http.header("Content-Type", "application/json")
        http.write('{"status": "error", "message": "No error message provided"}')
        return
    end
    
    -- 构建错误日志条目
    local log_entry = string.format(
        "[DEBUG-%s] %s - %s | URL: %s | Details: %s | User-Agent: %s",
        error_timestamp,
        error_type,
        error_message,
        error_url,
        error_details,
        error_user_agent
    )
    
    -- 记录到文件传输日志
    log_to_file(log_entry)
    
    -- 使用系统命令记录到系统日志
    local safe_message = error_message:gsub("'", "'\"'\"'")
    local syslog_cmd = string.format("logger -t filetransfer-debug 'Browser Error: %s - %s'", error_type, safe_message)
    os.execute(syslog_cmd)
    
    http.header("Content-Type", "application/json")
    http.write('{"status": "success", "message": "Debug error logged successfully"}')
end