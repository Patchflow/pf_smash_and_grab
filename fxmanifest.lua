game "gta5"
fx_version "cerulean"
lua54 "yes"

author "pf_smash_and_grab"
description "A smash and grab script for FiveM, allowing players to break into cars and steal items."
version "1.0.0"

shared_scripts {
  "@ox_lib/init.lua",
}

client_scripts {
  "script/client/main.lua",
}

server_scripts {
  "script/server/main.lua",
}

files {
  "script/shared/*.lua",
  "script/client/modules/*.lua"
}

dependencies {
  "ox_lib",
  "ox_target",
  "ox_inventory",
}
