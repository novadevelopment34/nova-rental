fx_version 'cerulean'
games { 'gta5' }

name "teezy-Carrental"
author 'Teezy Core'
description 'An Advanced Car Rental System for FiveM QBCore Framework Originally Made by NaorNC'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua', -- ox_lib'i ekledik ✅
    'config.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

lua54 'yes'
