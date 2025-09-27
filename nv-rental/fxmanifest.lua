fx_version 'cerulean'
games { 'gta5' }

name "rental"
author 'nv'
description 'An Advanced Car Rental System for FiveM QBCore Framework upgraged by novadev'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua', 
    'config.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

lua54 'yes'

