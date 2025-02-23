local fs = require "nixio.fs"
local http = luci.http
local sys = require "luci.sys"
local csrf = require "luci.csrf"
local i18n = require "luci.i18n"

-- 安全配置常量
local CONFIG = {
    UPLOAD_DIR = "/mnt/secure_uploads",  -- 更安全的持久化目录
    MAX_SIZE = 50 * 1024 * 1024,         -- 50MB限制
    ALLOWED_TYPES = { "txt", "log", "conf", "ipk" }, -- 文件类型白名单
    LOG_FILE = "/var/log/filetransfer.log"  -- 持久化日志
}

-- 初始化安全目录
fs.mkdir(CONFIG.UPLOAD_DIR, 0750)
sys.call("chown www-data:www-data "..CONFIG.UPLOAD_DIR)

-- 日志记录函数（系统日志+文件日志）
local function log_event(action, file, status)
    local user = luci.dispatcher.context.authuser or "unknown"
    local msg = string.format(
        "用户:%s 操作:%s 文件:%s 状态:%s",
        user, action, file, status
    )
    
    -- 写入系统日志
    sys.exec("logger -t filetransfer '%s'" % msg)
    
    -- 写入文件日志
    local fd = io.open(CONFIG.LOG_FILE, "a")
    if fd then
        fd:write(os.date("[%Y-%m-%d %H:%M:%S] ")..msg.."\n")
        fd:close()
    end
end

-- 文件名消毒函数
local function sanitize_filename(name)
    return name:gsub("[^%w%.%-_]", ""):gsub("%.%.+", ".")
end

-- 原生CSRF集成 --------------------------------------------------
local ful = SimpleForm("upload", translate("文件上传"))
ful:section(SimpleSection, "", translate("上传文件到安全目录"))
ful.reset = false
ful.submit = false

-- 添加CSRF令牌
ful:section(SimpleSection).template = "cbi/csrftoken"

-- 文件上传处理
local fu = ful:field(FileUpload, "ulfile")
fu.template = "cbi/other_upload"

-- 安全上传处理
http.setfilehandler(function(meta, chunk, eof)
    if not csrf.verify() then
        http.status(403, "CSRF验证失败")
        log_event("UPLOAD", "N/A", "CSRF_FAIL")
        return
    end

    local filename = sanitize_filename(meta and meta.file or "")
    local filepath = CONFIG.UPLOAD_DIR.."/"..filename
    
    -- 类型验证
    local ext = filename:match("%.(%w+)$")
    if not ext or not table.contains(CONFIG.ALLOWED_TYPES, ext:lower()) then
        log_event("UPLOAD", filename, "TYPE_BLOCKED")
        http.status(415, "不支持的文件类型")
        return
    end

    -- 大小验证
    if meta and meta.size > CONFIG.MAX_SIZE then
        log_event("UPLOAD", filename, "SIZE_EXCEED")
        http.status(413, "文件过大")
        return
    end

    -- 分块写入
    local fd
    if meta and not fd then
        fd = nixio.open(filepath, "w", 0600)
        if not fd then
            log_event("UPLOAD", filename, "OPEN_FAIL")
            return
        end
        fd:lock("excl")
    end

    if chunk and fd then
        fd:write(chunk)
    end

    if eof and fd then
        fd:close()
        log_event("UPLOAD", filename, "SUCCESS")
    end
end)

-- 安全下载处理 --------------------------------------------------
local fdl = SimpleForm("download", translate("文件下载"))
fdl:section(SimpleSection, "", translate("从安全目录下载文件"))
fdl.reset = false
fdl.submit = false

-- 下载路径输入
local dl = fdl:field(Value, "dlfile", translate("文件路径"))
dl.template = "cbi/other_download"

function fdl.handle(self, state, data)
    if state == FORM_VALID then
        local path = data.dlfile
        local safe_path = CONFIG.UPLOAD_DIR.."/"..sanitize_filename(path)
        
        if not fs.stat(safe_path) then
            log_event("DOWNLOAD", path, "NOT_FOUND")
            return nil, "文件不存在"
        end

        http.header('Content-Disposition', 'attachment; filename="%s"'%fs.basename(safe_path))
        http.prepare_content(fs.mimetype(safe_path) or "application/octet-stream")
        
        local fd = nixio.open(safe_path, "r")
        if fd then
            fd:sendfile(http.getsocket())
            fd:close()
            log_event("DOWNLOAD", path, "SUCCESS")
            return true
        end
    end
end

-- 文件管理模块 --------------------------------------------------
local file_list = {}
for f in fs.glob(CONFIG.UPLOAD_DIR.."/*") do
    local attr = fs.stat(f)
    if attr then
        table.insert(file_list, {
            name = fs.basename(f),
            size = attr.size,
            mtime = os.date("%Y-%m-%d %H:%M:%S", attr.mtime)
        })
    end
end

local flist = SimpleForm("filelist", translate("文件管理"))
local fl = flist:section(Table, file_list)

fl:option(DummyValue, "name", translate("文件名"))
fl:option(DummyValue, "size", translate("大小"))
fl:option(DummyValue, "mtime", translate("修改时间"))

-- 安全安装按钮
local btn_install = fl:option(Button, "install", translate("安装"))
btn_install.render = function(self, section, scope)
    if file_list[section].name:match("%.ipk$") then
        Button.render(self, section, scope)
    else
        scope.display = "none"
    end
end

btn_install.write = function(self, section)
    local fname = file_list[section].name
    local cmd = "opkg verify %s/%s && opkg install %s/%s" % {
        CONFIG.UPLOAD_DIR, fname,
        CONFIG.UPLOAD_DIR, fname
    }
    
    local res = sys.call(cmd)
    if res == 0 then
        log_event("INSTALL", fname, "SUCCESS")
        return true
    else
        log_event("INSTALL", fname, "FAILED")
        return false
    end
end

-- 日志查看模块 --------------------------------------------------
local log_form = SimpleForm("log", translate("操作日志"))
local log_view = log_form:section(SimpleSection)
local log_content = log_view:option(TextValue, "_log")
log_content.rows = 20
log_content.readonly = true
log_content.cfgvalue = function()
    return fs.readfile(CONFIG.LOG_FILE) or ""
end

return ful, fdl, flist, log_form