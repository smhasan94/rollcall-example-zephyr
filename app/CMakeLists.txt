# SPDX-License-Identifier: Apache-2.0
#
# A minimal application built with sysbuild and MCUboot, after Zephyr's
# samples/sysbuild/with_mcuboot (Apache-2.0, Copyright (c) 2022 Nordic Semiconductor).

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(rollcall_example)

# Built through sysbuild only, so MCUboot is always part of the product.
test_sysbuild()

target_sources(app PRIVATE src/main.c)
