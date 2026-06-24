fx_version 'cerulean'
game 'gta5'

name 'Admin Web Panel'
description 'Control your FiveM server from a web browser'
author 'AdminPanel'
version '1.0.0'

server_scripts {
    'server/config.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

http_files {
    'web/index.html'
}
