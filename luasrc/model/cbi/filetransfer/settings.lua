--[[
 Copyright 2024 DustReliant
 Licensed to the public under the MIT License.
]]--

local m, s, o

m = Map("filetransfer", translate("文件传输设置"), translate("配置文件传输系统的各项参数"))

s = m:section(NamedSection, "config", "filetransfer", translate("基本设置"))

o = s:option(Value, "upload_dir", translate("上传目录"))
o.default = "/tmp/upload/"
o.description = translate("文件上传的默认目录")

o = s:option(Value, "max_file_size", translate("最大文件大小"))
o.default = "50"
o.datatype = "uinteger"
o.description = translate("单个文件的最大大小（MB）")

o = s:option(Value, "allowed_extensions", translate("允许的文件类型"))
o.default = "ipk,tar,gz,zip,txt,conf,json"
o.description = translate("允许上传的文件类型，用逗号分隔")

s = m:section(NamedSection, "config", "filetransfer", translate("日志设置"))

o = s:option(ListValue, "log_level", translate("日志级别"))
o:value("debug", translate("调试"))
o:value("info", translate("信息"))
o:value("warning", translate("警告"))
o:value("error", translate("错误"))
o.default = "info"
o.description = translate("设置日志记录的详细程度")

o = s:option(Value, "log_retention", translate("日志保留时间"))
o.default = "7"
o.datatype = "uinteger"
o.description = translate("日志保留的天数")

o = s:option(Flag, "auto_clean", translate("自动清理"))
o.default = true
o.description = translate("自动清理过期的日志文件")

s = m:section(NamedSection, "config", "filetransfer", translate("安全设置"))

o = s:option(Flag, "enable_csrf", translate("启用 CSRF 保护"))
o.default = true
o.description = translate("启用跨站请求伪造保护")

o = s:option(Flag, "enable_ssl", translate("启用 SSL"))
o.default = false
o.description = translate("启用安全套接字层加密")

o = s:option(Value, "allowed_ips", translate("允许的 IP 地址"))
o.description = translate("允许访问的 IP 地址，用逗号分隔")

return m 