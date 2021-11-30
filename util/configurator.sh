#!/usr/bin/env bash
cd "util"
pub get
cd ..
dart ./util/lib/main.dart "$@"
