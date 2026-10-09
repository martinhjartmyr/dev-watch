#!/usr/bin/env bash
pkill -x DevWatch 2>/dev/null && echo "🛑 DevWatch stopped" || echo "DevWatch is not running"
