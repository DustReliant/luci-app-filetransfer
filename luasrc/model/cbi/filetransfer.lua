--[[
 Copyright 2024 DustReliant
 Licensed to the public under the MIT License.
]]--

local m, s, o

m = Map("filetransfer", translate("File Transfer Settings"), translate("Configure file transfer system parameters"))

s = m:section(NamedSection, "config", "filetransfer", translate("Basic Settings"))

o = s:option(Value, "upload_dir", translate("Upload Directory"))
o.default = "/tmp/upload"
o.description = translate("Default directory for file uploads")

o = s:option(Value, "max_file_size", translate("Maximum File Size"))
o.default = "50"
o.datatype = "uinteger"
o.description = translate("Maximum size of a single file (MB)")

o = s:option(Value, "allowed_extensions", translate("Allowed File Types"))
o.default = "ipk,tar,gz,zip,txt,conf,json"
o.description = translate("Allowed file types for upload, separated by commas")

s = m:section(NamedSection, "config", "filetransfer", translate("Log Settings"))

o = s:option(ListValue, "log_level", translate("Log Level"))
o:value("debug", translate("Debug"))
o:value("info", translate("Info"))
o:value("warning", translate("Warning"))
o:value("error", translate("Error"))
o.default = "info"
o.description = translate("Set the detail level of log records")

o = s:option(Value, "log_retention", translate("Log Retention"))
o.default = "30"
o.datatype = "uinteger"
o.description = translate("Number of days to retain logs")

o = s:option(Flag, "auto_clean", translate("Auto Clean"))
o.default = "1"
o.description = translate("Automatically clean expired log files")

s = m:section(NamedSection, "config", "filetransfer", translate("Security Settings"))

o = s:option(Flag, "enable_csrf", translate("Enable CSRF Protection"))
o.default = "1"
o.description = translate("Enable Cross-Site Request Forgery protection")

o = s:option(Flag, "enable_ssl", translate("Enable SSL"))
o.default = "0"
o.description = translate("Enable Secure Socket Layer encryption")

o = s:option(Value, "allowed_ips", translate("Allowed IP Addresses"))
o.description = translate("Allowed IP addresses for access, separated by commas")

return m 