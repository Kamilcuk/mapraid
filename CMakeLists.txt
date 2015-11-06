cmake_minimum_required(VERSION 2.8.3)
project(mapraidgen)

add_executable(phrase-gen phrase-gen.c stamp.c)
#add_library(phrase-gen stamp.c)

add_executable(restore restore.c raid-map.c)
#add_library(restore raid-map.c)

add_executable(map-gen map-gen.c raid-map.c stamp.c)
#add_library(map-gen raid-map.c)
#add_library(map-gen stamp.c)

