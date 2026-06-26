#!/usr/bin/env sh

name="$1"
name=${name%.exe}

printf '%s' "$name"
