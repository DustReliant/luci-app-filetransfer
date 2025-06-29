--
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"

m = Map("filetransfer", translate("Server Logs"))
s = m:section(TypedSection, "filetransfer")
m.pageaction = false  -- 不显示保存和应用按钮
s.anonymous = true
s.addremove = false

log = s:option(TextValue, "clog")
log.readonly = true
log.pollcheck = true
log.template = "cbi/log"
log.description = translate("")
log.rows = 29



return m